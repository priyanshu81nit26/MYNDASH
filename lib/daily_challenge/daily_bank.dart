import 'dart:math';

import 'daily_models.dart';

/// A dedicated 100-day bank for the expanded Daily Challenge.
///
/// It intentionally does not call the regular Solve/Contest generators.
/// Every day has its own deterministic paper, so retries and replays remain
/// stable while the content stays separate from the existing question bank.
const dailyChallengeDayCount = 100;

final dailyChallengeEpoch = DateTime(2026, 7, 1);

int dailyChallengeDayIndex([DateTime? when]) {
  final d = when ?? DateTime.now();
  final raw =
      DateTime(d.year, d.month, d.day).difference(dailyChallengeEpoch).inDays;
  return ((raw % dailyChallengeDayCount) + dailyChallengeDayCount) %
      dailyChallengeDayCount;
}

DailyChallengeDay dailyChallengeDay(int day) {
  final d = day % dailyChallengeDayCount;
  final rng = Random(0x51A7E ^ (d * 104729));
  final math = _mathPaper(d, rng);
  final shuffledRatings = <int>[
    800,
    900,
    1000,
    1100,
    1200,
    1300,
    1400,
    1500,
    1600,
    1700,
    1800,
    1900,
    2000,
    2100,
    2200,
    2300,
    2400,
    2500,
  ]..shuffle(Random(0xD411 ^ d * 3571));

  final games = <DailyChallengeItem>[
    DailyChallengeItem(
      id: 'sudoku',
      type: DailyItemType.sudoku,
      title: '8×8 Sudoku',
      subtitle: 'Rows, columns and 2×4 boxes',
      category: 'sudoku',
      rating: shuffledRatings[0],
      xp: 20,
      coins: 10,
      seed: 0x5D0 + d * 7907,
    ),
    DailyChallengeItem(
      id: 'art-heist',
      type: DailyItemType.artHeist,
      title: 'Art Heist',
      subtitle: 'Restore the stolen 4×4 artwork',
      category: 'art',
      rating: shuffledRatings[1],
      xp: 20,
      coins: 10,
      seed: 0xA47 + d * 6151,
    ),
    DailyChallengeItem(
      id: 'crossword',
      type: DailyItemType.crossword,
      title: 'Word Hunt',
      subtitle: 'Trace any real word through the embedded letter trails',
      category: 'crossword',
      rating: shuffledRatings[2],
      xp: 20,
      coins: 10,
      seed: 0xC2055 + d * 3253,
      note: 'Every accepted trail must be a real dictionary word.',
    ),
    DailyChallengeItem(
      id: 'number-puzzle',
      type: DailyItemType.numberPuzzle,
      title: 'Number Puzzle 5×5',
      subtitle: 'Slide 1–24 into order',
      category: 'numpz',
      rating: shuffledRatings[3],
      xp: 20,
      coins: 10,
      seed: 0x25 + d * 12289,
    ),
    DailyChallengeItem(
      id: 'kenken',
      type: DailyItemType.kenKen,
      title: 'KenKen',
      subtitle: 'Latin-square logic with arithmetic cages',
      category: 'kenken',
      rating: shuffledRatings[4],
      xp: 20,
      coins: 10,
      seed: 0x4E4B + d * 7919,
    ),
    DailyChallengeItem(
      id: 'cross-math',
      type: DailyItemType.crossMath,
      title: 'Cross Math',
      subtitle: 'Complete a full web of six crossing equations',
      category: 'crossmath',
      rating: shuffledRatings[5],
      xp: 20,
      coins: 10,
      seed: 0xC2055A + d * 1013,
      note: 'Each missing number is constrained by its linked equations.',
    ),
  ];

  // The six game ratings appear in a fresh order every day. Math remains a
  // genuine progressive chain (1200 → 1800), as requested.
  return DailyChallengeDay(dayIndex: d, math: math, games: games);
}

/// Resolves a persisted Daily Archive record back to its deterministic board.
///
/// Regular game level pickers use this to append completed Daily boards under
/// the matching game and rating instead of hiding them in a separate feed.
DailyChallengeItem dailyChallengeItemForArchive(
  Map<String, dynamic> record,
) {
  final day = (record['day'] as num?)?.toInt() ?? 0;
  final id = '${record['id']}';
  final challenge = dailyChallengeDay(day);
  return challenge.all.firstWhere(
    (item) => item.id == id,
    orElse: () => challenge.math.first,
  );
}

List<DailyChallengeItem> _mathPaper(int day, Random rng) {
  final a = 18 + day * 3 + rng.nextInt(3);
  final b = 9 + day * 2;
  final percent = [12, 15, 18, 20, 25][day % 5];
  // Keep the base divisible by 100 so every configured percentage produces
  // an exact rupee answer rather than silently truncating a decimal value.
  final base = (25 + day) * 100;
  final k = 3 + day % 7;
  final x = 8 + day;
  final c = 5 + (day * 2) % 17;
  final n1 = 6 + day;
  final n2 = 11 + day;
  final rateA = 5 + day;
  final rateB = 9 + day;
  final togetherNum = rateA * rateB;
  final togetherDen = rateA + rateB;

  return [
    DailyChallengeItem(
      id: 'math-0',
      type: DailyItemType.math,
      title: 'Math 1',
      subtitle: 'Warm-up · mental arithmetic',
      category: 'mental',
      rating: 1200,
      xp: 12,
      coins: 4,
      seed: day * 101 + 1,
      prompt: 'Calculate: ${a * 3} + ${b * 4} − $a',
      answer: '${a * 2 + b * 4}',
      note: 'Group like terms before calculating.',
    ),
    DailyChallengeItem(
      id: 'math-1',
      type: DailyItemType.math,
      title: 'Math 2',
      subtitle: 'Percentages',
      category: 'quant',
      rating: 1300,
      xp: 14,
      coins: 5,
      seed: day * 101 + 2,
      prompt:
          'A ₹$base item is discounted by $percent%. What is the sale price?',
      answer: '${base - (base * percent ~/ 100)}',
      note: 'Sale price = original − discount.',
    ),
    DailyChallengeItem(
      id: 'math-2',
      type: DailyItemType.math,
      title: 'Math 3',
      subtitle: 'Linear reasoning',
      category: 'quant',
      rating: 1500,
      xp: 16,
      coins: 6,
      seed: day * 101 + 3,
      prompt: 'Solve for x: ${k}x + $c = ${k * x + c}',
      answer: '$x',
      note: 'Subtract the constant, then divide by the coefficient.',
    ),
    DailyChallengeItem(
      id: 'math-3',
      type: DailyItemType.math,
      title: 'Math 4',
      subtitle: 'Number theory',
      category: 'numtheory',
      rating: 1700,
      xp: 18,
      coins: 7,
      seed: day * 101 + 4,
      prompt: 'Find the LCM of ${n1 * 2} and ${n2 * 3}.',
      answer: '${_lcm(n1 * 2, n2 * 3)}',
      note: 'LCM(a,b) = a×b ÷ GCD(a,b).',
    ),
    DailyChallengeItem(
      id: 'math-4',
      type: DailyItemType.math,
      title: 'Math 5',
      subtitle: 'Work-rate finish',
      category: 'quant',
      rating: 1800,
      xp: 20,
      coins: 8,
      seed: day * 101 + 5,
      prompt:
          'A finishes a job in $rateA days and B in $rateB days. Working together, how many days? Give the reduced fraction.',
      answer: _fraction(togetherNum, togetherDen),
      note: 'Add rates: 1/a + 1/b, then invert.',
    ),
  ];
}

int _gcd(int a, int b) {
  while (b != 0) {
    final t = a % b;
    a = b;
    b = t;
  }
  return a.abs();
}

int _lcm(int a, int b) => (a * b).abs() ~/ _gcd(a, b);

String _fraction(int n, int d) {
  final g = _gcd(n, d);
  return '${n ~/ g}/${d ~/ g}';
}

// Kept temporarily for compatibility with older persisted Daily payloads.
// ignore: unused_element
String _patternFor(String word, int day) {
  final chars = word.toUpperCase().split('');
  for (var i = 0; i < chars.length; i++) {
    if ((i + day) % 3 != 0) chars[i] = '_';
  }
  return chars.join(' ');
}

// ignore: unused_element
(String, String) _crossMath(int day) {
  final center = 7 + day % 29;
  final left = 3 + day % 9;
  final top = 2 + (day * 2) % 8;
  final horizontal = left + center;
  final vertical = top * center;
  return (
    'Fill the centre □ so both are true:\n\n'
        '$left + □ = $horizontal\n'
        '$top × □ = $vertical',
    '$center',
  );
}

/// (answer, clue, embedded crossing hint 1, embedded crossing hint 2).
// ignore: unused_element
const _crosswordWords = <(String, String, String, String)>[
  (
    'ALGORITHM',
    'A finite procedure for solving a problem',
    'LOG is fixed across',
    'RIM is fixed down'
  ),
  (
    'PARADOX',
    'A statement that appears self-contradictory',
    'RAY is fixed down',
    'ADO is fixed across'
  ),
  (
    'EQUINOX',
    'The date when day and night are nearly equal',
    'INK is fixed down',
    'NO is fixed across'
  ),
  (
    'CATALYST',
    'Something that accelerates change',
    'CAT is fixed across',
    'LYE is fixed down'
  ),
  (
    'FRACTAL',
    'A self-similar geometric form',
    'RAT is fixed down',
    'ACT is fixed across'
  ),
  (
    'MOMENTUM',
    'Mass multiplied by velocity',
    'MOM is fixed across',
    'TEN is fixed down'
  ),
  (
    'SYMMETRY',
    'Balanced correspondence across an axis',
    'MET is fixed across',
    'TRY is fixed down'
  ),
  (
    'QUANTUM',
    'A discrete packet of physical energy',
    'ANT is fixed across',
    'TUM is fixed down'
  ),
  (
    'NEBULA',
    'A cloud of gas and dust in space',
    'BUL is fixed across',
    'ELM is fixed down'
  ),
  (
    'CIPHER',
    'A coded system of writing',
    'HIP is fixed down',
    'PER is fixed across'
  ),
  (
    'VECTOR',
    'A quantity with magnitude and direction',
    'VET is fixed down',
    'CORE is fixed across'
  ),
  (
    'MATRIX',
    'A rectangular array of values',
    'MAT is fixed across',
    'RIX is fixed down'
  ),
  (
    'TANGENT',
    'A line touching a curve at one point',
    'ANG is fixed across',
    'TEN is fixed down'
  ),
  (
    'SCALAR',
    'A quantity having magnitude but no direction',
    'CAR is fixed across',
    'ALA is fixed down'
  ),
  (
    'ORBITAL',
    'A region where an electron is likely found',
    'BIT is fixed across',
    'TAL is fixed down'
  ),
  ('KINETIC', 'Relating to motion', 'NET is fixed across', 'TIC is fixed down'),
  (
    'ENTROPY',
    'A measure of disorder in a system',
    'TRO is fixed across',
    'RYE is fixed down'
  ),
  (
    'AXIOM',
    'A statement accepted without proof',
    'XI is fixed across',
    'ION is fixed down'
  ),
  (
    'THEOREM',
    'A proposition established by proof',
    'HE is fixed across',
    'ORE is fixed down'
  ),
  (
    'INTEGER',
    'A whole number, positive, negative, or zero',
    'TEG is fixed across',
    'GER is fixed down'
  ),
  (
    'VARIABLE',
    'A symbol whose value may change',
    'ARIA is fixed across',
    'BLE is fixed down'
  ),
  (
    'POLYGON',
    'A closed plane figure with straight sides',
    'LOG is fixed across',
    'GON is fixed down'
  ),
  (
    'ISOTOPE',
    'Atoms sharing protons but differing in neutrons',
    'TOP is fixed across',
    'SOP is fixed down'
  ),
  (
    'VORTEX',
    'A spinning mass of fluid or air',
    'ORT is fixed across',
    'TEX is fixed down'
  ),
  (
    'ZENITH',
    'The point directly above an observer',
    'NIT is fixed across',
    'HEN is fixed down'
  ),
  (
    'APOGEE',
    'The farthest point in an orbit',
    'POG is fixed across',
    'GEE is fixed down'
  ),
  (
    'PERIGEE',
    'The nearest point in an orbit',
    'RIG is fixed across',
    'GEE is fixed down'
  ),
  (
    'CHROMATIC',
    'Relating to colour or a semitone scale',
    'ROM is fixed across',
    'MAT is fixed down'
  ),
  (
    'RESONANCE',
    'A strong response at a natural frequency',
    'SON is fixed across',
    'NAN is fixed down'
  ),
  (
    'PRISMATIC',
    'Displaying separated spectral colours',
    'ISM is fixed across',
    'MAT is fixed down'
  ),
  (
    'LUMINOUS',
    'Emitting or reflecting bright light',
    'MIN is fixed across',
    'NOUS is fixed down'
  ),
  (
    'OBSIDIAN',
    'Dark volcanic glass',
    'SID is fixed across',
    'IAN is fixed down'
  ),
  (
    'MAGNETIC',
    'Relating to attraction by a field',
    'NET is fixed across',
    'TIC is fixed down'
  ),
  (
    'DYNAMIC',
    'Characterised by constant change or motion',
    'NAM is fixed across',
    'MIC is fixed down'
  ),
  (
    'ECLIPTIC',
    'The apparent annual path of the Sun',
    'LIP is fixed across',
    'TIC is fixed down'
  ),
  (
    'SPECTRUM',
    'A range of wavelengths or qualities',
    'PEC is fixed across',
    'RUM is fixed down'
  ),
  (
    'FIBONACCI',
    'Sequence where each term sums the prior two',
    'BON is fixed across',
    'CCI is fixed down'
  ),
  (
    'HYPOTENUSE',
    'Longest side of a right triangle',
    'POT is fixed across',
    'USE is fixed down'
  ),
  (
    'LOGARITHM',
    'Exponent needed to produce a number',
    'GAR is fixed across',
    'RIM is fixed down'
  ),
  (
    'POLYNOMIAL',
    'Expression with variables and nonnegative powers',
    'NOM is fixed across',
    'MAL is fixed down'
  ),
  (
    'ASYMPTOTE',
    'A line a curve approaches indefinitely',
    'SYM is fixed across',
    'TOTE is fixed down'
  ),
  (
    'CONGRUENT',
    'Identical in shape and size',
    'GRU is fixed across',
    'ENT is fixed down'
  ),
  (
    'PERMUTATION',
    'An ordered arrangement',
    'MUT is fixed across',
    'ION is fixed down'
  ),
  (
    'COMBINATION',
    'An unordered selection',
    'BIN is fixed across',
    'ION is fixed down'
  ),
  (
    'DERIVATIVE',
    'Instantaneous rate of change',
    'RIV is fixed across',
    'ATIVE is fixed down'
  ),
  (
    'INTEGRAL',
    'Accumulated quantity or area under a curve',
    'TEG is fixed across',
    'RAL is fixed down'
  ),
  (
    'CENTROID',
    'Geometric centre of a shape',
    'TRO is fixed across',
    'OID is fixed down'
  ),
  (
    'DIAGONAL',
    'Segment joining nonadjacent vertices',
    'AGO is fixed across',
    'NAL is fixed down'
  ),
  (
    'SEQUENCE',
    'An ordered list following a rule',
    'QUE is fixed across',
    'ENCE is fixed down'
  ),
  (
    'RECURRENCE',
    'Rule defining terms from preceding terms',
    'CUR is fixed across',
    'ENCE is fixed down'
  ),
  (
    'BISECTION',
    'Division into two equal parts',
    'SEC is fixed across',
    'ION is fixed down'
  ),
  (
    'COEFFICIENT',
    'Number multiplying a variable',
    'EFF is fixed across',
    'IENT is fixed down'
  ),
  (
    'DENOMINATOR',
    'Bottom number of a fraction',
    'NOM is fixed across',
    'TOR is fixed down'
  ),
  (
    'NUMERATOR',
    'Top number of a fraction',
    'MER is fixed across',
    'TOR is fixed down'
  ),
  (
    'PROPORTION',
    'Equality between two ratios',
    'PORT is fixed across',
    'ION is fixed down'
  ),
  (
    'RECIPROCAL',
    'Multiplicative inverse of a number',
    'CIP is fixed across',
    'CAL is fixed down'
  ),
  (
    'TRANSITIVE',
    'If aRb and bRc imply aRc',
    'SIT is fixed across',
    'IVE is fixed down'
  ),
  (
    'BIJECTIVE',
    'Both one-to-one and onto',
    'JECT is fixed across',
    'IVE is fixed down'
  ),
  (
    'INVARIANT',
    'Property unchanged by a transformation',
    'VAR is fixed across',
    'IANT is fixed down'
  ),
  (
    'CONJECTURE',
    'A claim believed true but not yet proved',
    'JECT is fixed across',
    'URE is fixed down'
  ),
  (
    'COROLLARY',
    'A result following readily from a theorem',
    'ROLL is fixed across',
    'ARY is fixed down'
  ),
  (
    'POSTULATE',
    'A proposition assumed as a basis for reasoning',
    'STU is fixed across',
    'LATE is fixed down'
  ),
  (
    'ELLIPTIC',
    'Oval-like or relating to an ellipse',
    'LIP is fixed across',
    'TIC is fixed down'
  ),
  (
    'HYPERBOLA',
    'Curve with two open symmetric branches',
    'PER is fixed across',
    'BOLA is fixed down'
  ),
  (
    'PARABOLA',
    'Curve traced by a quadratic relation',
    'ARA is fixed across',
    'BOLA is fixed down'
  ),
  (
    'TESSELLATE',
    'Tile a plane without gaps or overlaps',
    'SELL is fixed across',
    'LATE is fixed down'
  ),
  (
    'DODECAHEDRON',
    'Solid with twelve plane faces',
    'DECA is fixed across',
    'HEDRON is fixed down'
  ),
  (
    'ICOSAHEDRON',
    'Solid with twenty triangular faces',
    'COSA is fixed across',
    'HEDRON is fixed down'
  ),
  (
    'RHOMBOID',
    'Parallelogram with oblique adjacent sides',
    'HOM is fixed across',
    'OID is fixed down'
  ),
  (
    'TRAPEZOID',
    'Quadrilateral with at least one parallel pair',
    'APE is fixed across',
    'OID is fixed down'
  ),
  (
    'ORTHOGONAL',
    'Meeting at right angles',
    'THO is fixed across',
    'GONAL is fixed down'
  ),
  (
    'COLLINEAR',
    'Lying on the same straight line',
    'LINE is fixed across',
    'EAR is fixed down'
  ),
  (
    'COPLANAR',
    'Lying in the same plane',
    'PLAN is fixed across',
    'NAR is fixed down'
  ),
  (
    'EQUIDISTANT',
    'At equal distance from two or more points',
    'DIST is fixed across',
    'TANT is fixed down'
  ),
  (
    'CIRCUMCENTER',
    'Centre of a triangle’s circumscribed circle',
    'CUM is fixed across',
    'CENTER is fixed down'
  ),
  (
    'ORTHOCENTER',
    'Intersection point of a triangle’s altitudes',
    'THO is fixed across',
    'CENTER is fixed down'
  ),
  (
    'PERPENDICULAR',
    'Meeting to form a right angle',
    'PEND is fixed across',
    'ULAR is fixed down'
  ),
  (
    'EXPONENTIAL',
    'Changing at a rate proportional to value',
    'PON is fixed across',
    'TIAL is fixed down'
  ),
  (
    'QUADRATIC',
    'Polynomial of degree two',
    'DRA is fixed across',
    'TIC is fixed down'
  ),
  (
    'RATIONAL',
    'Expressible as a ratio of integers',
    'TIO is fixed across',
    'NAL is fixed down'
  ),
  (
    'IRRATIONAL',
    'Not expressible as a ratio of integers',
    'RAT is fixed across',
    'NAL is fixed down'
  ),
  (
    'IMAGINARY',
    'Number involving the square root of minus one',
    'MAG is fixed across',
    'NARY is fixed down'
  ),
  (
    'COMPLEX',
    'Having real and imaginary components',
    'PLE is fixed across',
    'LEX is fixed down'
  ),
  (
    'MODULUS',
    'Magnitude or remainder base in mathematics',
    'DUL is fixed across',
    'LUS is fixed down'
  ),
  (
    'MANTISSA',
    'Significant fractional part of a logarithm',
    'TIS is fixed across',
    'SSA is fixed down'
  ),
  (
    'ABSCISSA',
    'Horizontal coordinate of a point',
    'CIS is fixed across',
    'SSA is fixed down'
  ),
  (
    'ORDINATE',
    'Vertical coordinate of a point',
    'DIN is fixed across',
    'NATE is fixed down'
  ),
  (
    'TOPOLOGY',
    'Study of properties preserved by deformation',
    'POL is fixed across',
    'LOGY is fixed down'
  ),
  (
    'MANIFOLD',
    'Space locally resembling Euclidean space',
    'NIF is fixed across',
    'FOLD is fixed down'
  ),
  (
    'CARDINAL',
    'A number describing set size',
    'DIN is fixed across',
    'NAL is fixed down'
  ),
  (
    'ORDINAL',
    'A number describing position in order',
    'DIN is fixed across',
    'NAL is fixed down'
  ),
  (
    'BOOLEAN',
    'Having one of two logical values',
    'OLE is fixed across',
    'EAN is fixed down'
  ),
  (
    'RECURSION',
    'A definition that refers to itself',
    'CUR is fixed across',
    'SION is fixed down'
  ),
  (
    'HEURISTIC',
    'A practical shortcut for problem solving',
    'URI is fixed across',
    'TIC is fixed down'
  ),
  (
    'GREEDY',
    'Algorithm choosing the best immediate option',
    'REE is fixed across',
    'EDY is fixed down'
  ),
  (
    'BACKTRACK',
    'Search by undoing choices that fail',
    'ACK is fixed across',
    'TRACK is fixed down'
  ),
  (
    'HASHING',
    'Mapping data to fixed-size values',
    'ASH is fixed across',
    'HING is fixed down'
  ),
  (
    'GRAPHICAL',
    'Represented by a diagram or visual form',
    'RAP is fixed across',
    'ICAL is fixed down'
  ),
  (
    'STOCHASTIC',
    'Involving random probability',
    'CHA is fixed across',
    'TIC is fixed down'
  ),
  (
    'DETERMINISTIC',
    'Fully determined by initial conditions',
    'TERM is fixed across',
    'TIC is fixed down'
  ),
];
