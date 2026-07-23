import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/models.dart';

/// Lightweight global app state.
class AppState {
  AppState._();
  static final AppState instance = AppState._();

  final ValueNotifier<ThemeMode> themeMode = ValueNotifier(ThemeMode.dark);
  bool online = false;
  SharedPreferences? prefs;
  PlayerProfile profile = PlayerProfile(uid: 'local');

  void persistLocal() {
    prefs?.setString('name', profile.name);
    prefs?.setInt('xp', profile.xp);
    prefs?.setInt('wins', profile.wins);
    prefs?.setInt('streak', profile.streak);
    prefs?.setBool('darkMode', themeMode.value == ThemeMode.dark);
  }

  void restoreLocal() {
    final p = prefs;
    if (p == null) return;
    profile.name = p.getString('name') ?? profile.name;
    if (!online) {
      profile.xp = p.getInt('xp') ?? 0;
      profile.wins = p.getInt('wins') ?? 0;
      profile.streak = p.getInt('streak') ?? 0;
    }
    themeMode.value =
        (p.getBool('darkMode') ?? true) ? ThemeMode.dark : ThemeMode.light;
  }
}
