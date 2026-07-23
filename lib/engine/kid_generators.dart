import 'dart:math';

import 'package:flutter/material.dart';

import '../theme_district.dart';
import 'question.dart';

/// ============================================================
/// MYNDASH KIDS — question generators for under-12s.
/// Topics are age-gated; every topic has 10 levels × 30 questions
/// with gentle progressive difficulty.
/// ============================================================

class KidTopic {
  final String id, name, emoji;
  final Color color;
  final int minAge; // 0 = everyone
  const KidTopic(this.id, this.name, this.emoji, this.color, {this.minAge = 0});
}

List<KidTopic> get kidTopics => <KidTopic>[
      KidTopic('counting', 'Counting', '🍎', DC.lime),
      KidTopic('addsub', 'Add & Subtract', '➕', DC.cyan),
      KidTopic('shapes', 'Shapes', '🔺', DC.amber),
      KidTopic('compare', 'Bigger or Smaller', '⚖️', DC.magenta),
      KidTopic('patterns', 'Patterns', '🌈', DC.violet),
      KidTopic('tables', 'Times Tables', '✖️', DC.cyan, minAge: 8),
      KidTopic('fractions', 'Fractions Fun', '🍕', DC.amber, minAge: 8),
      KidTopic('clockkid', 'Clock Time', '⏰', DC.lime, minAge: 8),
      KidTopic('wordskid', 'Story Sums', '📖', DC.magenta, minAge: 8),
      // ---- expansion pack ----
      KidTopic('oddone', 'Odd One Out', '🕵️', DC.cyan),
      KidTopic('evenodd', 'Even or Odd', '🎲', DC.lime),
      KidTopic('missing', 'Missing Number', '❓', DC.amber),
      KidTopic('position', 'Left or Right', '🧭', DC.magenta),
      KidTopic('skipcount', 'Skip Counting', '🦘', DC.violet),
      KidTopic('money', 'Money Math', '💰', DC.amber, minAge: 8),
      KidTopic('measure', 'Measuring', '📏', DC.cyan, minAge: 8),
      KidTopic('roman', 'Roman Numerals', '🏛️', DC.violet, minAge: 8),
    ];

List<KidTopic> kidTopicsFor(int age) =>
    kidTopics.where((t) => age >= t.minAge).toList();

List<String> _opts(Random rng, int answer, int spread) {
  final set = <int>{answer};
  while (set.length < 4) {
    final w = answer + rng.nextInt(spread * 2 + 1) - spread;
    if (w >= 0) set.add(w);
  }
  final list = set.toList()..shuffle(rng);
  return list.map((e) => '$e').toList();
}

/// level: 1..10.
Question generateKid(String topic, int level, Random rng) {
  switch (topic) {
    case 'counting':
      final n = min(3 + level + rng.nextInt(3), 15);
      const items = ['🍎', '⭐', '🐟', '🎈', '🐞', '🍪'];
      final it = items[rng.nextInt(items.length)];
      return Question(
        prompt: 'How many $it?\n\n${List.filled(n, it).join(' ')}',
        options: _opts(rng, n, 2 + level ~/ 3),
        answer: '$n',
        parMs: 12000,
      );
    case 'addsub':
      final top = 5 + level * 4;
      final a = 1 + rng.nextInt(top);
      final b = 1 + rng.nextInt(top);
      if (level >= 4 && rng.nextBool()) {
        final hi = max(a, b), lo = min(a, b);
        return Question(
          prompt: '$hi − $lo = ?',
          options: _opts(rng, hi - lo, 3 + level),
          answer: '${hi - lo}',
          parMs: 10000,
        );
      }
      return Question(
        prompt: '$a + $b = ?',
        options: _opts(rng, a + b, 3 + level),
        answer: '${a + b}',
        parMs: 10000,
      );
    case 'shapes':
      const qs = [
        (
          'Which shape has 3 sides?',
          'Triangle',
          ['Triangle', 'Square', 'Circle', 'Star']
        ),
        (
          'Which shape has 4 equal sides?',
          'Square',
          ['Square', 'Triangle', 'Circle', 'Oval']
        ),
        (
          'Which shape is perfectly round?',
          'Circle',
          ['Circle', 'Square', 'Triangle', 'Diamond']
        ),
        ('How many sides does a hexagon have?', '6', ['6', '5', '7', '8']),
        ('How many corners does a square have?', '4', ['4', '3', '5', '6']),
        (
          'A ball is shaped like a…',
          'Sphere',
          ['Sphere', 'Cube', 'Cone', 'Pyramid']
        ),
        ('How many sides does a pentagon have?', '5', ['5', '4', '6', '7']),
        (
          'Which shape do dice have?',
          'Cube',
          ['Cube', 'Sphere', 'Cone', 'Cylinder']
        ),
      ];
      final (p, ans, opts) = qs[rng.nextInt(qs.length)];
      final shuffled = [...opts]..shuffle(rng);
      return Question(prompt: p, options: shuffled, answer: ans, parMs: 10000);
    case 'compare':
      final top = 10 + level * 15;
      final a = rng.nextInt(top), b = rng.nextInt(top);
      if (a == b) return generateKid(topic, level, rng);
      return Question(
        prompt: 'Which number is BIGGER?',
        options: ['$a', '$b']..shuffle(rng),
        answer: '${max(a, b)}',
        parMs: 8000,
      );
    case 'patterns':
      final step = 1 + rng.nextInt(min(2 + level, 9));
      final start = 1 + rng.nextInt(10);
      final seq = List.generate(4, (i) => start + i * step);
      return Question(
        prompt: 'What comes next?\n${seq.join(', ')}, …',
        options: _opts(rng, start + 4 * step, step + 2),
        answer: '${start + 4 * step}',
        parMs: 12000,
        note: 'The numbers grow by $step each time.',
      );
    case 'tables':
      final a = 2 + rng.nextInt(min(1 + level, 10));
      final b = 1 + rng.nextInt(10);
      return Question(
        prompt: '$a × $b = ?',
        options: _opts(rng, a * b, a + 3),
        answer: '${a * b}',
        parMs: 9000,
      );
    case 'fractions':
      final wholes = [4, 6, 8, 10, 12, 16, 20];
      final w = wholes[rng.nextInt(min(3 + level ~/ 2, wholes.length))];
      if (level >= 5 && w % 4 == 0 && rng.nextBool()) {
        return Question(
          prompt: '🍕 What is a QUARTER of $w?',
          options: _opts(rng, w ~/ 4, 3),
          answer: '${w ~/ 4}',
          parMs: 11000,
        );
      }
      return Question(
        prompt: '🍕 What is HALF of $w?',
        options: _opts(rng, w ~/ 2, 3),
        answer: '${w ~/ 2}',
        parMs: 10000,
      );
    case 'clockkid':
      final h = 1 + rng.nextInt(11);
      final add = level < 4 ? 1 : 1 + rng.nextInt(3);
      final ans = (h + add - 1) % 12 + 1;
      return Question(
        prompt:
            '⏰ It is $h o\'clock.\nWhat time will it be in $add hour${add > 1 ? 's' : ''}?',
        options: _opts(rng, ans, 2).map((e) => '$e o\'clock').toList(),
        answer: '$ans o\'clock',
        parMs: 12000,
      );
    case 'oddone':
      // one item breaks the group — spot it
      const groups = [
        (['🍎', '🍌', '🍇', '🚗'], '🚗', 'fruit vs vehicle'),
        (['🐶', '🐱', '🐰', '🌳'], '🌳', 'animals vs tree'),
        (['⚽', '🏀', '🎾', '📚'], '📚', 'balls vs book'),
        (['🔺', '🔻', '📐', '⭕'], '⭕', 'pointy vs round'),
        (['🚌', '🚕', '🚓', '🐟'], '🐟', 'vehicles vs fish'),
        (['🌞', '🌝', '⭐', '🥦'], '🥦', 'sky vs veggie'),
        (['✏️', '🖍️', '🖊️', '🍩'], '🍩', 'writing vs donut'),
        (['🦁', '🐯', '🐆', '🐢'], '🐢', 'big cats vs turtle'),
      ];
      final g = groups[rng.nextInt(groups.length)];
      final shown = [...g.$1]..shuffle(rng);
      return Question(
        prompt: '🕵️ Which one does NOT belong?\n\n${shown.join('   ')}',
        options: shown,
        answer: g.$2,
        parMs: 10000,
        note: 'Hint: ${g.$3}.',
      );
    case 'evenodd':
      final n = rng.nextInt(20 + level * 10);
      final even = n % 2 == 0;
      return Question(
        prompt: '🎲 Is $n EVEN or ODD?',
        options: ['Even', 'Odd']..shuffle(rng),
        answer: even ? 'Even' : 'Odd',
        parMs: 7000,
        note: 'Numbers ending in 0,2,4,6,8 are even.',
      );
    case 'missing':
      final step = 1 + rng.nextInt(min(1 + level ~/ 2, 5));
      final start = 1 + rng.nextInt(10);
      final seq = List.generate(5, (i) => start + i * step);
      final hole = 1 + rng.nextInt(3); // hide a middle number
      final shown = [for (var i = 0; i < 5; i++) i == hole ? '❓' : '${seq[i]}'];
      return Question(
        prompt: 'Find the missing number:\n${shown.join(', ')}',
        options: _opts(rng, seq[hole], step + 2),
        answer: '${seq[hole]}',
        parMs: 12000,
      );
    case 'position':
      const things = ['🐶', '🐱', '🦊', '🐼', '🐸'];
      final row = [...things]..shuffle(rng);
      final int count = 3 + min(level ~/ 3, 2);
      final line = row.take(count).toList();
      final fromLeft = rng.nextBool();
      final idx = rng.nextInt(count);
      final pos = fromLeft ? idx + 1 : count - idx;
      const ordinal = ['1st', '2nd', '3rd', '4th', '5th'];
      return Question(
        prompt:
            '🧭 ${line.join('  ')}\n\nWho is ${ordinal[pos - 1]} from the ${fromLeft ? 'LEFT' : 'RIGHT'}?',
        options: line,
        answer: line[idx],
        parMs: 12000,
      );
    case 'skipcount':
      final by = [2, 5, 10, 3, 4][min(rng.nextInt(2 + level ~/ 2), 4)];
      final start = by * (1 + rng.nextInt(4));
      final seq = List.generate(4, (i) => start + i * by);
      return Question(
        prompt: '🦘 Skip-count by $by:\n${seq.join(', ')}, …',
        options: _opts(rng, start + 4 * by, by),
        answer: '${start + 4 * by}',
        parMs: 10000,
      );
    case 'money':
      final coins = [1, 2, 5, 10, 20];
      final n = 2 + min(level ~/ 2, 3);
      var total = 0;
      final held = <int>[];
      for (var i = 0; i < n; i++) {
        final c = coins[rng.nextInt(min(2 + level ~/ 2, coins.length))];
        held.add(c);
        total += c;
      }
      if (level >= 6 && rng.nextBool() && total > 1) {
        final price = total - (1 + rng.nextInt(min(total - 1, 9)));
        return Question(
          prompt:
              '💰 You have ₹$total and buy a toy for ₹$price.\nHow much change?',
          options: _opts(rng, total - price, 4),
          answer: '${total - price}',
          parMs: 14000,
        );
      }
      return Question(
        prompt:
            '💰 You have these coins:\n${held.map((c) => '₹$c').join(' + ')}\nHow much in total?',
        options: _opts(rng, total, 5),
        answer: '$total',
        parMs: 14000,
      );
    case 'measure':
      if (level >= 4 && rng.nextBool()) {
        final m = 1 + rng.nextInt(min(level, 9));
        return Question(
          prompt: '📏 $m meter${m > 1 ? 's' : ''} = how many centimeters?',
          options: _opts(rng, m * 100, 100),
          answer: '${m * 100}',
          parMs: 12000,
        );
      }
      final qs = <(String, String, List<String>)>[
        (
          '📏 100 centimeters make a…',
          'Meter',
          ['Meter', 'Kilometer', 'Liter', 'Gram']
        ),
        (
          '⚖️ 1000 grams make a…',
          'Kilogram',
          ['Kilogram', 'Meter', 'Liter', 'Ton']
        ),
        (
          '🥛 We measure milk in…',
          'Liters',
          ['Liters', 'Meters', 'Grams', 'Hours']
        ),
        (
          '🛣️ Long distances are measured in…',
          'Kilometers',
          ['Kilometers', 'Centimeters', 'Liters', 'Kilograms']
        ),
        ('⏱️ 60 seconds make a…', 'Minute', ['Minute', 'Hour', 'Day', 'Week']),
        ('📆 7 days make a…', 'Week', ['Week', 'Month', 'Year', 'Hour']),
      ];
      final mq = qs[rng.nextInt(qs.length)];
      final mo = [...mq.$3]..shuffle(rng);
      return Question(prompt: mq.$1, options: mo, answer: mq.$2, parMs: 11000);
    case 'roman':
      const pairs = [
        (1, 'I'),
        (2, 'II'),
        (3, 'III'),
        (4, 'IV'),
        (5, 'V'),
        (6, 'VI'),
        (7, 'VII'),
        (8, 'VIII'),
        (9, 'IX'),
        (10, 'X'),
        (12, 'XII'),
        (15, 'XV'),
        (20, 'XX'),
        (25, 'XXV'),
        (30, 'XXX'),
        (40, 'XL'),
        (50, 'L'),
        (90, 'XC'),
        (100, 'C'),
      ];
      final cap = min(5 + level * 2, pairs.length);
      final pick2 = pairs[rng.nextInt(cap)];
      if (rng.nextBool()) {
        final opts = <String>{pick2.$2};
        while (opts.length < 4) {
          opts.add(pairs[rng.nextInt(cap)].$2);
        }
        return Question(
          prompt: '🏛️ How do Romans write ${pick2.$1}?',
          options: opts.toList()..shuffle(rng),
          answer: pick2.$2,
          parMs: 11000,
        );
      }
      return Question(
        prompt: '🏛️ What number is ${pick2.$2}?',
        options: _opts(rng, pick2.$1, 4 + level),
        answer: '${pick2.$1}',
        parMs: 11000,
      );
    default: // wordskid
      final n1 = 2 + rng.nextInt(4 + level * 2);
      final n2 = 1 + rng.nextInt(3 + level);
      final stories = [
        ('You have $n1 stickers and win $n2 more. How many now?', n1 + n2),
        ('A tree has $n1 birds; $n2 fly away. How many stay?', max(n1 - n2, 0)),
        ('$n2 friends each bring $n1 sweets. How many sweets?', n1 * n2),
      ];
      final pick = stories[rng.nextInt(level >= 5 ? stories.length : 2)];
      return Question(
        prompt: '📖 ${pick.$1}',
        options: _opts(rng, pick.$2, 4 + level),
        answer: '${pick.$2}',
        parMs: 15000,
      );
  }
}
