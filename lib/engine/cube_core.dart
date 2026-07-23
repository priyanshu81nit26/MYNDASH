import 'dart:math';

/// ============================================================
/// RUBIK'S CUBE CORE — exact NxN sticker model (2x2, 3x3, 4x4…).
///
/// Every sticker is stored as (position, outward normal, color).
/// Turning a layer rotates the positions AND normals of all
/// stickers in that slice — mathematically exact for any N.
///
/// Axes: x → right, y → up, z → toward the viewer.
/// Faces: +y U (white) · −y D (yellow) · +z F (green) ·
///        −z B (blue) · +x R (red) · −x L (orange).
/// ============================================================

/// Authentic Rubik's colors, index 0..5.
const cubeColors = [
  0xFFFFFFFF, // 0 U white
  0xFFFFD500, // 1 D yellow
  0xFF009E60, // 2 F green
  0xFF0051BA, // 3 B blue
  0xFFC41E3A, // 4 R red
  0xFFFF5800, // 5 L orange
];

class Sticker {
  int x, y, z; // cell coords 0..n-1
  int nx, ny, nz; // outward unit normal
  final int color;
  Sticker(this.x, this.y, this.z, this.nx, this.ny, this.nz, this.color);

  Sticker clone() => Sticker(x, y, z, nx, ny, nz, color);
}

/// One 90° turn: rotate [layer] of [axis] (0=x,1=y,2=z);
/// [positive] = the mathematically positive direction (see below).
class CubeTurn {
  final int axis, layer;
  final bool positive;
  const CubeTurn(this.axis, this.layer, this.positive);
}

class CubeState {
  final int n;
  final List<Sticker> stickers = [];
  int moveCount = 0;

  CubeState(this.n) {
    for (var a = 0; a < n; a++) {
      for (var b = 0; b < n; b++) {
        stickers.add(Sticker(a, n - 1, b, 0, 1, 0, 0)); // U
        stickers.add(Sticker(a, 0, b, 0, -1, 0, 1)); // D
        stickers.add(Sticker(a, b, n - 1, 0, 0, 1, 2)); // F
        stickers.add(Sticker(a, b, 0, 0, 0, -1, 3)); // B
        stickers.add(Sticker(n - 1, a, b, 1, 0, 0, 4)); // R
        stickers.add(Sticker(0, a, b, -1, 0, 0, 5)); // L
      }
    }
  }

  /// The two axes perpendicular to [axis], in cyclic order.
  /// axis 0(x) → (y,z) · axis 1(y) → (z,x) · axis 2(z) → (x,y)
  static (int, int) tangents(int axis) => switch (axis) {
        0 => (1, 2),
        1 => (2, 0),
        _ => (0, 1),
      };

  int _get(Sticker s, int axis) => axis == 0 ? s.x : (axis == 1 ? s.y : s.z);
  void _set(Sticker s, int axis, int v) {
    if (axis == 0) {
      s.x = v;
    } else if (axis == 1) {
      s.y = v;
    } else {
      s.z = v;
    }
  }

  int _getN(Sticker s, int axis) =>
      axis == 0 ? s.nx : (axis == 1 ? s.ny : s.nz);
  void _setN(Sticker s, int axis, int v) {
    if (axis == 0) {
      s.nx = v;
    } else if (axis == 1) {
      s.ny = v;
    } else {
      s.nz = v;
    }
  }

  /// One positive 90° rotation of a layer:
  /// in the (b,c) tangent plane, (b,c) → (−c, b) around the center.
  void _rotOnce(int axis, int layer) {
    final (bA, cA) = tangents(axis);
    for (final s in stickers) {
      if (_get(s, axis) != layer) continue;
      final b = _get(s, bA), c = _get(s, cA);
      _set(s, bA, n - 1 - c);
      _set(s, cA, b);
      final nb = _getN(s, bA), nc = _getN(s, cA);
      _setN(s, bA, -nc);
      _setN(s, cA, nb);
    }
  }

  void turn(CubeTurn t) {
    final times = t.positive ? 1 : 3;
    for (var i = 0; i < times; i++) {
      _rotOnce(t.axis, t.layer);
    }
    moveCount++;
  }

  bool get solved {
    final byFace = <int, int>{}; // normal key → color
    for (final s in stickers) {
      final key = (s.nx + 1) * 100 + (s.ny + 1) * 10 + (s.nz + 1);
      final seen = byFace[key];
      if (seen == null) {
        byFace[key] = s.color;
      } else if (seen != s.color) {
        return false;
      }
    }
    return true;
  }

  /// Scrambles with random layer turns (seeded → same for a race).
  List<CubeTurn> scramble(Random rng, [int? moves]) {
    final k = moves ?? n * 12;
    final applied = <CubeTurn>[];
    for (var i = 0; i < k; i++) {
      final t = CubeTurn(rng.nextInt(3), rng.nextInt(n), rng.nextBool());
      turn(t);
      applied.add(t);
    }
    moveCount = 0;
    return applied;
  }
}
