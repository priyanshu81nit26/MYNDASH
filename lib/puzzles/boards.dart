import 'package:flutter/material.dart';

import 'action_boards.dart';
import 'board_core.dart';
import 'grid_boards.dart';
import 'logic_boards.dart';

export 'board_core.dart';

/// Number of boards that make up one Solve level for board categories.
const boardsPerLevel = 6;

/// Factory: the right gamified dashboard for a board category.
Widget boardFor(String catId, int rating, int seed, BoardDone onDone) {
  switch (catId) {
    case 'sudoku':
      return SudokuBoard(rating: rating, seed: seed, onDone: onDone);
    case 'kenken':
      return KenKenBoard(rating: rating, seed: seed, onDone: onDone);
    case 'kakuro':
      return KakuroBoard(rating: rating, seed: seed, onDone: onDone);
    case 'nonogram':
      return NonogramBoard(rating: rating, seed: seed, onDone: onDone);
    case 'mines':
      return MinesweeperBoard(rating: rating, seed: seed, onDone: onDone);
    case 'sliding':
      return SlidingBoard(rating: rating, seed: seed, onDone: onDone);
    case 'hanoi':
      return HanoiBoard(rating: rating, seed: seed, onDone: onDone);
    case 'memory':
      return MemoryBoard(rating: rating, seed: seed, onDone: onDone);
    case 'setgame':
      return SetBoard(rating: rating, seed: seed, onDone: onDone);
    case 'river':
      return RiverBoard(rating: rating, seed: seed, onDone: onDone);
    case 'logicgrid':
      return LogicGridBoard(rating: rating, seed: seed, onDone: onDone);
    default:
      return SudokuBoard(rating: rating, seed: seed, onDone: onDone);
  }
}
