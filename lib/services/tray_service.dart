import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

class AppTrayService with TrayListener, WindowListener {
  Future<void> initialize({
    required Future<void> Function() onRefresh,
    required Future<void> Function() onExit,
    required Future<void> Function() onCheckUpdate,
  }) async {
    if (!Platform.isWindows) return;

    windowManager.addListener(this);
    trayManager.addListener(this);

    try {
      final icon = await rootBundle.load("assets/icons/app_icon.ico");

      final temp = File("${Directory.systemTemp.path}/app_icon.ico");
      await temp.writeAsBytes(icon.buffer.asUint8List());

      await trayManager.setIcon(temp.path);
      await trayManager.setToolTip("Android Emulator Manager");

      await trayManager.setContextMenu(
        Menu(
          items: [
            MenuItem(key: 'open', label: 'Open Manager'),
            MenuItem(key: 'refresh', label: 'Refresh'),
            MenuItem.separator(),
            MenuItem(key: 'exit', label: 'Exit'),
          ],
        ),
      );
    } catch (e, st) {
      debugPrint("Tray error: $e");
      debugPrintStack(stackTrace: st);
    }

    _onRefresh = onRefresh;
    _onExit = onExit;
    _onCheckUpdate = onCheckUpdate;
  }

  Future<void> dispose() async {
    if (!Platform.isWindows) return;

    trayManager.removeListener(this);
    windowManager.removeListener(this);
  }

  Future<void> Function()? _onRefresh;
  Future<void> Function()? _onExit;
  Future<void> Function()? _onCheckUpdate;

  @override
  void onTrayIconMouseDown() async {
    await windowManager.show();
    await windowManager.focus();

    await _onCheckUpdate?.call();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    switch (menuItem.key) {
      case 'open':
        await windowManager.show();
        await windowManager.focus();
        await _onCheckUpdate?.call();
        break;

      case 'refresh':
        await _onRefresh?.call();
        break;

      case 'exit':
        await _onExit?.call();
        break;
    }
  }
}