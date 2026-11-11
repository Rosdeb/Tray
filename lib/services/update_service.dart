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
      dynamic chosenAsset;

      if (Platform.isWindows) {
        chosenAsset = assets.firstWhere(
          (a) {
            final name = (a["name"] as String? ?? "").toLowerCase();
            return name.endsWith('.exe') || name.contains('setup');
          },
          orElse: () => null,
        );
      } else if (Platform.isMacOS) {
        chosenAsset = assets.firstWhere(
          (a) {
            final name = (a["name"] as String? ?? "").toLowerCase();
            return name.endsWith('.dmg') || name.endsWith('.zip');
          },
          orElse: () => null,
        );
      }

      chosenAsset ??= assets.firstWhere(
        (a) {
          final name = (a["name"] as String? ?? "").toLowerCase();
          return name.endsWith('.exe') || name.endsWith('.dmg') || name.endsWith('.zip');
        },
        orElse: () => assets.isNotEmpty ? assets.first : null,
      );

      if (chosenAsset == null) {
        return UpdateCheckResult(
          isUpToDate: false,
          currentVersion: currentVersion,
          error: "No compatible installer asset found in release $rawTag",
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
    final ext = Platform.isWindows ? '.exe' : (Platform.isMacOS ? '.dmg' : '.zip');
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
      await Process.start(
        installerPath,
        [],
        mode: ProcessStartMode.detached,
      );
    } else if (Platform.isMacOS) {
      await Process.start(
        'open',
        [installerPath],
        mode: ProcessStartMode.detached,
      );
    }

    await Future.delayed(const Duration(milliseconds: 500));
    exit(0);
  }
}
