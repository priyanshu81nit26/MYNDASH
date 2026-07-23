import 'question.dart';

enum ArenaGameMode {
  questions,
  sudoku,
  artHeist,
  crossword,
  chess,
  numberPuzzle,
}

class ArenaGameSpec {
  final String id;
  final String label;
  final ArenaGameMode mode;

  const ArenaGameSpec(this.id, this.label, this.mode);

  bool get usesQuestionCount => mode == ArenaGameMode.questions;
}

/// One source of truth for every game that can be hosted in an Arena.
///
/// Ready question-feed games are discovered from [cats], so adding a new
/// generated game to the app automatically exposes it in Arena filters and
/// hosting. Interactive board games use explicit adapters because each has a
/// different completion and scoring contract.
class ArenaGameCatalog {
  ArenaGameCatalog._();

  static const _special = <ArenaGameSpec>[
    ArenaGameSpec('mixed', 'Mixed Skills', ArenaGameMode.questions),
    ArenaGameSpec('speedmath', 'Speed Maths', ArenaGameMode.questions),
    ArenaGameSpec('sudoku', 'Sudoku', ArenaGameMode.sudoku),
    ArenaGameSpec('art_heist', 'Art Heist', ArenaGameMode.artHeist),
    ArenaGameSpec('crossword', 'Crossword', ArenaGameMode.crossword),
    ArenaGameSpec('chess', 'Chess', ArenaGameMode.chess),
    ArenaGameSpec(
      'number_puzzle',
      'Number Puzzle',
      ArenaGameMode.numberPuzzle,
    ),
  ];

  static List<ArenaGameSpec> get all {
    final discovered =
        cats.where((cat) => cat.ready && !cat.board).map((cat) => ArenaGameSpec(
              cat.id,
              cat.name,
              ArenaGameMode.questions,
            ));
    final byId = <String, ArenaGameSpec>{
      for (final game in _special) game.id: game,
      for (final game in discovered) game.id: game,
    };
    return List.unmodifiable(byId.values);
  }

  static List<String> get ids => List.unmodifiable(all.map((game) => game.id));

  static ArenaGameSpec byId(String id) => all.firstWhere(
        (game) => game.id == id,
        orElse: () => _special.first,
      );

  static bool supports(String id) => all.any((game) => game.id == id);
}
