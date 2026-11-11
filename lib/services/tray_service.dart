import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../models/emulator.dart';

class AppTrayService with TrayListener, WindowListener {
  Future<void> Function()? _onRefresh;
  Future<void> Function()? _onExit;
  Future<void> Function()? _onCheckUpdate;
  Future<void> Function()? _onOpenManager;
  Future<void> Function(String name, {bool coldBoot})? _onLaunchEmulator;
  Future<void> Function(String name)? _onStopEmulator;
  Future<void> Function(String name)? _onMirrorEmulator;
  Future<void> Function(String serial)? _onMirrorPhysical;

  List<Emulator> _lastEmulators = const [];
  Set<String> _lastBooting = const {};
  Set<String> _lastStopping = const {};

  Future<void> initialize({
    required Future<void> Function() onRefresh,
    required Future<void> Function() onExit,
    required Future<void> Function() onCheckUpdate,
    required Future<void> Function() onOpenManager,
    Future<void> Function(String name, {bool coldBoot})? onLaunchEmulator,
    Future<void> Function(String name)? onStopEmulator,
    Future<void> Function(String name)? onMirrorEmulator,
    Future<void> Function(String serial)? onMirrorPhysical,
  }) async {
    if (!Platform.isWindows && !Platform.isMacOS) return;

    _onRefresh = onRefresh;
    _onExit = onExit;
    _onCheckUpdate = onCheckUpdate;
    _onOpenManager = onOpenManager;
    _onLaunchEmulator = onLaunchEmulator;
    _onStopEmulator = onStopEmulator;
    _onMirrorEmulator = onMirrorEmulator;
    _onMirrorPhysical = onMirrorPhysical;

    windowManager.addListener(this);
    trayManager.addListener(this);

    try {
      final iconAsset = Platform.isWindows ? "assets/icons/app_icon.ico" : "assets/icons/tray.png";
      final iconExt = Platform.isWindows ? "ico" : "png";
      final icon = await rootBundle.load(iconAsset);

      final temp = File("${Directory.systemTemp.path}/app_icon.$iconExt");
      await temp.writeAsBytes(icon.buffer.asUint8List());

      await trayManager.setIcon(temp.path);
      await trayManager.setToolTip("Simulation Tray");

      await updateMenu(
        emulators: _lastEmulators,
        booting: _lastBooting,
        stopping: _lastStopping,
      );
    } catch (e, st) {
      debugPrint("Tray initialization error: $e");
      debugPrintStack(stackTrace: st);
    }
  }

  /// Updates the tray context menu dynamically with the active devices and emulators.
  Future<void> updateMenu({
    required List<Emulator> emulators,
    Set<String> booting = const {},
    Set<String> stopping = const {},
  }) async {
    if (!Platform.isWindows && !Platform.isMacOS) return;
    _lastEmulators = emulators;
    _lastBooting = booting;
    _lastStopping = stopping;

    try {
      final items = <MenuItem>[
        MenuItem(
          key: 'header',
          label: 'Simulation Tray',
          disabled: true,
        ),
        MenuItem.separator(),
      ];

      final physicalDevices = emulators.where((e) => e.isPhysical).toList();
      final virtualDevices = emulators.where((e) => !e.isPhysical).toList();

      if (physicalDevices.isNotEmpty) {
        for (final device in physicalDevices) {
          final conn = (device.connectionType ?? 'usb').toUpperCase();
          final label = '📱 ${device.displayName} ($conn)';
          items.add(
            MenuItem.submenu(
              label: label,
              submenu: Menu(
                items: [
                  MenuItem(
                    key: 'mirror_phys:${device.serial ?? device.name}',
                    label: 'Mirror Screen (scrcpy)',
                  ),
                ],
              ),
            ),
          );
        }
        items.add(MenuItem.separator());
      }

      if (virtualDevices.isNotEmpty) {
        for (final emu in virtualDevices) {
          final isBooting = booting.contains(emu.name);
          final isStopping = stopping.contains(emu.name);

          if (isBooting) {
            items.add(
              MenuItem(
                key: 'noop',
                label: '⏳ ${emu.displayName} (Booting...)',
                disabled: true,
              ),
            );
          } else if (isStopping) {
            items.add(
              MenuItem(
                key: 'noop',
                label: '⏳ ${emu.displayName} (Stopping...)',
                disabled: true,
              ),
            );
          } else if (emu.isRunning) {
            items.add(
              MenuItem.submenu(
                label: '🟢 ${emu.displayName} (Running)',
                submenu: Menu(
                  items: [
                    MenuItem(
                      key: 'mirror_emu:${emu.name}',
                      label: 'Mirror Screen (scrcpy)',
                    ),
                    MenuItem(
                      key: 'stop_emu:${emu.name}',
                      label: 'Stop Emulator',
                    ),
                  ],
                ),
              ),
            );
          } else {
            items.add(
              MenuItem.submenu(
                label: '▶ ${emu.displayName}',
                submenu: Menu(
                  items: [
                    MenuItem(
                      key: 'launch_emu:${emu.name}',
                      label: 'Start Emulator',
                    ),
                    MenuItem(
                      key: 'cold_emu:${emu.name}',
                      label: 'Start Cold Boot',
                    ),
                  ],
                ),
              ),
            );
          }
        }
        items.add(MenuItem.separator());
      }

      if (physicalDevices.isEmpty && virtualDevices.isEmpty) {
        items.add(
          MenuItem(
            key: 'none',
            label: 'No devices detected',
            disabled: true,
          ),
        );
        items.add(MenuItem.separator());
      }

      items.addAll([
        MenuItem(key: 'open', label: 'Open Manager'),
        MenuItem(key: 'refresh', label: 'Refresh Devices'),
        MenuItem(key: 'check_update', label: 'Check for Updates...'),
        MenuItem.separator(),
        MenuItem(key: 'exit', label: 'Exit'),
      ]);

      await trayManager.setContextMenu(Menu(items: items));
    } catch (e, st) {
      debugPrint("Failed to update tray menu: $e");
      debugPrintStack(stackTrace: st);
    }
  }

  Future<void> dispose() async {
    if (!Platform.isWindows && !Platform.isMacOS) return;

    trayManager.removeListener(this);
    windowManager.removeListener(this);
  }

  @override
  void onTrayIconMouseDown() async {
    // Left-click directly opens the menu dropdown (like Expo Orbit)
    await trayManager.popUpContextMenu();
  }

  @override
  void onTrayIconRightMouseDown() async {
    // Right-click also opens the menu dropdown
    await trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    final key = menuItem.key;
    if (key == null) return;

    switch (key) {
      case 'open':
        await _onOpenManager?.call();
        break;
      case 'refresh':
        await _onRefresh?.call();
        break;
      case 'check_update':
        await _onCheckUpdate?.call();
        break;
      case 'exit':
        await _onExit?.call();
        break;
      default:
        if (key.startsWith('launch_emu:')) {
          final name = key.substring('launch_emu:'.length);
          await _onLaunchEmulator?.call(name, coldBoot: false);
        } else if (key.startsWith('cold_emu:')) {
          final name = key.substring('cold_emu:'.length);
          await _onLaunchEmulator?.call(name, coldBoot: true);
        } else if (key.startsWith('stop_emu:')) {
          final name = key.substring('stop_emu:'.length);
          await _onStopEmulator?.call(name);
        } else if (key.startsWith('mirror_emu:')) {
          final name = key.substring('mirror_emu:'.length);
          await _onMirrorEmulator?.call(name);
        } else if (key.startsWith('mirror_phys:')) {
          final serial = key.substring('mirror_phys:'.length);
          await _onMirrorPhysical?.call(serial);
        }
        break;
    }
  }
}
