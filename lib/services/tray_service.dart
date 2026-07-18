import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

class AppTrayService with TrayListener, WindowListener {
  Future<void> initialize({
    required Future<void> Function() onRefresh,
    required Future<void> Function() onExit,
  }) async {
    if (!Platform.isWindows) return;

    print("Initializing tray...");

    windowManager.addListener(this);
    trayManager.addListener(this);

    try {

      final icon = await rootBundle.load("assets/icons/app_icon.ico");

      final temp = File("${Directory.systemTemp.path}/app_icon.ico");
      print("Icon loaded");
      await temp.writeAsBytes(icon.buffer.asUint8List());

      await trayManager.setIcon(temp.path);

      await trayManager.setToolTip("Android Emulator Manager");
      print("Tooltip set");

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

      print("Menu created");
    } catch (e, st) {
      print("Tray error: $e");
      debugPrintStack(stackTrace: st);
    }

    _onRefresh = onRefresh;
    _onExit = onExit;
  }

  Future<void> dispose() async {
    if (!Platform.isWindows) {
      return;
    }
    trayManager.removeListener(this);
    windowManager.removeListener(this);
  }

  Future<void> Function()? _onRefresh;
  Future<void> Function()? _onExit;

  @override
  void onTrayIconMouseDown() {
    windowManager.show();
    windowManager.focus();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'open':
        windowManager.show();
        windowManager.focus();
      case 'refresh':
        _onRefresh?.call();
      case 'exit':
        _onExit?.call();
    }
  }
}
