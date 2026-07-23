import 'dart:async';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import '../firebase_options.dart';
import '../models/models.dart';

/// All online functionality: anonymous auth, profiles, rooms,
/// quick-match queue, and the server-synced clock used for
/// lag-fair round timing.
class FirebaseService {
  FirebaseService._();
  static final FirebaseService instance = FirebaseService._();

  late final FirebaseDatabase _db;

  /// Always the CURRENT signed-in user — never a cached one. Reflex used
  /// to cache the anonymous uid from startup, which went stale the moment
  /// the player signed in with Google/email, breaking friend rooms
  /// ("room is full / doesn't exist"). Reading it live keeps reflex on
  /// the same identity as the rest of the app.
  String get uid => FirebaseAuth.instance.currentUser?.uid ?? '';
  int _serverOffsetMs = 0;
  bool ready = false;

  /// Server-synchronized clock (epoch ms). Both players use this,
  /// so rounds fire at the same real moment on both phones.
  int nowMs() => DateTime.now().millisecondsSinceEpoch + _serverOffsetMs;

  Future<void> init() async {
    // Pin the regional database URL (asia-southeast1) — the plain
    // `.instance` getter targets the US endpoint and hangs.
    _db = FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: DefaultFirebaseOptions.currentPlatform.databaseURL);
    // Only fall back to anonymous auth if nobody is signed in yet — never
    // overwrite an existing (Google/email) session with a throwaway anon
    // one. uid is read live via the getter above.
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }
    _db.ref('.info/serverTimeOffset').onValue.listen((e) {
      _serverOffsetMs = (e.snapshot.value as num?)?.toInt() ?? 0;
    });
    ready = true;
  }

  // ------------------------- profile -------------------------

  Future<PlayerProfile> loadProfile() async {
    final snap = await _db.ref('users/$uid').get();
    return PlayerProfile.fromMap(uid, snap.value as Map<dynamic, dynamic>?);
  }

  Future<void> saveProfile(PlayerProfile p) =>
      _db.ref('users/$uid').set(p.toMap());

  // ------------------------- rooms -------------------------

  static const _codeChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  String _newCode() {
    final r = Random.secure();
    return List.generate(6, (_) => _codeChars[r.nextInt(_codeChars.length)])
        .join();
  }

  DatabaseReference roomRef(String code) => _db.ref('rooms/$code');

  Future<String> createRoom(String name, {bool quick = false}) async {
    final code = _newCode();
    await roomRef(code).set({
      'host': uid,
      'state': 'waiting',
      'quick': quick,
      'target': 4,
      'createdAt': ServerValue.timestamp,
      'players': {
        uid: {'name': name, 'score': 0, 'connected': true}
      },
    });
    roomRef(code).child('players/$uid/connected').onDisconnect().set(false);
    return code;
  }

  /// Returns null on success, or an error message.
  Future<String?> joinRoom(String code, String name) async {
    code = code.trim().toUpperCase();
    final ref = roomRef(code);
    // Fetch from the server FIRST. Without this, the joiner's device has
    // never cached rooms/$code, so runTransaction is first handed a null
    // local value and aborts before the SDK ever consults the server —
    // the "room is full / not created" false-negative even when the room
    // exists with a free seat. The get() warms the cache with real data.
    final pre = await ref.get();
    final preData = pre.value as Map<dynamic, dynamic>?;
    if (preData == null) {
      return 'Room not found — double-check the code.';
    }
    final guest = preData['guest'];
    if (guest != null && guest != uid) {
      return 'That room is already full.';
    }
    if (preData['state'] != 'waiting') {
      return 'That match already started.';
    }
    // Direct guarded write. A private code is shared with ONE rival, so a
    // true two-joiner race is negligible — and a runTransaction here was
    // aborting on the transient null local value the SDK hands it first,
    // producing "room filled/closed" even for a wide-open room.
    try {
      final updates = <String, Object?>{
        'guest': uid,
        'players/$uid': {'name': name, 'score': 0, 'connected': true},
      };
      if (preData['quick'] == true) updates['state'] = 'playing';
      await ref.update(updates).timeout(const Duration(seconds: 8));
    } catch (_) {
      return 'Could not reach the room — check your internet and retry.';
    }
    ref.child('players/$uid/connected').onDisconnect().set(false);
    return null;
  }

  /// Re-asserts the local player as online in [code]. Call on app-resume so a
  /// quick trip to WhatsApp (background, not killed) doesn't leave the player
  /// showing "offline" — the OS suspends the socket and onDisconnect fires,
  /// so we set connected back to true and re-arm the disconnect handler.
  Future<void> keepAlive(String code) async {
    if (uid.isEmpty) return;
    try {
      final ref = roomRef(code).child('players/$uid/connected');
      await ref.set(true).timeout(const Duration(seconds: 8));
      ref.onDisconnect().set(false);
    } catch (_) {/* best-effort */}
  }

  Stream<Room?> roomStream(String code) => roomRef(code).onValue.map((e) =>
      Room.fromSnapshot(code, e.snapshot.value as Map<dynamic, dynamic>?));

  Future<void> startMatch(String code) =>
      roomRef(code).update({'state': 'playing'});

  Future<void> leaveRoom(String code) async {
    await roomRef(code).child('players/$uid/connected').set(false);
    // Host abandoning a waiting room deletes it.
    final snap = await roomRef(code).get();
    final data = snap.value as Map<dynamic, dynamic>?;
    if (data != null && data['host'] == uid && data['state'] == 'waiting') {
      await roomRef(code).remove();
      await _db.ref('matchmaking/$code').remove();
    }
  }

  // ------------------------- round sync -------------------------

  Future<void> publishRound(String code, RoundSpec spec) =>
      roomRef(code).update({
        'round': spec.toMap(),
        'results': null,
        'lastRound': null,
      });

  Future<void> submitResult(String code, int timeMs) =>
      roomRef(code).child('results/$uid').set({'t': timeMs});

  /// Host resolves the round: writes scores + lastRound summary,
  /// then either finishes the match or clears for the next round.
  Future<void> resolveRound({
    required String code,
    required Room room,
    required Map<String, int> newScores,
    required String? roundWinner,
    required Map<String, int> times,
  }) async {
    final target = room.targetScore;
    String? matchWinner;
    for (final e in newScores.entries) {
      if (e.value >= target) matchWinner = e.key;
    }
    final updates = <String, dynamic>{
      'lastRound': {
        'i': room.currentRound?.index ?? 0,
        'winner': roundWinner,
        'times': times,
      },
      'round': null,
      'results': null,
    };
    for (final e in newScores.entries) {
      updates['players/${e.key}/score'] = e.value;
    }
    if (matchWinner != null) {
      updates['state'] = 'done';
      updates['winner'] = matchWinner;
    }
    await roomRef(code).update(updates);
  }

  /// Rematch: reset the finished room back to playing state.
  Future<void> rematch(String code) async {
    final snap = await roomRef(code).get();
    final data = snap.value as Map<dynamic, dynamic>?;
    if (data == null) return;
    final players = Map<dynamic, dynamic>.from(data['players'] as Map? ?? {});
    final updates = <String, dynamic>{
      'state': 'playing',
      'winner': null,
      'round': null,
      'results': null,
      'lastRound': null,
    };
    for (final k in players.keys) {
      updates['players/$k/score'] = 0;
    }
    await roomRef(code).update(updates);
  }

  // ------------------------- quick match -------------------------

  /// Finds an open quick-match room to join, or creates one and
  /// waits. Returns the room code either way.
  ///
  /// Deadlock-proof: after hosting, we keep watching the matchmaking
  /// index for ~12s. If another host's entry is OLDER than ours (tie
  /// broken by code), WE migrate into their room and tear ours down —
  /// so when two players search simultaneously and both host, exactly
  /// one of them is obliged to move. No more "two people waiting at
  /// each other forever".
  Future<String> quickMatch(String name) async {
    Future<String?> tryJoinExisting({int? myCreatedAt, String? myCode}) async {
      final snap = await _db.ref('matchmaking').get();
      final entries = snap.value as Map<dynamic, dynamic>?;
      if (entries == null) return null;
      // oldest first — deterministic direction of migration
      final list = entries.entries.toList()
        ..sort((a, b) {
          final at = ((a.value as Map?)?['createdAt'] as num?) ?? 0;
          final bt = ((b.value as Map?)?['createdAt'] as num?) ?? 0;
          final c = at.compareTo(bt);
          return c != 0 ? c : '${a.key}'.compareTo('${b.key}');
        });
      for (final e in list) {
        final code = e.key as String;
        final m = e.value as Map?;
        if (m?['host'] == uid || code == myCode) continue;
        // only migrate towards entries older than my own
        if (myCreatedAt != null) {
          final theirs = (m?['createdAt'] as num?)?.toInt() ?? 0;
          final older = theirs < myCreatedAt ||
              (theirs == myCreatedAt && code.compareTo(myCode ?? '') < 0);
          if (!older) continue;
        }
        final err = await joinRoom(code, name);
        await _db.ref('matchmaking/$code').remove();
        if (err == null) return code;
      }
      return null;
    }

    // 1) fast path: someone is already waiting
    final joined = await tryJoinExisting();
    if (joined != null) return joined;

    // 2) host a quick room + register in the index
    final code = await createRoom(name, quick: true);
    final entryRef = _db.ref('matchmaking/$code');
    final createdAt = DateTime.now().millisecondsSinceEpoch + _serverOffsetMs;
    await entryRef.set({'host': uid, 'createdAt': createdAt});
    entryRef.onDisconnect().remove();

    // 3) anti-deadlock watch: for ~12s, if an OLDER host appears
    //    (simultaneous search), migrate into their room instead.
    for (var i = 0; i < 4; i++) {
      await Future.delayed(const Duration(seconds: 3));
      // someone may have already joined MY room — then stay put
      final g = await roomRef(code).child('guest').get();
      if (g.value != null) return code;
      final migrated =
          await tryJoinExisting(myCreatedAt: createdAt, myCode: code);
      if (migrated != null) {
        await entryRef.remove();
        await roomRef(code).remove();
        return migrated;
      }
    }
    return code; // keep waiting in the lobby as host
  }

  Future<void> cancelQuickMatch(String code) async {
    await _db.ref('matchmaking/$code').remove();
    await leaveRoom(code);
  }

  // ------------------------- post-match stats -------------------------

  Future<PlayerProfile> recordMatch({
    required PlayerProfile profile,
    required bool won,
    required int roundsWon,
  }) async {
    if (won) {
      profile.wins++;
      profile.streak++;
      profile.bestStreak = max(profile.bestStreak, profile.streak);
      profile.xp += 100 + roundsWon * 10 + min(profile.streak * 15, 150);
    } else {
      profile.losses++;
      profile.streak = 0;
      profile.xp += roundsWon * 10 + 15; // effort XP
    }
    await saveProfile(profile);
    return profile;
  }
}
