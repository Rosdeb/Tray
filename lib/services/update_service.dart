import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

class UpdateInfo {
  final String latestVersion;
  final String downloadUrl;
  final String releaseNotes;

  UpdateInfo({
    required this.latestVersion,
    required this.downloadUrl,
    required this.releaseNotes,
  });
}

class UpdateService {
  static const String owner = "Rosdeb";
  static const String repo = "Tray";

  Future<UpdateInfo?> checkForUpdate() async {
    try {
      final response = await http.get(
        Uri.parse(
          "https://api.github.com/repos/$owner/$repo/releases/latest",
        ),
        headers: {"Accept": "application/vnd.github+json"},
      );

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final tagName = (data["tag_name"] as String).replaceAll("v", "");

      final currentInfo = await PackageInfo.fromPlatform();
      final currentVersion = currentInfo.version;

      if (!_isNewerVersion(tagName, currentVersion)) {
        return null; // আপডেট নেই
      }

      final assets = data["assets"] as List<dynamic>;

      final setupAsset = assets.firstWhere(
            (a) => (a["name"] as String).toLowerCase().contains("setup.exe"),
        orElse: () => null,
      );

      if (setupAsset == null) return null;

      return UpdateInfo(
        latestVersion: tagName,
        downloadUrl: setupAsset["browser_download_url"] as String,
        releaseNotes: (data["body"] as String?) ?? "",
      );
    } catch (e) {
      return null;
    }
  }

  bool _isNewerVersion(String latest, String current) {
    final latestParts = latest.split('.').map(int.parse).toList();
    final currentParts = current.split('.').map(int.parse).toList();

    for (int i = 0; i < latestParts.length; i++) {
      final l = latestParts[i];
      final c = i < currentParts.length ? currentParts[i] : 0;
      if (l > c) return true;
      if (l < c) return false;
    }
    return false;
  }

  /// Installer download kore local e save kore, path return kore
  Future<String> downloadInstaller(
      String url, {
        void Function(double progress)? onProgress,
      }) async {
    final tempDir = await getTemporaryDirectory();
    final filePath = "${tempDir.path}\\Tray-Setup.exe";

    final request = http.Request("GET", Uri.parse(url));
    final response = await http.Client().send(request);

    final total = response.contentLength ?? 0;
    int received = 0;

    final file = File(filePath);
    final sink = file.openWrite();

    await response.stream.listen((chunk) {
      received += chunk.length;
      sink.add(chunk);
      if (total > 0 && onProgress != null) {
        onProgress(received / total);
      }
    }).asFuture();

    await sink.close();
    return filePath;
  }

  /// Downloaded installer run kore, then current app close kore
  Future<void> runInstallerAndExit(String installerPath) async {

    await Process.start(
      installerPath,
      [],
      mode: ProcessStartMode.detached,
    );

    await Future.delayed(const Duration(seconds: 1));
    exit(0);
  }
}