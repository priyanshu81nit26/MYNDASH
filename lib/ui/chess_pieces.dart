import 'package:flutter/material.dart';

/// Vector chess pieces — drawn as solid silhouettes so a piece is ALWAYS
/// pure white or pitch black regardless of the device font. (System chess
/// glyphs get emoji-substituted on many Androids, which ignores color;
/// this renderer sidesteps that entirely.)
///
/// [type]: 1=pawn 2=knight 3=bishop 4=rook 5=queen 6=king. [white] picks
/// the fill. Both colors use the SAME silhouette — only the fill differs.
class ChessPieceGlyph extends StatelessWidget {
  final int type; // 1..6
  final bool white;
  final double size;
  const ChessPieceGlyph(
      {super.key, required this.type, required this.white, required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _PiecePainter(type, white)),
    );
  }
}

class _PiecePainter extends CustomPainter {
  final int type;
  final bool white;
  _PiecePainter(this.type, this.white);

  @override
  void paint(Canvas canvas, Size size) {
    // Work in a 100×100 box, scale to the cell.
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);

    final path = _pathFor(type);
    // Soft grounding shadow.
    canvas.drawPath(
        path,
        Paint()
          ..color = Colors.black.withOpacity(white ? 0.35 : 0.55)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.2)
          ..style = PaintingStyle.fill);
    // Solid fill: pure white or pitch black.
    canvas.drawPath(
        path,
        Paint()
          ..color = white ? Colors.white : Colors.black
          ..style = PaintingStyle.fill);
    // Thin contrast outline so the piece reads on any square color.
    canvas.drawPath(
        path,
        Paint()
          ..color = white ? const Color(0xFF3A3A3A) : const Color(0xFFB9C2CC)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeJoin = StrokeJoin.round);
    canvas.restore();
  }

  // ---- silhouettes in a 100×100 box, base sitting near y=92 ----

  Path _pathFor(int t) {
    switch (t) {
      case 1:
        return _pawn();
      case 2:
        return _knight();
      case 3:
        return _bishop();
      case 4:
        return _rook();
      case 5:
        return _queen();
      default:
        return _king();
    }
  }

  Path _base() => Path()
    ..moveTo(26, 92)
    ..lineTo(74, 92)
    ..lineTo(69, 82)
    ..lineTo(31, 82)
    ..close();

  Path _pawn() {
    final p = _base();
    p.addOval(Rect.fromCircle(center: const Offset(50, 30), radius: 13));
    p.moveTo(41, 44);
    p.cubicTo(41, 58, 36, 66, 34, 82);
    p.lineTo(66, 82);
    p.cubicTo(64, 66, 59, 58, 59, 44);
    p.close();
    return p;
  }

  Path _rook() {
    final p = _base();
    // tower body
    p.moveTo(37, 82);
    p.lineTo(63, 82);
    p.lineTo(60, 42);
    p.lineTo(40, 42);
    p.close();
    // top band
    p.addRect(const Rect.fromLTRB(33, 30, 67, 42));
    // crenellations
    p.addRect(const Rect.fromLTRB(33, 20, 42, 32));
    p.addRect(const Rect.fromLTRB(45, 20, 55, 32));
    p.addRect(const Rect.fromLTRB(58, 20, 67, 32));
    return p;
  }

  Path _bishop() {
    final p = _base();
    // body
    p.moveTo(40, 82);
    p.cubicTo(38, 66, 44, 58, 44, 50);
    p.lineTo(56, 50);
    p.cubicTo(56, 58, 62, 66, 60, 82);
    p.close();
    // collar
    p.addRRect(RRect.fromRectAndRadius(
        const Rect.fromLTRB(42, 48, 58, 54), const Radius.circular(3)));
    // mitre head (teardrop)
    p.moveTo(50, 16);
    p.cubicTo(60, 26, 62, 40, 50, 46);
    p.cubicTo(38, 40, 40, 26, 50, 16);
    p.close();
    // finial ball
    p.addOval(Rect.fromCircle(center: const Offset(50, 14), radius: 4));
    return p;
  }

  Path _knight() {
    // Horse head facing left, on a base.
    final p = _base();
    p.moveTo(38, 82);
    p.lineTo(34, 60);
    p.cubicTo(30, 50, 34, 40, 44, 34); // back of neck up to ears
    p.lineTo(40, 24); // ear notch
    p.lineTo(48, 26);
    p.cubicTo(52, 18, 60, 20, 64, 30); // top of head
    p.cubicTo(72, 40, 74, 46, 70, 52); // forehead to muzzle
    p.lineTo(60, 50); // nostril dip
    p.lineTo(56, 58); // mouth
    p.cubicTo(52, 60, 50, 60, 46, 58); // jaw
    p.cubicTo(50, 66, 56, 72, 62, 82); // front of neck down
    p.close();
    return p;
  }

  Path _queen() {
    final p = _base();
    // bell body
    p.moveTo(36, 82);
    p.cubicTo(32, 64, 40, 54, 40, 46);
    p.lineTo(60, 46);
    p.cubicTo(60, 54, 68, 64, 64, 82);
    p.close();
    // crown collar
    p.addRRect(RRect.fromRectAndRadius(
        const Rect.fromLTRB(38, 42, 62, 48), const Radius.circular(2)));
    // 5-point crown (zigzag)
    p.moveTo(38, 44);
    p.lineTo(33, 24);
    p.lineTo(42, 36);
    p.lineTo(50, 22);
    p.lineTo(58, 36);
    p.lineTo(67, 24);
    p.lineTo(62, 44);
    p.close();
    // crown-tip balls
    for (final x in [33.0, 50.0, 67.0]) {
      p.addOval(Rect.fromCircle(center: Offset(x, 22), radius: 4));
    }
    return p;
  }

  Path _king() {
    final p = _base();
    // bell body
    p.moveTo(36, 82);
    p.cubicTo(32, 64, 40, 54, 40, 48);
    p.lineTo(60, 48);
    p.cubicTo(60, 54, 68, 64, 64, 82);
    p.close();
    // crown collar
    p.addRRect(RRect.fromRectAndRadius(
        const Rect.fromLTRB(38, 44, 62, 50), const Radius.circular(2)));
    // crown mound
    p.moveTo(40, 46);
    p.cubicTo(40, 34, 60, 34, 60, 46);
    p.close();
    // cross
    p.addRect(const Rect.fromLTRB(46, 12, 54, 40));
    p.addRect(const Rect.fromLTRB(38, 20, 62, 28));
    return p;
  }

  @override
  bool shouldRepaint(covariant _PiecePainter old) =>
      old.type != type || old.white != white;
}
