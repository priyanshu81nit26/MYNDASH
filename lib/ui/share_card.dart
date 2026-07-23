import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Canonical MYNDASH share link — every share points here so WhatsApp /
/// Instagram render a rich preview (logo + name) from the site's Open Graph
/// tags (see web/index.html).
const String kMyndashUrl = 'https://myndash.online';

/// Wraps any share body in the one common MYNDASH sign-off + link, so every
/// share across the app reads as one branded style — only the top line
/// (the game / result / invite) changes.
String myndashShare(String body) {
  final b = body.trim();
  const footer = '🧠 Play MYNDASH free → $kMyndashUrl';
  return b.isEmpty ? footer : '$b\n\n$footer';
}

/// Renders the widget under [key]'s RepaintBoundary to a crisp PNG and
/// opens the system share sheet — from there one tap posts it to an
/// Instagram story or a WhatsApp status. Used by the wrap-up cards and
/// the private-arena invite card.
Future<void> shareCardImage(
  BuildContext context,
  GlobalKey key, {
  String text = '',
  String filename = 'mynd_card',
}) async {
  final shareText = myndashShare(text);
  try {
    final boundary =
        key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) throw Exception('no boundary');
    final image = await boundary.toImage(pixelRatio: 3);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) throw Exception('encode failed');
    final bytes = data.buffer.asUint8List();
    if (kIsWeb) {
      await Share.shareXFiles(
          [XFile.fromData(bytes, mimeType: 'image/png', name: '$filename.png')],
          text: shareText);
      return;
    }
    final dir = await getTemporaryDirectory();
    final file = File(
        '${dir.path}/${filename}_${DateTime.now().millisecondsSinceEpoch}.png');
    await file.writeAsBytes(bytes);
    await Share.shareXFiles([XFile(file.path)], text: shareText);
  } catch (_) {
    // graceful fallback: at least put the text on the clipboard
    await Clipboard.setData(ClipboardData(text: shareText));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Could not render the image — invite text copied instead.')));
    }
  }
}
