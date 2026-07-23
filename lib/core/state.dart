import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../engine/game_progression.dart';
import '../engine/rating_catalog.dart';

/// A tenure rank the player earns by how long they've been on MYNDASH.
/// Milestones: day 1 → Beginner (from the very start, no lesser rank before
/// it), 1 month → Practitioner, 3 months → Challenger, 6 months → Hustler.
/// Each has its own card art (assets/mynd_cards/…) used as the Wrapped
/// title-card background and in the Journey timeline.
enum MyndTitle {
  beginner(0, 'Beginner', 'assets/mynd_cards/beginner.jpg', Color(0xFF22D3EE)),
  practitioner(30, 'Practitioner', 'assets/mynd_cards/practitioner.jpg',
      Color(0xFF34D399)),
  challenger(
      90, 'Challenger', 'assets/mynd_cards/challenger.jpg', Color(0xFF60A5FA)),
  hustler(180, 'Hustler', 'assets/mynd_cards/hustler.jpg', Color(0xFF4ADE80));

  const MyndTitle(this.days, this.label, this.asset, this.color);

  /// Days on the platform required to earn this title.
  final int days;
  final String label;
  final String asset;
  final Color color;

  static MyndTitle forDays(int days) {
    MyndTitle t = MyndTitle.beginner;
    for (final v in MyndTitle.values) {
      if (days >= v.days) t = v;
    }
    return t;
  }

  /// The next rank to chase, or null once Hustler is reached.
  MyndTitle? get next {
    final i = index;
    return i + 1 < MyndTitle.values.length ? MyndTitle.values[i + 1] : null;
  }
}

/// Persistent app data — account, coins, XP, ratings, level stars,
/// daily challenge, contest rating, social cache, orders.
class AppData extends ChangeNotifier {
  AppData._();
  static final AppData i = AppData._();

  SharedPreferences? _prefs;

  // ---------------- account ----------------
  bool onboarded = false;
  String name = 'Challenger'; // display name
  String username = ''; // unique handle (≥6 chars)
  String usernameChangedAt = ''; // ISO date of last change
  String avatarPath = ''; // legacy local file path — no longer written to
  // Base64 photo bytes — the one avatar representation that works on every
  // platform (web has no dart:io File, so a path-based avatar never rendered
  // there; bytes render everywhere via Image.memory/MemoryImage).
  String avatarB64 = '';
  String authMethod = ''; // 'google' | 'email' | 'phone' | 'guest'
  String bio = ''; // short public bio, shown on the profile others see
  String contactEmail = ''; // profile contact info — NOT the sign-in email
  String contactPhone = ''; // profile contact info — device-local only

  // ---------------- economy & progression ----------------
  int coins = 500;
  int xp = 0;
  int elo = 800; // 1v1/arena rating
  int contestRating = 1500; // weekly contest rating (titles)
  String lastContestKey = ''; // prevents double entry per contest day
  int freeHints = 3; // reset each level run

  // ---------------- daily challenge (5 math + 6 open games) ----------------
  String dailyKey = ''; // date the progress belongs to
  int dailySolved = 0; // legacy mirror: consecutive math solves, 0..5
  List<String> dailyCompleted = [];
  List<Map<String, dynamic>> dailyArchive = [];
  int streak = 0;
  String lastDaily = ''; // last date any daily-challenge item was cleared

  // ---------------- solve progress ----------------
  /// catId -> { 'unlocked': 800, 'stars': {'800': 2, ...} }
  Map<String, dynamic> cats = {};

  // ---------------- social (cloud-synced when online) ----------------
  List<String> following = [];
  List<String> followers = [];

  /// Incoming follow requests (usernames) — Instagram-style: someone
  /// tapped FOLLOW on you; they only become a follower once you accept.
  List<String> followRequests = [];

  /// Outgoing requests I've sent that are still pending.
  List<String> sentRequests = [];

  List<String> get friends =>
      following.where((u) => followers.contains(u)).toList();

  // ---------------- store ----------------
  List<Map<String, dynamic>> orders = [];

  /// What others may see on your public profile.
  Map<String, dynamic> publicPrefs = {
    'elo': true,
    'matches': true,
    'streak': true,
    'orgs': true,
  };

  // ---------------- account age / tenure ----------------
  /// Epoch ms of the player's first app open — the anchor for how long
  /// they've been on MYNDASH. Drives the tenure titles and when MYNDASH Wrapped
  /// unlocks. Seeded on first launch (see [seedFirstOpen]); 0 = not set.
  int firstOpenMs = 0;

  /// The most recent weekly Wrapped "drop" the player has opened, as a
  /// week index (tenureDays ~/ 7). Lets the profile feature the newest
  /// drop for a 2-day window and stop nagging once it's been seen.
  int lastWrapWeekSeen = -1;

  /// Set [firstOpenMs] once. Prefers the earliest recorded activity date so
  /// existing players get credit for time already spent, else uses now.
  void seedFirstOpen() {
    if (firstOpenMs != 0) return;
    var earliest = DateTime.now();
    for (final k in activity.keys) {
      final d = DateTime.tryParse('$k');
      if (d != null && d.isBefore(earliest)) earliest = d;
    }
    firstOpenMs = earliest.millisecondsSinceEpoch;
    save();
  }

  /// Whole days since the player joined.
  int get tenureDays => firstOpenMs == 0
      ? 0
      : DateTime.now()
          .difference(DateTime.fromMillisecondsSinceEpoch(firstOpenMs))
          .inDays;

  /// MYNDASH Wrapped is visible from the player's very first day — it just
  /// recaps whatever activity exists so far (even zero).
  bool get wrappedUnlocked => true;

  /// Which weekly drop we're in (0-based). A fresh drop lands every 7 days.
  int get wrapWeekIndex => tenureDays ~/ 7;

  /// True while the newest weekly drop is still "fresh" — the first 2 days
  /// of the current 7-day week, and only if the player hasn't opened it yet.
  bool get wrapDropFresh =>
      wrappedUnlocked &&
      wrapWeekIndex > lastWrapWeekSeen &&
      (tenureDays % 7) < 2;

  /// The tenure title the player has earned so far (highest reached).
  MyndTitle get myndTitle => MyndTitle.forDays(tenureDays);

  // ---------------- activity heatmap ----------------
  /// dateKey (yyyy-MM-dd) -> number of solves/matches that day.
  Map<String, dynamic> activity = {};

  // ---------------- match history (last 15) ----------------
  /// {mode, opponent, result: 'W'|'L'|'D', delta, date}
  List<Map<String, dynamic>> matches = [];

  // ---------------- AI coach telemetry ----------------
  /// catId -> {n, correct, ms, fastWrong, slowRight}
  Map<String, dynamic> catStats = {};

  /// Last 40 mistakes: {cat, prompt, answer, date} — the coach's
  /// retrieval corpus for personalized training.
  List<Map<String, dynamic>> mistakes = [];

  /// Bounded, on-device timeline used by AI Trainer trend analysis.
  ///
  /// Items are intentionally compact and contain no typed answer or personal
  /// text: {type, domain, value, durationMs?, parMs?, ts}.
  List<Map<String, dynamic>> trainingEvents = [];

  void _recordTrainingEvent(
    String type,
    String domain, {
    num value = 1,
    int? durationMs,
    int? parMs,
  }) {
    // The daily-activity streak ticks on ANY play event, anywhere — a solve,
    // a 1v1, an online clash, a game, a daily-challenge item. Every activity
    // funnels through here, and the same-day guard keeps it to once a day.
    _touchDailyStreak();
    // Mark the heatmap in the SAME funnel that ticks the streak, so the two can
    // never diverge. (Previously each caller had to remember a separate
    // _bumpActivity() and some — e.g. recordChessJourney — forgot, so the
    // streak moved but the heatmap stayed empty.) Any event that counts toward
    // the streak now also lights up today's heatmap cell.
    _bumpActivity();
    trainingEvents.insert(0, {
      'type': type,
      'domain': domain,
      'value': value,
      if (durationMs != null) 'durationMs': durationMs,
      if (parMs != null) 'parMs': parMs,
      'ts': DateTime.now().millisecondsSinceEpoch,
    });
    if (trainingEvents.length > 480) {
      trainingEvents.removeRange(480, trainingEvents.length);
    }
  }

  /// Feed every answered question through here (solve/daily/contest).
  void recordAnswer(String catId, bool correct, int ms, int parMs,
      {String? prompt, String? answer}) {
    final st = Map<String, dynamic>.from(catStats[catId] ?? {});
    st['n'] = (st['n'] ?? 0) + 1;
    if (correct) st['correct'] = (st['correct'] ?? 0) + 1;
    st['ms'] = (st['ms'] ?? 0) + ms;
    // blunder: answered fast (under 40% of par) AND wrong
    if (!correct && ms < parMs * 0.4) {
      st['fastWrong'] = (st['fastWrong'] ?? 0) + 1;
    }
    // deep think: slow but right — good instinct to reinforce
    if (correct && ms > parMs) {
      st['slowRight'] = (st['slowRight'] ?? 0) + 1;
    }
    catStats[catId] = st;
    if (!correct && prompt != null) {
      mistakes.insert(0, {
        'cat': catId,
        'prompt': prompt,
        'answer': answer ?? '',
        'date': todayKey(),
      });
      if (mistakes.length > 40) mistakes.removeRange(40, mistakes.length);
    }
    _recordTrainingEvent(
      'answer',
      catId,
      value: correct ? 1 : 0,
      durationMs: ms,
      parMs: parMs,
    );
    save();
  }

  // ---------------- first-time guides ----------------
  List<String> guidesSeen = [];

  // ---------------- chess journey (30 levels × 5 games) ----------------
  int chessLevel = 1; // highest unlocked level, 1..30
  int chessWins = 0; // games won inside the current level, 0..5
  int chessIqLevel = 1; // chess IQ testing — highest unlocked set, 1..30

  // ---------------- darts journey (50 levels) ----------------
  int dartsLevel = 1; // highest unlocked level, 1..50

  // ---------------- rated game journeys ----------------
  int ratedCatalogVersion = 2;
  int artLevel = 1; // highest unlocked rated variant, 1..180

  /// Art Heist flat variant step -> best stars (0..3).
  Map<String, dynamic> artStars = {};

  static int artGridForLevel(int level) => ArtHeistCatalog.gridForStep(level);

  int artStarsAt(int level) => (artStars['$level'] as int?) ?? 0;

  /// Records an Art Heist result and unlocks exactly the next rated variant.
  /// Returns true if a new level was just unlocked.
  bool recordArtJourney(int level, int stars) {
    if (stars > artStarsAt(level)) artStars['$level'] = stars;
    final next = SequentialProgression.advance(
      step: level,
      unlocked: artLevel,
      completed: stars >= 1,
      maxStep: ArtHeistCatalog.totalSteps,
    );
    final unlocked = next != artLevel;
    artLevel = next;
    _recordTrainingEvent('level', 'art', value: stars);
    save();
    return unlocked;
  }

  /// Game id -> highest unlocked rated variant step.
  Map<String, dynamic> mindLevels = {};

  /// '<game>/<level>' -> best stars (0..3)
  Map<String, dynamic> mindStars = {};

  int mindLevel(String game) => (mindLevels[game] as int?) ?? 1;

  int mindStarsAt(String game, int level) =>
      (mindStars['$game/$level'] as int?) ?? 0;

  int mindTotalStars(String game, {int maxLevel = 50}) {
    var total = 0;
    for (var l = 1; l <= maxLevel; l++) {
      total += mindStarsAt(game, l);
    }
    return total;
  }

  /// Records a mind-game practice result; any solve unlocks the next level.
  /// Returns true if a new level was just unlocked.
  bool recordMindLevel(String game, int level, int stars, {int maxLevel = 50}) {
    if (stars > mindStarsAt(game, level)) mindStars['$game/$level'] = stars;
    final current = mindLevel(game);
    final next = SequentialProgression.advance(
      step: level,
      unlocked: current,
      completed: stars >= 1,
      maxStep: maxLevel,
    );
    final unlocked = next != current;
    mindLevels[game] = next;
    _recordTrainingEvent('level', game, value: stars);
    save();
    return unlocked;
  }

  // ---------------- communities ----------------
  String college = '';
  String company = '';
  String squadId = '';
  String squadName = '';
  bool isSquadLeader = false; // creator = admin; only admin enters events

  // ---------------- legacy v1 membership data ----------------
  // Retained only so existing local saves deserialize safely. Membership
  // purchase surfaces and feature gates are disabled; AI Trainer is free.
  bool isPro = false;
  bool isUltra = false;
  int proUntil = 0; // epoch ms; 0 = none
  bool adminOverride = false;

  void grantPro(int days) {
    isPro = true;
    final base = proUntil > DateTime.now().millisecondsSinceEpoch
        ? proUntil
        : DateTime.now().millisecondsSinceEpoch;
    proUntil = base + days * 24 * 3600 * 1000;
    save();
  }

  /// Drops expired PRO (admins never expire).
  void refreshProStatus() {
    if (adminOverride) {
      isPro = true;
      return;
    }
    if (isPro &&
        proUntil > 0 &&
        DateTime.now().millisecondsSinceEpoch > proUntil) {
      isPro = false;
      isUltra = false;
    }
  }

  // ---------------- official MYNDASH arenas ----------------
  String lastArenaDayKey = ''; // official arena already played (dateKey)

  // ---------------- live drops ----------------
  String lastDropKey = ''; // drop window already played
  String lastKidDropKey = ''; // kids' 8pm drop (dateKey)
  String lastKidContestKey = ''; // kids' weekend contest

  // ---------------- calendar ----------------
  /// {date: 'yyyy-MM-dd', title, type: 'reminder'|'match'|'event'}
  List<Map<String, dynamic>> calendarNotes = [];

  // ---------------- onboarding profile ----------------
  int age = 0; // 0 = not asked yet
  bool kidMode = false; // age < 12 → kids app
  String iqGuess = ''; // the fun onboarding answer

  /// Answers to the extra "about you" onboarding questions, keyed by
  /// question id (see AboutYouScreen._questions). Adding a new question
  /// there needs no change here — it just shows up in this map.
  Map<String, String> onboardingAnswers = {};

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs!.getString('district');
    if (raw == null) return;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      onboarded = m['onboarded'] ?? false;
      name = m['name'] ?? name;
      username = m['username'] ?? '';
      usernameChangedAt = m['usernameChangedAt'] ?? '';
      avatarPath = m['avatarPath'] ?? '';
      avatarB64 = m['avatarB64'] ?? '';
      authMethod = m['authMethod'] ?? '';
      bio = m['bio'] ?? '';
      contactEmail = m['contactEmail'] ?? '';
      contactPhone = m['contactPhone'] ?? '';
      coins = m['coins'] ?? coins;
      xp = m['xp'] ?? 0;
      elo = m['elo'] ?? elo;
      contestRating = m['contestRating'] ?? 1500;
      lastContestKey = m['lastContestKey'] ?? '';
      dailyKey = m['dailyKey'] ?? '';
      dailySolved = m['dailySolved'] ?? 0;
      dailyCompleted = List<String>.from(m['dailyCompleted'] ?? []);
      dailyArchive = List<Map<String, dynamic>>.from(
          (m['dailyArchive'] as List? ?? [])
              .map((e) => Map<String, dynamic>.from(e)));
      if (dailyCompleted.isEmpty && dailyKey == todayKey() && dailySolved > 0) {
        dailyCompleted =
            List.generate(dailySolved.clamp(0, 5).toInt(), (i) => 'math-$i');
      }
      streak = m['streak'] ?? streak;
      lastDaily = m['lastDaily'] ?? '';
      cats = Map<String, dynamic>.from(m['cats'] ?? {});
      following = List<String>.from(m['following'] ?? []);
      followers = List<String>.from(m['followers'] ?? []);
      followRequests = List<String>.from(m['followRequests'] ?? []);
      sentRequests = List<String>.from(m['sentRequests'] ?? []);
      lastArenaDayKey = m['lastArenaDayKey'] ?? '';
      orders = List<Map<String, dynamic>>.from((m['orders'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e)));
      activity = Map<String, dynamic>.from(m['activity'] ?? {});
      firstOpenMs = (m['firstOpenMs'] as num?)?.toInt() ?? 0;
      lastWrapWeekSeen = (m['lastWrapWeekSeen'] as num?)?.toInt() ?? -1;
      matches = List<Map<String, dynamic>>.from((m['matches'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e)));
      catStats = Map<String, dynamic>.from(m['catStats'] ?? {});
      mistakes = List<Map<String, dynamic>>.from((m['mistakes'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e)));
      trainingEvents = List<Map<String, dynamic>>.from(
          (m['trainingEvents'] as List? ?? [])
              .map((e) => Map<String, dynamic>.from(e)));
      guidesSeen = List<String>.from(m['guidesSeen'] ?? []);
      chessLevel = m['chessLevel'] ?? 1;
      chessWins = m['chessWins'] ?? 0;
      chessIqLevel = m['chessIqLevel'] ?? 1;
      dartsLevel = m['dartsLevel'] ?? 1;
      ratedCatalogVersion = (m['ratedCatalogVersion'] as num?)?.toInt() ?? 0;
      artLevel = m['artLevel'] ?? 1;
      artStars = Map<String, dynamic>.from(m['artStars'] ?? {});
      mindLevels = Map<String, dynamic>.from(m['mindLevels'] ?? {});
      mindStars = Map<String, dynamic>.from(m['mindStars'] ?? {});
      if (ratedCatalogVersion < 2) {
        _migrateRatedCatalogs();
      }
      college = m['college'] ?? '';
      company = m['company'] ?? '';
      squadId = m['squadId'] ?? '';
      squadName = m['squadName'] ?? '';
      isSquadLeader = m['isSquadLeader'] ?? false;
      isPro = m['isPro'] ?? false;
      isUltra = m['isUltra'] ?? false;
      proUntil = m['proUntil'] ?? 0;
      adminOverride = m['adminOverride'] ?? false;
      refreshProStatus();
      lastDropKey = m['lastDropKey'] ?? '';
      lastKidDropKey = m['lastKidDropKey'] ?? '';
      lastKidContestKey = m['lastKidContestKey'] ?? '';
      publicPrefs = Map<String, dynamic>.from(m['publicPrefs'] ??
          {'elo': true, 'matches': true, 'streak': true, 'orgs': true});
      calendarNotes = List<Map<String, dynamic>>.from(
          (m['calendarNotes'] as List? ?? [])
              .map((e) => Map<String, dynamic>.from(e)));
      age = m['age'] ?? 0;
      kidMode = m['kidMode'] ?? false;
      iqGuess = m['iqGuess'] ?? '';
      onboardingAnswers =
          Map<String, String>.from(m['onboardingAnswers'] ?? {});
      kidProgress = Map<String, dynamic>.from(m['kidProgress'] ?? {});
      kidArcadeBest = Map<String, dynamic>.from(m['kidArcadeBest'] ?? {});
      chocDayKey = m['chocDayKey'] ?? '';
      chocSolvedHours = List<dynamic>.from(m['chocSolvedHours'] ?? []);
      coinDayKey = m['coinDayKey'] ?? '';
      coinsEarnedToday = (m['coinsEarnedToday'] as num?)?.toInt() ?? 0;
      tutsSeen = Set<String>.from(m['tutsSeen'] ?? const []);
    } catch (_) {}
  }

  void _migrateRatedCatalogs() {
    int remap(int value, int oldMax, int newMax) {
      if (value <= 1) return 1;
      final progress = (value.clamp(1, oldMax) - 1) / (oldMax - 1);
      return 1 + (progress * (newMax - 1)).round();
    }

    artLevel = remap(artLevel, 15, ArtHeistCatalog.totalSteps);
    for (final game in const [
      'sudoku',
      'hanoi',
      'numpz',
      'arrow',
      'crossword',
    ]) {
      final old = (mindLevels[game] as num?)?.toInt();
      if (old == null) continue;
      final oldMax = game == 'hanoi' ? 45 : 50;
      final newMax =
          RatedProgression.totalSteps(RatingCatalog.variantsFor(game));
      mindLevels[game] = remap(old, oldMax, newMax);
    }
    ratedCatalogVersion = 2;
  }

  Future<void> save() async {
    notifyListeners();
    await _prefs?.setString(
        'district',
        jsonEncode({
          'onboarded': onboarded,
          'name': name,
          'username': username,
          'usernameChangedAt': usernameChangedAt,
          'avatarPath': avatarPath,
          'avatarB64': avatarB64,
          'authMethod': authMethod,
          'bio': bio,
          'contactEmail': contactEmail,
          'contactPhone': contactPhone,
          'coins': coins,
          'xp': xp,
          'elo': elo,
          'contestRating': contestRating,
          'lastContestKey': lastContestKey,
          'dailyKey': dailyKey,
          'dailySolved': dailySolved,
          'dailyCompleted': dailyCompleted,
          'dailyArchive': dailyArchive,
          'streak': streak,
          'lastDaily': lastDaily,
          'cats': cats,
          'following': following,
          'followers': followers,
          'followRequests': followRequests,
          'sentRequests': sentRequests,
          'lastArenaDayKey': lastArenaDayKey,
          'orders': orders,
          'activity': activity,
          'firstOpenMs': firstOpenMs,
          'lastWrapWeekSeen': lastWrapWeekSeen,
          'matches': matches,
          'catStats': catStats,
          'mistakes': mistakes,
          'trainingEvents': trainingEvents,
          'guidesSeen': guidesSeen,
          'chessLevel': chessLevel,
          'chessWins': chessWins,
          'chessIqLevel': chessIqLevel,
          'dartsLevel': dartsLevel,
          'ratedCatalogVersion': ratedCatalogVersion,
          'artLevel': artLevel,
          'artStars': artStars,
          'mindLevels': mindLevels,
          'mindStars': mindStars,
          'college': college,
          'company': company,
          'squadId': squadId,
          'squadName': squadName,
          'isSquadLeader': isSquadLeader,
          'isPro': isPro,
          'isUltra': isUltra,
          'proUntil': proUntil,
          'adminOverride': adminOverride,
          'lastDropKey': lastDropKey,
          'lastKidDropKey': lastKidDropKey,
          'lastKidContestKey': lastKidContestKey,
          'publicPrefs': publicPrefs,
          'calendarNotes': calendarNotes,
          'age': age,
          'kidMode': kidMode,
          'iqGuess': iqGuess,
          'onboardingAnswers': onboardingAnswers,
          'kidProgress': kidProgress,
          'kidArcadeBest': kidArcadeBest,
          'chocDayKey': chocDayKey,
          'chocSolvedHours': chocSolvedHours,
          'coinDayKey': coinDayKey,
          'coinsEarnedToday': coinsEarnedToday,
          'tutsSeen': tutsSeen.toList(),
        }));
  }

  // ---------------- account switch ----------------
  /// Wipes every account-scoped field back to its fresh-install default.
  /// Called on sign-out so a new/different account never inherits the
  /// previous account's coins, XP, purchases or progress on this device.
  Future<void> resetAll() async {
    onboarded = false;
    name = 'Challenger';
    username = '';
    usernameChangedAt = '';
    avatarPath = '';
    avatarB64 = '';
    authMethod = '';
    bio = '';
    contactEmail = '';
    contactPhone = '';
    coins = 500;
    xp = 0;
    elo = 800;
    contestRating = 1500;
    lastContestKey = '';
    freeHints = 3;
    dailyKey = '';
    dailySolved = 0;
    dailyCompleted = [];
    dailyArchive = [];
    streak = 0;
    lastDaily = '';
    cats = {};
    following = [];
    followers = [];
    followRequests = [];
    sentRequests = [];
    lastArenaDayKey = '';
    orders = [];
    activity = {};
    firstOpenMs = 0;
    lastWrapWeekSeen = -1;
    matches = [];
    guidesSeen = [];
    chessLevel = 1;
    chessWins = 0;
    chessIqLevel = 1;
    dartsLevel = 1;
    ratedCatalogVersion = 2;
    artLevel = 1;
    artStars = {};
    mindLevels = {};
    mindStars = {};
    college = '';
    company = '';
    squadId = '';
    squadName = '';
    isSquadLeader = false;
    isPro = false;
    isUltra = false;
    proUntil = 0;
    adminOverride = false;
    catStats = {};
    mistakes = [];
    trainingEvents = [];
    lastDropKey = '';
    calendarNotes = [];
    age = 0;
    kidMode = false;
    iqGuess = '';
    onboardingAnswers = {};
    kidProgress = {};
    kidArcadeBest = {};
    chocDayKey = '';
    chocSolvedHours = [];
    tutsSeen = {};
    await save();
  }

  // ---------------- game tutorials (level-0 "how to play") ----------------
  /// Keys of games whose intro tutorial the player has already dismissed.
  Set<String> tutsSeen = {};
  bool tutSeen(String key) => tutsSeen.contains(key);
  void markTutSeen(String key) {
    if (tutsSeen.add(key)) save();
  }

  // ---------------- calendar ----------------
  void addCalendarNote(String date, String title, String type) {
    calendarNotes.add({'date': date, 'title': title, 'type': type});
    calendarNotes.sort((a, b) => '${a['date']}'.compareTo('${b['date']}'));
    save();
  }

  void removeCalendarNote(Map<String, dynamic> note) {
    calendarNotes.remove(note);
    save();
  }

  List<Map<String, dynamic>> notesOn(String date) =>
      calendarNotes.where((n) => n['date'] == date).toList();

  // ---------------- kids practice progress ----------------
  /// topicId -> highest unlocked level (1..50)
  Map<String, dynamic> kidProgress = {};

  /// Playable levels per kid topic.
  static const kidMaxLevel = 50;

  /// Playable levels for the fun brain games (Almanac, Memory, Block, Cross).
  static const kidFunMaxLevel = 100;

  int kidLevel(String topic) => (kidProgress[topic] as int?) ?? 1;

  void recordKidLevel(String topic, int level, int stars,
      {int max = kidMaxLevel}) {
    kidProgress[topic] = SequentialProgression.advance(
      step: level,
      unlocked: kidLevel(topic),
      completed: stars >= 1,
      maxStep: max,
    );
    _recordTrainingEvent('level', topic, value: stars);
    xp += stars * 8;
    earnCoins(5 + stars * 5); // solo → capped faucet (also saves)
  }

  /// gameId -> best score, for the endless arcade fun games.
  Map<String, dynamic> kidArcadeBest = {};

  int kidBest(String id) => (kidArcadeBest[id] as int?) ?? 0;

  /// Records an arcade run: keeps the best score, pays coins/xp for the run.
  void recordKidArcade(String id, int score) {
    if (score > kidBest(id)) kidArcadeBest[id] = score;
    _recordTrainingEvent('score', id, value: score);
    xp += (score ~/ 5).clamp(0, 50); // XP stays generous
    earnCoins((score ~/ 6).clamp(0, 40)); // solo → capped faucet (also saves)
  }

  // ---------------- Chocolate Hour (24 hourly problems / day) ----------------
  /// Day key the [chocSolvedHours] belong to; resets at midnight.
  String chocDayKey = '';
  List<dynamic> chocSolvedHours = []; // hours (0..23) solved today

  /// Hours solved today (empty on a new day).
  List<int> chocSolvedToday() {
    if (chocDayKey != todayKey()) return const [];
    return chocSolvedHours.map((e) => e as int).toList();
  }

  /// Marks a Chocolate hour as solved; pays a sweet reward. Returns the new
  /// day-total (for the leaderboard).
  int recordChoc(int hour) {
    final today = todayKey();
    if (chocDayKey != today) {
      chocDayKey = today;
      chocSolvedHours = [];
    }
    if (!chocSolvedHours.contains(hour)) {
      chocSolvedHours.add(hour);
      _recordTrainingEvent('level', 'chocolate', value: 1);
      xp += 12; // XP generous
      earnCoins(4); // solo → capped faucet (also saves)
    } else {
      save();
    }
    return chocSolvedHours.length;
  }

  // ---------------- coins & xp ----------------
  /// Daily cap on repeatable SOLO faucets (practice, kid games, chocolate,
  /// live drop). Daily Arena uses its visible, once-only reward pool instead.
  static const dailyCoinCap = 50;
  String coinDayKey = '';
  int coinsEarnedToday = 0;

  int get coinsLeftToday {
    if (coinDayKey != todayKey()) return dailyCoinCap;
    return (dailyCoinCap - coinsEarnedToday).clamp(0, dailyCoinCap);
  }

  /// SOLO faucet — credits up to the daily cap, then saves. Competitive wins
  /// (wagers, arena/contest payouts) use [addCoins] instead (uncapped, since
  /// those coins are redistributed between players, not minted). Returns the
  /// amount actually credited.
  int earnCoins(int n) {
    final today = todayKey();
    if (coinDayKey != today) {
      coinDayKey = today;
      coinsEarnedToday = 0;
    }
    final give = n <= 0 ? 0 : (dailyCoinCap - coinsEarnedToday).clamp(0, n);
    coins += give;
    coinsEarnedToday += give;
    _bumpActivity();
    save();
    return give;
  }

  void addCoins(int n) {
    coins += n;
    save();
  }

  bool spendCoins(int n) {
    if (coins < n) return false;
    coins -= n;
    save();
    return true;
  }

  void addXp(int n) {
    xp += n;
    save();
  }

  // ---------------- activity heatmap ----------------
  /// Increment today's activity counter (no save — callers save).
  void _bumpActivity([int n = 1]) {
    final k = todayKey();
    activity[k] = ((activity[k] as int?) ?? 0) + n;
    // keep the map small: prune entries older than ~18 weeks
    if (activity.length > 140) {
      final cutoff = DateTime.now().subtract(const Duration(days: 126));
      activity.removeWhere((key, _) {
        final d = DateTime.tryParse(key);
        return d != null && d.isBefore(cutoff);
      });
    }
  }

  /// Public bump for one-off completions (saves immediately).
  void bumpActivity() {
    _bumpActivity();
    save();
  }

  /// Records a non-question practice result for AI Trainer and activity.
  void recordTrainingSession(
    String domain, {
    String type = 'practice',
    num value = 1,
    int? durationMs,
    int? parMs,
  }) {
    _recordTrainingEvent(
      type,
      domain,
      value: value,
      durationMs: durationMs,
      parMs: parMs,
    );
    save();
  }

  int activityOn(String dateKey) => (activity[dateKey] as int?) ?? 0;

  // ---------------- match history ----------------
  /// Records a match (1v1 duel, arena, contest, reflex, darts…),
  /// keeps only the last 15, and counts it as today's activity.
  void recordMatch({
    required String mode,
    required String opponent,
    required String result, // 'W' | 'L' | 'D'
    int delta = 0,
  }) {
    matches.insert(0, {
      'mode': mode,
      'opponent': opponent,
      'result': result,
      'delta': delta,
      'date': todayKey(),
    });
    if (matches.length > 15) {
      matches.removeRange(15, matches.length);
    }
    _recordTrainingEvent(
      'match',
      mode,
      value: result == 'W'
          ? 1
          : result == 'D'
              ? 0.5
              : 0,
    );
    save();
  }

  /// Last up-to-5 results, newest first: e.g. ['W','W','L','D','W'].
  List<String> get lastForm =>
      matches.take(5).map((m) => '${m['result']}').toList();

  // ---------------- first-time guides ----------------
  bool seenGuide(String id) => guidesSeen.contains(id);

  void markGuideSeen(String id) {
    if (!guidesSeen.contains(id)) {
      guidesSeen.add(id);
      save();
    }
  }

  // ---------------- chess journey ----------------
  /// Thirty internal journey steps distributed across the public 800–2500
  /// rating bands. Multiple steps become variants within the same band.
  static int chessLevelElo(int level) {
    final raw = 800 + ((level.clamp(1, 30) - 1) * 1700 / 29).round();
    return ((raw / 100).round() * 100).clamp(800, 2500).toInt();
  }

  /// Bot rating for game g (1..5) of a level: +20 per game.
  static int chessGameElo(int level, int game) =>
      (chessLevelElo(level) + (game - 1) * 20).clamp(800, 2500).toInt();

  /// Which game (1..5) is next in the current level.
  int get chessNextGame => (chessWins + 1).clamp(1, 5).toInt();

  /// Records a journey game result. Returns true if the level was
  /// just completed (all 5 games won → next level unlocks).
  bool recordChessJourney(bool won) {
    if (!won) {
      _recordTrainingEvent('match', 'chess', value: 0);
      save();
      return false;
    }
    _recordTrainingEvent('match', 'chess', value: 1);
    chessWins++;
    if (chessWins >= 5) {
      chessWins = 0;
      if (chessLevel < 30) chessLevel++;
      save();
      return true;
    }
    save();
    return false;
  }

  // ---------------- store economy ----------------
  /// Redeeming an item worth X coins also needs earned XP >= 5X.
  /// XP only comes from playing — it can never be purchased — so
  /// wallets alone can't buy their way to prizes.
  int xpNeededFor(int price) => price * 5;
  bool canRedeem(int price) => coins >= price && xp >= xpNeededFor(price);

  // ---------------- username rules ----------------
  static final usernameRx = RegExp(r'^[a-z0-9_]{6,20}$');

  bool get canChangeUsername {
    if (usernameChangedAt.isEmpty) return true;
    final last = DateTime.tryParse(usernameChangedAt);
    if (last == null) return true;
    return DateTime.now().difference(last).inDays >= 15;
  }

  int get daysUntilUsernameChange {
    final last = DateTime.tryParse(usernameChangedAt);
    if (last == null) return 0;
    return (15 - DateTime.now().difference(last).inDays).clamp(0, 15).toInt();
  }

  // ---------------- solve progress ----------------
  int unlockedLevel(String catId) => (cats[catId]?['unlocked'] as int?) ?? 800;

  int starsAt(String catId, int level) =>
      (cats[catId]?['stars']?['$level'] as int?) ?? 0;

  int totalStars(String catId) {
    final stars = cats[catId]?['stars'] as Map<String, dynamic>? ?? {};
    return stars.values.fold<int>(0, (a, b) => a + (b as int));
  }

  void recordLevel(String catId, int level, int stars) {
    final cat = Map<String, dynamic>.from(cats[catId] ?? {});
    final starMap = Map<String, dynamic>.from(cat['stars'] ?? {});
    if (stars > ((starMap['$level'] as int?) ?? 0)) {
      starMap['$level'] = stars;
    }
    cat['stars'] = starMap;
    final unlockedRating = (cat['unlocked'] as int?) ?? 800;
    final unlockedStep =
        ((unlockedRating - RatingCatalog.min) ~/ RatingCatalog.step + 1)
            .clamp(1, RatingCatalog.bands.length)
            .toInt();
    final playedStep = ((level - RatingCatalog.min) ~/ RatingCatalog.step + 1)
        .clamp(1, RatingCatalog.bands.length)
        .toInt();
    final nextStep = SequentialProgression.advance(
      step: playedStep,
      unlocked: unlockedStep,
      completed: stars >= 1,
      maxStep: RatingCatalog.bands.length,
    );
    cat['unlocked'] = RatingCatalog.bands[nextStep - 1];
    cats[catId] = cat;
    _recordTrainingEvent('level', catId, value: stars);
    xp += stars * 10;
    save();
  }

  /// Rough overall rating = average of top-3 category unlocks.
  int get overallRating {
    final unlocks = cats.values
        .map((c) => (c['unlocked'] as int?) ?? 800)
        .toList()
      ..sort((a, b) => b.compareTo(a));
    if (unlocks.isEmpty) return 800;
    final top = unlocks.take(3).toList();
    return top.reduce((a, b) => a + b) ~/ top.length;
  }

  // ---------------- daily (5 progressive math + 6 open games) ----------------
  static String todayKey() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  void _ensureDailyToday() {
    if (dailyKey == todayKey()) return;
    dailyKey = todayKey();
    dailySolved = 0;
    dailyCompleted = [];
  }

  /// Today's progress 0..11, auto-resetting each day.
  int get dailyProgress {
    if (dailyKey != todayKey()) return 0;
    if (dailyCompleted.isEmpty && dailySolved > 0) return dailySolved;
    return dailyCompleted.length;
  }

  int get dailyMathProgress {
    if (dailyKey != todayKey()) return 0;
    var progress = 0;
    while (progress < 5 &&
        (dailyCompleted.contains('math-$progress') || progress < dailySolved)) {
      progress++;
    }
    return progress;
  }

  bool dailyItemDone(String id) {
    if (dailyKey != todayKey()) return false;
    if (dailyCompleted.contains(id)) return true;
    final mathIndex =
        id.startsWith('math-') ? int.tryParse(id.substring(5)) : null;
    return mathIndex != null && mathIndex < dailySolved;
  }

  void recordDailyItem({
    required String id,
    required String category,
    required int rating,
    required int xpReward,
    required int coinReward,
    required int dayIndex,
  }) {
    _ensureDailyToday();
    if (dailyItemDone(id)) return;
    dailyCompleted.add(id);
    if (id.startsWith('math-')) {
      final index = int.tryParse(id.substring(5)) ?? 0;
      if (index == dailySolved) dailySolved++;
    }

    xp += xpReward;
    coins += coinReward;
    final archiveKey = '$dayIndex/$id';
    if (!dailyArchive.any((e) => e['key'] == archiveKey)) {
      dailyArchive.add({
        'key': archiveKey,
        'day': dayIndex,
        'id': id,
        'category': category,
        'rating': rating,
        'completedAt': DateTime.now().millisecondsSinceEpoch,
      });
      if (dailyArchive.length > 1100) {
        dailyArchive.removeRange(0, dailyArchive.length - 1100);
      }
    }
    _recordTrainingEvent('level', category, value: 1);
    save();
  }

  void recordDailySolve(int qIndex) {
    recordDailyItem(
      id: 'math-$qIndex',
      category: 'mental',
      rating: 1200 + qIndex * 150,
      xpReward: 15,
      coinReward: 0,
      dayIndex: 0,
    );
  }

  bool get dailyDone => dailyProgress >= 11;

  /// Advances the daily-activity streak once per calendar day. A same-day
  /// call is a no-op (guard on [lastDaily]); a consecutive day increments;
  /// a gap resets to 1. Milestone bonuses pay out on the day they're hit.
  void _touchDailyStreak() {
    final today = todayKey();
    if (lastDaily == today) return; // already counted an activity today
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final yKey =
        '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
    streak = (lastDaily == yKey) ? streak + 1 : 1;
    lastDaily = today;
    // Streak milestones are rare and hard-earned, so pay them in full
    // (uncapped) — you can't grind these.
    if (streak == 7) addCoins(30);
    if (streak == 30) addCoins(150);
  }

  // ---------------- elo ----------------
  int applyElo(int opponent, double score) {
    final expected = 1 / (1 + math.pow(10, (opponent - elo) / 400).toDouble());
    final delta = (32 * (score - expected)).round();
    elo = (elo + delta).clamp(400, 3000).toInt();
    save();
    return delta;
  }

  // ---------------- store ----------------
  void placeOrder(String item, int price) {
    orders.insert(0, {
      'item': item,
      'coins': price,
      'date': todayKey(),
      'status': 'Processing (demo)',
    });
    save();
  }
}
