import 'dart:io';

import 'package:path/path.dart' as p;

import 'system_environment_service.dart';

class ScrcpyService {
  ScrcpyService(this._systemEnvironmentService);

  final SystemEnvironmentService _systemEnvironmentService;

  Future<String?> findExecutable({String? customPath, String? sdkPath}) async {
    return _systemEnvironmentService.findScrcpy(
      customPath: customPath,
      sdkPath: sdkPath,
    );
  }

  Future<bool> isAvailable({String? customPath, String? sdkPath}) async {
    final path = await findExecutable(customPath: customPath, sdkPath: sdkPath);
    return path != null;
  }

  Future<String?> getVersion({String? customPath, String? sdkPath}) async {
    final path = await findExecutable(customPath: customPath, sdkPath: sdkPath);
    if (path == null) return null;
    try {
      final res = await Process.run(path, ['--version']);
      if (res.exitCode == 0) {
        final line = res.stdout.toString().split(RegExp(r'\r?\n')).first.trim();
        if (line.isNotEmpty) return line;
      }
    } catch (_) {}
    return null;
  }

  Future<Process?> startMirror({
    required String serial,
    String? windowTitle,
    String? customPath,
    String? sdkPath,
    String? adbPath,
  }) async {
    final scrcpyPath = await findExecutable(
      customPath: customPath,
      sdkPath: sdkPath,
    );
    if (scrcpyPath == null) return null;

    final args = <String>[
      '-s',
      serial,
      if (windowTitle != null) ...['--window-title', windowTitle],
      '--stay-awake',
    ];

    final env = Map<String, String>.from(Platform.environment);
    if (adbPath != null && File(adbPath).existsSync()) {
      env['ADB'] = adbPath;
    }

    return Process.start(
      scrcpyPath,
      args,
      workingDirectory: p.dirname(scrcpyPath),
      environment: env,
      mode: ProcessStartMode.detached,
    );
  }
}
