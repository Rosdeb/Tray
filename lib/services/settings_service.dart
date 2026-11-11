import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';

class SettingsService {
  SettingsService(this._preferences);

  static const _sdkPathKey = 'sdkPath';
  static const _scrcpyPathKey = 'scrcpyPath';
  static const _themeModeKey = 'themeMode';
  static const _startupKey = 'startWithWindows';
  static const _notificationsKey = 'notificationsEnabled';
  static const _minimizeToTrayKey = 'minimizeToTray';
  static const _refreshIntervalKey = 'refreshIntervalSeconds';
  static const _favoritesKey = 'favoriteEmulators';
  static const _lastLaunchPrefix = 'lastLaunch.';

  final SharedPreferences _preferences;

  AppSettings load() {
    final favorites = _preferences.getStringList(_favoritesKey)?.toSet() ?? <String>{};
    final lastLaunchByName = <String, DateTime>{};
    for (final key in _preferences.getKeys()) {
      if (!key.startsWith(_lastLaunchPrefix)) {
        continue;
      }
      final value = _preferences.getString(key);
      final parsed = value == null ? null : DateTime.tryParse(value);
      if (parsed != null) {
        lastLaunchByName[key.substring(_lastLaunchPrefix.length)] = parsed;
      }
    }

    return AppSettings(
      sdkPath: _preferences.getString(_sdkPathKey),
      scrcpyPath: _preferences.getString(_scrcpyPathKey),
      themeMode: _themeModeFromName(_preferences.getString(_themeModeKey)),
      startWithWindows: _preferences.getBool(_startupKey) ?? false,
      notificationsEnabled: _preferences.getBool(_notificationsKey) ?? true,
      minimizeToTray: _preferences.getBool(_minimizeToTrayKey) ?? true,
      refreshIntervalSeconds: _preferences.getInt(_refreshIntervalKey) ?? 5,
      favoriteEmulators: favorites,
      lastLaunchByName: lastLaunchByName,
    );
  }

  Future<void> save(AppSettings settings) async {
    final sdkPath = settings.sdkPath;
    if (sdkPath == null || sdkPath.trim().isEmpty) {
      await _preferences.remove(_sdkPathKey);
    } else {
      await _preferences.setString(_sdkPathKey, sdkPath);
    }

    final scrcpyPath = settings.scrcpyPath;
    if (scrcpyPath == null || scrcpyPath.trim().isEmpty) {
      await _preferences.remove(_scrcpyPathKey);
    } else {
      await _preferences.setString(_scrcpyPathKey, scrcpyPath);
    }
    await _preferences.setString(_themeModeKey, settings.themeMode.name);
    await _preferences.setBool(_startupKey, settings.startWithWindows);
    await _preferences.setBool(_notificationsKey, settings.notificationsEnabled);
    await _preferences.setBool(_minimizeToTrayKey, settings.minimizeToTray);
    await _preferences.setInt(_refreshIntervalKey, settings.refreshIntervalSeconds);
    await _preferences.setStringList(_favoritesKey, settings.favoriteEmulators.toList()..sort());

    for (final key in _preferences.getKeys().where((key) => key.startsWith(_lastLaunchPrefix))) {
      await _preferences.remove(key);
    }
    for (final entry in settings.lastLaunchByName.entries) {
      await _preferences.setString('$_lastLaunchPrefix${entry.key}', entry.value.toIso8601String());
    }
  }

  static ThemeMode _themeModeFromName(String? name) {
    return ThemeMode.values.firstWhere(
      (mode) => mode.name == name,
      orElse: () => ThemeMode.system,
    );
  }
}
