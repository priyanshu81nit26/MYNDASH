import 'dart:math';

import 'wordlist.dart';

class WordGridSpec {
  final int size;
  final List<String> letters;
  final List<String> guaranteedWords;

  const WordGridSpec({
    required this.size,
    required this.letters,
    required this.guaranteedWords,
  });

  bool containsWord(String word) {
    final target = word.toLowerCase();
    if (target.isEmpty) return false;
    for (var start = 0; start < letters.length; start++) {
      if (letters[start] != target[0]) continue;
      if (_walk(target, 1, start, {start})) return true;
    }
    return false;
  }

  bool _walk(String word, int at, int cell, Set<int> used) {
    if (at == word.length) return true;
    final row = cell ~/ size;
    final col = cell % size;
    for (var dr = -1; dr <= 1; dr++) {
      for (var dc = -1; dc <= 1; dc++) {
        if (dr == 0 && dc == 0) continue;
        final nr = row + dr;
        final nc = col + dc;
        if (nr < 0 || nc < 0 || nr >= size || nc >= size) continue;
        final next = nr * size + nc;
        if (used.contains(next) || letters[next] != word[at]) continue;
        used.add(next);
        if (_walk(word, at + 1, next, used)) return true;
        used.remove(next);
      }
    }
    return false;
  }
}

/// Builds a Boggle-style grid with a guaranteed core of valid words.
///
/// The previous implementation filled every cell independently, which often
/// produced boards with very few playable paths. This generator deliberately
/// embeds dictionary words along legal adjacent-cell paths, then fills unused
/// cells from a language-weighted letter bag.
class WordGridGenerator {
  WordGridGenerator._();

  static const _bag =
      'eeeeeeeeeeaaaaaaaaiiiiiiiioooooonnnnnnrrrrrrttttttllllssssuuuu'
      'ddddgggbbccmmppffhhvvwwyykjxz';

  static final List<String> _candidates = wordSet
      .where((word) => word.length >= 3 && word.length <= 5)
      .toList(growable: false);

  static WordGridSpec generate({
    required int size,
    required int seed,
    required int minimumWords,
  }) {
    final safeSize = size.clamp(4, 6).toInt();
    WordGridSpec? best;

    for (var boardTry = 0; boardTry < 8; boardTry++) {
      final rng = Random(seed ^ (boardTry * 7919));
      final cells = List<String?>.filled(safeSize * safeSize, null);
      final candidates = List<String>.from(_candidates)..shuffle(rng);
      final placed = <String>[];

      for (final word in candidates) {
        if (placed.length >= minimumWords) break;
        if (_place(word, cells, safeSize, rng)) placed.add(word);
      }

      final letters = [
        for (final cell in cells) cell ?? _bag[rng.nextInt(_bag.length)],
      ];
      final spec = WordGridSpec(
        size: safeSize,
        letters: letters,
        guaranteedWords: placed,
      );
      if (best == null ||
          spec.guaranteedWords.length > best.guaranteedWords.length) {
        best = spec;
      }
      if (placed.length >= minimumWords) return spec;
    }

    return best!;
  }

  static bool _place(
    String word,
    List<String?> cells,
    int size,
    Random rng,
  ) {
    for (var attempt = 0; attempt < 160; attempt++) {
      final start = rng.nextInt(cells.length);
      final path = <int>[start];
      final used = <int>{start};
      var valid = cells[start] == null || cells[start] == word[0];

      for (var i = 1; valid && i < word.length; i++) {
        final current = path.last;
        final row = current ~/ size;
        final col = current % size;
        final options = <int>[];
        for (var dr = -1; dr <= 1; dr++) {
          for (var dc = -1; dc <= 1; dc++) {
            if (dr == 0 && dc == 0) continue;
            final nr = row + dr;
            final nc = col + dc;
            if (nr < 0 || nc < 0 || nr >= size || nc >= size) continue;
            final next = nr * size + nc;
            if (used.contains(next)) continue;
            if (cells[next] == null || cells[next] == word[i]) {
              options.add(next);
            }
          }
        }
        if (options.isEmpty) {
          valid = false;
          break;
        }
        final next = options[rng.nextInt(options.length)];
        path.add(next);
        used.add(next);
      }

      if (!valid || path.length != word.length) continue;
      for (var i = 0; i < path.length; i++) {
        cells[path[i]] = word[i];
      }
      return true;
    }
    return false;
  }
}
