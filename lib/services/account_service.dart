import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import '../core/state.dart';
import '../daily_challenge/daily_bank.dart';
import '../engine/arena_game_catalog.dart';
import '../engine/banks.dart';
import '../engine/event_calendar.dart';

import '../firebase_options.dart';

const _netTimeout = Duration(seconds: 12);

class CompetitionAccess {
  final bool allowed;
  final String? message;
  final int? startsAt;
  final int? lobbyEndsAt;

  const CompetitionAccess({
    required this.allowed,
    this.message,
    this.startsAt,
    this.lobbyEndsAt,
  });
}

List<String> arenaPlayerNames(dynamic rawPlayers) {
  final players = rawPlayers as Map?;
  if (players == null) return const <String>[];
  return players.entries.map((entry) {
    final value = entry.value;
    if (value is Map) {
      final username = '${value['username'] ?? ''}'.trim();
      if (username.isNotEmpty) return username;
      final name = '${value['name'] ?? ''}'.trim();
      if (name.isNotEmpty) return name;
    }
    // Backward compatibility for arenas created before registrations moved
    // from mutable usernames to stable Firebase auth UIDs.
    return '${entry.key}';
  }).toList();
}

bool arenaHasRegistered(
  Map<String, dynamic> event, {
  required String? uid,
  required String username,
}) {
  final players = event['players'] as Map?;
  if (players == null) return false;
  if (uid != null && uid.isNotEmpty && players.containsKey(uid)) return true;
  if (username.isNotEmpty && players.containsKey(username)) return true;
  return players.values.any(
    (value) => value is Map && value['username'] == username,
  );
}

int arenaPrizePool(Map<String, dynamic> event) {
  final fee = (event['fee'] as num?)?.toInt() ?? 0;
  final entrants = (event['players'] as Map?)?.length ?? 0;
  return fee * max(entrants, 2);
}

bool arenaWasCreatedBy(Map<String, dynamic> event, String? uid) =>
    uid != null &&
    uid.isNotEmpty &&
    (event['hostUid'] == uid || event['createdByUid'] == uid);

/// ------------------------------------------------------------------
/// RTDB LIST-COERCION GUARDS.
/// Firebase Realtime Database silently converts children stored under
/// sequential numeric keys ("0","1","2"…) into a JSON *array*, so a
/// node you wrote as a Map can come back as a List. Casting it with
/// `as Map?` then yields null and sync silently dies — the exact bug
/// behind "opponent's move never shows up". ALWAYS read indexed
/// collections through these helpers.
/// ------------------------------------------------------------------
dynamic idxValue(dynamic node, int i) {
  if (node == null) return null;
  if (node is List) return (i >= 0 && i < node.length) ? node[i] : null;
  if (node is Map) return node['m$i'] ?? node['t$i'] ?? node['$i'];
  return null;
}

int idxLen(dynamic node) {
  if (node == null) return 0;
  if (node is List) {
    var n = 0;
    for (final v in node) {
      if (v != null) n++;
    }
    return n;
  }
  if (node is Map) return node.length;
  return 0;
}


/// Accounts, unique usernames, social graph and events.
/// Every method degrades gracefully when Firebase isn't configured —
/// the app then runs in guest mode with local data.
class AccountService {
  AccountService._();
  static final AccountService instance = AccountService._();

  bool get online => Firebase.apps.isNotEmpty;
  FirebaseAuth get _auth => FirebaseAuth.instance;

  /// Always pin the regional database URL — the plain `.instance`
  /// getter falls back to the (wrong) US endpoint and hangs.
  FirebaseDatabase get _db => FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: DefaultFirebaseOptions.currentPlatform.databaseURL);

  String? get uid => online ? _auth.currentUser?.uid : null;

  /// Pulls a returning user's cloud profile down into local state so
  /// they land straight on the dashboard with their real username,
  /// name, elo, contest rating and XP — instead of the app treating
  /// this device's (possibly reset/fresh) local data as the truth.
  Future<void> _restoreProfile() async {
    if (uid == null) return;
    try {
      final snap = await _db.ref('profiles/$uid').get().timeout(_netTimeout);
      final m = snap.value as Map<dynamic, dynamic>?;
      if (m == null) return;
      final a = AppData.i;
      final username = m['username'] as String?;
      if (username != null && username.isNotEmpty) a.username = username;
      final name = m['name'] as String?;
      if (name != null && name.isNotEmpty) a.name = name;
      final bio = m['bio'] as String?;
      if (bio != null) a.bio = bio;
      a.elo = (m['elo'] as num?)?.toInt() ?? a.elo;
      a.contestRating =
          (m['contestRating'] as num?)?.toInt() ?? a.contestRating;
      a.xp = (m['xp'] as num?)?.toInt() ?? a.xp;
      // Restore the under-12 zone: a kid account that signed out must come
      // back into MYNDASH KIDS, not the adult app.
      a.kidMode = m['kids'] == true;
      await a.save();
      // Restore the saved profile photo — kept in a separate avatars/{uid}
      // node (NOT the profile) so leaderboard/profile reads stay light.
      await _restoreAvatar();
    } catch (_) {/* best-effort — worst case they just re-claim locally */}
  }

  /// Uploads the profile photo bytes as base64 to avatars/{uid} so it
  /// survives sign-out and follows the account to a new device. Takes raw
  /// bytes (not a file path) so it works on web too, where there's no
  /// dart:io File to read a picked image back from.
  Future<void> saveAvatar(Uint8List bytes) async {
    if (!online || uid == null) return;
    // image_picker already downscales; guard against oversized files.
    if (bytes.length > 400 * 1024) return;
    try {
      await _db
          .ref('avatars/$uid')
          .set(base64Encode(bytes))
          .timeout(_netTimeout);
    } catch (_) {/* keep the local copy regardless */}
  }

  Future<void> _restoreAvatar() async {
    if (uid == null) return;
    try {
      final snap = await _db.ref('avatars/$uid').get().timeout(_netTimeout);
      final av = snap.value as String?;
      if (av == null || av.isEmpty) return;
      AppData.i.avatarB64 = av;
      await AppData.i.save();
    } catch (_) {/* keep whatever local avatar we have */}
  }

  // ============================ AUTH ============================

  /// Returns (error, isNewUser). Google auth is create-or-sign-in
  /// transparently on Firebase's side, so "Create account" vs "Sign in"
  /// always lands the user in their real (existing or new) account.
  Future<(String?, bool)> signInGoogle() async {
    if (!online)
      return ('No internet connection — connect and try again.', false);
    try {
      final UserCredential res;
      if (kIsWeb) {
        // WEB: use Firebase's own popup handler. The Google OAuth screen is
        // served from the Firebase authDomain (…firebaseapp.com), so Google
        // only ever sees THAT as the JavaScript origin — which is already
        // authorised. Our custom domain (myndash.online) just needs to be in
        // Firebase → Auth → Settings → Authorized domains. This sidesteps the
        // "Error 400: origin_mismatch" the google_sign_in (GIS) flow throws
        // when the custom origin isn't registered on the OAuth client.
        final provider = GoogleAuthProvider()
          ..setCustomParameters({'prompt': 'select_account'});
        res = await _auth.signInWithPopup(provider);
      } else {
        // MOBILE: native Google Sign-In (reads the client id from
        // google-services.json / plist).
        final g = await GoogleSignIn().signIn();
        if (g == null) return ('Cancelled.', false);
        final t = await g.authentication;
        final cred = GoogleAuthProvider.credential(
            idToken: t.idToken, accessToken: t.accessToken);
        res = await _auth.signInWithCredential(cred);
      }
      AppData.i.authMethod = 'google';
      AppData.i.name = res.user?.displayName ?? AppData.i.name;
      await AppData.i.save();
      final isNewUser = res.additionalUserInfo?.isNewUser ?? false;
      if (!isNewUser) await _restoreProfile();
      return (null, isNewUser);
    } on FirebaseAuthException catch (e) {
      debugPrint('Google sign-in FirebaseAuthException: ${e.code} ${e.message}');
      if (e.code == 'popup-closed-by-user' ||
          e.code == 'cancelled-popup-request' ||
          e.code == 'user-cancelled') {
        return ('Cancelled.', false);
      }
      if (e.code == 'unauthorized-domain') {
        return (
          'This site isn\'t authorised for Google sign-in yet. '
              'Add this domain in Firebase → Authentication → Authorized domains.',
          false
        );
      }
      return ('Google sign-in failed. Try again in a moment.', false);
    } catch (e) {
      debugPrint('Google sign-in failed: $e');
      return (
        kIsWeb
            ? 'Google sign-in failed. Try again in a moment.'
            : 'Google sign-in failed. Try again, or sign in with email instead.',
        false
      );
    }
  }

  /// Create-account flow for email. If the email is already registered,
  /// falls back to signing in with the same credentials instead of
  /// erroring out — so picking "Create account" by mistake still gets
  /// a returning user straight into their real account.
  /// Returns (error, isNewUser).
  Future<(String?, bool)> signUpOrSignInEmail(String email, String pass) async {
    if (!online)
      return ('No internet connection — connect and try again.', false);
    try {
      final res = await _auth.createUserWithEmailAndPassword(
          email: email, password: pass);
      await res.user?.sendEmailVerification();
      AppData.i.authMethod = 'email';
      await AppData.i.save();
      return (null, true);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        final signInErr = await signInEmail(email, pass);
        return (
          signInErr == null
              ? null
              : 'This email already has an account. $signInErr',
          false
        );
      }
      return (
        switch (e.code) {
          'weak-password' => 'Password too weak (min 6 characters).',
          'invalid-email' => 'That email looks invalid.',
          _ => 'Sign-up failed — please try again.',
        },
        false
      );
    }
  }

  Future<bool> isEmailVerified() async {
    if (!online) return false;
    await _auth.currentUser?.reload();
    return _auth.currentUser?.emailVerified ?? false;
  }

  Future<String?> resendVerification() async {
    try {
      await _auth.currentUser?.sendEmailVerification();
      return null;
    } catch (e) {
      debugPrint('resendVerification failed: $e');
      return 'Could not resend — try again in a moment.';
    }
  }

  Future<String?> signInEmail(String email, String pass) async {
    if (!online) return 'No internet connection — connect and try again.';
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: pass);
      AppData.i.authMethod = 'email';
      await AppData.i.save();
      await _restoreProfile();
      return null;
    } on FirebaseAuthException catch (e) {
      return switch (e.code) {
        'user-not-found' => 'No account with that email.',
        'wrong-password' || 'invalid-credential' => 'Wrong password.',
        'operation-not-allowed' =>
          'Email sign-in isn\'t available right now — try Google sign-in instead.',
        _ => 'Sign-in failed — please try again.',
      };
    }
  }

  /// Phone OTP step 1 — sends the SMS. Returns error or null;
  /// [onCodeSent] gives the verificationId for step 2.
  Future<String?> startPhoneAuth(
      String phone, void Function(String verificationId) onCodeSent) async {
    if (!online) return 'No internet connection — connect and try again.';
    final completer = Completer<String?>();
    await _auth.verifyPhoneNumber(
      phoneNumber: phone,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (cred) async {
        await _auth.signInWithCredential(cred);
        if (!completer.isCompleted) completer.complete(null);
      },
      verificationFailed: (e) {
        if (!completer.isCompleted) {
          completer.complete(
              'Phone verification failed — check the number and try again.');
        }
      },
      codeSent: (id, _) {
        onCodeSent(id);
        if (!completer.isCompleted) completer.complete(null);
      },
      codeAutoRetrievalTimeout: (_) {},
    );
    return completer.future;
  }

  /// Phone OTP step 2 — verify the 6-digit code. Returns (error, isNewUser).
  /// Phone auth is also create-or-sign-in transparently: an already
  /// registered number just signs straight into its existing account.
  Future<(String?, bool)> confirmOtp(String verificationId, String code) async {
    try {
      final cred = PhoneAuthProvider.credential(
          verificationId: verificationId, smsCode: code);
      final res = await _auth.signInWithCredential(cred);
      AppData.i.authMethod = 'phone';
      await AppData.i.save();
      final isNewUser = res.additionalUserInfo?.isNewUser ?? false;
      if (!isNewUser) await _restoreProfile();
      return (null, isNewUser);
    } catch (_) {
      return ('Wrong or expired OTP.', false);
    }
  }

  // ======================= UNIQUE USERNAMES =======================

  /// Instagram-style instant availability check: one O(1) key lookup
  /// against the usernames index, debounced by the UI while typing.
  /// Returns: 'available' | 'taken' | 'offline' | error message.
  Future<String> checkUsernameAvailable(String name) async {
    name = name.trim().toLowerCase();
    if (!AppData.usernameRx.hasMatch(name)) return 'invalid';
    if (!online || uid == null) return 'offline';
    try {
      final snap = await _db.ref('usernames/$name').get().timeout(_netTimeout);
      if (snap.value == null || snap.value == uid) return 'available';
      return 'taken';
    } catch (_) {
      return 'Could not check that name — check your connection and try again.';
    }
  }

  /// Claims [name] globally (lowercased). Returns error or null.
  /// Rules: 6–20 chars, a-z 0-9 _, unique across all users.
  /// The claim itself is an atomic transaction, so two people racing
  /// for the same handle can never both win.
  Future<String?> claimUsername(String name) async {
    name = name.trim().toLowerCase();
    if (!AppData.usernameRx.hasMatch(name)) {
      return 'Use 6–20 characters: letters, numbers, underscore.';
    }
    if (!online || uid == null) {
      // guest mode — local only
      AppData.i.username = name;
      AppData.i.usernameChangedAt = DateTime.now().toIso8601String();
      await AppData.i.save();
      return null;
    }
    final ref = _db.ref('usernames/$name');
    final TransactionResult result;
    try {
      result = await ref.runTransaction((raw) {
        if (raw != null && raw != uid) return Transaction.abort();
        return Transaction.success(uid);
      }).timeout(const Duration(seconds: 8));
    } catch (_) {
      return 'Connection timed out — check your internet and try again.';
    }
    if (!result.committed) return 'That username is taken — try another.';
    final old = AppData.i.username;
    try {
      if (old.isNotEmpty && old != name) {
        await _db.ref('usernames/$old').remove().timeout(_netTimeout);
      }
      await _db.ref('profiles/$uid').update({
        'username': name,
        'name': AppData.i.name,
        'elo': AppData.i.elo,
        'contestRating': AppData.i.contestRating,
      }).timeout(_netTimeout);
    } catch (_) {/* profile sync is best-effort */}
    AppData.i.username = name;
    AppData.i.usernameChangedAt = DateTime.now().toIso8601String();
    await AppData.i.save();
    return null;
  }

  // ======================= PUBLIC PROFILES =======================

  /// Pushes the user's public stats to /profiles/{uid}. Call after
  /// matches and rating changes so search/leaderboard stay fresh.
  Future<void> updatePublicProfile() async {
    if (!online || uid == null) return;
    final a = AppData.i;
    if (a.username.isEmpty) return;
    try {
      final prefs = a.publicPrefs;
      await _db.ref('profiles/$uid').update({
        'username': a.username,
        'name': a.name,
        'bio': a.bio.isEmpty ? null : a.bio,
        // under-12 flag so a kid account comes back into MYNDASH KIDS after a
        // sign-out (restored in _restoreProfile); null keeps adults clean.
        'kids': a.kidMode ? true : null,
        // users choose what the world sees — off = removed from cloud
        'elo': prefs['elo'] == false ? null : a.elo,
        'contestRating': a.contestRating, // leaderboards need this
        'xp': a.xp,
        'streak': prefs['streak'] == false ? null : a.streak,
        'college': prefs['orgs'] == false ? null : a.college,
        'company': prefs['orgs'] == false ? null : a.company,
        'recent': prefs['matches'] == false
            ? null
            : a.matches
                .take(5)
                .map((m) => {
                      'mode': m['mode'],
                      'result': m['result'],
                      'delta': m['delta'],
                      'date': m['date'],
                    })
                .toList(),
        'updatedAt': ServerValue.timestamp,
      }).timeout(_netTimeout);
    } catch (_) {/* best-effort */}
    // keep squad / college / company member stats fresh too
    syncMemberships();
  }

  /// Prefix search on the /usernames index (Instagram-style autocomplete).
  /// Returns username -> uid pairs, max 8, alphabetical.
  Future<List<MapEntry<String, String>>> searchUsernames(String prefix) async {
    prefix = prefix.trim().toLowerCase();
    if (prefix.isEmpty || !online) return [];
    try {
      final snap = await _db
          .ref('usernames')
          .orderByKey()
          .startAt(prefix)
          .endAt('$prefix\uf8ff')
          .limitToFirst(8)
          .get()
          .timeout(_netTimeout);
      final m = snap.value as Map<dynamic, dynamic>?;
      if (m == null) return [];
      final out = m.entries
          .map((e) => MapEntry('${e.key}', '${e.value}'))
          .toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      return out;
    } catch (_) {
      return [];
    }
  }

  /// Loads another player's public profile from /profiles/{uid}.
  Future<Map<String, dynamic>?> fetchProfile(String targetUid) async {
    if (!online) return null;
    try {
      final snap =
          await _db.ref('profiles/$targetUid').get().timeout(_netTimeout);
      final m = snap.value as Map<dynamic, dynamic>?;
      if (m == null) return null;
      return Map<String, dynamic>.from(m);
    } catch (_) {
      return null;
    }
  }

  /// Top players platform-wide by contest rating (highest first). Pulls
  /// up to 200 so the whole roster (all bots + humans) is browsable via
  /// the leaderboard's own pagination, not capped at a token 30.
  Future<List<Map<String, dynamic>>?> fetchLeaderboard() async {
    if (!online) return null;
    try {
      final snap = await _db
          .ref('profiles')
          .orderByChild('contestRating')
          .limitToLast(200)
          .get()
          .timeout(_netTimeout);
      final m = snap.value as Map<dynamic, dynamic>?;
      if (m == null) return [];
      final out = <Map<String, dynamic>>[];
      m.forEach((key, value) {
        final p = Map<String, dynamic>.from(value as Map);
        p['uid'] = '$key';
        out.add(p);
      });
      out.sort((a, b) => ((b['contestRating'] as num?) ?? 0)
          .compareTo((a['contestRating'] as num?) ?? 0));
      return out;
    } catch (_) {
      return null; // null = offline / unreachable
    }
  }

  // ============================ LOGOUT ============================

  /// Signs out everywhere and wipes all local account data (coins, XP,
  /// purchases, progress) so the next account signed into on this device
  /// never inherits the previous one's state. Returns to the first-run flow.
  Future<void> signOut() async {
    if (online) {
      try {
        await GoogleSignIn().signOut();
      } catch (_) {}
      try {
        await _auth.signOut();
      } catch (_) {}
    }
    await AppData.i.resetAll();
  }

  /// PLAY-STORE COMPLIANCE: permanent account deletion (Google Play's
  /// account-deletion policy requires an in-app path). Removes the
  /// cloud profile, username reservation and social node, deletes the
  /// Firebase auth user, then wipes all local data.
  /// Returns null on success, or a note if cloud deletion was partial.
  Future<String?> deleteAccount() async {
    String? note;
    if (online) {
      final uid = _auth.currentUser?.uid;
      final uname = AppData.i.username.trim().toLowerCase();
      if (uid != null) {
        try {
          await _db.ref('profiles/$uid').remove().timeout(_netTimeout);
        } catch (_) {}
        try {
          await _db.ref('social/$uid').remove().timeout(_netTimeout);
        } catch (_) {}
        if (uname.isNotEmpty) {
          try {
            await _db.ref('usernames/$uname').remove().timeout(_netTimeout);
          } catch (_) {}
        }
        try {
          await _auth.currentUser?.delete();
        } on FirebaseAuthException catch (e) {
          note = e.code == 'requires-recent-login'
              ? 'Your data was removed. For security, deleting the sign-in '
                  'record needs a fresh login — sign in again and retry, or '
                  'email us and we\'ll finish it within 30 days.'
              : null;
        } catch (_) {}
      }
      try {
        await GoogleSignIn().signOut();
      } catch (_) {}
      try {
        await _auth.signOut();
      } catch (_) {}
    }
    await AppData.i.resetAll();
    return note;
  }

  // ============================ SOCIAL ============================

  /// Finds a user by username. Returns their uid, or null.
  Future<String?> findUser(String username) async {
    if (!online) return null;
    try {
      final snap = await _db
          .ref('usernames/${username.trim().toLowerCase()}')
          .get()
          .timeout(_netTimeout);
      return snap.value as String?;
    } catch (_) {
      return null;
    }
  }

  // -------- follow REQUESTS (Instagram-style) --------
  //
  // Following someone is no longer instant: it lands as a request in
  // /social/{targetUid}/requests/{myUsername}. Only when the target
  // ACCEPTS does the graph update — and it updates on BOTH sides in a
  // single atomic multi-path write (one round trip, can never end up
  // half-applied).

  /// Sends a follow request. Returns error string, or null on success.
  Future<String?> requestFollow(String username) async {
    username = username.trim().toLowerCase();
    if (username == AppData.i.username) return "That's you!";
    if (AppData.i.following.contains(username)) return null; // already
    if (!online || uid == null) {
      return 'You need to be online to follow players.';
    }
    if (AppData.i.username.isEmpty) return 'Claim a username first.';
    final target = await findUser(username);
    if (target == null) return 'No user called @$username.';
    try {
      await _db.ref('social/$target/requests/${AppData.i.username}').set({
        'uid': uid,
        'at': ServerValue.timestamp,
      }).timeout(_netTimeout);
    } catch (_) {
      return 'Could not send the request — check your internet.';
    }
    if (!AppData.i.sentRequests.contains(username)) {
      AppData.i.sentRequests.add(username);
    }
    await AppData.i.save();
    return null;
  }

  /// Withdraws a pending follow request.
  Future<void> cancelFollowRequest(String username) async {
    username = username.trim().toLowerCase();
    if (online && uid != null) {
      try {
        final target = await findUser(username);
        if (target != null) {
          await _db
              .ref('social/$target/requests/${AppData.i.username}')
              .remove()
              .timeout(_netTimeout);
        }
      } catch (_) {}
    }
    AppData.i.sentRequests.remove(username);
    await AppData.i.save();
  }

  /// Accepts [requester]'s follow request. One atomic multi-path
  /// update clears the request, adds them to MY followers and adds me
  /// to THEIR following — both sides reflect instantly.
  Future<String?> acceptFollowRequest(String requester) async {
    if (!online || uid == null) return 'You need to be online.';
    try {
      final theirUidSnap = await _db
          .ref('social/$uid/requests/$requester/uid')
          .get()
          .timeout(_netTimeout);
      var theirUid = theirUidSnap.value as String?;
      theirUid ??= await findUser(requester);
      if (theirUid == null) return 'That account no longer exists.';
      await _db.ref().update({
        'social/$uid/requests/$requester': null,
        'social/$uid/followers/$requester': true,
        'social/$theirUid/following/${AppData.i.username}': true,
      }).timeout(_netTimeout);
      AppData.i.followRequests.remove(requester);
      if (!AppData.i.followers.contains(requester)) {
        AppData.i.followers.add(requester);
      }
      await AppData.i.save();
      return null;
    } catch (_) {
      return 'Could not accept — check your internet.';
    }
  }

  /// Declines (silently removes) a follow request.
  Future<void> declineFollowRequest(String requester) async {
    if (online && uid != null) {
      try {
        await _db
            .ref('social/$uid/requests/$requester')
            .remove()
            .timeout(_netTimeout);
      } catch (_) {}
    }
    AppData.i.followRequests.remove(requester);
    await AppData.i.save();
  }

  /// Unfollow: single atomic multi-path write clears both sides.
  Future<void> unfollow(String username) async {
    if (online && uid != null) {
      try {
        final target = await findUser(username);
        if (target != null) {
          await _db.ref().update({
            'social/$uid/following/$username': null,
            'social/$target/followers/${AppData.i.username}': null,
          }).timeout(_netTimeout);
        }
      } catch (_) {}
    }
    AppData.i.following.remove(username);
    await AppData.i.save();
  }

  /// Refresh followers/following/requests from the cloud in ONE read.
  Future<void> syncSocial() async {
    if (!online || uid == null) return;
    try {
      final snap = await _db.ref('social/$uid').get().timeout(_netTimeout);
      final m = snap.value as Map<dynamic, dynamic>?;
      if (m == null) return;
      AppData.i.following =
          ((m['following'] as Map?)?.keys ?? []).map((e) => '$e').toList();
      AppData.i.followers =
          ((m['followers'] as Map?)?.keys ?? []).map((e) => '$e').toList();
      AppData.i.followRequests =
          ((m['requests'] as Map?)?.keys ?? []).map((e) => '$e').toList();
      // prune sent requests that were accepted (now in following) or
      // declined server-side is unknowable cheaply — accepted ones go.
      AppData.i.sentRequests
          .removeWhere((u) => AppData.i.following.contains(u));
      await AppData.i.save();
    } catch (_) {/* best-effort */}
  }

  // ==================== ARENAS / EVENTS 3.0 ====================
  //
  // Rating-range arenas (no more bronze/silver/gold).
  //  · PRIVATE — join by code; host picks a rating range; up to 100 players.
  //    Prize: ¾ winner, ¼ runner-up.
  //  · PUBLIC — browsable, no rating restriction; up to 128 players. Starts
  //    at the organiser's
  //    "ultimatum" time — never before. Whole prize to the winner.
  //  · Both: 10–30 questions, 10–30 minutes, any topic from the full
  //    game list. Questions come from the seeded bank of that topic,
  //    so every entrant sees the identical paper.

  /// Memberships are disabled in v1, so every organizer gets the same cap.
  static int privateHostCap() => 100;

  static int publicHostCap() => 128;

  static const arenaMinQuestions = 10;
  static const arenaMaxQuestions = 30;
  static const arenaMinMinutes = 10;
  static const arenaMaxMinutes = 30;

  /// Every topic an arena can serve: mixed + speed modes + all the
  /// question-feed subjects in the app.
  static List<String> get arenaTopics => ArenaGameCatalog.ids;

  /// Preset rating ranges an organiser can pick for a PRIVATE arena.
  /// (lo, hi) — hi 9999 means open-top; (0, 9999) = open to everyone.
  static const ratingRanges = <(int, int)>[
    (0, 9999),
    (1500, 1600),
    (1500, 1700),
    (1600, 1800),
    (1700, 1900),
    (1800, 2000),
    (1900, 2100),
    (2100, 2300),
    (2300, 2500),
    (2500, 9999),
  ];

  static String rangeLabel((int, int) r) => r.$1 == 0
      ? 'Open to all'
      : (r.$2 >= 9000 ? '${r.$1}+' : '${r.$1}–${r.$2}');

  final List<Map<String, dynamic>> _localEvents = [];

  String _newCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no 0/O/1/I
    final r = DateTime.now().microsecondsSinceEpoch;
    return List.generate(
        6, (i) => chars[(r >> (i * 5) ^ r ~/ (i + 7)) % chars.length]).join();
  }

  // ============================ RATE LIMITING ============================
  // Generic per-action limiter: a daily quota + exponential backoff between
  // attempts, shared by every write-heavy action (arena hosting, matchmaking,
  // room creation, OTP sends). Thresholds are read from `config/limits/$key`
  // in RTDB when present — editable from the Firebase console with no app
  // redeploy — and fall back to [_rateLimitDefaults] only when that node is
  // missing or unreachable, so a threshold is never a hardcoded dead end.
  //
  // This still runs client-side (check-then-record, not atomic across the
  // two), same trust model as the rest of this app's Firebase-only backend —
  // see SECURITY_THREATS.md §6 for why a fully tamper-proof version needs a
  // Cloud Function. It's a real improvement over the flat hard-lockout it
  // replaces: attempts back off exponentially instead of one fixed cooldown,
  // and the numbers can be retuned without shipping a new build.
  static const _rateLimitDefaults =
      <String, (int maxPerDay, int baseBackoffMs)>{
    // Host one arena/tournament per day — a clean 1-day cooldown. The small
    // backoff just guards against a double-tap; the 1/day cap is what enforces
    // the cooldown (resets at midnight).
    'arena': (1, 60 * 1000), // 1/day · 60s anti-double-submit
    // Friend-invite rooms AND matchmaking both create a room here, so this
    // one limit naturally covers matchmaking-ticket spam too.
    'room_create': (60, 3 * 1000), // 60/day · 3s base backoff
    'corp_otp': (5, 60 * 1000), // 5/day · 60s base backoff
  };
  static const _backoffCapExponent = 5; // caps growth at base × 2^5 (×32)

  /// Read-only check: returns an error message if [key]'s quota/backoff is
  /// exceeded, or null if the action may proceed. Does not record anything —
  /// call [_rateLimitRecord] after the action actually succeeds.
  Future<String?> _rateLimitCheck(String key, {String label = 'that'}) async {
    if (!online || uid == null) return null;
    final d = _rateLimitDefaults[key]!;
    var maxPerDay = d.$1;
    var baseBackoffMs = d.$2;
    var capExponent = _backoffCapExponent;
    try {
      final cfg =
          await _db.ref('config/limits/$key').get().timeout(_netTimeout);
      final c = cfg.value as Map?;
      if (c != null) {
        maxPerDay = (c['maxPerDay'] as num?)?.toInt() ?? maxPerDay;
        baseBackoffMs = (c['baseBackoffMs'] as num?)?.toInt() ?? baseBackoffMs;
        capExponent = (c['backoffCapExponent'] as num?)?.toInt() ?? capExponent;
      }
    } catch (_) {/* use defaults */}
    try {
      final snap =
          await _db.ref('host_limits/$uid/$key').get().timeout(_netTimeout);
      final m = snap.value as Map?;
      final today = AppData.todayKey();
      final sameDay = m?['day'] == today;
      var count = sameDay ? ((m?['count'] as num?)?.toInt() ?? 0) : 0;
      final attempts = sameDay ? ((m?['attempts'] as num?)?.toInt() ?? 0) : 0;
      var lastAt = (m?['lastAt'] as num?)?.toInt();

      // Arena quota follows arenas that really exist, not a stale local
      // counter. This repairs false "limit reached" records left by older
      // clients and permits a safe retry after a rolled-back create.
      if (key == 'arena') {
        final actual = await _successfulArenaCountToday();
        if (actual == 0) {
          count = 0;
          lastAt = null;
        } else {
          count = actual;
        }
      }
      final now = DateTime.now().millisecondsSinceEpoch;
      if (lastAt != null) {
        final backoff = baseBackoffMs * (1 << attempts.clamp(0, capExponent));
        final remain = backoff - (now - lastAt);
        if (remain > 0) {
          return remain > 60000
              ? 'Slow down — try again in ${(remain / 60000).ceil()} minute(s).'
              : 'Slow down — try again in ${(remain / 1000).ceil()}s.';
        }
      }
      if (count >= maxPerDay) {
        return 'You\'ve hit today\'s limit for $label ($maxPerDay/day) — try again tomorrow.';
      }
      return null;
    } catch (_) {
      return null; // best-effort — don't block the action if the check fails
    }
  }

  Future<int> _successfulArenaCountToday() async {
    if (!online || uid == null) return 0;
    try {
      final now = DateTime.now();
      final start =
          DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
      final snap =
          await _db.ref('events').limitToLast(200).get().timeout(_netTimeout);
      final events = snap.value as Map<dynamic, dynamic>?;
      if (events == null) return 0;
      var count = 0;
      for (final value in events.values) {
        if (value is! Map) continue;
        final createdAt = (value['createdAt'] as num?)?.toInt() ?? 0;
        if (value['hostUid'] == uid &&
            value['official'] != true &&
            createdAt >= start) {
          count++;
        }
      }
      return count;
    } catch (_) {
      // Verification failure must not turn a stale counter into a hard lock.
      return 0;
    }
  }

  /// Records a successful attempt at [key] — call only after the action
  /// this limiter guards actually went through.
  Future<void> _rateLimitRecord(String key) async {
    if (uid == null) return;
    try {
      final today = AppData.todayKey();
      await _db.ref('host_limits/$uid/$key').runTransaction((raw) {
        final m = raw as Map?;
        final sameDay = m?['day'] == today;
        final count = sameDay ? ((m?['count'] as num?)?.toInt() ?? 0) : 0;
        final attempts = sameDay ? ((m?['attempts'] as num?)?.toInt() ?? 0) : 0;
        return Transaction.success({
          'day': today,
          'count': count + 1,
          'attempts': attempts + 1,
          'lastAt': DateTime.now().millisecondsSinceEpoch,
        });
      }).timeout(_netTimeout);
    } catch (_) {/* best-effort */}
  }

  /// Creates an arena. Returns (error, joinCode) — error is null on
  /// success; joinCode is non-null only for private arenas.
  Future<(String?, String?)> createArena({
    required String title,
    required int fee,
    required bool isPublic,
    required String category,
    required int maxPlayers,
    required int questionCount,
    required int durationMin,
    int ratingMin = 0,
    int ratingMax = 9999,
    int gameRating = 800,
    int? startAt, // epoch ms — required and aligned to a clean hourly slot
    String? org, // 'college:IIT Delhi' / 'company:Infosys'
    String? bgBase64, // optional host-uploaded background (small jpeg)
    // Up to 5 topics blended together (one drawn at random per question).
    // Null/empty falls back to the single [category] — board games (chess,
    // sudoku, art heist, crossword, number puzzle) never combine.
    List<String>? categories,
  }) async {
    final topics = (categories == null || categories.isEmpty)
        ? [category]
        : categories;
    // ---------- validation ----------
    if (title.trim().length < 3) {
      return ('Give your arena a name (3+ characters).', null);
    }
    if (questionCount < arenaMinQuestions ||
        questionCount > arenaMaxQuestions) {
      return (
        'Questions must be between $arenaMinQuestions and $arenaMaxQuestions.',
        null
      );
    }
    if (durationMin < arenaMinMinutes || durationMin > arenaMaxMinutes) {
      return (
        'Duration must be between $arenaMinMinutes and $arenaMaxMinutes minutes.',
        null
      );
    }
    final cap = isPublic ? publicHostCap() : privateHostCap();
    if (maxPlayers < 2) return ('An arena needs at least 2 players.', null);
    if (maxPlayers > cap) {
      return (
        isPublic
            ? 'Public arenas support up to $cap players.'
            : 'Private arenas support up to $cap players.',
        null
      );
    }
    if (topics.length > 5) {
      return ('Pick up to 5 topics to combine.', null);
    }
    if (topics.toSet().length != topics.length) {
      return ('Pick each topic only once.', null);
    }
    if (topics.length > 1 && topics.contains('mixed')) {
      return ('"Mixed Skills" already draws from every topic — pick it alone.',
          null);
    }
    for (final t in topics) {
      if (!arenaTopics.contains(t)) {
        return ('Pick a game from the list.', null);
      }
    }
    if (topics.length > 1 &&
        topics.any((t) => !ArenaGameCatalog.byId(t).usesQuestionCount)) {
      return ('Only quiz-style topics can be combined together.', null);
    }
    if (gameRating < 800 ||
        gameRating > 2500 ||
        (gameRating - 800) % 100 != 0) {
      return ('Game level must be a rating from 800 to 2500.', null);
    }
    if (startAt == null || startAt <= DateTime.now().millisecondsSinceEpoch) {
      return ('Pick a future hourly start time for your arena.', null);
    }
    final scheduledStart = DateTime.fromMillisecondsSinceEpoch(startAt);
    if (scheduledStart.minute != 0 ||
        scheduledStart.second != 0 ||
        scheduledStart.millisecond != 0) {
      return ('Arena starts must use a clean hourly slot.', null);
    }
    if (!online || uid == null) {
      return (
        'Arenas need an internet connection — sign in and try again.',
        null
      );
    }

    // ---------- host rate limit: configurable quota + exponential backoff ----------
    final limitErr = await _rateLimitCheck('arena', label: 'hosting arenas');
    if (limitErr != null) return (limitErr, null);

    final code = isPublic ? null : _newCode();
    final event = <String, dynamic>{
      'title': title.trim(),
      'fee': fee,
      'public': isPublic,
      if (code != null) 'code': code,
      'category': topics.first,
      if (topics.length > 1) 'categories': topics,
      'maxPlayers': maxPlayers,
      'questionCount': questionCount,
      'durationMin': durationMin,
      'gameRating': gameRating,
      // Hosts can restrict eligibility independently from game difficulty.
      'ratingMin': ratingMin,
      'ratingMax': ratingMax,
      // Public and private arenas use the same hourly registration cutoff.
      'startAt': startAt,
      'lobbySeconds': arenaLobbyDuration.inSeconds,
      // prize split (percent): public → winner takes all;
      // private → ¾ to the winner, ¼ to the runner-up.
      'split1': isPublic ? 100 : 75,
      'split2': isPublic ? 0 : 25,
      // shared seed: every entrant draws the SAME questions from the
      // topic's bank.
      'seed': Random().nextInt(1 << 31),
      'organizer':
          AppData.i.username.isEmpty ? AppData.i.name : AppData.i.username,
      'hostUid': uid,
      'createdByUid': uid,
      'creationScope': org == null ? 'personal' : 'organization',
      'official': false,
      if (org != null) 'org': org,
      if (org != null) 'orgType': org.split(':').first,
      if (org != null) 'orgKey': orgKey(org.substring(org.indexOf(':') + 1)),
      // small (<~110KB) host-uploaded background, rides on the event node.
      if (bgBase64 != null && bgBase64.length < 160 * 1024) 'bg': bgBase64,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
      'players': {
        uid!: {
          'username': AppData.i.username.isEmpty ? 'host' : AppData.i.username,
          'name': AppData.i.name,
          'registeredAt': DateTime.now().millisecondsSinceEpoch,
        },
      },
    };
    try {
      final ref = _db.ref('events').push();
      final eventId = ref.key;
      if (eventId == null) {
        return ('Could not allocate an arena ID. Please retry.', null);
      }
      // One atomic write keeps the event, private-code lookup and per-user
      // "My Arenas" index in sync. Organization arenas use the same index.
      await _db.ref().update({
        'events/$eventId': event,
        'user_events/$uid/$eventId': {
          'createdAt': event['createdAt'],
          if (org != null) 'org': org,
        },
        if (code != null) 'event_codes/$code': eventId,
      }).timeout(_netTimeout);
      // record the attempt — best-effort, never blocks the response;
      // the arena itself already succeeded above.
      await _rateLimitRecord('arena');
      return (null, code);
    } catch (_) {
      return (
        'Could not reach the arena server — check your internet and try again.',
        null
      );
    }
  }

  /// Arenas the current user organized (public or private), newest first.
  /// Returns null when offline/unreachable.
  Future<List<Map<String, dynamic>>?> listMyEvents() async {
    if (!online || uid == null) return null;
    final mine = <String, Map<String, dynamic>>{};
    var reachedServer = false;

    // Keep the recent scan for arenas created by older app versions before
    // the stable per-user index existed.
    try {
      final recent =
          await _db.ref('events').limitToLast(200).get().timeout(_netTimeout);
      reachedServer = true;
      final values = recent.value as Map<dynamic, dynamic>?;
      values?.forEach((key, value) {
        if (value is! Map) return;
        final event = Map<String, dynamic>.from(value);
        final createdByMe = arenaWasCreatedBy(event, uid);
        if (event['official'] != true && createdByMe) {
          event['id'] = '$key';
          mine['$key'] = event;
        }
      });
    } catch (_) {/* the stable index may still be available */}

    // Every new arena—including College and Corporate events—is indexed here,
    // so it remains in My Arenas even after it falls outside the recent scan.
    try {
      final indexed = await _db
          .ref('user_events/$uid')
          .limitToLast(200)
          .get()
          .timeout(_netTimeout);
      reachedServer = true;
      final values = indexed.value as Map<dynamic, dynamic>?;
      final missing = values?.keys
              .map((key) => '$key')
              .where((id) => !mine.containsKey(id))
              .toList() ??
          const <String>[];
      if (missing.isNotEmpty) {
        final snapshots = await Future.wait(
          missing.map(
            (id) => _db.ref('events/$id').get().timeout(_netTimeout),
          ),
        );
        for (var index = 0; index < missing.length; index++) {
          final raw = snapshots[index].value;
          if (raw is! Map) continue;
          final event = Map<String, dynamic>.from(raw);
          final createdByMe = arenaWasCreatedBy(event, uid);
          if (event['official'] != true && createdByMe) {
            event['id'] = missing[index];
            mine[missing[index]] = event;
          }
        }
      }
    } catch (_) {/* rules may not have the new index yet; use recent scan */}

    if (!reachedServer) return null;
    final out = mine.values.toList()
      ..sort((a, b) =>
          (b['createdAt'] as num? ?? 0).compareTo(a['createdAt'] as num? ?? 0));
    return out;
  }

  /// All public player-hosted arenas, most popular first.
  /// Returns null when offline/unreachable (so the UI can say so).
  Future<List<Map<String, dynamic>>?> listPublicEvents(
      {String? organization}) async {
    final out = <Map<String, dynamic>>[];
    if (online) {
      try {
        final snap =
            await _db.ref('events').limitToLast(100).get().timeout(_netTimeout);
        final m = snap.value as Map<dynamic, dynamic>?;
        if (m != null) {
          m.forEach((key, value) {
            final e = Map<String, dynamic>.from(value as Map);
            final eventOrg = e['org'] as String?;
            final visible = organization == null
                ? eventOrg == null
                : eventOrg == organization;
            if (e['public'] == true && visible) {
              e['id'] = '$key';
              out.add(e);
            }
          });
        }
      } catch (_) {
        if (_localEvents.isEmpty) return null;
      }
    } else if (_localEvents.isEmpty) {
      return null;
    }
    out.addAll(_localEvents);
    int joined(Map<String, dynamic> e) => (e['players'] as Map?)?.length ?? 0;
    out.sort((a, b) {
      final byPlayers = joined(b).compareTo(joined(a));
      if (byPlayers != 0) return byPlayers;
      return (b['createdAt'] as num? ?? 0)
          .compareTo(a['createdAt'] as num? ?? 0);
    });
    return out;
  }

  /// Looks up a private arena by its join code.
  Future<Map<String, dynamic>?> findEventByCode(String code) async {
    if (!online) return null;
    try {
      final idSnap = await _db
          .ref('event_codes/${code.trim().toUpperCase()}')
          .get()
          .timeout(_netTimeout);
      final id = idSnap.value as String?;
      if (id == null) return null;
      final snap = await _db.ref('events/$id').get().timeout(_netTimeout);
      final m = snap.value as Map<dynamic, dynamic>?;
      if (m == null) return null;
      final e = Map<String, dynamic>.from(m);
      e['id'] = id;
      return e;
    } catch (_) {
      return null;
    }
  }

  String _competitionFunctionError(
    Object error, {
    required String fallback,
  }) {
    // Always log the raw error so the true cause is visible in debug/console.
    debugPrint('competition fn error: $error');
    if (error is FirebaseFunctionsException) {
      // Prefer the server's own message when it sent one.
      final message = error.message?.trim();
      // Code-specific, actionable copy so users (and we) aren't misled by a
      // blanket "check your connection" when the real issue is different.
      switch (error.code) {
        case 'unauthenticated':
          return 'Please sign in again, then retry.';
        case 'permission-denied':
          return message?.isNotEmpty == true
              ? message!
              : 'You\'re not eligible for this one.';
        case 'not-found':
          return 'This isn\'t available right now — the server may be updating. Try again shortly.';
        case 'unavailable':
        case 'deadline-exceeded':
        case 'internal':
          return 'The server is waking up or busy — give it a few seconds and try again.';
        default:
          if (message != null && message.isNotEmpty) return message;
      }
      // Uncommon code with no server message — still show the code so it's
      // diagnosable instead of a blanket "check your connection".
      return '$fallback (${error.code})';
    }
    if (error is TimeoutException) {
      return 'The server took too long to respond — try again in a moment.';
    }
    // Not a Functions/Timeout error at all (e.g. a raw web/network failure).
    // Append the type so a screenshot tells us exactly what it was.
    return '$fallback (${error.runtimeType})';
  }

  /// Registers the current auth UID through the backend. Capacity, rating,
  /// organization membership and the exact start-time cutoff are all checked
  /// before the server adds the entrant.
  Future<String?> registerHostedArena(Map<String, dynamic> event) async {
    final id = '${event['id'] ?? ''}';
    if (!online || uid == null) return 'Your session is still connecting.';
    if (id.isEmpty || id == 'local') {
      return 'This arena is not available online.';
    }
    try {
      await FirebaseFunctions.instance.httpsCallable('registerHostedArena', options: HttpsCallableOptions(timeout: const Duration(seconds: 30)))
          .call<void>({'eventId': id}).timeout(const Duration(seconds: 35));
      return null;
    } catch (error) {
      return _competitionFunctionError(
        error,
        fallback: 'Could not register. Check your connection and try again.',
      );
    }
  }

  Future<bool> isHostedArenaRegistered(Map<String, dynamic> event) async {
    if (arenaHasRegistered(
      event,
      uid: uid,
      username: AppData.i.username,
    )) {
      return true;
    }
    final id = '${event['id'] ?? ''}';
    if (!online || uid == null || id.isEmpty || id == 'local') return false;
    try {
      final current =
          await _db.ref('events/$id/players/$uid').get().timeout(_netTimeout);
      if (current.exists) return true;
      if (AppData.i.username.isEmpty) return false;
      final legacy = await _db
          .ref('events/$id/players/${AppData.i.username}')
          .get()
          .timeout(_netTimeout);
      return legacy.exists;
    } catch (_) {
      return false;
    }
  }

  Future<CompetitionAccess> authorizeHostedArena(
      Map<String, dynamic> event) async {
    final id = '${event['id'] ?? ''}';
    if (!online || uid == null || id.isEmpty || id == 'local') {
      return const CompetitionAccess(
        allowed: false,
        message: 'Connect to the arena server and try again.',
      );
    }
    try {
      final result = await FirebaseFunctions.instance.httpsCallable('authorizeHostedArena', options: HttpsCallableOptions(timeout: const Duration(seconds: 30)))
          .call<Map<Object?, Object?>>({'eventId': id}).timeout(const Duration(seconds: 35));
      final data = Map<String, dynamic>.from(result.data);
      return CompetitionAccess(
        allowed: data['allowed'] == true,
        message: data['message'] as String?,
        startsAt: (data['startsAt'] as num?)?.toInt(),
        lobbyEndsAt: (data['lobbyEndsAt'] as num?)?.toInt(),
      );
    } catch (error) {
      return CompetitionAccess(
        allowed: false,
        message: _competitionFunctionError(
          error,
          fallback: 'Could not verify your arena registration.',
        ),
      );
    }
  }

  /// Live list of usernames currently in an arena/tournament — powers the
  /// pre-game lobby so everyone sees who's entered before it begins.
  Stream<List<String>> eventPlayersStream(String id) => _db
      .ref('events/$id/players')
      .onValue
      .map((ev) => arenaPlayerNames(ev.snapshot.value));

  Future<void> submitHostedArenaScore(String eventId, int score) async {
    if (!online || uid == null || eventId.isEmpty) return;
    try {
      await _db.ref('events/$eventId/scores/$uid').set({
        'username': AppData.i.username,
        'name': AppData.i.name,
        'score': score,
      }).timeout(_netTimeout);
    } catch (_) {/* best-effort */}
  }

  Future<List<MapEntry<String, int>>?> fetchHostedArenaScores(
      String eventId) async {
    if (!online) return null;
    try {
      final snap =
          await _db.ref('events/$eventId/scores').get().timeout(_netTimeout);
      final scores = snap.value as Map<dynamic, dynamic>?;
      if (scores == null) return [];
      final out = scores.entries.map((entry) {
        final value = entry.value;
        if (value is Map) {
          return MapEntry(
            '${value['username'] ?? value['name'] ?? entry.key}',
            (value['score'] as num?)?.toInt() ?? 0,
          );
        }
        return MapEntry('${entry.key}', (value as num?)?.toInt() ?? 0);
      }).toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      return out;
    } catch (_) {
      return null;
    }
  }

  /// Deletes an arena you hosted. Blocked once a scheduled (public)
  /// arena is under 15 minutes from starting, or already started —
  /// private/instant arenas (no schedule) can be deleted any time.
  Future<String?> deleteArena(Map<String, dynamic> e) async {
    if (!online || uid == null) return 'You need to be online.';
    final id = e['id'] as String?;
    if (id == null) return 'Could not find that arena.';
    if (!arenaWasCreatedBy(e, uid)) {
      return 'Only the host can delete this arena.';
    }
    // An arena can be deleted while it's UPCOMING or after it's FINISHED
    // (History) — but NOT while it's live/ongoing.
    final startAt = (e['startAt'] as num?)?.toInt();
    if (startAt != null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final durMin = (e['durationMin'] as num?)?.toInt() ?? 15;
      final end = startAt + durMin * 60000;
      if (now >= startAt && now < end) {
        return 'This arena is live right now — you can delete it once it finishes.';
      }
    }
    try {
      final code = e['code'] as String?;
      await _db.ref().update({
        'events/$id': null,
        'user_events/$uid/$id': null,
        if (code != null) 'event_codes/$code': null,
      }).timeout(_netTimeout);
      return null;
    } catch (_) {
      return 'Could not reach the server — try again.';
    }
  }

  // -------------------- OFFICIAL MYNDASH ARENAS --------------------

  /// Register for an official arena through the server-controlled cutoff.
  Future<String?> registerOfficialArena(String dayKey, int bracket) async {
    if (!online || uid == null) return 'Your session is still connecting.';
    try {
      await FirebaseFunctions.instance.httpsCallable('registerOfficialArena', options: HttpsCallableOptions(timeout: const Duration(seconds: 30)))
          .call<void>({
        'dayKey': dayKey,
        'bracket': bracket,
      }).timeout(const Duration(seconds: 35));
      return null;
    } catch (error) {
      return _competitionFunctionError(
        error,
        fallback: 'Could not register. Check your connection and try again.',
      );
    }
  }

  /// Live entrants registered for today's official arena bracket — powers
  /// the pre-game lobby for official arenas.
  Stream<List<String>> officialArenaPlayersStream(String dayKey, int bracket) =>
      _db
          .ref('official_arenas/$dayKey/b$bracket/reg')
          .onValue
          .map((ev) => arenaPlayerNames(ev.snapshot.value));

  /// The official brackets the current user is registered for today — so
  /// registration survives an app restart instead of a local-only flag.
  Future<Set<int>> myOfficialRegs(String dayKey) async {
    final out = <int>{};
    if (!online || uid == null) return out;
    try {
      final snap =
          await _db.ref('official_arenas/$dayKey').get().timeout(_netTimeout);
      final m = snap.value as Map?;
      m?.forEach((k, v) {
        final key = '$k';
        final reg = (v as Map?)?['reg'] as Map?;
        final registered = reg != null &&
            (reg.containsKey(uid) ||
                reg.containsKey(AppData.i.username) ||
                reg.values.any((value) =>
                    value is Map && value['username'] == AppData.i.username));
        if (key.startsWith('b') && registered) {
          final b = int.tryParse(key.substring(1));
          if (b != null) out.add(b);
        }
      });
    } catch (_) {/* best-effort */}
    return out;
  }

  Future<CompetitionAccess> authorizeOfficialArena(
      String dayKey, int bracket) async {
    if (!online || uid == null) {
      return const CompetitionAccess(
        allowed: false,
        message: 'Connect to the arena server and try again.',
      );
    }
    try {
      final result = await FirebaseFunctions.instance.httpsCallable('authorizeOfficialArena', options: HttpsCallableOptions(timeout: const Duration(seconds: 30)))
          .call<Map<Object?, Object?>>({
        'dayKey': dayKey,
        'bracket': bracket,
      }).timeout(const Duration(seconds: 35));
      final data = Map<String, dynamic>.from(result.data);
      return CompetitionAccess(
        allowed: data['allowed'] == true,
        message: data['message'] as String?,
        startsAt: (data['startsAt'] as num?)?.toInt(),
        lobbyEndsAt: (data['lobbyEndsAt'] as num?)?.toInt(),
      );
    } catch (error) {
      return CompetitionAccess(
        allowed: false,
        message: _competitionFunctionError(
          error,
          fallback: 'Could not verify your official arena registration.',
        ),
      );
    }
  }

  // ---------------- Chocolate Hour leaderboard ----------------
  /// Submits my Chocolate Hour count for [dayKey] to the global board.
  Future<void> submitChoc(String dayKey, int count) async {
    if (!online || uid == null || AppData.i.username.isEmpty) return;
    try {
      await _db.ref('choc/$dayKey/${AppData.i.username}').set({
        'name': AppData.i.name,
        'count': count,
      }).timeout(_netTimeout);
    } catch (_) {/* best-effort */}
  }

  /// The global Chocolate Hour leaderboard for [dayKey], best first.
  Future<List<Map<String, dynamic>>> chocLeaderboard(String dayKey) async {
    if (!online) return [];
    try {
      final snap = await _db.ref('choc/$dayKey').get().timeout(_netTimeout);
      final m = snap.value as Map?;
      final out = <Map<String, dynamic>>[];
      m?.forEach((k, v) {
        if (v is Map) out.add({'user': '$k', ...Map<String, dynamic>.from(v)});
      });
      out.sort((a, b) =>
          ((b['count'] as num?) ?? 0).compareTo((a['count'] as num?) ?? 0));
      return out;
    } catch (_) {
      return [];
    }
  }

  /// How many players registered for a bracket today.
  Future<int> officialArenaRegCount(String dayKey, int bracket) async {
    if (!online) return 0;
    try {
      final snap = await _db
          .ref('official_arenas/$dayKey/b$bracket/reg')
          .get()
          .timeout(_netTimeout);
      return (snap.value as Map?)?.length ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Submit my official-arena score.
  Future<void> submitOfficialArenaScore(
      String dayKey, int bracket, int score) async {
    if (!online || uid == null) return;
    try {
      await _db.ref('official_arenas/$dayKey/b$bracket/scores/$uid').set({
        'username': AppData.i.username,
        'name': AppData.i.name,
        'score': score,
      }).timeout(_netTimeout);
    } catch (_) {/* best-effort */}
  }

  /// username → score, sorted descending. Null when unreachable.
  Future<List<MapEntry<String, int>>?> fetchOfficialArenaScores(
      String dayKey, int bracket) async {
    if (!online) return null;
    try {
      final snap = await _db
          .ref('official_arenas/$dayKey/b$bracket/scores')
          .get()
          .timeout(_netTimeout);
      final m = snap.value as Map<dynamic, dynamic>?;
      if (m == null) return [];
      final out = m.entries.map((e) {
        final value = e.value;
        if (value is Map) {
          return MapEntry(
            '${value['username'] ?? value['name'] ?? e.key}',
            (value['score'] as num?)?.toInt() ?? 0,
          );
        }
        return MapEntry('${e.key}', (value as num?)?.toInt() ?? 0);
      }).toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      return out;
    } catch (_) {
      return null;
    }
  }

  // ============================ SQUADS ============================

  Map<String, dynamic> get _myMemberStats => {
        'uid': uid,
        'name': AppData.i.name,
        'elo': AppData.i.elo,
        'contestRating': AppData.i.contestRating,
        'xp': AppData.i.xp,
      };

  /// Hard cap — Clash-style tight squads.
  static const squadMaxMembers = 10;

  /// Normalised key used for the squad-name search index.
  static String squadNameKey(String name) => name
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9 ]'), '')
      .replaceAll(RegExp(r'\s+'), '_');

  /// Short display tag auto-derived from the squad name (no separate
  /// tag input) — first 4 alphanumerics, uppercased.
  static String _deriveTag(String name) {
    final letters = name.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    return letters.isEmpty
        ? 'SQD'
        : letters.substring(0, min(4, letters.length));
  }

  /// Creates a squad (public = joinable directly; private = listed
  /// but joined only with the code). The creator becomes the squad's
  /// sole admin. Returns (error, joinCode).
  Future<(String?, String?)> createSquad(String name,
      {bool isPublic = true, String motto = '', String location = ''}) async {
    if (!online || uid == null) {
      return ('Squads need an internet connection.', null);
    }
    if (AppData.i.username.isEmpty) return ('Claim a username first.', null);
    if (AppData.i.squadId.isNotEmpty) {
      return ('Leave your current squad first.', null);
    }
    final key = squadNameKey(name);
    if (key.length < 3) return ('Squad name needs 3+ characters.', null);
    final tag = _deriveTag(name);
    final code = _newCode();
    try {
      // unique-name claim (atomic — two squads can't share a name)
      final nameRef = _db.ref('squad_names/$key');
      final ref = _db.ref('squads').push();
      final claim = await nameRef.runTransaction((raw) {
        if (raw != null) return Transaction.abort();
        return Transaction.success({
          'id': ref.key,
          'name': name.trim(),
          'tag': tag,
          'public': isPublic,
          if (location.trim().isNotEmpty) 'location': location.trim(),
          'members': 1,
          // kid-mode creators make KIDS squads (under-12 only)
          if (AppData.i.kidMode) 'kids': true,
        });
      }).timeout(_netTimeout);
      if (!claim.committed) {
        return ('A squad with that name already exists — pick another.', null);
      }
      await ref.set({
        'name': name.trim(),
        'tag': tag,
        'code': code,
        'public': isPublic,
        if (motto.trim().isNotEmpty) 'motto': motto.trim(),
        if (location.trim().isNotEmpty) 'location': location.trim(),
        'leader': AppData.i.username,
        'leaderUid': uid,
        'trophies': 0,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'members': {AppData.i.username: _myMemberStats},
        // kid-mode creators make KIDS squads (under-12 only)
        if (AppData.i.kidMode) 'kids': true,
      }).timeout(_netTimeout);
      await _db.ref('squad_codes/$code').set(ref.key).timeout(_netTimeout);
      AppData.i.squadId = ref.key!;
      AppData.i.squadName = name;
      AppData.i.isSquadLeader = true; // creator = admin
      await AppData.i.save();
      return (null, code);
    } catch (_) {
      return ('Could not reach the squad server — try again.', null);
    }
  }

  /// Membership write with the 10-member cap enforced atomically:
  /// the transaction rewrites the members map only if there's room.
  Future<String?> _claimSquadSeat(String id) async {
    final result = await _db.ref('squads/$id/members').runTransaction((raw) {
      final m = raw == null
          ? <String, dynamic>{}
          : Map<String, dynamic>.from(raw as Map);
      if (m.length >= squadMaxMembers && !m.containsKey(AppData.i.username)) {
        return Transaction.abort();
      }
      m[AppData.i.username] = _myMemberStats;
      return Transaction.success(m);
    }).timeout(_netTimeout);
    if (!result.committed) {
      return 'That squad is full ($squadMaxMembers/$squadMaxMembers).';
    }
    return null;
  }

  Future<void> _bumpSquadNameIndex(String squadName, int delta) async {
    try {
      await _db
          .ref('squad_names/${squadNameKey(squadName)}/members')
          .runTransaction((raw) =>
              Transaction.success(((raw as num?) ?? 0).toInt() + delta))
          .timeout(_netTimeout);
    } catch (_) {}
  }

  /// Joins a squad by its 6-letter code. Returns an error or null.
  Future<String?> joinSquad(String code) async {
    if (!online || uid == null) return 'Squads need an internet connection.';
    if (AppData.i.username.isEmpty) return 'Claim a username first.';
    if (AppData.i.squadId.isNotEmpty) return 'Leave your current squad first.';
    try {
      final idSnap = await _db
          .ref('squad_codes/${code.trim().toUpperCase()}')
          .get()
          .timeout(_netTimeout);
      final id = idSnap.value as String?;
      if (id == null) return 'No squad with that code.';
      return _finishJoin(id);
    } catch (_) {
      return 'Could not reach the squad server — try again.';
    }
  }

  /// Joins a PUBLIC squad directly by id (from browse/search). For a
  /// private squad the caller must collect the code and use
  /// [joinSquad] instead. Returns an error or null.
  Future<String?> joinPublicSquad(String id) async {
    if (!online || uid == null) return 'Squads need an internet connection.';
    if (AppData.i.username.isEmpty) return 'Claim a username first.';
    if (AppData.i.squadId.isNotEmpty) return 'Leave your current squad first.';
    try {
      final pubSnap =
          await _db.ref('squads/$id/public').get().timeout(_netTimeout);
      if (pubSnap.value != true) {
        return 'private'; // sentinel — UI prompts for the code
      }
      return _finishJoin(id);
    } catch (_) {
      return 'Could not reach the squad server — try again.';
    }
  }

  Future<String?> _finishJoin(String id) async {
    // KIDS SAFETY: under-12s can only join kids squads, and 12+
    // players can never join a kids squad.
    final kidsSnap =
        await _db.ref('squads/$id/kids').get().timeout(_netTimeout);
    final isKidsSquad = kidsSnap.value == true;
    if (AppData.i.kidMode && !isKidsSquad) {
      return 'That squad is 12+ — join a KIDS squad instead!';
    }
    if (!AppData.i.kidMode && isKidsSquad) {
      return 'That\'s a KIDS squad (under-12 only).';
    }
    final nameSnap =
        await _db.ref('squads/$id/name').get().timeout(_netTimeout);
    final capErr = await _claimSquadSeat(id);
    if (capErr != null) return capErr;
    AppData.i.squadId = id;
    AppData.i.squadName = '${nameSnap.value ?? 'Squad'}';
    AppData.i.isSquadLeader = false; // joiners are members, not admins
    await AppData.i.save();
    _bumpSquadNameIndex(AppData.i.squadName, 1);
    return null;
  }

  /// Prefix autocomplete over the squad-name index — one indexed
  /// range read, ≤10 results, exactly like the username search.
  /// Returns entries: {id, name, tag, public, members}.
  Future<List<Map<String, dynamic>>> searchSquads(String prefix) async {
    prefix = squadNameKey(prefix);
    if (prefix.isEmpty || !online) return [];
    try {
      final snap = await _db
          .ref('squad_names')
          .orderByKey()
          .startAt(prefix)
          .endAt('$prefix')
          .limitToFirst(10)
          .get()
          .timeout(_netTimeout);
      final m = snap.value as Map<dynamic, dynamic>?;
      if (m == null) return [];
      final out = <Map<String, dynamic>>[];
      m.forEach((k, v) {
        if (v is Map) {
          final e = Map<String, dynamic>.from(v);
          // kids see only kids squads; adults never see kids squads
          if ((e['kids'] == true) == AppData.i.kidMode) out.add(e);
        }
      });
      out.sort((a, b) => '${a['name']}'.compareTo('${b['name']}'));
      return out;
    } catch (_) {
      return [];
    }
  }

  /// Browse feed: newest ~40 squads (public + private — private ones
  /// show a lock and ask for the code on tap).
  Future<List<Map<String, dynamic>>?> listSquads() async {
    if (!online) return null;
    try {
      final snap =
          await _db.ref('squads').limitToLast(40).get().timeout(_netTimeout);
      final m = snap.value as Map<dynamic, dynamic>?;
      if (m == null) return [];
      final out = <Map<String, dynamic>>[];
      m.forEach((k, v) {
        final s = Map<String, dynamic>.from(v as Map);
        // kids see only kids squads; adults never see kids squads
        if ((s['kids'] == true) != AppData.i.kidMode) return;
        out.add({
          'id': '$k',
          'name': s['name'],
          'tag': s['tag'],
          'public': s['public'] == true,
          'motto': s['motto'],
          'members': (s['members'] as Map?)?.length ?? 0,
          'power': ((s['members'] as Map?) ?? {}).values.fold<int>(0,
              (sum, mm) => sum + (((mm as Map?)?['xp'] as num?)?.toInt() ?? 0)),
        });
      });
      out.sort((a, b) => (b['power'] as int).compareTo(a['power'] as int));
      return out;
    } catch (_) {
      return null;
    }
  }

  // ==================== SQUAD MANIA 🏆 ====================
  //
  // Monthly inter-squad tournament. All state lives under
  // /squad_mania/{yyyy-MM}/… — registration, per-round scores and
  // prize claims. Writes are transactions, so double-registration,
  // double-scoring and double-claiming are structurally impossible.

  /// Generic read used by the Mania screen. Returns a Map or null.
  Future<Map<String, dynamic>?> maniaFetch(String path) async {
    if (!online) return null;
    try {
      final snap = await _db.ref(path).get().timeout(_netTimeout);
      final v = snap.value;
      if (v is Map) return Map<String, dynamic>.from(v);
      if (v == null) return null;
      return {'value': v}; // scalar (e.g. a claim flag)
    } catch (_) {
      return null;
    }
  }

  /// Registers my squad for this month's Mania (10 🪙 paid by caller).
  /// Atomic: only the first registration for the squad commits.
  Future<String?> maniaRegister(String month) async {
    if (!online || uid == null) return 'You need to be online.';
    final sid = AppData.i.squadId;
    if (sid.isEmpty) return 'Join a squad first.';
    try {
      final result =
          await _db.ref('squad_mania/$month/squads/$sid').runTransaction((raw) {
        if (raw != null) return Transaction.abort();
        return Transaction.success({
          'name': AppData.i.squadName,
          'by': AppData.i.username,
          'at': ServerValue.timestamp,
        });
      }).timeout(_netTimeout);
      if (!result.committed) return 'Your squad is already registered!';
      return null;
    } catch (_) {
      return 'Could not reach the tournament server — try again.';
    }
  }

  /// Banks my score for [round]. Write-once per member per round.
  Future<String?> maniaSubmitScore(
      String month, String round, int score) async {
    if (!online || uid == null) return 'You need to be online.';
    final sid = AppData.i.squadId;
    if (sid.isEmpty || AppData.i.username.isEmpty) {
      return 'Join a squad first.';
    }
    try {
      final result = await _db
          .ref('squad_mania/$month/scores/$round/$sid/${AppData.i.username}')
          .runTransaction((raw) {
        if (raw != null) return Transaction.abort(); // already played
        return Transaction.success(score);
      }).timeout(_netTimeout);
      if (!result.committed) {
        return 'You already played this round — score stands.';
      }
      return null;
    } catch (_) {
      return 'Could not submit the score — check your internet.';
    }
  }

  /// Claims my share of the squad's prize: squadPrize split equally
  /// among members who actually scored this month. Write-once.
  Future<String?> maniaClaim(String month, int squadPrize,
      {int maxShare = 1 << 30}) async {
    if (!online || uid == null) return 'You need to be online.';
    final sid = AppData.i.squadId;
    final me = AppData.i.username;
    if (sid.isEmpty || me.isEmpty) return 'Join a squad first.';
    try {
      // how many squadmates contributed at any stage this month?
      var contributors = <String>{};
      for (final r in const ['base', 'r16', 'qf', 'sf', 'final']) {
        final snap = await _db
            .ref('squad_mania/$month/scores/$r/$sid')
            .get()
            .timeout(_netTimeout);
        (snap.value as Map?)?.keys.forEach((k) => contributors.add('$k'));
      }
      if (!contributors.contains(me)) {
        return 'Only members who played this month can claim a share.';
      }
      final share = (squadPrize ~/ max(contributors.length, 1))
          .clamp(0, maxShare)
          .toInt();
      final result = await _db
          .ref('squad_mania/$month/claims/$sid/$me')
          .runTransaction((raw) {
        if (raw != null) return Transaction.abort();
        return Transaction.success(share);
      }).timeout(_netTimeout);
      if (!result.committed) return 'Already claimed 🪙';
      AppData.i.addCoins(share);
      return null;
    } catch (_) {
      return 'Could not claim right now — try again.';
    }
  }

  /// Fetches the current squad. Returns null ONLY when the squad no
  /// longer exists (deleted) — a network/permission error THROWS instead,
  /// so callers can tell "your squad was deleted, clear it" apart from
  /// "can't reach the server right now, keep it and retry".
  Future<Map<String, dynamic>?> fetchSquad() async {
    final id = AppData.i.squadId;
    if (!online || id.isEmpty) return null;
    final snap = await _db.ref('squads/$id').get().timeout(_netTimeout);
    final m = snap.value as Map<dynamic, dynamic>?;
    return m == null ? null : Map<String, dynamic>.from(m);
  }

  /// Clears local squad membership without touching the server — used
  /// when the squad was deleted out from under us.
  Future<void> clearSquadLocal() async {
    AppData.i.squadId = '';
    AppData.i.squadName = '';
    AppData.i.isSquadLeader = false;
    await AppData.i.save();
  }

  Future<void> leaveSquad() async {
    final id = AppData.i.squadId;
    final name = AppData.i.squadName;
    if (online && id.isNotEmpty && AppData.i.username.isNotEmpty) {
      try {
        await _db
            .ref('squads/$id/members/${AppData.i.username}')
            .remove()
            .timeout(_netTimeout);
        if (name.isNotEmpty) _bumpSquadNameIndex(name, -1);
      } catch (_) {}
    }
    AppData.i.squadId = '';
    AppData.i.squadName = '';
    AppData.i.isSquadLeader = false;
    await AppData.i.save();
  }

  // ==================== COMMUNITIES (college / company) ====================

  static String orgKey(String name) => name
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9 ]'), '')
      .replaceAll(RegExp(r'\s+'), '_');

  /// Free-mail providers are not valid workplace domains.
  static const _freeMail = {
    'gmail.com',
    'yahoo.com',
    'outlook.com',
    'hotmail.com',
    'icloud.com',
    'proton.me',
    'protonmail.com',
    'aol.com',
    'live.com',
    'rediffmail.com',
    'mail.com',
    'zoho.com',
    'yandex.com',
  };

  static bool _looksAcademic(String domain) =>
      domain.endsWith('.edu') ||
      domain.contains('.edu.') ||
      domain.contains('.ac.') ||
      domain.endsWith('.ac');

  /// Sends a REAL 6-digit OTP to the work/college email via the Resend-backed
  /// Cloud Function. Code generation, hashing, storage and rate limiting all
  /// happen on the server. No OTP or OTP database value reaches Flutter Web.
  Future<(Map<String, dynamic>?, String?)> _callOtpFunction(
    String functionName,
    Map<String, dynamic> data,
  ) async {
    final user = _auth.currentUser;
    if (user == null) return (null, 'Sign in again to continue.');
    try {
      final token = await user.getIdToken();
      if (token == null || token.isEmpty) {
        return (null, 'Your session expired. Sign in again to continue.');
      }
      final response = await http
          .post(
            Uri.parse(
              'https://us-central1-district-966f3.cloudfunctions.net/'
              '$functionName',
            ),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'data': data}),
          )
          .timeout(_netTimeout);

      dynamic decoded;
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        decoded = null;
      }
      if (response.statusCode == 200 && decoded is Map) {
        final result = decoded['result'];
        if (result is Map) {
          return (Map<String, dynamic>.from(result), null);
        }
      }
      final error = decoded is Map ? decoded['error'] : null;
      final message = error is Map ? '${error['message'] ?? ''}'.trim() : '';
      debugPrint('$functionName http ${response.statusCode}: ${response.body}');
      return (
        null,
        message.isNotEmpty
            ? message
            : 'The verification service is unavailable. Please try again.',
      );
    } on TimeoutException {
      return (
        null,
        'The verification service took too long to respond. Please retry.',
      );
    } catch (error) {
      debugPrint('$functionName failed: $error');
      return (
        null,
        'Could not reach the verification service. Check your connection and retry.',
      );
    }
  }

  /// Returns an actionable error string, or null when Resend accepted the mail.
  Future<String?> sendCorpEmailOtp(String email,
      {bool college = false, String orgName = ''}) async {
    if (!online || uid == null) return 'You need to be online.';
    email = email.trim().toLowerCase();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'Enter a valid email.';
    }
    final domain = email.split('@').last;
    if (college && !_looksAcademic(domain)) {
      return 'Use your COLLEGE email (…@xyz.edu / …ac.in / .edu.xx).';
    }
    if (!college && (_freeMail.contains(domain) || _looksAcademic(domain))) {
      return 'Use your WORK email — personal/college domains are not '
          'accepted for corporate spaces.';
    }
    final (result, error) = await _callOtpFunction('sendCorpOtp', {
      'to': email,
      'orgName': orgName.trim(),
      'college': college,
    });
    if (error != null) return error;
    return result?['ok'] == true
        ? null
        : 'The email provider did not accept the message. Please retry.';
  }

  /// Verifies the code server-side without reading RTDB from Flutter Web.
  Future<String?> verifyCorpEmailOtp(String email, String code) async {
    if (uid == null) return 'You need to be online.';
    email = email.trim().toLowerCase();
    final (result, error) = await _callOtpFunction('verifyCorpOtp', {
      'email': email,
      'code': code.trim(),
    });
    if (error != null) return error;
    return result?['ok'] == true
        ? null
        : 'The code could not be verified. Request a new one.';
  }

  /// Org names people must not be able to squat or spoof.
  static const _reservedOrgNames = {
    'mynd',
    'admin',
    'administrator',
    'official',
    'support',
    'moderator',
    'google',
    'firebase',
    'anthropic',
  };

  /// Validates an org (college/company) name: printable characters
  /// only, sane length, no reserved/impersonation names, no URLs or
  /// email-looking strings. Returns an error or null.
  static String? validateOrgName(String name) {
    final n = name.trim();
    if (n.length < 3) return 'Enter the full name (3+ characters).';
    if (n.length > 48) return 'Keep the name under 48 characters.';
    if (!RegExp(r"^[A-Za-z0-9 &.,'()\-]+$").hasMatch(n)) {
      return 'Only letters, numbers, spaces and & . , \' ( ) - are allowed.';
    }
    if (RegExp(r'(https?://|www\.|@)').hasMatch(n.toLowerCase())) {
      return 'Org names can\'t contain links or emails.';
    }
    if (_reservedOrgNames.contains(orgKey(n).replaceAll('_', ''))) {
      return 'That name is reserved.';
    }
    return null;
  }

  /// Joins an org; creates it first when it doesn't exist yet.
  /// [type] is 'college' or 'company'.
  /// Returns (error, createdNew).
  Future<(String?, bool)> joinOrg(String type, String name) async {
    if (!online || uid == null) {
      return ('This needs an internet connection.', false);
    }
    if (AppData.i.username.isEmpty) return ('Claim a username first.', false);
    final nameErr = validateOrgName(name);
    if (nameErr != null) return (nameErr, false);
    final key = orgKey(name);
    if (key.length < 3) return ('Enter the full name (3+ characters).', false);

    // One org affiliation total: a user reps EITHER a college OR a company,
    // never both. If the other kind is already set, they must leave it first.
    final otherLabel = type == 'college' ? 'company' : 'college';
    final otherName =
        type == 'college' ? AppData.i.company : AppData.i.college;
    if (otherName.isNotEmpty) {
      return (
        'You can only rep one — leave your $otherLabel ($otherName) first, '
            'then join a $type.',
        false
      );
    }
    // Switching to a different org of the SAME kind → drop the old membership
    // so a stale entry isn't left behind.
    final currentSame =
        type == 'college' ? AppData.i.college : AppData.i.company;
    if (currentSame.isNotEmpty && orgKey(currentSame) != key) {
      try {
        await _db
            .ref('orgs/$type/${orgKey(currentSame)}/members/${AppData.i.username}')
            .remove()
            .timeout(_netTimeout);
      } catch (_) {/* best-effort cleanup */}
    }

    try {
      final ref = _db.ref('orgs/$type/$key');
      final snap = await ref.child('name').get().timeout(_netTimeout);
      final createdNew = snap.value == null;
      if (createdNew) {
        await ref.set({
          'name': name.trim(),
          'createdAt': DateTime.now().millisecondsSinceEpoch,
          'members': {AppData.i.username: _myMemberStats},
        }).timeout(_netTimeout);
      } else {
        await ref
            .child('members/${AppData.i.username}')
            .set(_myMemberStats)
            .timeout(_netTimeout);
      }
      if (type == 'college') {
        AppData.i.college = name.trim();
      } else {
        AppData.i.company = name.trim();
      }
      await AppData.i.save();
      return (null, createdNew);
    } catch (_) {
      return ('Could not reach the server — try again.', false);
    }
  }

  Future<Map<String, dynamic>?> fetchOrg(String type, String name) async {
    if (!online) return null;
    try {
      final snap = await _db
          .ref('orgs/$type/${orgKey(name)}')
          .get()
          .timeout(_netTimeout);
      final m = snap.value as Map<dynamic, dynamic>?;
      return m == null ? null : Map<String, dynamic>.from(m);
    } catch (_) {
      return null;
    }
  }

  Future<void> leaveOrg(String type) async {
    final name = type == 'college' ? AppData.i.college : AppData.i.company;
    if (online && name.isNotEmpty && AppData.i.username.isNotEmpty) {
      try {
        await _db
            .ref('orgs/$type/${orgKey(name)}/members/${AppData.i.username}')
            .remove()
            .timeout(_netTimeout);
      } catch (_) {}
    }
    if (type == 'college') {
      AppData.i.college = '';
    } else {
      AppData.i.company = '';
    }
    await AppData.i.save();
  }

  /// Refreshes my stats inside squad & org member lists (best-effort,
  /// piggybacks on public-profile updates after matches).
  Future<void> syncMemberships() async {
    if (!online || AppData.i.username.isEmpty) return;
    final stats = _myMemberStats;
    final u = AppData.i.username;
    try {
      if (AppData.i.squadId.isNotEmpty) {
        await _db
            .ref('squads/${AppData.i.squadId}/members/$u')
            .update(stats)
            .timeout(_netTimeout);
      }
      if (AppData.i.college.isNotEmpty) {
        await _db
            .ref('orgs/college/${orgKey(AppData.i.college)}/members/$u')
            .update(stats)
            .timeout(_netTimeout);
      }
      if (AppData.i.company.isNotEmpty) {
        await _db
            .ref('orgs/company/${orgKey(AppData.i.company)}/members/$u')
            .update(stats)
            .timeout(_netTimeout);
      }
    } catch (_) {/* best-effort */}
  }

  // ==================== ONLINE ROOMS (all games) ====================
  //
  // One protocol for every 1v1 game: question duels, real chess,
  // darts and the Rubik's cube race.
  //   /rooms/{id}   {game, sub, seed, code, host{u,elo}, guest{...},
  //                  state{...}, createdAt}
  //   /room_codes/{CODE} = roomId
  //   /queue/{game}_{sub}/{pushId} = {uid, elo, room, at}
  // Matchmaking pairs you with the closest-rated waiting player.

  Stream<Map<String, dynamic>?> roomStream(String id) =>
      _db.ref('rooms/$id').onValue.map((e) {
        final m = e.snapshot.value as Map<dynamic, dynamic>?;
        return m == null ? null : Map<String, dynamic>.from(m);
      });

  Future<void> roomWrite(String id, String path, Object? value) async {
    if (!online) return;
    try {
      await _db.ref('rooms/$id/$path').set(value).timeout(_netTimeout);
    } catch (_) {/* best-effort */}
  }

  /// Keep the active game room hot in the local cache — moves render
  /// instantly with no cold-start fetch. Call with false when leaving.
  void pinRoom(String id, bool pin) {
    if (!online) return;
    try {
      _db.ref('rooms/$id').keepSynced(pin);
    } catch (_) {}
  }

  /// Atomic first-finisher claim for race games (cube, speed solves).
  /// Exactly ONE side can ever win: the transaction commits only for
  /// the first writer; everyone else sees their claim rejected.
  Future<bool> claimRoomWin(String id, String side) async {
    if (!online) return true;
    try {
      final result =
          await _db.ref('rooms/$id/state/winner').runTransaction((raw) {
        if (raw != null && raw != side) return Transaction.abort();
        return Transaction.success(side);
      }).timeout(_netTimeout);
      return result.committed;
    } catch (_) {
      return true; // offline blip — let local result stand
    }
  }

  Map<String, dynamic> _mySideData() => {
        'u': AppData.i.username.isEmpty ? AppData.i.name : AppData.i.username,
        'elo': AppData.i.elo,
      };

  static String inviteMessage(String label, String code) =>
      '⚔️ I challenge you to $label on MYNDASH!\n'
      'Open MYNDASH → 1v1 → I HAVE A CODE → enter: $code\n'
      'Loser buys snacks 😤\n\n'
      '🧠 Play MYNDASH free → https://myndash.online';

  /// Creates a friend-invite room. Returns (error, room-with-id).
  // ---------------- demo bot opponents ----------------
  // 100 seeded bots (/bots) stand in when no human is searching, so an
  // online search never dead-ends. Cached after the first read.
  List<Map<String, dynamic>>? _botsCache;

  Future<List<Map<String, dynamic>>> _loadBots() async {
    if (_botsCache != null) return _botsCache!;
    if (!online) return [];
    try {
      final snap = await _db.ref('bots').get().timeout(_netTimeout);
      final m = snap.value as Map<dynamic, dynamic>?;
      final out = <Map<String, dynamic>>[];
      m?.forEach((k, v) {
        if (v is Map) out.add({'uid': '$k', ...Map<String, dynamic>.from(v)});
      });
      _botsCache = out;
      return out;
    } catch (_) {
      return [];
    }
  }

  /// Picks a bot opponent whose rating is near [rating] (with a little
  /// spread so it isn't always the exact-closest). Returns null if the
  /// bot pool couldn't be loaded.
  Future<Map<String, dynamic>?> pickBotOpponent(int rating) async {
    final bots = await _loadBots();
    if (bots.isEmpty) return null;
    final sorted = [...bots]..sort((a, b) =>
        ((a['elo'] as num? ?? 800) - rating)
            .abs()
            .compareTo(((b['elo'] as num? ?? 800) - rating).abs()));
    // pick randomly among the 8 closest for variety
    final pool = sorted.take(8).toList();
    return pool[Random().nextInt(pool.length)];
  }

  Future<(String?, Map<String, dynamic>?)> createRoom(String game, String sub,
      {int timeMinutes = 0, int ratingMin = 800, int ratingMax = 2500}) async {
    if (!online || uid == null) {
      return ('You need to be online for friend battles.', null);
    }
    final limitErr = await _rateLimitCheck('room_create', label: 'new rooms');
    if (limitErr != null) return (limitErr, null);
    try {
      final ref = _db.ref('rooms').push();
      final code = _newCode();
      final room = <String, dynamic>{
        'game': game,
        'sub': sub,
        'code': code,
        'seed': Random().nextInt(1 << 31),
        'ratingMin': ratingMin.clamp(800, 2500),
        'ratingMax': ratingMax.clamp(800, 2500),
        'createdAt': ServerValue.timestamp,
        'host': _mySideData(),
        if (timeMinutes > 0) 't': timeMinutes,
      };
      await ref.set(room).timeout(_netTimeout);
      await _db.ref('room_codes/$code').set(ref.key).timeout(_netTimeout);
      room['id'] = ref.key;
      await _rateLimitRecord('room_create');
      return (null, room);
    } catch (_) {
      return ('Could not reach the cloud — check your internet.', null);
    }
  }

  /// Join a friend's room by its 6-char code. Returns (error, room).
  Future<(String?, Map<String, dynamic>?)> joinRoomByCode(String code) async {
    if (!online || uid == null) {
      return ('You need to be online for friend battles.', null);
    }
    code = code.trim().toUpperCase();
    try {
      final idSnap =
          await _db.ref('room_codes/$code').get().timeout(_netTimeout);
      final id = idSnap.value as String?;
      if (id == null) return ('No room with that code.', null);
      final myU =
          AppData.i.username.isEmpty ? AppData.i.name : AppData.i.username;
      // atomic guest claim — two DIFFERENT joiners can't both take the
      // seat, but re-entering my own seat (retry / reconnect) is allowed
      // so a room I already joined never falsely reports "full".
      final result = await _db.ref('rooms/$id/guest').runTransaction((raw) {
        if (raw != null) {
          if (raw is Map && raw['u'] == myU) return Transaction.success(raw);
          return Transaction.abort();
        }
        return Transaction.success(_mySideData());
      }).timeout(_netTimeout);
      if (!result.committed) return ('That room is already full.', null);
      final snap = await _db.ref('rooms/$id').get().timeout(_netTimeout);
      final m = snap.value as Map<dynamic, dynamic>?;
      if (m == null) return ('Room vanished — ask for a new code.', null);
      final room = Map<String, dynamic>.from(m);
      room['id'] = id;
      return (null, room);
    } catch (_) {
      return ('Could not reach the cloud — check your internet.', null);
    }
  }

  /// ---------------- ONLINE MATCHMAKING 2.0 ----------------
  ///
  /// The old flow read the queue ONCE: if two players searched at the
  /// same moment, both saw an empty queue, both hosted, and both sat
  /// waiting until the 30s timeout — the exact "search never matches"
  /// bug. The new protocol is event-driven and deadlock-free:
  ///
  ///  1. I publish my ticket at queue/{key}/{uid} (keyed by uid — a
  ///     re-search overwrites instead of duplicating) and host a room.
  ///  2. I LISTEN to the queue the whole time. Total order rule: a
  ///     player only ever claims tickets OLDER than their own (ties
  ///     broken by uid). So of any two waiting players exactly one is
  ///     the claimer and one the claimee — mutual-wait deadlock and
  ///     claim-each-other livelock are both structurally impossible.
  ///  3. Claims are two lock-free atomic transactions (take ticket →
  ///     take guest seat); losers of a race just rescan. Nobody ever
  ///     blocks anybody.
  ///  4. Rating gate widens over time: ±300 → ±600 → anyone, so good
  ///     matches are preferred but nobody starves.
  ///  5. 60s window, stale tickets (>2 min) are ignored and reaped,
  ///     onDisconnect cleans up after crashes.
  Future<(String?, Map<String, dynamic>?, bool)> quickMatch(
    String game,
    String sub, {
    int timeMinutes = 0,
    int ratingMin = 800,
    int ratingMax = 2500,
    Duration searchWindow = const Duration(seconds: 60),
    void Function(String status)? onStatus,
  }) async {
    if (!online || uid == null) {
      return ('You need to be online to matchmake.', null, false);
    }
    // Time control partitions the queue so you only pair with a rival on the
    // same clock; the chosen minutes ride along on the room too.
    final qKey =
        timeMinutes > 0 ? '${game}_${sub}_t$timeMinutes' : '${game}_$sub';
    final qRef = _db.ref('queue/$qKey');
    final myUid = uid!;

    DatabaseReference? myTicket;
    String? myRoomId;
    StreamSubscription? guestSub;
    StreamSubscription? queueSub;
    Timer? rescanTimer;
    Timer? timeoutTimer;
    final done = Completer<(String?, Map<String, dynamic>?, bool)>();
    var claiming = false;

    Future<void> cleanup({bool removeRoom = true}) async {
      await guestSub?.cancel();
      await queueSub?.cancel();
      rescanTimer?.cancel();
      timeoutTimer?.cancel();
      try {
        await myTicket?.remove();
      } catch (_) {}
      if (removeRoom && myRoomId != null) {
        try {
          // only tear down my room if nobody claimed the guest seat
          final g = await _db.ref('rooms/$myRoomId/guest').get();
          if (g.value == null) await _db.ref('rooms/$myRoomId').remove();
        } catch (_) {}
      }
    }

    void finish((String?, Map<String, dynamic>?, bool) result) {
      if (!done.isCompleted) done.complete(result);
    }

    /// Strict total order over tickets: (at, uid). I may only claim
    /// tickets that sort BEFORE mine.
    bool olderThanMine(int at, String tUid, int myAt) =>
        at < myAt || (at == myAt && tUid.compareTo(myUid) < 0);

    Future<void> tryClaim(Map<dynamic, dynamic> waiting, int myAt) async {
      if (claiming || done.isCompleted) return;
      claiming = true;
      try {
        final now = DateTime.now().millisecondsSinceEpoch;
        // claimable = older than me, not me, not stale, inside band
        final candidates = <(String tUid, String room, int diff, int at)>[];
        waiting.forEach((k, v) {
          if (v is! Map) return;
          final tUid = '$k';
          if (tUid == myUid) return;
          final at = (v['at'] as num?)?.toInt() ?? 0;
          if (now - at > 120000) {
            // stale crash-leftover: reap it (best-effort) and skip
            qRef.child(tUid).remove();
            return;
          }
          if (!olderThanMine(at, tUid, myAt)) return;
          final theirElo = (v['elo'] as num?)?.toInt() ?? 800;
          final theirMin = (v['ratingMin'] as num?)?.toInt() ?? 800;
          final theirMax = (v['ratingMax'] as num?)?.toInt() ?? 2500;
          if (ratingMax < theirMin || theirMax < ratingMin) {
            return;
          }
          // Match ANY waiting human regardless of rating — a real opponent
          // always beats a bot. Rating is only a preference: we still sort
          // closest-first below, but never reject someone for being too far.
          final diff = (theirElo - AppData.i.elo).abs().toInt();
          candidates.add((tUid, '${v['room']}', diff, at));
        });
        candidates.sort((a, b) => a.$3.compareTo(b.$3)); // closest rating first
        for (final c in candidates) {
          if (done.isCompleted) return;
          // atomic take of their ticket — exactly one claimer can win
          final claim = await qRef.child(c.$1).runTransaction((raw) {
            if (raw == null) return Transaction.abort();
            return Transaction.success(null);
          }).timeout(_netTimeout);
          if (!claim.committed) continue;
          // atomic take of their guest seat
          final gr = await _db.ref('rooms/${c.$2}/guest').runTransaction((raw) {
            if (raw != null) return Transaction.abort();
            return Transaction.success(_mySideData());
          }).timeout(_netTimeout);
          if (!gr.committed) continue;
          await _db.ref('rooms/${c.$2}').update({
            'ratingMin': max(ratingMin,
                (waiting[c.$1]?['ratingMin'] as num?)?.toInt() ?? 800),
            'ratingMax': min(ratingMax,
                (waiting[c.$1]?['ratingMax'] as num?)?.toInt() ?? 2500),
          }).timeout(_netTimeout);
          final snap =
              await _db.ref('rooms/${c.$2}').get().timeout(_netTimeout);
          final m = snap.value as Map<dynamic, dynamic>?;
          if (m == null) continue;
          final room = Map<String, dynamic>.from(m);
          room['id'] = c.$2;
          await cleanup();
          finish((null, room, false));
          return;
        }
      } catch (_) {/* transient — rescan will retry */} finally {
        claiming = false;
      }
    }

    try {
      onStatus?.call('Setting up your room…');
      // ---- 1) host a room + publish my ticket (keyed by uid) ----
      final (err, room) = await createRoom(game, sub,
          timeMinutes: timeMinutes, ratingMin: ratingMin, ratingMax: ratingMax);
      if (err != null || room == null) return (err, null, false);
      myRoomId = room['id'] as String;
      final myAt = DateTime.now().millisecondsSinceEpoch;
      final ticket = qRef.child(myUid);
      myTicket = ticket;
      await ticket.set({
        'uid': myUid,
        'elo': AppData.i.elo,
        'ratingMin': ratingMin,
        'ratingMax': ratingMax,
        'room': myRoomId,
        'at': myAt, // client clock is fine: ordering just needs consistency
      }).timeout(_netTimeout);
      ticket.onDisconnect().remove();

      onStatus?.call('Scanning for rivals…');

      // ---- 2) someone might claim MY seat at any moment ----
      guestSub = _db.ref('rooms/$myRoomId/guest').onValue.listen((e) async {
        if (e.snapshot.value == null || done.isCompleted) return;
        final snap =
            await _db.ref('rooms/$myRoomId').get().timeout(_netTimeout);
        final m = snap.value as Map<dynamic, dynamic>?;
        final full = Map<String, dynamic>.from(m ?? room);
        full['id'] = myRoomId!;
        full['guest'] ??= e.snapshot.value;
        await cleanup(removeRoom: false);
        finish((null, full, true));
      });

      // ---- 3) live queue watch: claim older tickets as they appear ----
      queueSub = qRef.onValue.listen((e) {
        final waiting = e.snapshot.value as Map<dynamic, dynamic>?;
        if (waiting != null) tryClaim(waiting, myAt);
      });

      // ---- 4) periodic rescan (catches any missed queue events) ----
      rescanTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
        if (done.isCompleted) return;
        try {
          final s = await qRef.get().timeout(_netTimeout);
          final waiting = s.value as Map<dynamic, dynamic>?;
          if (waiting != null) tryClaim(waiting, myAt);
        } catch (_) {}
      });

      // ---- 5) give up after the window ----
      timeoutTimer = Timer(searchWindow, () async {
        await cleanup();
        finish((
          'No rivals online right now — invite a friend with a code!',
          null,
          false
        ));
      });

      return await done.future;
    } catch (_) {
      await cleanup();
      return ('Matchmaking hiccup — try again.', null, false);
    }
  }

  // ============================ BANKS ============================

  /// Admin devices mirror the fixed-seed question banks to /banks so
  /// the "papers" are inspectable in the database (100 days daily,
  /// 100 days drops, 20 contests, 60 days × 6 brackets of official
  /// arenas). Runs once per bank version. The arena mirror is written
  /// in per-day chunks so no single write gets huge.
  Future<void> maybeSeedBanks() async {
    if (!online || !AppData.i.adminOverride) return;
    try {
      final v = await _db.ref('banks/version').get().timeout(_netTimeout);
      if (v.value == 4) return;
      final payload = <String, dynamic>{'version': 4};
      for (var d = 0; d < 100; d++) {
        final expanded = dailyChallengeDay(d);
        for (final item in expanded.all) {
          payload['daily_v2/d$d/${item.id}'] = {
            'type': item.type.name,
            'title': item.title,
            'p': item.prompt ?? item.subtitle,
            if (item.answer != null) 'a': item.answer,
            'rating': item.rating,
            'xp': item.xp,
            'coins': item.coins,
            'seed': item.seed,
          };
        }
        for (var s = 0; s < 5; s++) {
          final q = bankDaily(d, s);
          payload['daily/d$d/q$s'] = {'p': q.prompt, 'a': q.answer};
        }
        for (var i = 0; i < 8; i++) {
          final q = bankDrop(d, i);
          payload['drops/d$d/q$i'] = {'p': q.prompt, 'a': q.answer};
        }
      }
      for (var c = 0; c < 20; c++) {
        for (var qi = 0; qi < 12; qi++) {
          final q = bankContest(c, qi, 12);
          payload['contests/c$c/q$qi'] = {'p': q.prompt, 'a': q.answer};
        }
      }
      await _db.ref('banks').update(payload);
      // official arenas: 60+ days of papers, one chunked write per day
      // (6 brackets × 30 questions = 180 entries per chunk).
      for (var d = 0; d < 62; d++) {
        final chunk = <String, dynamic>{};
        for (var b = 0; b < officialBrackets.length; b++) {
          for (var qi = 0; qi < arenaQuestionCount; qi++) {
            final q = bankArena(d, b, qi);
            chunk['b$b/q$qi'] = {'p': q.prompt, 'a': q.answer};
          }
        }
        await _db.ref('banks/arenas/d$d').update(chunk);
      }
    } catch (_) {/* best-effort */}
  }

  // ============================ CONTEST HISTORY ============================

  /// Registers the signed-in player for one official weekly contest and also
  /// writes a private user index. The second path lets the Contest hub show
  /// only this player's joined events instead of downloading the full event
  /// catalog or participant list.
  Future<String?> registerOfficialContest({
    required String eventKey,
    required int startsAt,
    required String kind,
    required int paperIndex,
  }) async {
    final userId = uid;
    if (!online || userId == null || eventKey.isEmpty) {
      return 'Your session is still connecting. Please retry in a moment.';
    }
    try {
      await FirebaseFunctions.instance.httpsCallable('registerOfficialContest', options: HttpsCallableOptions(timeout: const Duration(seconds: 30)))
          .call<void>({
        'eventKey': eventKey,
        // These fields are display metadata only. The callable derives and
        // validates the real start from eventKey before writing anything.
        'startsAt': startsAt,
        'kind': kind,
        'paperIndex': paperIndex,
      }).timeout(const Duration(seconds: 35));
      return null;
    } catch (error) {
      return _competitionFunctionError(
        error,
        fallback: 'Could not register. Check your connection and try again.',
      );
    }
  }

  Future<CompetitionAccess> authorizeOfficialContest(String eventKey) async {
    if (!online || uid == null) {
      return const CompetitionAccess(
        allowed: false,
        message: 'Your session is still connecting. Please retry.',
      );
    }
    try {
      final result = await FirebaseFunctions.instance.httpsCallable('authorizeOfficialContest', options: HttpsCallableOptions(timeout: const Duration(seconds: 30)))
          .call<Map<Object?, Object?>>({'eventKey': eventKey}).timeout(
              _netTimeout);
      final data = Map<String, dynamic>.from(result.data);
      return CompetitionAccess(
        allowed: data['allowed'] == true,
        message: data['message'] as String?,
        startsAt: (data['startsAt'] as num?)?.toInt(),
      );
    } catch (error) {
      return CompetitionAccess(
        allowed: false,
        message: _competitionFunctionError(
          error,
          fallback: 'Could not verify your contest registration.',
        ),
      );
    }
  }

  /// Event keys registered by the current account. Null means the cloud is
  /// unavailable; an empty set is a valid online account with no registrations.
  Future<Set<String>?> myOfficialContestRegistrations() async {
    final userId = uid;
    if (!online || userId == null) return null;
    try {
      final snap =
          await _db.ref('contest_users/$userId').get().timeout(const Duration(seconds: 35));
      final value = snap.value as Map<dynamic, dynamic>?;
      return value?.keys.map((key) => '$key').toSet() ?? <String>{};
    } catch (_) {
      return null;
    }
  }

  Future<void> submitOfficialContestResult({
    required String eventKey,
    required int score,
    required int solved,
    required int elapsedMs,
  }) async {
    final userId = uid;
    if (!online || userId == null || eventKey.isEmpty) return;
    try {
      await FirebaseFunctions.instance.httpsCallable('submitOfficialContestResult', options: HttpsCallableOptions(timeout: const Duration(seconds: 30)))
          .call<void>({
        'eventKey': eventKey,
        'score': score,
        'solved': solved,
        'elapsedMs': elapsedMs,
      }).timeout(const Duration(seconds: 35));
    } catch (_) {/* best-effort */}
  }

  /// Final official standings. Score wins; elapsed time breaks equal scores.
  Future<List<Map<String, dynamic>>?> fetchOfficialContestResults(
      String eventKey) async {
    if (!online) return null;
    try {
      final snap = await _db
          .ref('official_contests/$eventKey/results')
          .get()
          .timeout(_netTimeout);
      final results = snap.value as Map<dynamic, dynamic>?;
      if (results == null) return [];
      final out = <Map<String, dynamic>>[];
      results.forEach((key, value) {
        if (value is Map) {
          final row = Map<String, dynamic>.from(value);
          out.add({
            'user': '${row['username'] ?? key}',
            'name': '${row['name'] ?? ''}',
            'score': (row['score'] as num?)?.toInt() ?? 0,
            'solved': (row['solved'] as num?)?.toInt() ?? 0,
            'elapsedMs': (row['elapsedMs'] as num?)?.toInt() ?? 2700000,
          });
        } else {
          // Backward-compatible with the original integer-only result shape.
          out.add({
            'user': '$key',
            'name': '',
            'score': (value as num?)?.toInt() ?? 0,
            'solved': 0,
            'elapsedMs': 2700000,
          });
        }
      });
      out.sort((a, b) {
        final byScore = (b['score'] as int).compareTo(a['score'] as int);
        if (byScore != 0) return byScore;
        return (a['elapsedMs'] as int).compareTo(b['elapsedMs'] as int);
      });
      return out;
    } catch (_) {
      return null;
    }
  }

  Future<void> submitContestScore(
      String dayKey, String format, int score) async {
    if (!online || AppData.i.username.isEmpty) return;
    try {
      await _db
          .ref('contest_scores/$dayKey/$format/${AppData.i.username}')
          .set(score)
          .timeout(_netTimeout);
    } catch (_) {/* best-effort */}
  }

  Future<List<MapEntry<String, int>>?> fetchContestScores(
      String dayKey, String format) async {
    if (!online) return null;
    try {
      final snap = await _db
          .ref('contest_scores/$dayKey/$format')
          .get()
          .timeout(_netTimeout);
      final scores = snap.value as Map<dynamic, dynamic>?;
      if (scores == null) return [];
      final out = scores.entries
          .map((entry) => MapEntry(
                '${entry.key}',
                (entry.value as num?)?.toInt() ?? 0,
              ))
          .toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      return out;
    } catch (_) {
      return null;
    }
  }

  // ============================ LIVE DROPS ============================

  Future<void> submitDropScore(String dropKey, int score) async {
    if (!online || AppData.i.username.isEmpty) return;
    try {
      await _db
          .ref('drops/$dropKey/${AppData.i.username}')
          .set(score)
          .timeout(_netTimeout);
    } catch (_) {/* best-effort */}
  }

  /// username → score, sorted descending. Null when unreachable.
  Future<List<MapEntry<String, int>>?> fetchDropScores(String dropKey) async {
    if (!online) return null;
    try {
      final snap = await _db.ref('drops/$dropKey').get().timeout(_netTimeout);
      final m = snap.value as Map<dynamic, dynamic>?;
      if (m == null) return [];
      final out = m.entries
          .map((e) => MapEntry('${e.key}', (e.value as num?)?.toInt() ?? 0))
          .toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      return out;
    } catch (_) {
      return null;
    }
  }
}
