import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tray/models/app_settings.dart';
import 'package:tray/services/settings_service.dart';

void main() {
  test('settings service persists user preferences', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final preferences = await SharedPreferences.getInstance();
    final service = SettingsService(preferences);

    await service.save(
      AppSettings(
        sdkPath: r'C:\Android\Sdk',
        scrcpyPath: r'C:\scrcpy\scrcpy.exe',
        themeMode: ThemeMode.dark,
        startWithWindows: true,
        favoriteEmulators: const <String>{'Pixel_8'},
        lastLaunchByName: <String, DateTime>{'Pixel_8': DateTime(2026, 1, 2, 3, 4)},
      ),
    );

    final loaded = service.load();

    expect(loaded.sdkPath, r'C:\Android\Sdk');
    expect(loaded.scrcpyPath, r'C:\scrcpy\scrcpy.exe');
    expect(loaded.themeMode, ThemeMode.dark);
    expect(loaded.startWithWindows, isTrue);
    expect(loaded.favoriteEmulators, contains('Pixel_8'));
    expect(loaded.lastLaunchByName['Pixel_8'], DateTime(2026, 1, 2, 3, 4));
  });
}
