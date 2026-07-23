import 'dart:async';

import 'package:flutter/services.dart';

/// ============================================================
/// FX — haptics + system sounds, one line anywhere.
/// No audio packages: uses platform haptic motors and the
/// system click/alert sounds, which feel native and cost 0 KB.
/// ============================================================
class Fx {
  Fx._();

  /// Master switch (could be exposed in settings later).
  static bool enabled = true;

  /// Light tick — every button/card tap. Wired automatically into
  /// Glass / NeonButton / GhostButton / Pill, so the whole app clicks.
  static void tap() {
    if (!enabled) return;
    HapticFeedback.selectionClick();
    SystemSound.play(SystemSoundType.click);
  }

  /// Soft bump — selections, toggles, keypad keys.
  static void light() {
    if (!enabled) return;
    HapticFeedback.lightImpact();
  }

  /// Correct answer / good dart / captured piece.
  static void success() {
    if (!enabled) return;
    HapticFeedback.mediumImpact();
    SystemSound.play(SystemSoundType.click);
  }

  /// Wrong answer / blocked dart / lost piece.
  static void fail() {
    if (!enabled) return;
    HapticFeedback.heavyImpact();
  }

  /// Invalid action / rejected input — a short double error buzz.
  static void error() {
    if (!enabled) return;
    HapticFeedback.heavyImpact();
    SystemSound.play(SystemSoundType.alert);
  }

  /// A dart leaves the hand / a chess piece lands.
  static void impact() {
    if (!enabled) return;
    HapticFeedback.mediumImpact();
  }

  /// Victory celebration — triple rising buzz.
  static Future<void> win() async {
    if (!enabled) return;
    HapticFeedback.mediumImpact();
    SystemSound.play(SystemSoundType.click);
    await Future<void>.delayed(const Duration(milliseconds: 120));
    HapticFeedback.heavyImpact();
    await Future<void>.delayed(const Duration(milliseconds: 120));
    HapticFeedback.heavyImpact();
    SystemSound.play(SystemSoundType.click);
  }

  /// Defeat — one long low thud.
  static Future<void> lose() async {
    if (!enabled) return;
    HapticFeedback.heavyImpact();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    HapticFeedback.lightImpact();
  }

  /// Level-up / unlock — quick ascending taps.
  static Future<void> unlock() async {
    if (!enabled) return;
    for (var i = 0; i < 3; i++) {
      HapticFeedback.lightImpact();
      await Future<void>.delayed(const Duration(milliseconds: 70));
    }
    HapticFeedback.mediumImpact();
  }
}
