import 'dart:math' as math;

import '../core/state.dart';
import '../engine/game_progression.dart';
import '../engine/rating_catalog.dart';

class CoachDayPoint {
  const CoachDayPoint({
    required this.date,
    required this.sessions,
    required this.quality,
  });

  final DateTime date;
  final int sessions;
  final double? quality;

  String get shortLabel => const [
        'M',
        'T',
        'W',
        'T',
        'F',
        'S',
        'S',
      ][date.weekday - 1];
}

class CoachDomainInsight {
  const CoachDomainInsight({
    required this.id,
    required this.label,
    required this.group,
    required this.score,
    required this.confidence,
    required this.attempts,
    required this.correct,
    required this.avgMs,
    required this.blunders,
    required this.deepThinks,
    required this.evidence,
  });

  final String id;
  final String label;
  final String group;
  final double score;
  final double confidence;
  final int attempts;
  final int correct;
  final int avgMs;
  final int blunders;
  final int deepThinks;
  final String evidence;

  bool get measured => confidence > 0;
  double? get accuracy => attempts == 0 ? null : correct / attempts;
  int get scorePercent => (score * 100).round();
}

class CoachPlanItem {
  const CoachPlanItem({
    required this.domainId,
    required this.title,
    required this.reason,
    required this.drill,
    required this.minutes,
    required this.priority,
  });

  final String domainId;
  final String title;
  final String reason;
  final String drill;
  final int minutes;
  final int priority;
}

class CoachReply {
  const CoachReply({
    required this.title,
    required this.message,
    required this.steps,
    required this.evidence,
    this.focusDomainId,
  });

  final String title;
  final String message;
  final List<String> steps;
  final String evidence;
  final String? focusDomainId;
}

class CoachSnapshot {
  const CoachSnapshot({
    required this.totalAnswers,
    required this.correctAnswers,
    required this.avgMs,
    required this.blunders,
    required this.deepThinks,
    required this.matches,
    required this.wins,
    required this.activeDays14,
    required this.momentumPercent,
    required this.insights,
    required this.groupScores,
    required this.days,
  });

  final int totalAnswers;
  final int correctAnswers;
  final int avgMs;
  final int blunders;
  final int deepThinks;
  final int matches;
  final int wins;
  final int activeDays14;
  final int momentumPercent;
  final List<CoachDomainInsight> insights;
  final Map<String, double> groupScores;
  final List<CoachDayPoint> days;

  double? get accuracy =>
      totalAnswers == 0 ? null : correctAnswers / totalAnswers;

  CoachDomainInsight? get strongest {
    final measured = insights.where((item) => item.measured).toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    return measured.isEmpty ? null : measured.first;
  }

  CoachDomainInsight? get focus {
    final measured = insights.where((item) => item.measured).toList()
      ..sort((a, b) {
        final aNeed = (1 - a.score) * (0.55 + a.confidence * 0.45);
        final bNeed = (1 - b.score) * (0.55 + b.confidence * 0.45);
        return bNeed.compareTo(aNeed);
      });
    return measured.isEmpty ? null : measured.first;
  }
}

class _Knowledge {
  const _Knowledge(
    this.id,
    this.label,
    this.group,
    this.aliases,
    this.tips,
  );

  final String id;
  final String label;
  final String group;
  final List<String> aliases;
  final List<String> tips;

  String get searchable => '$label ${aliases.join(' ')} ${tips.join(' ')}';
}

/// Fully local personal coach.
///
/// Retrieval uses BM25 over a compact, curated game corpus. Generation is a
/// deterministic, evidence-grounded response composer, so it works offline,
/// requires no model API key and never sends player telemetry away.
class LocalCoachEngine {
  LocalCoachEngine(this.data);

  final AppData data;

  static const _groups = <String>[
    'Calculation',
    'Logic',
    'Spatial',
    'Memory',
    'Language',
    'Competition',
  ];

  static const _knowledge = <_Knowledge>[
    _Knowledge('mental', 'Mental Math', 'Calculation', [
      'arithmetic',
      'speed math',
      'calculation',
      'addition',
      'multiply'
    ], [
      'Split numbers into friendly parts, calculate, then recombine.',
      'Use anchors such as 19×7 = 20×7 − 7 before chasing raw speed.',
    ]),
    _Knowledge('quant', 'Quant Aptitude', 'Calculation', [
      'aptitude',
      'ratio',
      'percent',
      'algebra',
      'quantitative'
    ], [
      'Translate the wording into one equation before calculating.',
      'For ratios, find one unit first; for percentages, keep the base visible.',
    ]),
    _Knowledge('numtheory', 'Number Theory', 'Calculation', [
      'factors',
      'gcd',
      'divisibility',
      'remainders',
      'powers'
    ], [
      'Use divisibility rules and the Euclidean algorithm instead of guessing.',
      'For last digits, write the repeating power cycle and reduce the exponent.',
    ]),
    _Knowledge('finance', 'Speed Finance', 'Calculation', [
      'money',
      'interest',
      'profit',
      'loss',
      'discount'
    ], [
      'Write the original amount, change and final amount on separate lines.',
      'Estimate first so a misplaced percentage cannot survive the final check.',
    ]),
    _Knowledge('probability', 'Probability', 'Logic', [
      'chance',
      'outcomes',
      'dice',
      'cards',
      'combinations'
    ], [
      'Count total equally likely outcomes before favorable outcomes.',
      'For multi-step events, draw branches and multiply along each branch.',
    ]),
    _Knowledge('clock', 'Clock & Calendar', 'Calculation', [
      'time',
      'calendar',
      'days',
      'angles'
    ], [
      'For clock angles use |30h − 5.5m|; for days move modulo seven.',
      'Write units beside every intermediate value to prevent conversion errors.',
    ]),
    _Knowledge('patterns', 'IQ Patterns', 'Logic', [
      'sequence',
      'series',
      'iq',
      'pattern recognition'
    ], [
      'Write first and second differences under a sequence.',
      'If one rule fails, test odd and even positions as two interleaved series.',
    ]),
    _Knowledge('geometry', 'Geometry', 'Spatial', [
      'shapes',
      'angles',
      'area',
      'triangle',
      'spatial'
    ], [
      'Mark known values directly on the figure before selecting a formula.',
      'Use invariants—angle sums, equal sides and symmetry—before arithmetic.',
    ]),
    _Knowledge('knights', 'Knights & Knaves', 'Logic', [
      'truth',
      'liar',
      'deduction',
      'logic puzzle'
    ], [
      'Assume one speaker is truthful and propagate every consequence.',
      'A contradiction eliminates the entire branch; do not patch it locally.',
    ]),
    _Knowledge('crypta', 'Cryptarithms', 'Logic', [
      'alphametic',
      'letters',
      'carry',
      'digit puzzle'
    ], [
      'Solve columns right to left and expose every carry explicitly.',
      'The leftmost carry is highly constrained; test it before free digits.',
    ]),
    _Knowledge('words', 'Word Problems', 'Language', [
      'story problem',
      'problem solving',
      'heads legs',
      'verbal math'
    ], [
      'Underline what is asked, name the unknown, then form the equation.',
      'After solving, substitute the answer back into the story constraints.',
    ]),
    _Knowledge('sudoku', 'Sudoku', 'Logic', [
      'grid',
      'candidates',
      'numbers',
      'pencil marks'
    ], [
      'Scan for singles, then locked candidates; guessing is the final resort.',
      'When stuck, choose one digit and scan every row, column and box for it.',
    ]),
    _Knowledge('mines', 'Minesweeper', 'Logic', [
      'mines',
      'flags',
      'adjacent',
      'minefield'
    ], [
      'Treat each numbered edge as a constraint, not an isolated clue.',
      'Compare overlapping neighborhoods to find forced safe cells and mines.',
    ]),
    _Knowledge('sliding', 'Sliding Tile', 'Spatial', [
      'tile puzzle',
      'fifteen puzzle',
      'move planning'
    ], [
      'Lock one row or column at a time and avoid disturbing solved structure.',
      'Plan the blank tile route first; the numbered tile follows that route.',
    ]),
    _Knowledge('hanoi', 'Tower of Hanoi', 'Spatial', [
      'discs',
      'tower',
      'recursive',
      'moves'
    ], [
      'Move n−1 discs away, move the largest disc, then rebuild n−1.',
      'The optimal move count is 2ⁿ−1; extra moves reveal where planning broke.',
    ]),
    _Knowledge('memory', 'Memory Matrix', 'Memory', [
      'recall',
      'visual memory',
      'matrix',
      'working memory'
    ], [
      'Chunk cells into shapes or rows instead of memorizing isolated squares.',
      'Replay the pattern once mentally before touching the board.',
    ]),
    _Knowledge('kenken', 'KenKen', 'Logic', [
      'cages',
      'latin square',
      'arithmetic grid'
    ], [
      'List cage combinations, then remove values blocked by row and column.',
      'Start with single-cell and extreme-product cages for maximum constraint.',
    ]),
    _Knowledge('nonogram', 'Nonograms', 'Spatial', [
      'picross',
      'paint by numbers',
      'runs'
    ], [
      'Place overlaps of long runs first, then mark impossible cells.',
      'Alternate rows and columns after every new confirmed block.',
    ]),
    _Knowledge('kakuro', 'Kakuro', 'Calculation', [
      'cross sums',
      'sum grid',
      'combinations'
    ], [
      'Memorize unique sum combinations and enforce non-repetition.',
      'Intersect across and down candidate sets before committing a digit.',
    ]),
    _Knowledge('logicgrid', 'Logic Grid', 'Logic', [
      'deduction grid',
      'clues',
      'elimination'
    ], [
      'Convert each clue into definite yes/no grid marks immediately.',
      'Use exclusivity: one confirmed match eliminates its entire row and column.',
    ]),
    _Knowledge('setgame', 'Set Cards', 'Logic', [
      'set',
      'cards',
      'attributes',
      'visual pattern'
    ], [
      'For every attribute, a set is all same or all different.',
      'Compare two cards and derive the only possible third card.',
    ]),
    _Knowledge('river', 'River Crossing', 'Logic', [
      'crossing',
      'state space',
      'constraints',
      'planning'
    ], [
      'Represent each bank as a state and reject unsafe states immediately.',
      'A useful move must change what becomes possible on the next return trip.',
    ]),
    _Knowledge('reflex', 'Reflex Duel', 'Competition', [
      'reaction',
      'tap',
      'focus',
      'duel'
    ], [
      'Use a stable finger position and react to the signal, not anticipation.',
      'Short focused sets beat long sessions once reaction quality drops.',
    ]),
    _Knowledge('chess', 'Chess', 'Logic', [
      'tactics',
      'strategy',
      'board',
      'checkmate'
    ], [
      'Before every move scan checks, captures and threats for both sides.',
      'After choosing a move, ask what the opponent would play immediately.',
    ]),
    _Knowledge('chess_iq', 'Chess IQ', 'Logic', [
      'chess puzzle',
      'vision',
      'tactical calculation'
    ], [
      'Calculate forcing moves first and stop only when the position is quiet.',
      'Name the tactical motif after each miss to improve retrieval next time.',
    ]),
    _Knowledge('darts', 'Darts', 'Spatial', [
      'aim',
      'throw',
      'bullseye',
      'coordination'
    ], [
      'Keep the release direction consistent before increasing throw power.',
      'Use the last landing as feedback and correct only one variable at a time.',
    ]),
    _Knowledge('cube', 'Rubik’s Cube', 'Memory', [
      'rubik',
      '3x3',
      '2x2',
      'algorithms',
      'turns'
    ], [
      'Recognize the case before executing; fast wrong recognition loses more time.',
      'Drill algorithms in short spaced sets until execution is interruption-proof.',
    ]),
    _Knowledge('scribble', 'Scribble', 'Language', [
      'drawing',
      'guessing',
      'visual communication',
      'sketch'
    ], [
      'Draw the most distinctive silhouette first, then one contextual clue.',
      'Avoid detail until the core object is instantly recognizable.',
    ]),
    _Knowledge('wordfind', 'Word Finder', 'Language', [
      'word search',
      'vocabulary',
      'letters',
      'anagram'
    ], [
      'Scan uncommon letter pairs and word endings before common short words.',
      'Rotate between rows, columns and diagonals to prevent tunnel vision.',
    ]),
    _Knowledge('art', 'Art Heist', 'Memory', [
      'visual recall',
      'tiles',
      'art race',
      'heist'
    ], [
      'Encode the board as grouped shapes and colors, not individual tiles.',
      'Reconstruct high-confidence regions first to reduce interference.',
    ]),
    _Knowledge('crossword', 'Crossword', 'Language', [
      'clues',
      'vocabulary',
      'word grid'
    ], [
      'Answer high-confidence clues first; crossings turn guesses into constraints.',
      'Match tense, plurality and abbreviation style before testing a word.',
    ]),
    _Knowledge('numpz', 'Number Puzzle', 'Spatial', [
      'number puzzle',
      'sliding numbers',
      'tiles'
    ], [
      'Solve the outer structure first and preserve completed rows.',
      'Think in blank-space cycles rather than moving the target tile directly.',
    ]),
    _Knowledge('arrow', 'Arrow Puzzle', 'Spatial', [
      'arrows',
      'rotation',
      'neighbors',
      'orientation'
    ], [
      'Track which taps affect each target before making local corrections.',
      'Work from low-interaction edges toward the highly connected center.',
    ]),
    _Knowledge('daily', 'Daily Arena', 'Competition', [
      'daily challenge',
      'mixed games',
      'streak'
    ], [
      'Treat the daily set as diagnosis: note the first category that slows you.',
      'Complete it at a consistent time to build a reliable practice cue.',
    ]),
    _Knowledge('contest', 'Contest', 'Competition', [
      'tournament',
      'ranked',
      'competition'
    ], [
      'Warm up in the weakest tested category, then protect accuracy early.',
      'Use a skip threshold so one problem cannot consume the whole contest.',
    ]),
    _Knowledge('arena', 'Arena', 'Competition', [
      'multiplayer',
      'public arena',
      'private arena',
      'match'
    ], [
      'Enter with one pacing rule and review outcome separately from decision quality.',
      'After a loss, replay the first avoidable error—not only the final score.',
    ]),
    _Knowledge('chocolate', 'Chocolate Hour', 'Calculation', [
      'hourly problem',
      'daily puzzle'
    ], [
      'Use the hourly problem as a recall check, not a speed test.',
      'If the method is unclear, write the setup before committing an answer.',
    ]),
  ];

  static List<String> get allKnownGames =>
      List.unmodifiable(_knowledge.map((item) => item.id));

  CoachSnapshot snapshot() {
    var totalN = 0;
    var totalC = 0;
    var totalMs = 0;
    var blunders = 0;
    var deepThinks = 0;
    for (final raw in data.catStats.values) {
      final stat = Map<String, dynamic>.from(raw as Map);
      totalN += (stat['n'] as num?)?.toInt() ?? 0;
      totalC += (stat['correct'] as num?)?.toInt() ?? 0;
      totalMs += (stat['ms'] as num?)?.toInt() ?? 0;
      blunders += (stat['fastWrong'] as num?)?.toInt() ?? 0;
      deepThinks += (stat['slowRight'] as num?)?.toInt() ?? 0;
    }

    final insights = _knowledge.map(_buildInsight).toList();
    final days = _dayPoints();
    final groupScores = <String, double>{};
    for (final group in _groups) {
      final measured = insights
          .where((item) => item.group == group && item.measured)
          .toList();
      groupScores[group] = measured.isEmpty
          ? 0
          : measured.fold<double>(
                  0,
                  (sum, item) =>
                      sum + item.score * (0.4 + item.confidence * 0.6)) /
              measured.fold<double>(
                  0, (sum, item) => sum + 0.4 + item.confidence * 0.6);
    }
    if (data.matches.isNotEmpty) {
      final wins = data.matches.where((m) => m['result'] == 'W').length;
      groupScores['Competition'] = wins / data.matches.length;
    }

    final recent = days.skip(7).fold<int>(0, (sum, d) => sum + d.sessions);
    final previous = days.take(7).fold<int>(0, (sum, d) => sum + d.sessions);
    final momentum = previous == 0
        ? (recent > 0 ? 100 : 0)
        : (((recent - previous) / previous) * 100).round().clamp(-999, 999);
    final wins = data.matches.where((m) => m['result'] == 'W').length;

    return CoachSnapshot(
      totalAnswers: totalN,
      correctAnswers: totalC,
      avgMs: totalN == 0 ? 0 : totalMs ~/ totalN,
      blunders: blunders,
      deepThinks: deepThinks,
      matches: data.matches.length,
      wins: wins,
      activeDays14: days.where((day) => day.sessions > 0).length,
      momentumPercent: momentum,
      insights: insights,
      groupScores: groupScores,
      days: days,
    );
  }

  CoachDomainInsight _buildInsight(_Knowledge item) {
    final raw = data.catStats[item.id];
    final stat = raw is Map ? Map<String, dynamic>.from(raw) : const {};
    var n = (stat['n'] as num?)?.toInt() ?? 0;
    var correct = (stat['correct'] as num?)?.toInt() ?? 0;
    final ms = (stat['ms'] as num?)?.toInt() ?? 0;
    final fastWrong = (stat['fastWrong'] as num?)?.toInt() ?? 0;
    final slowRight = (stat['slowRight'] as num?)?.toInt() ?? 0;

    final events = data.trainingEvents
        .where((event) => _canonicalDomain('${event['domain']}') == item.id)
        .toList();
    if (n == 0 && events.isNotEmpty) {
      n = events.length;
      correct = events.where((event) {
        final value = (event['value'] as num?)?.toDouble() ?? 0;
        return _eventQuality(event, value) >= 0.6;
      }).length;
    }

    final progress = _progressScore(item.id);
    final eventQuality = events.isEmpty
        ? null
        : events
                .map((event) => _eventQuality(
                    event, (event['value'] as num?)?.toDouble() ?? 0))
                .reduce((a, b) => a + b) /
            events.length;
    final answerQuality = n == 0 ? null : correct / n;
    final confidence = math.min(1.0, n / 18 + (progress > 0 ? 0.2 : 0));
    final quality = answerQuality ?? eventQuality ?? progress;
    final pacePenalty = n == 0 ? 0.0 : (slowRight / n * 0.12);
    final impulsePenalty = n == 0 ? 0.0 : (fastWrong / n * 0.22);
    final score =
        (quality * 0.82 + progress * 0.18 - pacePenalty - impulsePenalty)
            .clamp(0.0, 1.0);

    String evidence;
    if (raw is Map && n > 0) {
      evidence =
          '$correct/$n correct${ms > 0 ? ' · ${(ms / n / 1000).toStringAsFixed(1)}s average' : ''}';
    } else if (events.isNotEmpty) {
      evidence =
          '${events.length} recent sessions · ${score * 100 ~/ 1}% signal';
    } else if (progress > 0) {
      evidence = '${(progress * 100).round()}% progression signal';
    } else {
      evidence = 'Not measured yet';
    }

    return CoachDomainInsight(
      id: item.id,
      label: item.label,
      group: item.group,
      score: score,
      confidence: confidence,
      attempts: n,
      correct: correct,
      avgMs: n == 0 ? 0 : ms ~/ n,
      blunders: fastWrong,
      deepThinks: slowRight,
      evidence: evidence,
    );
  }

  double _progressScore(String id) {
    final solve = data.cats[id];
    if (solve is Map) {
      final unlocked = (solve['unlocked'] as num?)?.toInt() ?? 800;
      return ((unlocked - RatingCatalog.min) /
              (RatingCatalog.max - RatingCatalog.min))
          .clamp(0.0, 1.0);
    }
    if (id == 'art') {
      return ((data.artLevel - 1) / (ArtHeistCatalog.totalSteps - 1))
          .clamp(0.0, 1.0);
    }
    if (id == 'chess') {
      return ((AppData.chessLevelElo(data.chessLevel) - 800) / 1700)
          .clamp(0.0, 1.0);
    }
    if (id == 'chess_iq') {
      return ((data.chessIqLevel - 1) / 29).clamp(0.0, 1.0);
    }
    if (id == 'darts') {
      return ((data.dartsLevel - 1) / 49).clamp(0.0, 1.0);
    }
    final mind = data.mindLevels[id];
    if (mind is num) {
      final total = RatedProgression.totalSteps(RatingCatalog.variantsFor(id));
      return ((mind.toInt() - 1) / math.max(1, total - 1)).clamp(0.0, 1.0);
    }
    final kid = data.kidProgress[id];
    if (kid is num) {
      return ((kid.toInt() - 1) / (AppData.kidMaxLevel - 1)).clamp(0.0, 1.0);
    }
    return 0;
  }

  List<CoachDayPoint> _dayPoints() {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day)
        .subtract(const Duration(days: 13));
    return List.generate(14, (index) {
      final date = start.add(Duration(days: index));
      final key = _dateKey(date);
      final events = data.trainingEvents.where((event) {
        final ts = (event['ts'] as num?)?.toInt();
        if (ts == null) return false;
        return _dateKey(DateTime.fromMillisecondsSinceEpoch(ts)) == key;
      }).toList();
      final fallback = data.activityOn(key);
      final sessions = math.max(events.length, fallback);
      final quality = events.isEmpty
          ? null
          : events.fold<double>(0, (sum, event) {
                final value = (event['value'] as num?)?.toDouble() ?? 0;
                return sum + _eventQuality(event, value);
              }) /
              events.length;
      return CoachDayPoint(date: date, sessions: sessions, quality: quality);
    });
  }

  List<CoachPlanItem> plan({int count = 3, String? focusId}) {
    final snap = snapshot();
    final measured = snap.insights.where((item) => item.measured).toList()
      ..sort((a, b) {
        if (focusId == a.id) return -1;
        if (focusId == b.id) return 1;
        final aNeed = (1 - a.score) * (0.5 + a.confidence * 0.5);
        final bNeed = (1 - b.score) * (0.5 + b.confidence * 0.5);
        return bNeed.compareTo(aNeed);
      });
    final selected = <CoachDomainInsight>[];
    for (final item in measured) {
      if (selected.length >= count) break;
      if (selected.any((chosen) => chosen.group == item.group) &&
          measured.length > count) {
        continue;
      }
      selected.add(item);
    }
    if (selected.length < count) {
      for (final item in snap.insights.where((item) => !item.measured)) {
        if (selected.length >= count) break;
        if (selected.any((chosen) => chosen.id == item.id)) continue;
        if (selected.any((chosen) => chosen.group == item.group)) continue;
        selected.add(item);
      }
    }
    if (selected.length < count) {
      for (final item in snap.insights.where((item) => !item.measured)) {
        if (selected.length >= count) break;
        if (selected.any((chosen) => chosen.id == item.id)) continue;
        selected.add(item);
      }
    }
    return [
      for (var i = 0; i < selected.length; i++) _planFor(selected[i], i + 1),
    ];
  }

  CoachPlanItem _planFor(CoachDomainInsight insight, int priority) {
    final doc = _knowledge.firstWhere((item) => item.id == insight.id);
    final impulse = insight.blunders >= math.max(2, insight.attempts * 0.12);
    final slow = insight.deepThinks >= math.max(2, insight.attempts * 0.15);
    final reason = !insight.measured
        ? 'Baseline needed · I have no reliable ${insight.label} sample yet.'
        : impulse
            ? '${insight.blunders} fast misses show an impulse leak.'
            : slow
                ? '${insight.deepThinks} slow-right answers show sound method but slow recall.'
                : '${insight.evidence} · highest current improvement value.';
    final drill = impulse
        ? 'Do 8 questions with a mandatory 3-second read before every answer.'
        : slow
            ? 'Repeat one method in a 10-minute speed ladder: calm, smooth, fast.'
            : doc.tips.first;
    return CoachPlanItem(
      domainId: insight.id,
      title: insight.label,
      reason: reason,
      drill: drill,
      minutes: priority == 1 ? 12 : 8,
      priority: priority,
    );
  }

  CoachReply answer(String query) {
    final snap = snapshot();
    final clean = query.trim();
    if (clean.isEmpty) return _brief(snap);
    final tokens = _expand(_tokens(clean));
    final intent = _intent(tokens);
    final ranked = _rank(tokens, snap);
    final doc = ranked.isEmpty ? _knowledge.first : ranked.first.$1;
    final insight = snap.insights.firstWhere((item) => item.id == doc.id);
    final planItem = _planFor(insight, 1);

    if (intent == 'progress') {
      final accuracy = snap.accuracy == null
          ? 'not measured yet'
          : '${(snap.accuracy! * 100).round()}%';
      return CoachReply(
        title: 'Your honest progress read',
        message:
            'You have ${snap.totalAnswers} tracked answers at $accuracy accuracy, '
            '${snap.activeDays14}/14 active days and ${snap.wins}/${snap.matches} '
            'wins in recorded matches. ${_momentumLine(snap)}',
        steps: [
          if (snap.focus != null)
            'Protect the next session for ${snap.focus!.label}; it has the best improvement value.',
          if (snap.strongest != null)
            'Keep ${snap.strongest!.label} warm with one short maintenance set.',
          'Judge the week by decision quality and consistency, not one result.',
        ],
        evidence:
            'On-device telemetry · ${snap.totalAnswers} answers · ${snap.matches} matches',
        focusDomainId: snap.focus?.id,
      );
    }

    if (intent == 'mistakes') {
      final relevant = data.mistakes
          .where((item) => _canonicalDomain('${item['cat']}') == doc.id)
          .length;
      return CoachReply(
        title: 'Why ${doc.label} is leaking points',
        message: insight.measured
            ? '${insight.evidence}. I found $relevant retained mistakes in this '
                'area. ${insight.blunders > 0 ? '${insight.blunders} were fast-wrong signals, so the first fix is decision control.' : 'The pattern points more to method or recall than impulse.'}'
            : 'I do not have enough ${doc.label} evidence to diagnose a weakness '
                'honestly. Let’s collect a short baseline instead of guessing.',
        steps: [
          planItem.drill,
          doc.tips.length > 1 ? doc.tips[1] : doc.tips.first,
          'After the set, explain one miss aloud in a single sentence.',
        ],
        evidence: insight.evidence,
        focusDomainId: doc.id,
      );
    }

    if (intent == 'speed') {
      return CoachReply(
        title: '${doc.label} speed, without reckless errors',
        message:
            'Speed comes after a stable method. Your current evidence is ${insight.evidence.toLowerCase()}. '
            'We will compress the same correct process instead of inventing shortcuts under pressure.',
        steps: [
          'Round 1: 4 calm reps with perfect setup.',
          'Round 2: 4 reps at about 80% pace.',
          'Round 3: 4 timed reps; stop if accuracy falls below 75%.',
        ],
        evidence: insight.evidence,
        focusDomainId: doc.id,
      );
    }

    if (intent == 'plan') {
      final items = plan(count: 3, focusId: doc.id);
      return CoachReply(
        title: 'Your next focused session',
        message:
            'I built this from current weakness, confidence and coverage—not a generic workout.',
        steps: [
          for (final item in items)
            '${item.minutes} min ${item.title}: ${item.drill}',
        ],
        evidence:
            '${snap.totalAnswers} answers · ${snap.activeDays14} active days · local retrieval only',
        focusDomainId: items.isEmpty ? null : items.first.domainId,
      );
    }

    return CoachReply(
      title: '${doc.label}: coach’s answer',
      message: insight.measured
          ? 'Your personal signal is ${insight.evidence.toLowerCase()}. '
              'The best next move is to isolate one repeatable method, then test it under light time pressure.'
          : 'I understand this as a ${doc.label} question. I do not have enough '
              'personal evidence yet, so I’m giving you a safe baseline method and will adapt after the first set.',
      steps: [
        doc.tips.first,
        if (doc.tips.length > 1) doc.tips[1],
        'Run a short set now, then ask me “why did I miss?” for an evidence-based review.',
      ],
      evidence:
          '${insight.evidence} · BM25 local match ${ranked.isEmpty ? 'baseline' : ranked.first.$2.toStringAsFixed(2)}',
      focusDomainId: doc.id,
    );
  }

  CoachReply _brief(CoachSnapshot snap) {
    final focus = snap.focus;
    if (focus == null) {
      return const CoachReply(
        title: 'Let’s build your skillprint',
        message:
            'I will learn from math, logic, board games, reaction games and matches. Start with one short mixed session so I can coach from evidence.',
        steps: [
          'Play 5–10 questions or one complete game.',
          'Return here for a measured plan.',
        ],
        evidence: 'No reliable personal sample yet · all analysis stays local',
      );
    }
    return CoachReply(
      title: 'Today I’d coach ${focus.label}',
      message:
          '${focus.evidence}. ${_momentumLine(snap)} I would work this now because it offers more improvement than simply replaying your strongest game.',
      steps: [
        _planFor(focus, 1).drill,
        'Finish with one easy rep to lock in the correct pattern.',
      ],
      evidence:
          '${snap.totalAnswers} answers · ${snap.matches} matches · ${snap.activeDays14}/14 active days',
      focusDomainId: focus.id,
    );
  }

  String _momentumLine(CoachSnapshot snap) {
    if (snap.momentumPercent > 0) {
      return 'Training volume is up ${snap.momentumPercent}% versus the previous week.';
    }
    if (snap.momentumPercent < 0) {
      return 'Training volume is down ${snap.momentumPercent.abs()}%; a short comeback session is enough today.';
    }
    return 'Training volume is steady versus the previous week.';
  }

  List<(_Knowledge, double)> _rank(Set<String> query, CoachSnapshot snap) {
    if (query.isEmpty) return const [];
    final documents =
        _knowledge.map((item) => _tokens(item.searchable)).toList();
    final averageLength =
        documents.fold<int>(0, (sum, doc) => sum + doc.length) /
            documents.length;
    final ranked = <(_Knowledge, double)>[];
    for (var i = 0; i < _knowledge.length; i++) {
      final doc = documents[i];
      var score = 0.0;
      for (final term in query) {
        final frequency = doc.where((token) => token == term).length;
        if (frequency == 0) continue;
        final documentFrequency =
            documents.where((tokens) => tokens.contains(term)).length;
        final idf = math.log(1 +
            (documents.length - documentFrequency + 0.5) /
                (documentFrequency + 0.5));
        const k1 = 1.2;
        const b = 0.75;
        score += idf *
            (frequency * (k1 + 1)) /
            (frequency + k1 * (1 - b + b * doc.length / averageLength));
      }
      final insight =
          snap.insights.firstWhere((item) => item.id == _knowledge[i].id);
      if (insight.measured) {
        score += (1 - insight.score) * insight.confidence * 0.45;
      }
      if (score > 0) ranked.add((_knowledge[i], score));
    }
    ranked.sort((a, b) => b.$2.compareTo(a.$2));
    return ranked;
  }

  String _intent(Set<String> tokens) {
    if (tokens.intersects({
      'progress',
      'improv',
      'doing',
      'stats',
      'performance',
      'telemetry',
      'report',
      'strong'
    })) {
      return 'progress';
    }
    if (tokens.intersects({
      'why',
      'wrong',
      'mistake',
      'miss',
      'stuck',
      'weak',
      'error',
      'blunder'
    })) {
      return 'mistakes';
    }
    if (tokens
        .intersects({'fast', 'faster', 'speed', 'quick', 'time', 'slow'})) {
      return 'speed';
    }
    if (tokens.intersects({
      'plan',
      'train',
      'session',
      'practice',
      'today',
      'routine',
      'workout'
    })) {
      return 'plan';
    }
    return 'explain';
  }

  Set<String> _expand(Set<String> input) {
    final output = {...input};
    const expansions = <String, List<String>>{
      'math': ['mental', 'quant', 'number', 'calculation', 'arithmetic'],
      'logic': ['pattern', 'deduction', 'puzzle'],
      'word': ['language', 'crossword', 'vocabulary'],
      'memory': ['recall', 'matrix', 'cube'],
      'aim': ['darts', 'spatial'],
      'reaction': ['reflex', 'speed'],
      'rubik': ['cube', 'algorithm'],
      'competition': ['arena', 'contest', 'match'],
      'personal': ['plan', 'progress'],
    };
    for (final token in input) {
      output.addAll(expansions[token] ?? const []);
    }
    return output;
  }

  Set<String> _tokens(String value) {
    final normalized =
        value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
    if (normalized.isEmpty) return {};
    const stop = {
      'a',
      'an',
      'and',
      'are',
      'can',
      'do',
      'for',
      'how',
      'i',
      'in',
      'is',
      'me',
      'my',
      'of',
      'on',
      'the',
      'to',
      'what',
      'with',
    };
    return normalized
        .split(RegExp(r'\s+'))
        .where((token) => token.length > 1 && !stop.contains(token))
        .map((token) {
      if (token.endsWith('ing') && token.length > 5) {
        return token.substring(0, token.length - 3);
      }
      if (token.endsWith('ed') && token.length > 4) {
        return token.substring(0, token.length - 2);
      }
      if (token.endsWith('s') && token.length > 3) {
        return token.substring(0, token.length - 1);
      }
      return token;
    }).toSet();
  }

  String _canonicalDomain(String raw) {
    final value = raw.toLowerCase();
    for (final item in _knowledge) {
      if (value == item.id) return item.id;
    }
    if (value.contains('chess iq') || value.contains('chess_iq')) {
      return 'chess_iq';
    }
    if (value.contains('wordfind') || value.contains('word finder')) {
      return 'wordfind';
    }
    if (value.contains('numpz') || value.contains('number puzzle')) {
      return 'numpz';
    }
    for (final item in _knowledge) {
      final candidates = [item.id, item.label, ...item.aliases];
      if (candidates.any((candidate) =>
          value.contains(candidate.toLowerCase().replaceAll('’', '')))) {
        return item.id;
      }
    }
    return value;
  }

  double _eventQuality(Map<String, dynamic> event, double value) {
    final type = '${event['type']}';
    if (type == 'level' && value > 1) return (value / 3).clamp(0.0, 1.0);
    if (type == 'score' && value > 1) {
      return (math.log(value + 1) / math.log(101)).clamp(0.0, 1.0);
    }
    return value.clamp(0.0, 1.0);
  }

  static String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

extension on Set<String> {
  bool intersects(Set<String> values) => values.any(contains);
}
