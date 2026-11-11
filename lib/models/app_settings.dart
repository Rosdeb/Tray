import 'package:flutter/material.dart';

class AppSettings {
  const AppSettings({
    this.sdkPath,
    this.scrcpyPath,
    this.themeMode = ThemeMode.system,
    this.startWithWindows = false,
    this.notificationsEnabled = true,
    this.minimizeToTray = true,
    this.refreshIntervalSeconds = 5,
    this.favoriteEmulators = const <String>{},
    this.lastLaunchByName = const <String, DateTime>{},
  });

  final String? sdkPath;
  final String? scrcpyPath;
  final ThemeMode themeMode;
  final bool startWithWindows;
  final bool notificationsEnabled;
  final bool minimizeToTray;
  final int refreshIntervalSeconds;
  final Set<String> favoriteEmulators;
  final Map<String, DateTime> lastLaunchByName;

  AppSettings copyWith({
    String? sdkPath,
    bool clearSdkPath = false,
    String? scrcpyPath,
    bool clearScrcpyPath = false,
    ThemeMode? themeMode,
    bool? startWithWindows,
    bool? notificationsEnabled,
    bool? minimizeToTray,
    int? refreshIntervalSeconds,
    Set<String>? favoriteEmulators,
    Map<String, DateTime>? lastLaunchByName,
  }) {
    return AppSettings(
      sdkPath: clearSdkPath ? null : sdkPath ?? this.sdkPath,
      scrcpyPath: clearScrcpyPath ? null : scrcpyPath ?? this.scrcpyPath,
      themeMode: themeMode ?? this.themeMode,
      startWithWindows: startWithWindows ?? this.startWithWindows,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      minimizeToTray: minimizeToTray ?? this.minimizeToTray,
      refreshIntervalSeconds:
          refreshIntervalSeconds ?? this.refreshIntervalSeconds,
      favoriteEmulators: favoriteEmulators ?? this.favoriteEmulators,
      lastLaunchByName: lastLaunchByName ?? this.lastLaunchByName,
    );
  }
}
