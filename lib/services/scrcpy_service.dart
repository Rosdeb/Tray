import 'dart:io';

import 'system_environment_service.dart';

class ScrcpyService {
  ScrcpyService(this._systemEnvironmentService);

  final SystemEnvironmentService _systemEnvironmentService;

  Future<bool> isAvailable() async {
    final path = await _systemEnvironmentService.findScrcpy();
    return path != null;
  }

  Future<Process?> startMirror({
    required String serial,
    String? windowTitle,
  }) async {
    final scrcpyPath = await _systemEnvironmentService.findScrcpy();
    if (scrcpyPath == null) return null;

    final args = <String>[
      '-s',
      serial,
      if (windowTitle != null) ...['--window-title', windowTitle],
      '--stay-awake',
    ];

    return Process.start(scrcpyPath, args, mode: ProcessStartMode.detached);
  }
}
