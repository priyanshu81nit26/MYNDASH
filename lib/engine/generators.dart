import 'dart:math';

import 'question.dart';

/// Generates one question for [catId] at [rating] (800–2500).
/// All parameters scale with rating; distractors model real mistakes.
Question generate(String catId, int rating, Random rng) {
  switch (catId) {
    case 'mental':
      return _mental(rating, rng);
    case 'quant':
      return _quant(rating, rng);
    case 'numtheory':
      return _numTheory(rating, rng);
    case 'patterns':
      return _patterns(rating, rng);
    case 'geometry':
      return _geometry(rating, rng);
    case 'probability':
      return _probability(rating, rng);
    case 'clock':
      return _clock(rating, rng);
    case 'knights':
      return _knights(rating, rng);
    case 'crypta':
      return _crypta(rating, rng);
    case 'words':
      return _words(rating, rng);
    case 'finance':
      return _finance(rating, rng);
    case 'speedmath':
      // speed maths = mental math on a tight clock
      final q = _mental(rating, rng);
      return Question(
          prompt: q.prompt,
          options: q.options,
          answer: q.answer,
          parMs: (q.parMs * 0.6).round(),
          note: q.note);
    default:
      return _mental(rating, rng);
  }
}

// ---------------------------------------------------------------- helpers

int _ri(Random r, int lo, int hi) => lo + r.nextInt(hi - lo + 1);

int _gcd(int a, int b) => b == 0 ? a.abs() : _gcd(b, a % b);

String _frac(int n, int d) {
  final g = _gcd(n, d);
  n ~/= g;
  d ~/= g;
  return d == 1 ? '$n' : '$n/$d';
}

/// MCQ options around a numeric answer using plausible-mistake deltas.
List<String> _numOptions(Random rng, num answer, List<num> traps) {
  final opts = <String>{_fmt(answer)};
  for (final t in traps) {
    if (opts.length >= 4) break;
    if (t != answer && t > -1000000) opts.add(_fmt(t));
  }
  var spread = max(1, (answer.abs() * 0.1).round());
  while (opts.length < 4) {
    final v = answer + (rng.nextBool() ? 1 : -1) * _ri(rng, 1, spread + 2);
    opts.add(_fmt(v));
  }
  final list = opts.toList()..shuffle(rng);
  return list;
}

String _fmt(num v) {
  if (v == v.roundToDouble()) return v.round().toString();
  return v
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

Question _mcq(Random rng, String prompt, num answer, List<num> traps, int par,
    {String? note}) {
  final options = _numOptions(rng, answer, traps);
  return Question(
      prompt: prompt,
      options: options,
      answer: _fmt(answer),
      parMs: par,
      note: note);
}

// ---------------------------------------------------------------- mental

Question _mental(int r, Random rng) {
  final d = d01(r);
  final par = parMsFor(r, 16000);
  String p;
  num ans;
  if (r < 1000) {
    final a = _ri(rng, 12, 89), b = _ri(rng, 12, 89);
    if (rng.nextBool()) {
      p = '$a + $b';
      ans = a + b;
    } else {
      final hi = max(a, b), lo = min(a, b);
      p = '$hi − $lo';
      ans = hi - lo;
    }
  } else if (r < 1300) {
    final a = _ri(rng, 13, 99), b = _ri(rng, 3, 9);
    p = '$a × $b';
    ans = a * b;
  } else if (r < 1600) {
    if (rng.nextBool()) {
      final a = _ri(rng, 12, 29), b = _ri(rng, 12, 29);
      p = '$a × $b';
      ans = a * b;
    } else {
      final a = _ri(rng, 100, 999),
          b = _ri(rng, 100, 999),
          c = _ri(rng, 10, 99);
      p = '$a + $b − $c';
      ans = a + b - c;
    }
  } else if (r < 1900) {
    final k = rng.nextInt(3);
    if (k == 0) {
      final a = _ri(rng, 11, 25);
      p = '$a²';
      ans = a * a;
    } else if (k == 1) {
      final pc = [5, 10, 15, 20, 25, 40, 60, 75][rng.nextInt(8)];
      final base = _ri(rng, 2, 9) * 20;
      p = '$pc% of $base';
      ans = base * pc / 100;
    } else {
      final a = _ri(rng, 6, 15), b = _ri(rng, 6, 15), c = _ri(rng, 10, 60);
      p = '$a × $b + $c';
      ans = a * b + c;
    }
  } else if (r < 2200) {
    final k = rng.nextInt(3);
    if (k == 0) {
      final a = _ri(rng, 26, 60);
      p = '$a²';
      ans = a * a;
    } else if (k == 1) {
      final a = _ri(rng, 91, 99), b = _ri(rng, 91, 99);
      p = '$a × $b';
      ans = a * b;
    } else {
      final b = _ri(rng, 3, 9);
      final q = _ri(rng, 24, 96);
      final a = b * q;
      final c = _ri(rng, 11, 19);
      p = '$a ÷ $b + $c²';
      ans = q + c * c;
    }
  } else {
    final k = rng.nextInt(3);
    if (k == 0) {
      final a = _ri(rng, 5, 12);
      p = '$a³';
      ans = a * a * a;
    } else if (k == 1) {
      final a = _ri(rng, 102, 999), b = _ri(rng, 11, 99);
      p = '$a × $b';
      ans = a * b;
    } else {
      final den = [8, 16, 25, 40][rng.nextInt(4)];
      final num_ = _ri(rng, 1, den - 1);
      p = '$num_/$den as a percentage? (number only)';
      ans = num_ * 100 / den;
    }
  }
  // intra-noise: slightly larger numbers deeper in a level handled by caller
  return Question(
      prompt: p, answer: _fmt(ans), parMs: (par * (1 + d * 0.2)).round());
}

// ---------------------------------------------------------------- quant

Question _quant(int r, Random rng) {
  final par = parMsFor(r, 45000);
  final k = rng.nextInt(r < 1300 ? 3 : (r < 1900 ? 5 : 7));
  switch (k) {
    case 0: // percentage
      final pc = _ri(rng, 2, 9) * 5;
      final base = _ri(rng, 4, 40) * 10;
      final ans = base * pc / 100;
      return _mcq(rng, 'What is $pc% of $base?', ans,
          [base * pc / 10, base + pc, base - pc], par);
    case 1: // ratio share
      final a = _ri(rng, 2, 7), b = _ri(rng, 2, 7);
      final unit = _ri(rng, 3, 12);
      final total = (a + b) * unit;
      final ans = a * unit;
      return _mcq(
          rng,
          '₹$total is split between two friends in ratio $a:$b. '
          'How much does the first get?',
          ans,
          [b * unit, total / 2, a * b],
          par,
          note: 'Each ratio unit = $total ÷ ${a + b} = $unit.');
    case 2: // average
      final n = _ri(rng, 4, 6);
      final avg = _ri(rng, 12, 60);
      final shift = _ri(rng, 2, 9);
      return _mcq(
          rng,
          'The average of $n numbers is $avg. If every number increases '
          'by $shift, what is the new average?',
          avg + shift,
          [avg, avg + shift * n, avg * n + shift],
          par,
          note: 'Adding a constant to all values adds it to the average.');
    case 3: // profit/loss
      final cost = _ri(rng, 5, 40) * 10;
      final pc = _ri(rng, 1, 6) * 5;
      final ans = cost * (100 + pc) / 100;
      return _mcq(
          rng,
          'A trader buys an item for ₹$cost and sells at $pc% profit. '
          'Selling price?',
          ans,
          [cost * pc / 100, cost - cost * pc / 100, cost + pc],
          par);
    case 4: // speed
      final s = _ri(rng, 3, 12) * 10;
      final t = _ri(rng, 2, 8);
      return _mcq(
          rng,
          'A car travels at $s km/h for $t hours. Distance covered?',
          s * t,
          [s + t, s * t / 2, s * (t + 1)],
          par);
    case 5: // work
      final a = _ri(rng, 2, 6) * 2;
      final b = a * _ri(rng, 2, 3);
      final ansDen = a + b;
      final lcm = a * b ~/ _gcd(a, b);
      final together =
          lcm * ansDen ~/ (a * b); // rate sum in lcm units — compute simply
      final ans = _frac(a * b, ansDen);
      return Question(
        prompt: 'A finishes a job in $a days, B in $b days. Working together, '
            'how many days? (fraction ok)',
        options: [
          ans,
          _frac(a + b, 2),
          '${(a + b)}',
          _frac(a * b, (a + b) * 2 + together * 0), // keep 4 distinct-ish
        ].toSet().toList()
          ..shuffle(rng),
        answer: ans,
        parMs: par,
        note: 'Together rate = 1/$a + 1/$b → ${_frac(a * b, ansDen)} days.',
      );
    default: // compound interest (approx years=2)
      final pr = _ri(rng, 1, 8) * 1000;
      final rate = _ri(rng, 1, 4) * 5;
      final ans = pr * (100 + rate) * (100 + rate) / 10000;
      return _mcq(
          rng,
          '₹$pr at $rate% compound interest per year for 2 years. '
          'Final amount?',
          ans,
          [pr * (100 + 2 * rate) / 100, pr + rate * 20, ans - pr],
          par,
          note: 'Multiply by ${(100 + rate)}/100 twice.');
  }
}

// ---------------------------------------------------------------- number theory

Question _numTheory(int r, Random rng) {
  final par = parMsFor(r, 40000);
  final k = rng.nextInt(r < 1200 ? 2 : (r < 1600 ? 4 : (r < 2000 ? 5 : 6)));
  switch (k) {
    case 0: // divisibility
      final d = [3, 4, 6, 9, 11][rng.nextInt(5)];
      final base = _ri(rng, 40, 900);
      final n = base * d;
      final wrong = n + _ri(rng, 1, d - 1);
      final useDiv = rng.nextBool();
      final shown = useDiv ? n : wrong;
      return Question(
        prompt: 'Is $shown divisible by $d?',
        options: const ['Yes', 'No'],
        answer: useDiv ? 'Yes' : 'No',
        parMs: par,
      );
    case 1: // gcd
      final g = _ri(rng, 3, 12);
      final a = g * _ri(rng, 2, 9), b = g * _ri(rng, 2, 9);
      final ans = _gcd(a, b);
      return _mcq(rng, 'GCD of $a and $b?', ans, [g, a % b, 1], par);
    case 2: // lcm
      final a = _ri(rng, 4, 12), b = _ri(rng, 4, 12);
      final ans = a * b ~/ _gcd(a, b);
      return _mcq(
          rng, 'LCM of $a and $b?', ans, [a * b, _gcd(a, b), a + b], par);
    case 3: // remainder
      final m = _ri(rng, 3, 9);
      final q = _ri(rng, 12, 99);
      final rem = rng.nextInt(m);
      final n = m * q + rem;
      return _mcq(rng, 'Remainder when $n is divided by $m?', rem,
          [m - rem, rem + 1, q % m], par);
    case 4: // last digit of power
      final base = _ri(rng, 2, 9);
      final exp = _ri(rng, 3, 40);
      final cycle = _lastDigitCycle(base);
      final ans = cycle[(exp - 1) % cycle.length];
      return _mcq(rng, 'Last digit of $base^$exp?', ans,
          [cycle[exp % cycle.length], base, (base * exp) % 10], par,
          note: 'Last digits of powers of $base cycle: ${cycle.join(', ')}.');
    default: // count divisors
      final primes = [2, 3, 5, 7];
      final p1 = primes[rng.nextInt(4)];
      var p2 = primes[rng.nextInt(4)];
      while (p2 == p1) {
        p2 = primes[rng.nextInt(4)];
      }
      final e1 = _ri(rng, 1, 3), e2 = _ri(rng, 1, 2);
      final n = pow(p1, e1).toInt() * pow(p2, e2).toInt();
      final ans = (e1 + 1) * (e2 + 1);
      return _mcq(rng, 'How many positive divisors does $n have?', ans,
          [e1 + e2, e1 * e2, ans - 1], par,
          note: '$n = $p1^$e1 × $p2^$e2 → (${e1 + 1})(${e2 + 1}) divisors.');
  }
}

List<int> _lastDigitCycle(int base) {
  final seen = <int>[];
  var d = base % 10;
  while (!seen.contains(d)) {
    seen.add(d);
    d = (d * base) % 10;
  }
  return seen;
}

// ---------------------------------------------------------------- patterns

Question _patterns(int r, Random rng) {
  final par = parMsFor(r, 35000);
  final k = rng.nextInt(r < 1200 ? 2 : (r < 1600 ? 4 : (r < 2000 ? 5 : 6)));
  List<int> seq;
  int ans;
  String? note;
  switch (k) {
    case 0: // arithmetic
      final start = _ri(rng, 2, 30), step = _ri(rng, 3, 12);
      seq = List.generate(5, (i) => start + step * i);
      ans = start + step * 5;
      note = 'Add $step each time.';
    case 1: // geometric
      final start = _ri(rng, 2, 6), q = _ri(rng, 2, 3);
      seq = List.generate(5, (i) => start * pow(q, i).toInt());
      ans = start * pow(q, 5).toInt();
      note = 'Multiply by $q.';
    case 2: // squares + offset
      final off = _ri(rng, -3, 5);
      seq = List.generate(5, (i) => (i + 1) * (i + 1) + off);
      ans = 36 + off;
      note = 'n² ${off >= 0 ? '+ $off' : '− ${-off}'}.';
    case 3: // fibonacci-like
      var a = _ri(rng, 1, 5), b = _ri(rng, 2, 7);
      seq = [a, b];
      for (var i = 0; i < 3; i++) {
        seq.add(seq[seq.length - 1] + seq[seq.length - 2]);
      }
      ans = seq[4] + seq[3];
      note = 'Each term = sum of previous two.';
    case 4: // interleaved
      final s1 = _ri(rng, 2, 10), d1 = _ri(rng, 2, 6);
      final s2 = _ri(rng, 20, 40), d2 = _ri(rng, 3, 8);
      seq = [s1, s2, s1 + d1, s2 - d2, s1 + 2 * d1, s2 - 2 * d2];
      ans = s1 + 3 * d1;
      note = 'Two interleaved sequences.';
    default: // second differences
      final a = _ri(rng, 1, 4), b = _ri(rng, 1, 6), c = _ri(rng, 0, 9);
      seq = List.generate(5, (i) => a * i * i + b * i + c);
      ans = a * 25 + b * 5 + c;
      note = 'Differences grow by ${2 * a} — a quadratic pattern.';
  }
  final last = seq.last;
  return _mcq(rng, '${seq.join(', ')}, … ?', ans,
      [last + (last - seq[seq.length - 2]), ans + 1, ans - 2], par,
      note: note);
}

// ---------------------------------------------------------------- geometry

Question _geometry(int r, Random rng) {
  final par = parMsFor(r, 40000);
  final k = rng.nextInt(r < 1200 ? 2 : (r < 1600 ? 4 : (r < 2000 ? 5 : 6)));
  switch (k) {
    case 0: // third angle
      final a = _ri(rng, 25, 80), b = _ri(rng, 25, 80);
      return _mcq(rng, 'A triangle has angles $a° and $b°. The third angle?',
          180 - a - b, [180 - a, 90 - (a + b - 90), a + b], par);
    case 1: // rectangle
      final w = _ri(rng, 3, 15), h = _ri(rng, 3, 15);
      final area = rng.nextBool();
      return _mcq(
          rng,
          'A rectangle is $w × $h. Its ${area ? 'area' : 'perimeter'}?',
          area ? w * h : 2 * (w + h),
          [area ? 2 * (w + h) : w * h, w + h, w * h * 2],
          par);
    case 2: // pythagoras
      final t = [
        [3, 4, 5],
        [6, 8, 10],
        [5, 12, 13],
        [8, 15, 17],
        [7, 24, 25]
      ][rng.nextInt(5)];
      return _mcq(
          rng,
          'A right triangle has legs ${t[0]} and ${t[1]}. Hypotenuse?',
          t[2],
          [t[0] + t[1], t[2] - 1, t[2] + 1],
          par);
    case 3: // circle with r multiple of 7 (π = 22/7)
      final rad = 7 * _ri(rng, 1, 4);
      final area = rng.nextBool();
      final ans = area ? 22 * rad * rad ~/ 7 : 2 * 22 * rad ~/ 7;
      return _mcq(
          rng,
          'Circle of radius $rad (take π = 22/7). Its ${area ? 'area' : 'circumference'}?',
          ans,
          [area ? 2 * 22 * rad ~/ 7 : 22 * rad * rad ~/ 7, rad * rad, 44 * rad],
          par);
    case 4: // polygon interior angle
      final n = [5, 6, 8, 9, 10, 12][rng.nextInt(6)];
      final ans = (n - 2) * 180 ~/ n;
      return _mcq(
          rng,
          'Each interior angle of a regular $n-gon?',
          ans,
          [
            360 ~/ n,
            180 - 360 ~/ n == ans ? ans + 5 : 180 - 360 ~/ n,
            (n - 2) * 180
          ],
          par,
          note: 'Interior = (n−2)·180 ÷ n.');
    default: // distance between points
      final x1 = _ri(rng, 0, 9), y1 = _ri(rng, 0, 9);
      final t = [
        [3, 4, 5],
        [6, 8, 10],
        [5, 12, 13]
      ][rng.nextInt(3)];
      return _mcq(
          rng,
          'Distance between ($x1, $y1) and (${x1 + t[0]}, ${y1 + t[1]})?',
          t[2],
          [t[0] + t[1], t[2] + 1, t[2] - 1],
          par);
  }
}

// ---------------------------------------------------------------- probability

Question _probability(int r, Random rng) {
  final par = parMsFor(r, 45000);
  final k = rng.nextInt(r < 1300 ? 2 : (r < 1800 ? 4 : 5));
  switch (k) {
    case 0: // single die
      final good = _ri(rng, 1, 5);
      final ans = _frac(good, 6);
      return Question(
        prompt: 'A fair die is rolled. Probability of getting at most $good?',
        options: _fracOptions(rng, good, 6),
        answer: ans,
        parMs: par,
      );
    case 1: // coins
      final n = r < 1300 ? 2 : 3;
      final ans = _frac(1, pow(2, n).toInt());
      return Question(
        prompt: '$n fair coins are tossed. Probability all show heads?',
        options: _fracOptions(rng, 1, pow(2, n).toInt()),
        answer: ans,
        parMs: par,
      );
    case 2: // bag of balls
      final red = _ri(rng, 2, 6), blue = _ri(rng, 2, 6);
      final ans = _frac(red, red + blue);
      return Question(
        prompt:
            'A bag has $red red and $blue blue balls. Probability of drawing red?',
        options: _fracOptions(rng, red, red + blue),
        answer: ans,
        parMs: par,
      );
    case 3: // two dice sum
      final s = _ri(rng, 5, 9);
      final ways = [0, 0, 1, 2, 3, 4, 5, 6, 5, 4, 3, 2, 1][s];
      final ans = _frac(ways, 36);
      return Question(
        prompt: 'Two dice are rolled. Probability the sum is $s?',
        options: _fracOptions(rng, ways, 36),
        answer: ans,
        parMs: par,
        note: '$ways ways out of 36.',
      );
    default: // nCr
      final n = _ri(rng, 5, 9), c = _ri(rng, 2, 3);
      var ans = 1;
      for (var i = 0; i < c; i++) {
        ans = ans * (n - i) ~/ (i + 1);
      }
      return _mcq(rng, 'How many ways to choose $c people from $n?', ans,
          [n * c, pow(n, c).toInt(), ans + n], par,
          note: 'C($n,$c).');
  }
}

List<String> _fracOptions(Random rng, int n, int d) {
  final opts = <String>{_frac(n, d)};
  opts.add(_frac(d - n <= 0 ? n + 1 : d - n, d));
  opts.add(_frac(1, d));
  opts.add(_frac(min(n + 1, d), d + (n == min(n + 1, d) ? 2 : 0)));
  while (opts.length < 4) {
    opts.add(_frac(_ri(rng, 1, d - 1), d + rng.nextInt(3)));
  }
  final l = opts.take(4).toList()..shuffle(rng);
  return l;
}

// ---------------------------------------------------------------- clock

Question _clock(int r, Random rng) {
  final par = parMsFor(r, 40000);
  if (r < 1500 || rng.nextBool()) {
    final h = _ri(rng, 1, 12), m = _ri(rng, 0, 11) * 5;
    var angle = (30 * h - 5.5 * m).abs();
    if (angle > 180) angle = 360 - angle;
    return _mcq(
        rng,
        'Angle between the hands at ${h}:${m.toString().padLeft(2, '0')}?',
        angle,
        [
          (30 * h - 6 * m).abs() % 360,
          angle + 15,
          360 - angle == angle ? angle + 30 : 360 - angle
        ],
        par,
        note: '|30h − 5.5m|.');
  }
  const days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday'
  ];
  final start = rng.nextInt(7);
  final jump = _ri(rng, 15, 200);
  final ans = days[(start + jump) % 7];
  final opts = <String>{
    ans,
    days[(start + jump + 1) % 7],
    days[(start + jump + 6) % 7],
    days[start]
  }.toList()
    ..shuffle(rng);
  return Question(
    prompt: 'Today is ${days[start]}. What day will it be in $jump days?',
    options: opts,
    answer: ans,
    parMs: par,
    note: '$jump mod 7 = ${jump % 7} days ahead.',
  );
}

// ---------------------------------------------------------------- knights & knaves

Question _knights(int r, Random rng) {
  final n = r < 1400 ? 2 : 3;
  final names = ['Aria', 'Bo', 'Cass'].sublist(0, n);
  for (var attempt = 0; attempt < 60; attempt++) {
    // random true roles
    final roles = List.generate(n, (_) => rng.nextBool());
    // statements: each person makes one
    final stmts = <List<int>>[]; // [speaker, kind, target]
    for (var i = 0; i < n; i++) {
      final target = rng.nextInt(n);
      final kind = rng.nextInt(
          3); // 0: "T is a liar", 1: "T is a knight", 2: "exactly one knight"
      stmts.add([i, kind, target]);
    }
    bool holds(List<bool> rs, List<int> s) {
      final truth = switch (s[1]) {
        0 => !rs[s[2]],
        1 => rs[s[2]],
        _ => rs.where((x) => x).length == 1,
      };
      return rs[s[0]] ? truth : !truth;
    }

    // count consistent role assignments
    final consistent = <List<bool>>[];
    for (var mask = 0; mask < (1 << n); mask++) {
      final rs = List.generate(n, (i) => (mask >> i) & 1 == 1);
      if (stmts.every((s) => holds(rs, s))) consistent.add(rs);
    }
    if (consistent.length != 1) continue;
    final sol = consistent.first;

    String describe(List<bool> rs) {
      final knights = [
        for (var i = 0; i < n; i++)
          if (rs[i]) names[i]
      ];
      if (knights.isEmpty) return 'Nobody';
      return knights.join(' & ');
    }

    final lines = stmts.map((s) {
      final who = names[s[0]];
      return switch (s[1]) {
        0 =>
          '$who says: "${names[s[2]] == who ? 'I am' : '${names[s[2]]} is'} a liar."',
        1 =>
          '$who says: "${names[s[2]] == who ? 'I am' : '${names[s[2]]} is'} a knight."',
        _ => '$who says: "Exactly one of us is a knight."',
      };
    }).join('\n');

    // options: distinct descriptions
    final opts = <String>{describe(sol)};
    for (var mask = 0; mask < (1 << n) && opts.length < 4; mask++) {
      opts.add(describe(List.generate(n, (i) => (mask >> i) & 1 == 1)));
    }
    final list = opts.toList()..shuffle(rng);
    return Question(
      prompt:
          'Knights always tell the truth, knaves always lie.\n$lines\n\nWho is a knight?',
      options: list,
      answer: describe(sol),
      parMs: parMsFor(r, 60000),
    );
  }
  // fallback (rare)
  return Question(
    prompt:
        'Knights tell the truth, knaves lie.\nAria says: "Bo is a liar."\nBo says: "We are both knights."\n\nWho is a knight?',
    options: const ['Aria', 'Bo', 'Aria & Bo', 'Nobody'],
    answer: 'Aria',
    parMs: parMsFor(r, 60000),
  );
}

// ---------------------------------------------------------------- cryptarithms

class _Classic {
  final String puzzle;
  final Map<String, int> sol;
  const _Classic(this.puzzle, this.sol);
}

const _classics = [
  _Classic('SEND + MORE = MONEY',
      {'S': 9, 'E': 5, 'N': 6, 'D': 7, 'M': 1, 'O': 0, 'R': 8, 'Y': 2}),
  _Classic('DONALD + GERALD = ROBERT', {
    'D': 5,
    'O': 2,
    'N': 6,
    'A': 4,
    'L': 8,
    'G': 1,
    'E': 9,
    'R': 7,
    'B': 3,
    'T': 0
  }),
  _Classic('CROSS + ROADS = DANGER',
      {'C': 9, 'R': 6, 'O': 2, 'S': 3, 'A': 5, 'D': 1, 'N': 8, 'G': 7, 'E': 4}),
];

Question _crypta(int r, Random rng) {
  final par = parMsFor(r, 90000);
  if (r >= 1600) {
    final c = _classics[rng.nextInt(_classics.length)];
    final letters = c.sol.keys.toList();
    final letter = letters[rng.nextInt(letters.length)];
    final ans = c.sol[letter]!;
    return _mcq(
        rng,
        'Each letter is a unique digit:\n${c.puzzle}\n\nWhat digit is $letter?',
        ans,
        [(ans + 1) % 10, (ans + 9) % 10, (ans + 5) % 10],
        par);
  }
  // generated micro-cryptarithm: XY + ZY = ABC or two-digit sums, ≤5 letters, unique
  for (var attempt = 0; attempt < 120; attempt++) {
    final a = _ri(rng, 12, 98), b = _ri(rng, 12, 98);
    final s = a + b;
    final digits = '${a}${b}${s}'.split('').map(int.parse).toList();
    final distinct = digits.toSet().toList();
    if (distinct.length > 5) continue;
    const alphabet = 'ABCDEFGH';
    final map = <int, String>{};
    for (var i = 0; i < distinct.length; i++) {
      map[distinct[i]] = alphabet[i];
    }
    String enc(int v) => '$v'.split('').map((d) => map[int.parse(d)]!).join();
    // uniqueness: brute force assignments
    var solutions = 0;
    final letters = distinct.map((d) => map[d]!).toList();
    final aPat = enc(a), bPat = enc(b), sPat = enc(s);
    void assign(int idx, Map<String, int> cur, List<bool> used) {
      if (solutions > 1) return;
      if (idx == letters.length) {
        int val(String pat) =>
            pat.split('').fold(0, (v, ch) => v * 10 + cur[ch]!);
        if (cur[aPat[0]] == 0 || cur[bPat[0]] == 0 || cur[sPat[0]] == 0) return;
        if (val(aPat) + val(bPat) == val(sPat)) solutions++;
        return;
      }
      for (var d = 0; d <= 9; d++) {
        if (used[d]) continue;
        used[d] = true;
        cur[letters[idx]] = d;
        assign(idx + 1, cur, used);
        used[d] = false;
      }
    }

    assign(0, {}, List.filled(10, false));
    if (solutions != 1) continue;

    final letter = letters[rng.nextInt(letters.length)];
    final ans = distinct[letters.indexOf(letter)];
    return _mcq(
        rng,
        'Each letter is a unique digit:\n$aPat + $bPat = $sPat\n\nWhat digit is $letter?',
        ans,
        [(ans + 1) % 10, (ans + 9) % 10, (ans + 3) % 10],
        par);
  }
  return _crypta(1700, rng); // fall back to a classic
}

// ---------------------------------------------------------------- word problems

Question _words(int r, Random rng) {
  final par = parMsFor(r, 55000);
  final k = rng.nextInt(r < 1300 ? 3 : (r < 1900 ? 5 : 6));
  switch (k) {
    case 0: // heads & legs
      final rabbits = _ri(rng, 3, 12), chickens = _ri(rng, 3, 12);
      final heads = rabbits + chickens, legs = rabbits * 4 + chickens * 2;
      return _mcq(
          rng,
          'A farm has rabbits and chickens: $heads heads and $legs legs. '
          'How many rabbits?',
          rabbits,
          [chickens, heads - 2, legs ~/ 4],
          par,
          note: 'Rabbits = (legs − 2·heads) ÷ 2.');
    case 1: // ages
      final son = _ri(rng, 6, 15);
      final k2 = _ri(rng, 2, 4);
      final dad = son * k2;
      final yrs = _ri(rng, 3, 10);
      return _mcq(
          rng,
          'A father is $k2× as old as his son, who is $son. '
          'How old will the father be in $yrs years?',
          dad + yrs,
          [dad, son + yrs, dad + son],
          par);
    case 2: // handshakes
      final n = _ri(rng, 5, 12);
      return _mcq(
          rng,
          '$n people all shake hands with each other once. Total handshakes?',
          n * (n - 1) ~/ 2,
          [n * n, n * (n - 1), n - 1],
          par,
          note: 'n(n−1)/2.');
    case 3: // socks worst case
      final colors = _ri(rng, 2, 4);
      return _mcq(
          rng,
          'A drawer has socks of $colors colors, plenty of each. In the dark, '
          'how many must you take to guarantee a matching pair?',
          colors + 1,
          [colors, 2, colors * 2],
          par,
          note: 'Pigeonhole: one more than the number of colors.');
    case 4: // consecutive integers
      final start = _ri(rng, 4, 40);
      final sum = 3 * start + 3;
      return _mcq(
          rng,
          'Three consecutive integers sum to $sum. What is the smallest?',
          start,
          [start + 1, sum ~/ 3, start - 1],
          par);
    default: // bat & ball trap
      final total = _ri(rng, 2, 8) * 55;
      final diff = total * 10 ~/ 11;
      final ball = (total - diff) ~/ 2;
      return _mcq(
          rng,
          'A bat and a ball cost ₹$total together. The bat costs ₹$diff more '
          'than the ball. How much is the ball?',
          ball,
          [total - diff, diff, total ~/ 2],
          par,
          note: 'Ball = (total − difference) ÷ 2 — don\'t fall for the trap!');
  }
}

// ---------------------------------------------------------------- finance

/// Speed Finance — interest, discounts, EMI-style splits, margins,
/// break-even, currency, taxes. Rating-scaled like every other feed.
Question _finance(int r, Random rng) {
  final par = parMsFor(r, 40000);
  final k = rng.nextInt(r < 1200 ? 3 : (r < 1600 ? 5 : (r < 2000 ? 7 : 9)));
  switch (k) {
    case 0: // simple interest
      final p = _ri(rng, 1, 9) * 1000;
      final rate = _ri(rng, 2, 12);
      final t = _ri(rng, 1, 5);
      final si = p * rate * t ~/ 100;
      return _mcq(
          rng,
          'Simple interest on ₹$p at $rate% per year for $t years?',
          si,
          [p * rate ~/ 100, si + p, p * t ~/ 100],
          par,
          note: 'SI = P × R × T ÷ 100.');
    case 1: // discount
      final mrp = _ri(rng, 2, 20) * 50;
      final d = _ri(rng, 1, 8) * 5;
      final ans = mrp * (100 - d) / 100;
      return _mcq(rng, 'An item has MRP ₹$mrp with $d% off. What do you pay?',
          ans, [mrp * d / 100, mrp - d, ans - 10], par);
    case 2: // GST / tax
      final base = _ri(rng, 2, 20) * 100;
      final gst = [5, 12, 18, 28][rng.nextInt(4)];
      final ans = base * (100 + gst) / 100;
      return _mcq(rng, 'A bill of ₹$base gets $gst% GST added. Total payable?',
          ans, [base * gst / 100, base + gst, ans - base], par);
    case 3: // profit margin
      final cost = _ri(rng, 4, 40) * 25;
      final sell = cost + cost * _ri(rng, 1, 8) * 5 ~/ 100;
      final ans = (sell - cost) * 100 ~/ cost;
      return _mcq(rng, 'Bought at ₹$cost, sold at ₹$sell. Profit percentage?',
          ans, [(sell - cost) * 100 ~/ sell, sell - cost, ans + 5], par,
          note: 'Profit% = profit ÷ cost × 100.');
    case 4: // EMI-style equal split
      final loan = _ri(rng, 2, 12) * 6000;
      final months = [6, 12, 24][rng.nextInt(3)];
      final ans = loan ~/ months;
      return _mcq(
          rng,
          'A ₹$loan interest-free loan is repaid in $months equal monthly '
          'installments. Each installment?',
          ans,
          [loan ~/ (months ~/ 2), ans * 2, ans + 100],
          par);
    case 5: // compound interest 2y
      final p = _ri(rng, 1, 6) * 2000;
      final rate = _ri(rng, 1, 4) * 5;
      final ans = p * (100 + rate) * (100 + rate) / 10000;
      return _mcq(
          rng,
          '₹$p invested at $rate% compounded yearly. Value after 2 years?',
          ans,
          [p * (100 + 2 * rate) / 100, ans - p, p + rate * 100],
          par,
          note: 'Multiply by ${100 + rate}/100 twice.');
    case 6: // break-even
      final fixed = _ri(rng, 2, 9) * 1000;
      final margin = _ri(rng, 2, 10) * 5;
      final ans = (fixed + margin - 1) ~/ margin;
      return _mcq(
          rng,
          'Fixed costs are ₹$fixed and each unit sold earns ₹$margin profit. '
          'Units needed to break even?',
          ans,
          [fixed ~/ (margin * 2), ans * 2, fixed],
          par,
          note: 'Break-even = fixed ÷ margin, rounded up.');
    case 7: // currency conversion
      final rate = _ri(rng, 80, 90);
      final usd = _ri(rng, 3, 25);
      return _mcq(rng, 'If 1 dollar = ₹$rate, how many rupees is \$$usd?',
          usd * rate, [usd + rate, usd * (rate - 5), usd * rate + 50], par);
    default: // successive discounts
      final d1 = _ri(rng, 1, 4) * 10, d2 = _ri(rng, 1, 3) * 10;
      final eff = d1 + d2 - d1 * d2 / 100;
      return _mcq(
          rng,
          'Two successive discounts of $d1% and $d2% equal a single '
          'discount of…? (number only)',
          eff,
          [d1 + d2, d1 * d2 / 100, eff + 2],
          par,
          note: 'Effective = a + b − ab/100.');
  }
}
