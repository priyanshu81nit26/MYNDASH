import 'dart:math';

/// ------------------------- Round types -------------------------
enum RoundType {
  strike,
  trap,
  target,
  sequence,
  math,
  // expansion — parameterized by seed, 50+ total variations
  stroop,
  oddemoji,
  countdots,
  arrows,
  bigger,
  memflash,
  avoid,
}

extension RoundTypeX on RoundType {
  String get title => switch (this) {
        RoundType.strike => 'STRIKE',
        RoundType.trap => 'TRAP',
        RoundType.target => 'TARGET',
        RoundType.sequence => 'SEQUENCE',
        RoundType.math => 'MATH FLASH',
        RoundType.stroop => 'COLOR TRAP',
        RoundType.oddemoji => 'ODD ONE',
        RoundType.countdots => 'DOT COUNT',
        RoundType.arrows => 'ARROW FLIP',
        RoundType.bigger => 'BIG NUMBER',
        RoundType.memflash => 'MEM FLASH',
        RoundType.avoid => 'BOMB DODGE',
      };

  String get hint => switch (this) {
        RoundType.strike =>
          'Tap when the screen turns GREEN. Early tap = lose!',
        RoundType.trap => 'Red TRAP is a lie. Only tap the green GO!',
        RoundType.target => 'Hit the shrinking target before your rival.',
        RoundType.sequence => 'Memorize the arrows. Repeat them fastest.',
        RoundType.math => 'Solve it. Tap the correct answer first.',
        RoundType.stroop => 'Tap the COLOR of the word — not what it says!',
        RoundType.oddemoji => 'One emoji is different. Find it first.',
        RoundType.countdots => 'Count the dots — tap the right number.',
        RoundType.arrows => 'Tap the OPPOSITE of the arrow. Stay sharp.',
        RoundType.bigger => 'Tap the bigger number. Sounds easy. Isn\'t.',
        RoundType.memflash => 'Memorize the number, then pick it.',
        RoundType.avoid => 'Tap every ⭐ — never the 💣!',
      };
}

/// A round both players play simultaneously.
/// Everything is derived from [seed], so both phones generate the
/// exact same challenge; [goAtMs] is a shared server-clock timestamp.
class RoundSpec {
  final int index;
  final RoundType type;
  final int seed;
  final int goAtMs;

  const RoundSpec({
    required this.index,
    required this.type,
    required this.seed,
    required this.goAtMs,
  });

  // Shuffle-bag rotation: draw every RoundType once (in random order) before
  // any repeats, and never start a fresh bag with the type we just showed. So
  // all 12 challenges cycle evenly and none recurs back-to-back — no more
  // "same few keep coming up" predictability. Seeds stay fully random, so the
  // actual puzzle differs every time even within a type.
  // ponytail: static bag, fine because only one duel is ever live at once.
  static final List<RoundType> _bag = [];
  static RoundType? _lastType;

  static RoundType _nextType(Random rng) {
    if (_bag.isEmpty) {
      _bag.addAll(RoundType.values);
      _bag.shuffle(rng);
      if (_bag.first == _lastType && _bag.length > 1) {
        _bag.add(_bag.removeAt(0)); // don't repeat across the bag seam
      }
    }
    final t = _bag.removeAt(0);
    _lastType = t;
    return t;
  }

  factory RoundSpec.generate({required int index, required int serverNowMs}) {
    final rng = Random();
    return RoundSpec(
      index: index,
      type: _nextType(rng),
      seed: rng.nextInt(1 << 31),
      goAtMs: serverNowMs + 3800 + rng.nextInt(2500),
    );
  }

  Map<String, dynamic> toMap() =>
      {'i': index, 't': type.index, 's': seed, 'go': goAtMs};

  static RoundSpec? fromMap(Map<dynamic, dynamic>? m) {
    if (m == null) return null;
    return RoundSpec(
      index: (m['i'] as num?)?.toInt() ?? 0,
      type: RoundType.values[(m['t'] as num?)?.toInt() ?? 0],
      seed: (m['s'] as num?)?.toInt() ?? 0,
      goAtMs: (m['go'] as num?)?.toInt() ?? 0,
    );
  }
}

/// A player's outcome for one round.
/// timeMs: reaction time in ms. -1 = false start / wrong answer.
class RoundResult {
  final int timeMs;
  const RoundResult(this.timeMs);
  bool get valid => timeMs >= 0;

  Map<String, dynamic> toMap() => {'t': timeMs};
  static RoundResult? fromMap(Map<dynamic, dynamic>? m) =>
      m == null ? null : RoundResult((m['t'] as num?)?.toInt() ?? -1);
}

/// ------------------------- Player profile -------------------------
class PlayerProfile {
  final String uid;
  String name;
  int wins;
  int losses;
  int streak;
  int bestStreak;
  int xp;

  PlayerProfile({
    required this.uid,
    this.name = 'Player',
    this.wins = 0,
    this.losses = 0,
    this.streak = 0,
    this.bestStreak = 0,
    this.xp = 0,
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'wins': wins,
        'losses': losses,
        'streak': streak,
        'bestStreak': bestStreak,
        'xp': xp,
      };

  static PlayerProfile fromMap(String uid, Map<dynamic, dynamic>? m) {
    m ??= {};
    return PlayerProfile(
      uid: uid,
      name: (m['name'] as String?) ?? 'Player',
      wins: (m['wins'] as num?)?.toInt() ?? 0,
      losses: (m['losses'] as num?)?.toInt() ?? 0,
      streak: (m['streak'] as num?)?.toInt() ?? 0,
      bestStreak: (m['bestStreak'] as num?)?.toInt() ?? 0,
      xp: (m['xp'] as num?)?.toInt() ?? 0,
    );
  }
}

/// ------------------------- Room -------------------------
class RoomPlayer {
  final String uid;
  final String name;
  final int score;
  final bool connected;
  const RoomPlayer({
    required this.uid,
    required this.name,
    this.score = 0,
    this.connected = true,
  });

  static RoomPlayer fromMap(String uid, Map<dynamic, dynamic> m) => RoomPlayer(
        uid: uid,
        name: (m['name'] as String?) ?? 'Player',
        score: (m['score'] as num?)?.toInt() ?? 0,
        connected: (m['connected'] as bool?) ?? true,
      );
}

class LastRound {
  final int index;
  final String? winnerUid; // null = draw
  final int myTime;
  final int oppTime;
  const LastRound(this.index, this.winnerUid, this.myTime, this.oppTime);
}

class Room {
  final String code;
  final String hostUid;
  final String? guestUid;
  final String state; // waiting | playing | done
  final Map<String, RoomPlayer> players;
  final RoundSpec? currentRound;
  final Map<String, RoundResult> results;
  final Map<dynamic, dynamic>? lastRound;
  final String? winnerUid;
  final int targetScore;

  const Room({
    required this.code,
    required this.hostUid,
    this.guestUid,
    required this.state,
    required this.players,
    this.currentRound,
    this.results = const {},
    this.lastRound,
    this.winnerUid,
    this.targetScore = 4,
  });

  static Room? fromSnapshot(String code, Map<dynamic, dynamic>? m) {
    if (m == null) return null;
    final playersRaw = (m['players'] as Map<dynamic, dynamic>?) ?? {};
    final players = <String, RoomPlayer>{
      for (final e in playersRaw.entries)
        e.key as String: RoomPlayer.fromMap(
            e.key as String, e.value as Map<dynamic, dynamic>)
    };
    final resultsRaw = (m['results'] as Map<dynamic, dynamic>?) ?? {};
    final results = <String, RoundResult>{
      for (final e in resultsRaw.entries)
        e.key as String:
            RoundResult.fromMap(e.value as Map<dynamic, dynamic>) ??
                const RoundResult(-1)
    };
    return Room(
      code: code,
      hostUid: (m['host'] as String?) ?? '',
      guestUid: m['guest'] as String?,
      state: (m['state'] as String?) ?? 'waiting',
      players: players,
      currentRound: RoundSpec.fromMap(m['round'] as Map<dynamic, dynamic>?),
      results: results,
      lastRound: m['lastRound'] as Map<dynamic, dynamic>?,
      winnerUid: m['winner'] as String?,
      targetScore: (m['target'] as num?)?.toInt() ?? 4,
    );
  }

  RoomPlayer? me(String uid) => players[uid];
  RoomPlayer? opponent(String uid) {
    for (final p in players.values) {
      if (p.uid != uid) return p;
    }
    return null;
  }

  bool get full => players.length >= 2;
}
