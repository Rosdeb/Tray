import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/android_sdk.dart';
import '../models/app_settings.dart';
import '../models/dashboard_statistics.dart';
import '../models/device_metrics.dart';
import '../models/emulator.dart';
import '../models/hardware_acceleration.dart';
import '../models/system_process.dart';
import '../repositories/emulator_repository.dart';
import '../services/adb_service.dart';
import '../services/android_sdk_detection_service.dart';
import '../services/app_logger.dart';
import '../services/device_monitor_service.dart';
import '../services/emulator_service.dart';
import '../services/notification_service.dart';
import '../services/process_manager_service.dart';
import '../services/scrcpy_service.dart';
import '../services/sdk_installer_service.dart';
import '../services/settings_service.dart';
import '../services/startup_service.dart';
import '../services/system_environment_service.dart';
import '../services/tray_service.dart';
import '../services/update_service.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('SharedPreferences must be overridden.'),
);

final appLoggerProvider = Provider<AppLogger>((ref) => AppLogger());

final settingsServiceProvider = Provider<SettingsService>(
  (ref) => SettingsService(ref.watch(sharedPreferencesProvider)),
);

final adbServiceProvider = Provider<AdbService>((ref) => AdbService());

final emulatorServiceProvider = Provider<EmulatorService>(
  (ref) => EmulatorService(ref.watch(adbServiceProvider)),
);

final systemEnvironmentServiceProvider = Provider<SystemEnvironmentService>(
  (ref) => SystemEnvironmentService(),
);

final scrcpyServiceProvider = Provider<ScrcpyService>(
  (ref) => ScrcpyService(ref.watch(systemEnvironmentServiceProvider)),
);

final processManagerServiceProvider = Provider<ProcessManagerService>(
  (ref) => ProcessManagerService(),
);

final deviceMonitorServiceProvider = Provider<DeviceMonitorService>(
  (ref) => DeviceMonitorService(ref.watch(adbServiceProvider)),
);

final sdkInstallerServiceProvider = Provider<SdkInstallerService>(
  (ref) => SdkInstallerService(ref.watch(systemEnvironmentServiceProvider)),
);

final sdkDetectionServiceProvider = Provider<AndroidSdkDetectionService>(
  (ref) => AndroidSdkDetectionService(ref.watch(systemEnvironmentServiceProvider)),
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
    sdkInstallerService: ref.watch(sdkInstallerServiceProvider),
    systemEnvironmentService: ref.watch(systemEnvironmentServiceProvider),
    scrcpyService: ref.watch(scrcpyServiceProvider),
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

  Future<void> setScrcpyPath(String? path) =>
      update(state.copyWith(scrcpyPath: path, clearScrcpyPath: path == null));

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

final hardwareAccelerationProvider = FutureProvider<HardwareAccelerationInfo>((ref) async {
  final repo = ref.watch(emulatorRepositoryProvider);
  final emuState = ref.watch(emulatorControllerProvider).value;
  return repo.checkHardwareAcceleration(emuState?.sdk);
});

class ScrcpyInfo {
  const ScrcpyInfo({
    required this.isAvailable,
    this.path,
    this.version,
    this.isCustom = false,
  });

  final bool isAvailable;
  final String? path;
  final String? version;
  final bool isCustom;
}

final scrcpyInfoProvider = FutureProvider<ScrcpyInfo>((ref) async {
  final settings = ref.watch(settingsControllerProvider);
  final emuState = ref.watch(emulatorControllerProvider).value;
  final scrcpyService = ref.watch(scrcpyServiceProvider);

  final path = await scrcpyService.findExecutable(
    customPath: settings.scrcpyPath,
    sdkPath: emuState?.sdk?.path,
  );

  if (path == null) {
    return const ScrcpyInfo(isAvailable: false);
  }

  final version = await scrcpyService.getVersion(
    customPath: settings.scrcpyPath,
    sdkPath: emuState?.sdk?.path,
  );

  return ScrcpyInfo(
    isAvailable: true,
    path: path,
    version: version,
    isCustom: settings.scrcpyPath != null && settings.scrcpyPath!.trim().isNotEmpty,
  );
});

final scrcpyAvailableProvider = FutureProvider<bool>((ref) async {
  final info = await ref.watch(scrcpyInfoProvider.future);
  return info.isAvailable;
});

class EmulatorState {
  const EmulatorState({
    required this.sdk,
    required this.emulators,
    this.message,
    this.launching = const {},
    this.booting = const {},
    this.stopping = const {},
    this.hardwareAccelInfo,
    this.assignedPorts = const {},
  });

  final AndroidSdk? sdk;
  final List<Emulator> emulators;
  final String? message;

  /// emulator names currently launching
  final Set<String> launching;

  /// emulator names currently booting (waiting for sys.boot_completed)
  final Set<String> booting;

  /// emulator names currently stopping
  final Set<String> stopping;

  /// Hardware acceleration diagnostic info
  final HardwareAccelerationInfo? hardwareAccelInfo;

  /// Port assigned per emulator name
  final Map<String, int> assignedPorts;

  DashboardStatistics get statistics =>
      DashboardStatistics.fromEmulators(emulators);

  EmulatorState copyWith({
    AndroidSdk? sdk,
    List<Emulator>? emulators,
    String? message,
    Set<String>? launching,
    Set<String>? booting,
    Set<String>? stopping,
    HardwareAccelerationInfo? hardwareAccelInfo,
    Map<String, int>? assignedPorts,
  }) {
    return EmulatorState(
      sdk: sdk ?? this.sdk,
      emulators: emulators ?? this.emulators,
      message: message ?? this.message,
      launching: launching ?? this.launching,
      booting: booting ?? this.booting,
      stopping: stopping ?? this.stopping,
      hardwareAccelInfo: hardwareAccelInfo ?? this.hardwareAccelInfo,
      assignedPorts: assignedPorts ?? this.assignedPorts,
    );
  }
}

final emulatorControllerProvider =
    AsyncNotifierProvider<EmulatorController, EmulatorState>(
      EmulatorController.new,
    );

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
        message: 'No Android SDK configured. Set up a standalone environment below without Android Studio.',
      );
    }

    final emulators = await repository.listEmulators(
      sdk: sdk,
      settings: settings,
    );

    // Apply booting status to emulators that are still waiting for boot completion
    final currentBooting = state.value?.booting ?? const <String>{};
    final updatedEmulators = emulators.map((e) {
      if (currentBooting.contains(e.name) && e.status == EmulatorStatus.offline) {
        return e.copyWith(status: EmulatorStatus.booting);
      }
      return e;
    }).toList(growable: false);

    final accelInfo = await repository.checkHardwareAcceleration(sdk);

    final message = updatedEmulators.isEmpty
        ? 'No Android Virtual Devices found. Click "+ Create Device" to create your first virtual device!'
        : null;

    return EmulatorState(
      sdk: sdk,
      emulators: updatedEmulators,
      message: message,
      booting: currentBooting,
      hardwareAccelInfo: accelInfo,
    );
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

  /// Launch an emulator and monitor sys.boot_completed
  Future<void> launch(Emulator emulator, {bool coldBoot = false, int? port}) async {
    final current = state.value;
    if (current == null) return;

    if (current.launching.contains(emulator.name) || current.booting.contains(emulator.name)) {
      return;
    }

    state = AsyncData(
      current.copyWith(
        launching: {...current.launching, emulator.name},
        booting: {...current.booting, emulator.name},
      ),
    );

    try {
      final sdk = current.sdk;
      if (sdk == null) return;

      final assignedPort = await ref.read(emulatorRepositoryProvider).launch(
        sdk,
        emulator,
        coldBoot: coldBoot,
        port: port,
      );

      final ports = {...current.assignedPorts};
      if (assignedPort != null) {
        ports[emulator.name] = assignedPort;
      }

      await ref.read(settingsControllerProvider.notifier)
          .markLaunched(emulator.name);

      await ref.read(notificationServiceProvider)
          .show('Emulator starting...', '${emulator.name} is booting (port ${assignedPort ?? 5554})');

      state = AsyncData(
        state.value?.copyWith(
          assignedPorts: ports,
        ) ?? current,
      );

      // Background task to track sys.boot_completed
      _trackBootCompleted(sdk, emulator);

      await refreshSilently();
    } finally {
      final latest = state.value;
      if (latest != null) {
        final launching = {...latest.launching};
        launching.remove(emulator.name);
        state = AsyncData(latest.copyWith(launching: launching));
      }
    }
  }

  void _trackBootCompleted(AndroidSdk sdk, Emulator emulator) async {
    try {
      final booted = await ref.read(emulatorRepositoryProvider).waitForBoot(sdk, emulator);
      if (booted) {
        await ref.read(notificationServiceProvider).show(
          'Emulator Ready',
          '${emulator.name} finished booting and is ready for use.',
        );
      }
    } catch (_) {
    } finally {
      final latest = state.value;
      if (latest != null) {
        final booting = {...latest.booting};
        booting.remove(emulator.name);
        state = AsyncData(latest.copyWith(booting: booting));
        await refreshSilently();
      }
    }
  }

  Future<void> stop(Emulator emulator) async {
    final current = state.value;
    final sdk = current?.sdk;
    if (sdk == null) return;

    state = AsyncData(
      current!.copyWith(
        stopping: {...current.stopping, emulator.name},
      ),
    );

    try {
      await ref.read(emulatorRepositoryProvider).stop(sdk, emulator);
      await ref.read(notificationServiceProvider).show('Emulator stopped', emulator.name);
    } finally {
      final latest = state.value;
      if (latest != null) {
        final stopping = {...latest.stopping};
        stopping.remove(emulator.name);
        final booting = {...latest.booting};
        booting.remove(emulator.name);
        state = AsyncData(latest.copyWith(stopping: stopping, booting: booting));
        await refreshSilently();
      }
    }
  }

  /// Mirror screen using scrcpy
  Future<void> mirrorWithScrcpy(Emulator emulator) async {
    final sdk = state.value?.sdk;
    if (sdk == null) return;

    final String? serial;
    if (emulator.isPhysical) {
      serial = emulator.serial ?? emulator.name;
    } else {
      serial = await ref.read(adbServiceProvider).findSerialForAvd(sdk.adbPath, emulator.name);
    }
    if (serial == null) return;

    final settings = ref.read(settingsControllerProvider);

    await ref.read(scrcpyServiceProvider).startMirror(
      serial: serial,
      windowTitle: '${emulator.name} (Simulation Tray)',
      customPath: settings.scrcpyPath,
      sdkPath: sdk.path,
      adbPath: sdk.adbPath,
    );
  }

  /// Create a new virtual device
  Future<void> createDevice({
    required String name,
    required String systemImage,
    String device = 'pixel_7',
    int ramMb = 4096,
    int cpuCores = 4,
    int internalStorageMb = 8192,
    String gpuMode = 'auto',
    bool hardwareKeyboard = true,
    void Function(String progress)? onProgress,
  }) async {
    final sdk = state.value?.sdk;
    if (sdk == null) {
      throw StateError('Android SDK is not configured.');
    }

    await ref.read(emulatorRepositoryProvider).createCustomAvd(
      sdk: sdk,
      name: name,
      systemImage: systemImage,
      device: device,
      ramMb: ramMb,
      cpuCores: cpuCores,
      internalStorageMb: internalStorageMb,
      gpuMode: gpuMode,
      hardwareKeyboard: hardwareKeyboard,
      onProgress: onProgress,
    );

    await refresh();
  }
}

class ProcessControllerState {
  const ProcessControllerState({
    this.processes = const [],
    this.selectedPids = const {},
    this.isLoading = false,
    this.errorMessage,
    this.searchQuery = '',
    this.filterCategory,
  });

  final List<SystemProcessItem> processes;
  final Set<int> selectedPids;
  final bool isLoading;
  final String? errorMessage;
  final String searchQuery;
  final ProcessCategory? filterCategory;

  List<SystemProcessItem> get filteredProcesses {
    return processes.where((p) {
      if (filterCategory != null && p.category != filterCategory) {
        return false;
      }
      return p.matchesQuery(searchQuery);
    }).toList();
  }

  Map<ProcessCategory, List<SystemProcessItem>> get groupedProcesses {
    final map = <ProcessCategory, List<SystemProcessItem>>{};
    for (final p in filteredProcesses) {
      map.putIfAbsent(p.category, () => <SystemProcessItem>[]).add(p);
    }
    return map;
  }

  int get totalMemoryBytes {
    return processes.fold(0, (sum, p) => sum + p.memoryBytes);
  }

  String get formattedTotalMemory {
    final mb = totalMemoryBytes / (1024 * 1024);
    if (mb >= 1024) {
      return '${(mb / 1024).toStringAsFixed(1)} GB';
    }
    return '${mb.toStringAsFixed(0)} MB';
  }

  ProcessControllerState copyWith({
    List<SystemProcessItem>? processes,
    Set<int>? selectedPids,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    String? searchQuery,
    ProcessCategory? filterCategory,
    bool clearFilterCategory = false,
  }) {
    return ProcessControllerState(
      processes: processes ?? this.processes,
      selectedPids: selectedPids ?? this.selectedPids,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      searchQuery: searchQuery ?? this.searchQuery,
      filterCategory: clearFilterCategory ? null : (filterCategory ?? this.filterCategory),
    );
  }
}

final processControllerProvider =
    NotifierProvider<ProcessController, ProcessControllerState>(ProcessController.new);

class ProcessController extends Notifier<ProcessControllerState> {
  @override
  ProcessControllerState build() {
    // Initial fetch
    Future.microtask(refresh);
    return const ProcessControllerState(isLoading: true);
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final service = ref.read(processManagerServiceProvider);
      final list = await service.getAndroidRelatedProcesses();
      // Retain selections that still exist
      final existingPids = list.map((p) => p.pid).toSet();
      final retainedPids = state.selectedPids.intersection(existingPids);

      state = state.copyWith(
        processes: list,
        selectedPids: retainedPids,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to inspect processes: $e',
      );
    }
  }

  void toggleSelect(int pid) {
    final current = Set<int>.from(state.selectedPids);
    if (current.contains(pid)) {
      current.remove(pid);
    } else {
      current.add(pid);
    }
    state = state.copyWith(selectedPids: current);
  }

  void selectAll() {
    final allPids = state.filteredProcesses.map((p) => p.pid).toSet();
    state = state.copyWith(selectedPids: allPids);
  }

  void deselectAll() {
    state = state.copyWith(selectedPids: const {});
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setFilterCategory(ProcessCategory? category) {
    state = state.copyWith(
      filterCategory: category,
      clearFilterCategory: category == null,
    );
  }

  Future<bool> killProcess(int pid) async {
    final service = ref.read(processManagerServiceProvider);
    final success = await service.killProcess(pid);
    await refresh();
    return success;
  }

  Future<int> killSelected() async {
    if (state.selectedPids.isEmpty) return 0;
    final service = ref.read(processManagerServiceProvider);
    final count = await service.killProcesses(state.selectedPids.toList());
    await refresh();
    return count;
  }

  Future<int> killGroup(ProcessCategory category) async {
    final service = ref.read(processManagerServiceProvider);
    final count = await service.killGroup(category, state.processes);
    await refresh();
    return count;
  }
}

class DeviceMonitorState {
  const DeviceMonitorState({
    this.targets = const [],
    this.selectedTargetId = 'host',
    this.selectedTargetName = 'Host PC / Development System',
    this.currentMetrics,
    this.cpuHistory = const [],
    this.ramHistory = const [],
    this.rxHistory = const [],
    this.txHistory = const [],
    this.config = const MonitorWidgetConfig(),
    this.isPaused = false,
    this.isLoading = false,
  });

  final List<MonitorTargetInfo> targets;
  final String selectedTargetId;
  final String selectedTargetName;
  final DeviceRealtimeMetrics? currentMetrics;
  final List<MetricDataPoint> cpuHistory;
  final List<MetricDataPoint> ramHistory;
  final List<MetricDataPoint> rxHistory;
  final List<MetricDataPoint> txHistory;
  final MonitorWidgetConfig config;
  final bool isPaused;
  final bool isLoading;

  DeviceMonitorState copyWith({
    List<MonitorTargetInfo>? targets,
    String? selectedTargetId,
    String? selectedTargetName,
    DeviceRealtimeMetrics? currentMetrics,
    List<MetricDataPoint>? cpuHistory,
    List<MetricDataPoint>? ramHistory,
    List<MetricDataPoint>? rxHistory,
    List<MetricDataPoint>? txHistory,
    MonitorWidgetConfig? config,
    bool? isPaused,
    bool? isLoading,
  }) {
    return DeviceMonitorState(
      targets: targets ?? this.targets,
      selectedTargetId: selectedTargetId ?? this.selectedTargetId,
      selectedTargetName: selectedTargetName ?? this.selectedTargetName,
      currentMetrics: currentMetrics ?? this.currentMetrics,
      cpuHistory: cpuHistory ?? this.cpuHistory,
      ramHistory: ramHistory ?? this.ramHistory,
      rxHistory: rxHistory ?? this.rxHistory,
      txHistory: txHistory ?? this.txHistory,
      config: config ?? this.config,
      isPaused: isPaused ?? this.isPaused,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

final deviceMonitorControllerProvider =
    NotifierProvider<DeviceMonitorController, DeviceMonitorState>(
  DeviceMonitorController.new,
);

class DeviceMonitorController extends Notifier<DeviceMonitorState> {
  Timer? _timer;
  bool _isPolling = false;
  bool _isScreenActive = false;

  @override
  DeviceMonitorState build() {
    ref.onDispose(() => _timer?.cancel());
    return const DeviceMonitorState(isLoading: true);
  }

  /// Called when the monitor screen is mounted to begin real-time telemetry polling.
  void resumePolling() {
    _isScreenActive = true;
    Future.microtask(() async {
      await refreshTargets();
      _restartTimer();
      await tick();
    });
  }

  /// Called when the user navigates away from the monitor screen to stop background CPU usage.
  void pausePolling() {
    _isScreenActive = false;
    _timer?.cancel();
    _timer = null;
  }

  void _restartTimer() {
    _timer?.cancel();
    if (!_isScreenActive) return;
    final interval = state.config.refreshIntervalSeconds.clamp(1, 10);
    _timer = Timer.periodic(Duration(seconds: interval), (_) {
      if (!state.isPaused && _isScreenActive) {
        tick();
      }
    });
  }

  Future<void> refreshTargets() async {
    final adbPath = ref.read(emulatorControllerProvider).value?.sdk?.adbPath;
    final service = ref.read(deviceMonitorServiceProvider);
    final targets = await service.getAvailableTargets(adbPath);

    String targetId = state.selectedTargetId;
    String targetName = state.selectedTargetName;

    // If currently selected target is no longer available, fallback to host
    if (!targets.any((t) => t.id == targetId)) {
      targetId = 'host';
      targetName = 'Host PC / Development System';
    }

    state = state.copyWith(
      targets: targets,
      selectedTargetId: targetId,
      selectedTargetName: targetName,
    );
  }

  void setTarget(String id, String name) {
    if (state.selectedTargetId == id) return;
    final service = ref.read(deviceMonitorServiceProvider);
    service.resetDeltas();
    state = state.copyWith(
      selectedTargetId: id,
      selectedTargetName: name,
      cpuHistory: const [],
      ramHistory: const [],
      rxHistory: const [],
      txHistory: const [],
    );
    tick();
  }

  void setConfig(MonitorWidgetConfig config) {
    final intervalChanged = state.config.refreshIntervalSeconds != config.refreshIntervalSeconds;
    state = state.copyWith(config: config);
    if (intervalChanged) {
      _restartTimer();
    }
  }

  void togglePause() {
    state = state.copyWith(isPaused: !state.isPaused);
  }

  Future<void> tick() async {
    if (_isPolling || state.isPaused) return;
    _isPolling = true;

    final adbPath = ref.read(emulatorControllerProvider).value?.sdk?.adbPath;
    final service = ref.read(deviceMonitorServiceProvider);

    try {
      final metrics = await service.pollMetrics(
        targetId: state.selectedTargetId,
        targetName: state.selectedTargetName,
        adbPath: adbPath,
      );

      final now = metrics.timestamp;
      const maxHistory = 30;

      final newCpu = [...state.cpuHistory, MetricDataPoint(timestamp: now, value: metrics.cpuPercent)];
      if (newCpu.length > maxHistory) newCpu.removeAt(0);

      final newRam = [...state.ramHistory, MetricDataPoint(timestamp: now, value: metrics.ramUsagePercent)];
      if (newRam.length > maxHistory) newRam.removeAt(0);

      final newRx = [...state.rxHistory, MetricDataPoint(timestamp: now, value: metrics.networkRxSpeedKbps)];
      if (newRx.length > maxHistory) newRx.removeAt(0);

      final newTx = [...state.txHistory, MetricDataPoint(timestamp: now, value: metrics.networkTxSpeedKbps)];
      if (newTx.length > maxHistory) newTx.removeAt(0);

      state = state.copyWith(
        currentMetrics: metrics,
        cpuHistory: newCpu,
        ramHistory: newRam,
        rxHistory: newRx,
        txHistory: newTx,
        isLoading: false,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false);
    } finally {
      _isPolling = false;
    }
  }
}
