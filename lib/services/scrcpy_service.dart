import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../core/utils/platform_paths.dart';
import 'system_environment_service.dart';

class ScrcpyService {
  ScrcpyService(this._systemEnvironmentService);

  final SystemEnvironmentService _systemEnvironmentService;

  static const String windowsScrcpyZipUrl =
      'https://github.com/Genymobile/scrcpy/releases/download/v3.1/scrcpy-win64-v3.1.zip';

  bool get isAutoInstallSupported => Platform.isWindows;

  String get defaultInstallDirectory {
    if (Platform.isWindows) {
      final localAppData = Platform.environment['LOCALAPPDATA'];
      if (localAppData != null && localAppData.trim().isNotEmpty) {
        return p.join(localAppData, 'Tray', 'scrcpy');
      }
      return p.join(PlatformPaths.userHomeDir(), 'AppData', 'Local', 'Tray', 'scrcpy');
    }
    return p.join(PlatformPaths.userHomeDir(), '.tray', 'scrcpy');
  }

  /// Automatically downloads and installs the standalone official scrcpy binaries.
  Future<String> installStandaloneScrcpy({
    void Function(String message, double progress)? onProgress,
  }) async {
    onProgress?.call('Preparing scrcpy installation directory...', 0.05);

    final targetDir = Directory(defaultInstallDirectory);
    await targetDir.create(recursive: true);

    final tempZip = File(p.join(Directory.systemTemp.path, 'scrcpy-win64.zip'));
    final client = http.Client();
    try {
      onProgress?.call('Downloading official scrcpy package (~6.6 MB)...', 0.15);

      final request = http.Request('GET', Uri.parse(windowsScrcpyZipUrl));
      request.followRedirects = true;
      final response = await client.send(request);

      if (response.statusCode >= 400) {
        throw HttpException('Download failed with status: ${response.statusCode}');
      }

      final totalBytes = response.contentLength ?? 6939768;
      int receivedBytes = 0;
      final sink = tempZip.openWrite();

      await for (final chunk in response.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (onProgress != null && totalBytes > 0) {
          final pct = (receivedBytes / totalBytes).clamp(0.0, 1.0);
          onProgress('Downloading scrcpy (${(pct * 100).toStringAsFixed(0)}%)...', 0.15 + pct * 0.60);
        }
      }

      await sink.flush();
      await sink.close();

      onProgress?.call('Extracting scrcpy binaries...', 0.80);

      if (Platform.isWindows) {
        final tarRes = await Process.run('tar.exe', ['-xf', tempZip.path, '-C', targetDir.path]);
        if (tarRes.exitCode != 0) {
          final psRes = await Process.run('powershell', [
            '-NoProfile',
            '-Command',
            'Expand-Archive -LiteralPath "${tempZip.path}" -DestinationPath "${targetDir.path}" -Force',
          ]);
          if (psRes.exitCode != 0) {
            throw ProcessException('powershell', ['Expand-Archive'], psRes.stderr.toString(), psRes.exitCode);
          }
        }
      } else {
        await Process.run('unzip', ['-q', '-o', tempZip.path, '-d', targetDir.path]);
      }

      onProgress?.call('Locating scrcpy executable...', 0.95);

      final resolved = SystemEnvironmentService.resolveScrcpyExecutable(targetDir.path);
      if (resolved == null) {
        throw StateError('Could not find scrcpy.exe in extracted folder: ${targetDir.path}');
      }

      try {
        if (tempZip.existsSync()) tempZip.deleteSync();
      } catch (_) {}

      onProgress?.call('scrcpy ready!', 1.0);
      return resolved;
    } finally {
      client.close();
    }
  }

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
