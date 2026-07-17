import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/android_sdk.dart';
import '../models/app_settings.dart';
import '../models/dashboard_statistics.dart';
import '../models/emulator.dart';
import '../repositories/emulator_repository.dart';
import '../services/adb_service.dart';
import '../services/android_sdk_detection_service.dart';
import '../services/app_logger.dart';
import '../services/emulator_service.dart';
import '../services/notification_service.dart';
import '../services/settings_service.dart';
import '../services/startup_service.dart';
import '../services/tray_service.dart';
import '../services/update_service.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('SharedPreferences must be overridden.'),
);

final Set<String> _launching = {};

bool isLaunching(String name) => _launching.contains(name);

final appLoggerProvider = Provider<AppLogger>((ref) => AppLogger());
final settingsServiceProvider = Provider<SettingsService>(
  (ref) => SettingsService(ref.watch(sharedPreferencesProvider)),
);
final adbServiceProvider = Provider<AdbService>((ref) => AdbService());
final emulatorServiceProvider = Provider<EmulatorService>(
  (ref) => EmulatorService(ref.watch(adbServiceProvider)),
);
final sdkDetectionServiceProvider = Provider<AndroidSdkDetectionService>(
  (ref) => AndroidSdkDetectionService(),
);
final startupServiceProvider = Provider<StartupService>(
  (ref) => StartupService(),
);
final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(),
);
final trayServiceProvider = Provider<AppTrayService>((ref) => AppTrayService());

final emulatorRepositoryProvider = Provider<EmulatorRepository>(
  (ref) => EmulatorRepository(
    sdkDetectionService: ref.watch(sdkDetectionServiceProvider),
    emulatorService: ref.watch(emulatorServiceProvider),
  ),
);

final settingsControllerProvider =
    NotifierProvider<SettingsController, AppSettings>(SettingsController.new);

class SettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.watch(settingsServiceProvider).load();

  Future<void> update(AppSettings settings) async {
    state = settings;
    await ref.read(settingsServiceProvider).save(settings);
  }

  Future<void> setSdkPath(String? path) =>
      update(state.copyWith(sdkPath: path, clearSdkPath: path == null));

  Future<void> setThemeMode(ThemeMode mode) =>
      update(state.copyWith(themeMode: mode));

  Future<void> setRefreshInterval(int seconds) {
    return update(state.copyWith(refreshIntervalSeconds: seconds.clamp(3, 60)));
  }

  Future<void> setStartWithWindows(bool enabled) async {
    await ref.read(startupServiceProvider).setEnabled(enabled);
    await update(state.copyWith(startWithWindows: enabled));
  }

  Future<void> toggleFavorite(String name) {
    final favorites = {...state.favoriteEmulators};
    if (!favorites.add(name)) {
      favorites.remove(name);
    }
    return update(state.copyWith(favoriteEmulators: favorites));
  }

  Future<void> markLaunched(String name) {
    final launches = {...state.lastLaunchByName, name: DateTime.now()};
    return update(state.copyWith(lastLaunchByName: launches));
  }
}

final updateServiceProvider = Provider((ref) => UpdateService());

final updateCheckProvider = FutureProvider<UpdateInfo?>((ref) async {
  final service = ref.read(updateServiceProvider);
  return service.checkForUpdate();
});

final emulatorControllerProvider =
    AsyncNotifierProvider<EmulatorController, EmulatorState>(
      EmulatorController.new,
    );

class EmulatorState {
  const EmulatorState({
    required this.sdk,
    required this.emulators,
    this.message,
    this.launching = const {},
    this.stopping = const {},
  });

  final AndroidSdk? sdk;
  final List<Emulator> emulators;
  final String? message;

  /// emulator names currently launching
  final Set<String> launching;

  /// emulator names currently stopping
  final Set<String> stopping;

  DashboardStatistics get statistics =>
      DashboardStatistics.fromEmulators(emulators);

  EmulatorState copyWith({
    AndroidSdk? sdk,
    List<Emulator>? emulators,
    String? message,
    Set<String>? launching,
    Set<String>? stopping,
  }) {
    return EmulatorState(
      sdk: sdk ?? this.sdk,
      emulators: emulators ?? this.emulators,
      message: message ?? this.message,
      launching: launching ?? this.launching,
      stopping: stopping ?? this.stopping,
    );
  }
}

class EmulatorController extends AsyncNotifier<EmulatorState> {
  Timer? _timer;

  @override
  Future<EmulatorState> build() async {
    ref.onDispose(() => _timer?.cancel());
    final settings = ref.watch(settingsControllerProvider);
    _timer?.cancel();
    _timer = Timer.periodic(
      Duration(seconds: settings.refreshIntervalSeconds),
      (_) => refreshSilently(),
    );
    return _load(settings);
  }

  Future<EmulatorState> _load(AppSettings settings) async {
    final repository = ref.read(emulatorRepositoryProvider);
    final sdk = await repository.detectSdk(settings);
    if (sdk == null) {
      return const EmulatorState(
        sdk: null,
        emulators: <Emulator>[],
        message:
            'Android SDK was not found. Select the SDK folder in Settings.',
      );
    }
    final emulators = await repository.listEmulators(
      sdk: sdk,
      settings: settings,
    );
    final message = emulators.isEmpty
        ? 'No Android Virtual Devices were found.'
        : null;
    return EmulatorState(sdk: sdk, emulators: emulators, message: message);
  }

  Future<void> refresh() async {
    state = const AsyncLoading<EmulatorState>();
    state = await AsyncValue.guard(
      () => _load(ref.read(settingsControllerProvider)),
    );
  }

  Future<void> refreshSilently() async {
    if (state.isLoading) {
      return;
    }
    state = await AsyncValue.guard(
      () => _load(ref.read(settingsControllerProvider)),
    );
  }

  Future<void> launch(Emulator emulator, {bool coldBoot = false}) async {
    final current = state.value;
    if (current == null) return;

    if (current.launching.contains(emulator.name)) {
      return;
    }

    state = AsyncData(
      current.copyWith(
        launching: {...current.launching, emulator.name},
      ),
    );

    try {
      final sdk = current.sdk;
      if (sdk == null) return;

      await ref.read(emulatorRepositoryProvider).launch(
        sdk,
        emulator,
        coldBoot: coldBoot,
      );

      await ref.read(settingsControllerProvider.notifier)
          .markLaunched(emulator.name);

      await ref.read(notificationServiceProvider)
          .show('Emulator started', emulator.name);

      await refreshSilently();
    } finally {
      final latest = state.value;
      if (latest != null) {
        final launching = {...latest.launching};
        launching.remove(emulator.name);

        state = AsyncData(
          latest.copyWith(launching: launching),
        );
      }
    }
  }
  
  Future<void> stop(Emulator emulator) async {
    final current = state.value;
    final sdk = current?.sdk;
    if (sdk == null) {
      return;
    }
    await ref.read(emulatorRepositoryProvider).stop(sdk, emulator);
    await ref
        .read(notificationServiceProvider)
        .show('Emulator stopped', emulator.name);
    await refreshSilently();
  }
}
