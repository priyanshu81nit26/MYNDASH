import 'dart:convert';

import 'package:flutter/material.dart';

/// Deterministic, asset-free default avatar: a seeded gradient disc with the
/// user's monogram. Every new account gets a distinct look for free — shown
/// wherever the user hasn't set a photo.
class DefaultAvatar extends StatelessWidget {
  final String name;
  final double size;
  const DefaultAvatar({super.key, required this.name, this.size = 46});

  static const _palettes = [
    [Color(0xFF7C4DFF), Color(0xFF00E5FF)],
    [Color(0xFFFF2E92), Color(0xFF7C4DFF)],
    [Color(0xFF00E5FF), Color(0xFF69F0AE)],
    [Color(0xFFFFC400), Color(0xFFFF2E92)],
    [Color(0xFF69F0AE), Color(0xFF0097C7)],
    [Color(0xFF2E7BFF), Color(0xFF7C4DFF)],
  ];

  @override
  Widget build(BuildContext context) {
    final key = name.isEmpty ? 'MYNDASH' : name;
    final pal = _palettes[key.hashCode.abs() % _palettes.length];
    final letter = name.isEmpty ? 'M' : name[0].toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight, colors: pal),
      ),
      child: Text(letter,
          style: TextStyle(
              fontSize: size * 0.44,
              fontWeight: FontWeight.w900,
              color: Colors.white)),
    );
  }
}

/// The one place that renders a user's photo. Backed by base64 bytes (not a
/// file path) so it works identically on web, Android and iOS — falls back
/// to [DefaultAvatar] when there's no photo, or if the bytes fail to decode.
class ProfileAvatar extends StatelessWidget {
  final String avatarB64;
  final String name;
  final double size;
  final BoxFit fit;
  const ProfileAvatar({
    super.key,
    required this.avatarB64,
    required this.name,
    this.size = 46,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    if (avatarB64.isEmpty) return DefaultAvatar(name: name, size: size);
    try {
      return ClipOval(
        child: Image.memory(
          base64Decode(avatarB64),
          width: size,
          height: size,
          fit: fit,
          errorBuilder: (_, __, ___) => DefaultAvatar(name: name, size: size),
        ),
      );
    } catch (_) {
      return DefaultAvatar(name: name, size: size);
    }
  }
}
