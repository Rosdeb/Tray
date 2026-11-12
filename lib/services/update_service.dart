import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class UpdateInfo {
  const UpdateInfo({
    required this.latestVersion,
    required this.downloadUrl,
    required this.releaseNotes,
  });

  final String latestVersion;
  final String downloadUrl;
  final String releaseNotes;
}

class UpdateCheckResult {
  const UpdateCheckResult({
    required this.isUpToDate,
    this.currentVersion = '',
    this.updateInfo,
    this.error,
  });

  final bool isUpToDate;
  final String currentVersion;
  final UpdateInfo? updateInfo;
  final String? error;

  bool get hasUpdate => updateInfo != null;
  bool get hasError => error != null;
}

class UpdateService {
  static const String owner = "Rosdeb";
  static const String repo = "Tray";

  static String cleanVersion(String v) {
    var clean = v.trim().replaceAll(RegExp(r'^[vV]'), '');
    if (clean.contains('+')) {
      clean = clean.split('+').first;
    }
    if (clean.contains('-')) {
      clean = clean.split('-').first;
    }
    return clean;
  }

  static bool isNewerVersion(String latest, String current) {
    final cleanLatest = cleanVersion(latest);
    final cleanCurrent = cleanVersion(current);

    final latestParts = cleanLatest.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    final currentParts = cleanCurrent.split('.').map((s) => int.tryParse(s) ?? 0).toList();

    final maxLen = latestParts.length > currentParts.length ? latestParts.length : currentParts.length;
    for (int i = 0; i < maxLen; i++) {
      final l = i < latestParts.length ? latestParts[i] : 0;
      final c = i < currentParts.length ? currentParts[i] : 0;
      if (l > c) return true;
      if (l < c) return false;
    }
    return false;
  }

  /// Strictly picks the installer asset matching the active OS platform.
  /// Never returns Windows .exe on macOS, and never returns macOS .dmg on Windows.
  static dynamic selectPlatformAsset(List<dynamic> assets, {bool? isWindows, bool? isMacOS}) {
    final win = isWindows ?? Platform.isWindows;
    final mac = isMacOS ?? Platform.isMacOS;

    for (final a in assets) {
      if (a is! Map) continue;
      final name = (a["name"] as String? ?? "").toLowerCase();
      if (name.endsWith('.sha256')) continue;

      if (win && name.endsWith('.exe')) {
        return a;
      }
      if (mac && (name.endsWith('.dmg') || name.endsWith('.zip')) && !name.endsWith('.exe')) {
        return a;
      }
    }
    return null;
  }

  /// Comprehensive check returning full details and error states.
  Future<UpdateCheckResult> checkUpdateWithDetails() async {
    try {
      final currentInfo = await PackageInfo.fromPlatform();
      final currentVersion = currentInfo.version;

      final response = await http.get(
        Uri.parse("https://api.github.com/repos/$owner/$repo/releases/latest"),
        headers: {
          "Accept": "application/vnd.github+json",
          "User-Agent": "Tray-Desktop-App",
        },
      ).timeout(const Duration(seconds: 12));

      if (response.statusCode != 200) {
        return UpdateCheckResult(
          isUpToDate: false,
          currentVersion: currentVersion,
          error: "GitHub API responded with status ${response.statusCode}",
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final rawTag = (data["tag_name"] as String? ?? "").trim();
      final latestVersion = cleanVersion(rawTag);

      if (!isNewerVersion(latestVersion, currentVersion)) {
        return UpdateCheckResult(
          isUpToDate: true,
          currentVersion: currentVersion,
        );
      }

      final assets = data["assets"] as List<dynamic>? ?? [];
      final chosenAsset = selectPlatformAsset(assets);

      if (chosenAsset == null) {
        final platformName = Platform.isMacOS ? "macOS (.dmg)" : (Platform.isWindows ? "Windows (.exe)" : "compatible");
        return UpdateCheckResult(
          isUpToDate: false,
          currentVersion: currentVersion,
          error: "A newer release ($rawTag) is available, but the $platformName installer is still building on GitHub Actions. Please check again in a few moments.",
        );
      }

      final info = UpdateInfo(
        latestVersion: latestVersion,
        downloadUrl: chosenAsset["browser_download_url"] as String,
        releaseNotes: (data["body"] as String?) ?? "",
      );

      return UpdateCheckResult(
        isUpToDate: false,
        currentVersion: currentVersion,
        updateInfo: info,
      );
    } catch (e) {
      return UpdateCheckResult(
        isUpToDate: false,
        error: e.toString(),
      );
    }
  }

  /// Simple check for riverpod providers returning UpdateInfo if newer version exists.
  Future<UpdateInfo?> checkForUpdate() async {
    final result = await checkUpdateWithDetails();
    return result.updateInfo;
  }

  /// Downloads the installer to local temp directory and reports progress.
  Future<String> downloadInstaller(
    String url, {
    void Function(double progress)? onProgress,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final uri = Uri.parse(url);
    final rawName = p.basename(uri.path).toLowerCase();
    String ext = p.extension(rawName);
    if (ext.isEmpty || ext == '.sha256') {
      ext = Platform.isWindows ? '.exe' : '.dmg';
    }
    final filePath = p.join(tempDir.path, 'Tray-Update$ext');

    final file = File(filePath);
    if (await file.exists()) {
      try {
        await file.delete();
      } catch (_) {}
    }

    final client = http.Client();
    try {
      final request = http.Request("GET", Uri.parse(url));
      request.headers['User-Agent'] = 'Tray-Desktop-App';
      final response = await client.send(request);

      if (response.statusCode >= 400) {
        throw HttpException('Download failed with status: ${response.statusCode}');
      }

      final total = response.contentLength ?? 0;
      int received = 0;
      final sink = file.openWrite();

      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0 && onProgress != null) {
          onProgress(received / total);
        }
      }

      await sink.flush();
      await sink.close();
      return filePath;
    } finally {
      client.close();
    }
  }

  /// Detaches and runs the installer, then closes the current application.
  Future<void> runInstallerAndExit(String installerPath) async {
    if (Platform.isWindows) {
      if (!installerPath.toLowerCase().endsWith('.exe')) {
        throw StateError('Downloaded update file is not a Windows executable: $installerPath');
      }
      await Process.start(
        installerPath,
        ['/CLOSEAPPLICATIONS'],
        mode: ProcessStartMode.detached,
      );
    } else if (Platform.isMacOS) {
      if (installerPath.toLowerCase().endsWith('.exe')) {
        throw StateError('Cannot run Windows .exe installer on macOS. Please ensure a macOS .dmg release is selected.');
      }

      String targetAppPath = '/Applications/Tray.app';
      try {
        final resolvedExecutable = Platform.resolvedExecutable;
        final appIdx = resolvedExecutable.indexOf('.app');
        if (appIdx != -1) {
          targetAppPath = resolvedExecutable.substring(0, appIdx + 4);
        }
      } catch (_) {}

      // Write a detached helper script that executes right after this process exits.
      // This avoids Unix 'Text file busy' locks while copying over the active binary.
      final scriptFile = File('/tmp/tray_apply_update.sh');
      final scriptContent = '''#!/bin/bash
sleep 1
TARGET_APP="$targetAppPath"
PKG_PATH="$installerPath"

if [[ "\$PKG_PATH" == *.dmg ]]; then
  MOUNT_DIR=\$(mktemp -d /tmp/tray_dmg_XXXXXX)
  hdiutil attach "\$PKG_PATH" -nobrowse -mountpoint "\$MOUNT_DIR" -quiet

  APP_SOURCE=\$(find "\$MOUNT_DIR" -maxdepth 1 -name "*.app" | head -n 1)
  SUCCESS=0

  if [ -n "\$APP_SOURCE" ] && [ -d "\$APP_SOURCE" ]; then
    rm -rf "\$TARGET_APP" 2>/dev/null && cp -R "\$APP_SOURCE" "\$TARGET_APP" 2>/dev/null
    if [ \$? -eq 0 ]; then
      SUCCESS=1
    fi
  fi

  hdiutil detach "\$MOUNT_DIR" -force -quiet 2>/dev/null || true
  rm -rf "\$MOUNT_DIR" 2>/dev/null || true

  if [ \$SUCCESS -eq 1 ]; then
    open -n "\$TARGET_APP"
  else
    open "\$PKG_PATH"
  fi
elif [[ "\$PKG_PATH" == *.zip ]]; then
  EXTRACT_DIR=\$(mktemp -d /tmp/tray_zip_XXXXXX)
  unzip -q -o "\$PKG_PATH" -d "\$EXTRACT_DIR" 2>/dev/null
  APP_SOURCE=\$(find "\$EXTRACT_DIR" -maxdepth 1 -name "*.app" | head -n 1)
  SUCCESS=0

  if [ -n "\$APP_SOURCE" ] && [ -d "\$APP_SOURCE" ]; then
    rm -rf "\$TARGET_APP" 2>/dev/null && cp -R "\$APP_SOURCE" "\$TARGET_APP" 2>/dev/null
    if [ \$? -eq 0 ]; then
      SUCCESS=1
    fi
  fi

  rm -rf "\$EXTRACT_DIR" 2>/dev/null || true

  if [ \$SUCCESS -eq 1 ]; then
    open -n "\$TARGET_APP"
  else
    open -R "\$PKG_PATH"
  fi
else
  open "\$PKG_PATH"
fi
''';

      await scriptFile.writeAsString(scriptContent);
      await Process.run('chmod', ['+x', scriptFile.path]);

      await Process.start(
        '/bin/bash',
        [scriptFile.path],
        mode: ProcessStartMode.detached,
      );
    }

    await Future.delayed(const Duration(milliseconds: 400));
    exit(0);
  }
}
