import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../core/utils/platform_paths.dart';
import '../models/sdk_install_progress.dart';
import 'system_environment_service.dart';

class SdkInstallerService {
  SdkInstallerService(this._systemEnvironmentService);

  final SystemEnvironmentService _systemEnvironmentService;

  // Google Android SDK License text preview / summary
  static const androidSdkLicenseAgreementText = '''
ANDROID SOFTWARE DEVELOPMENT KIT TERMS AND CONDITIONS

1. Introduction
1.1 The Android Software Development Kit (referred to in the License Agreement as the "SDK" and specifically including the Android system files, packaged APIs, and Google APIs add-ons) is licensed to you subject to the terms of the License Agreement. The License Agreement forms a legally binding contract between you and Google in relation to your use of the SDK.

1.2 "Android" means the Android software stack for devices, as made available under the Android Open Source Project.

1.3 "Google" means Google LLC, a Delaware corporation with principal place of business at 1600 Amphitheatre Parkway, Mountain View, CA 94043, United States.

2. Accepting the License Agreement
2.1 In order to use the SDK, you must first agree to the License Agreement. You may not use the SDK if you do not accept the License Agreement.

2.2 By downloading, installing, or using the SDK components on this device, you hereby agree to the terms of the Android Software Development Kit License Agreement.
''';

  /// Download a file with progress stream.
  Future<void> downloadFile(
    String url,
    File destination, {
    void Function(int received, int total)? onProgress,
  }) async {
    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(url));
      final response = await client.send(request);

      if (response.statusCode >= 400) {
        throw HttpException('Download failed with status: ${response.statusCode}', uri: Uri.parse(url));
      }

      final totalBytes = response.contentLength ?? -1;
      int receivedBytes = 0;

      await destination.parent.create(recursive: true);
      final sink = destination.openWrite();

      await for (final chunk in response.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (onProgress != null) {
          onProgress(receivedBytes, totalBytes);
        }
      }

      await sink.flush();
      await sink.close();
    } finally {
      client.close();
    }
  }

  /// Extract a .zip or .tar.gz archive using system tools.
  Future<void> extractArchive(File archiveFile, Directory targetDir) async {
    await targetDir.create(recursive: true);
    final filePath = archiveFile.path;
    final targetPath = targetDir.path;

    if (filePath.endsWith('.tar.gz') || filePath.endsWith('.tgz')) {
      final result = await Process.run('tar', ['-xzf', filePath, '-C', targetPath]);
      if (result.exitCode != 0) {
        throw ProcessException('tar', ['-xzf', filePath, '-C', targetPath], result.stderr.toString(), result.exitCode);
      }
      return;
    }

    if (filePath.endsWith('.zip')) {
      if (Platform.isWindows) {
        // Try Windows tar first (Windows 10/11 includes bsdtar)
        final tarResult = await Process.run('tar.exe', ['-xf', filePath, '-C', targetPath]);
        if (tarResult.exitCode == 0) return;

        // Fallback to PowerShell Expand-Archive
        final psResult = await Process.run('powershell', [
          '-NoProfile',
          '-Command',
          'Expand-Archive -LiteralPath "$filePath" -DestinationPath "$targetPath" -Force',
        ]);
        if (psResult.exitCode != 0) {
          throw ProcessException('powershell', ['Expand-Archive'], psResult.stderr.toString(), psResult.exitCode);
        }
      } else {
        // macOS / Linux unzip
        final result = await Process.run('unzip', ['-q', '-o', filePath, '-d', targetPath]);
        if (result.exitCode != 0) {
          throw ProcessException('unzip', ['-q', '-o', filePath, '-d', targetPath], result.stderr.toString(), result.exitCode);
        }
      }
    }
  }

  /// Resolve Adoptium Temurin OpenJDK 17 download URL based on OS and architecture.
  String getTemurinJdkUrl() {
    final abi = _systemEnvironmentService.getHostAbi();
    final isArm = abi == 'arm64-v8a';

    if (Platform.isWindows) {
      // Adoptium Temurin 17 Windows x64 zip
      return 'https://api.adoptium.net/v3/binary/latest/17/ga/windows/x64/jdk/hotspot/normal/eclipse';
    } else if (Platform.isMacOS) {
      final arch = isArm ? 'aarch64' : 'x64';
      return 'https://api.adoptium.net/v3/binary/latest/17/ga/mac/$arch/jdk/hotspot/normal/eclipse';
    } else {
      final arch = isArm ? 'aarch64' : 'x64';
      return 'https://api.adoptium.net/v3/binary/latest/17/ga/linux/$arch/jdk/hotspot/normal/eclipse';
    }
  }

  /// Google cmdline-tools download URL.
  String getCmdlineToolsUrl() {
    if (Platform.isWindows) {
      return 'https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip';
    } else if (Platform.isMacOS) {
      return 'https://dl.google.com/android/repository/commandlinetools-mac-11076708_latest.zip';
    } else {
      return 'https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip';
    }
  }

  /// Writes standard Google Android SDK license hashes to `<sdk>/licenses`.
  Future<void> writeSdkLicenses(Directory sdkDir) async {
    final licensesDir = Directory(p.join(sdkDir.path, 'licenses'));
    await licensesDir.create(recursive: true);

    final licenses = <String, List<String>>{
      'android-sdk-license': [
        '24333f8a63b6825ea9c5514f83c2829b004d1fee',
        'd56f5187479451eabf01fb78af6dfcb131a6481e',
        '8933bad161af4178b1185d1a37fbf41ea5269c55',
      ],
      'android-sdk-preview-license': [
        '84831b9409646a918e30573bab4c9c91346d8abd',
      ],
      'intel-android-extra-license': [
        'd975f751698a77b662f1254ddbeed3901e1ad6f6',
      ],
      'google-gdk-license': [
        '33b6a2b64607f11b759f320ef9dff4ae5c47d97a',
      ],
      'mips-android-sysimage-license': [
        'e9acab5b5fbb560a72cfa4e27c30d7500488f578',
      ],
    };

    for (final entry in licenses.entries) {
      final file = File(p.join(licensesDir.path, entry.key));
      await file.writeAsString('${entry.value.join('\n')}\n');
    }
  }

  /// Automatically accepts licenses using `sdkmanager --licenses`.
  Future<void> acceptLicensesWithSdkManager({
    required String sdkManagerPath,
    required String javaHome,
    required String sdkRoot,
    void Function(String line)? onLog,
  }) async {
    // First write the license files directly
    await writeSdkLicenses(Directory(sdkRoot));

    try {
      final env = Map<String, String>.from(Platform.environment);
      env['JAVA_HOME'] = javaHome;
      env['ANDROID_HOME'] = sdkRoot;
      env['ANDROID_SDK_ROOT'] = sdkRoot;

      final process = await Process.start(
        sdkManagerPath,
        ['--licenses', '--sdk_root=$sdkRoot'],
        environment: env,
        runInShell: Platform.isWindows,
      );

      // Pipe 'y' to every license prompt
      final stdinTimer = Timer.periodic(const Duration(milliseconds: 200), (t) {
        try {
          process.stdin.writeln('y');
        } catch (_) {
          t.cancel();
        }
      });

      process.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
        onLog?.call(line);
      });

      process.stderr.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
        onLog?.call(line);
      });

      await process.exitCode.timeout(const Duration(seconds: 30), onTimeout: () {
        process.kill();
        return 0;
      });

      stdinTimer.cancel();
    } catch (e) {
      onLog?.call('License check note: $e');
    }
  }

  /// Full automated setup flow yielding progress updates.
  Stream<SdkInstallProgress> runFullSetup({
    required String sdkPath,
    String? preferredJdkPath,
    String? avdName,
    String apiLevel = '34',
  }) async* {
    final totalSteps = 6;
    final logs = <String>[];
    void addLog(String message) {
      logs.add('[${DateTime.now().toIso8601String().substring(11, 19)}] $message');
    }

    // Step 1: Check System & Disk
    yield SdkInstallProgress(
      step: SdkInstallStep.checkingSystem,
      currentStepIndex: 1,
      totalSteps: totalSteps,
      description: 'Checking system requirements and disk space...',
      logs: logs,
    );
    addLog('Target SDK directory: $sdkPath');

    final sdkDir = Directory(sdkPath);
    await sdkDir.create(recursive: true);

    final freeSpace = await _systemEnvironmentService.getFreeDiskSpaceGb(sdkPath);
    if (freeSpace != null) {
      addLog('Free disk space: ${freeSpace.toStringAsFixed(1)} GB');
      if (freeSpace < 6.0) {
        addLog('WARNING: Low disk space detected (< 6 GB). Installation may require more space.');
      }
    }

    final abi = _systemEnvironmentService.getHostAbi();
    addLog('Detected host Android ABI: $abi');

    // Step 2: JDK 17+ Setup
    yield SdkInstallProgress(
      step: SdkInstallStep.downloadingJdk,
      currentStepIndex: 2,
      totalSteps: totalSteps,
      description: 'Verifying Java Development Kit (JDK 17+)...',
      logs: logs,
    );

    String? javaHome;
    // Check if user provided preferred or if existing JDK 17+ exists
    javaHome = await _systemEnvironmentService.findValidJavaHome(
      candidates: [
        ?preferredJdkPath,
        p.join(sdkPath, 'jdk-17'),
        p.join(Directory.systemTemp.path, 'aem_jdk17'),
      ],
    );

    if (javaHome != null) {
      addLog('Found existing valid JDK 17+ at: $javaHome');
    } else {
      addLog('No JDK 17+ found. Downloading portable Eclipse Temurin JDK 17...');
      final jdkUrl = getTemurinJdkUrl();
      final tempJdkArchive = File(p.join(Directory.systemTemp.path, 'temurin_jdk17${Platform.isWindows ? '.zip' : '.tar.gz'}'));

      yield SdkInstallProgress(
        step: SdkInstallStep.downloadingJdk,
        currentStepIndex: 2,
        totalSteps: totalSteps,
        description: 'Downloading portable Temurin OpenJDK 17...',
        logs: logs,
      );

      await downloadFile(
        jdkUrl,
        tempJdkArchive,
        onProgress: (received, total) {
          // progress callback can be handled if needed
        },
      );
      addLog('JDK 17 download completed. Extracting to SDK folder...');

      final jdkTarget = Directory(p.join(sdkPath, 'jdk-17'));
      yield SdkInstallProgress(
        step: SdkInstallStep.extractingJdk,
        currentStepIndex: 2,
        totalSteps: totalSteps,
        description: 'Extracting Temurin JDK 17...',
        logs: logs,
      );
      await extractArchive(tempJdkArchive, jdkTarget);
      try {
        await tempJdkArchive.delete();
      } catch (_) {}

      javaHome = await _systemEnvironmentService.findValidJavaHome(candidates: [jdkTarget.path]);
      if (javaHome == null) {
        throw Exception('Failed to resolve Java home in extracted JDK at ${jdkTarget.path}');
      }
      addLog('JDK 17 ready at: $javaHome');
    }

    // Step 3: Command-line tools
    yield SdkInstallProgress(
      step: SdkInstallStep.downloadingCmdlineTools,
      currentStepIndex: 3,
      totalSteps: totalSteps,
      description: 'Setting up Android Command-line Tools (sdkmanager & avdmanager)...',
      logs: logs,
    );

    final sdkManagerExe = Platform.isWindows ? 'sdkmanager.bat' : 'sdkmanager';
    final avdManagerExe = Platform.isWindows ? 'avdmanager.bat' : 'avdmanager';
    final canonicalSdkManager = File(p.join(sdkPath, 'cmdline-tools', 'latest', 'bin', sdkManagerExe));
    final canonicalAvdManager = File(p.join(sdkPath, 'cmdline-tools', 'latest', 'bin', avdManagerExe));

    if (await canonicalSdkManager.exists() && await canonicalAvdManager.exists()) {
      addLog('Android Command-line tools already installed.');
    } else {
      addLog('Downloading cmdline-tools from Google...');
      final cmdToolsUrl = getCmdlineToolsUrl();
      final tempZip = File(p.join(Directory.systemTemp.path, 'cmdline-tools.zip'));

      await downloadFile(cmdToolsUrl, tempZip);
      addLog('Extracting cmdline-tools...');

      yield SdkInstallProgress(
        step: SdkInstallStep.extractingCmdlineTools,
        currentStepIndex: 3,
        totalSteps: totalSteps,
        description: 'Extracting Android Command-line Tools into canonical structure...',
        logs: logs,
      );

      // Google's zip unpacks into a 'cmdline-tools' directory
      final tempExtract = Directory(p.join(Directory.systemTemp.path, 'cmdtools_extract_${DateTime.now().millisecondsSinceEpoch}'));
      await extractArchive(tempZip, tempExtract);
      try {
        await tempZip.delete();
      } catch (_) {}

      // Move into <sdk>/cmdline-tools/latest
      final latestDir = Directory(p.join(sdkPath, 'cmdline-tools', 'latest'));
      if (await latestDir.exists()) {
        await latestDir.delete(recursive: true);
      }
      await latestDir.create(recursive: true);

      final extractedInner = Directory(p.join(tempExtract.path, 'cmdline-tools'));
      final sourceDir = await extractedInner.exists() ? extractedInner : tempExtract;

      // Copy all contents of sourceDir to latestDir
      for (final item in sourceDir.listSync()) {
        final dest = p.join(latestDir.path, p.basename(item.path));
        if (item is Directory) {
          await Process.run(
            Platform.isWindows ? 'xcopy' : 'cp',
            Platform.isWindows ? ['/E', '/I', '/Y', item.path, dest] : ['-R', item.path, dest],
          );
        } else if (item is File) {
          await item.copy(dest);
        }
      }

      try {
        await tempExtract.delete(recursive: true);
      } catch (_) {}

      // Ensure executable permissions on macOS / Linux
      if (!Platform.isWindows) {
        await Process.run('chmod', ['-R', '+x', p.join(latestDir.path, 'bin')]);
      }
      addLog('cmdline-tools arranged at ${latestDir.path}');
    }

    // Step 4: Accept licenses
    yield SdkInstallProgress(
      step: SdkInstallStep.acceptingLicenses,
      currentStepIndex: 4,
      totalSteps: totalSteps,
      description: 'Accepting Google Android SDK licenses...',
      logs: logs,
    );
    addLog('Writing license acceptance hashes...');
    await writeSdkLicenses(sdkDir);
    await acceptLicensesWithSdkManager(
      sdkManagerPath: canonicalSdkManager.path,
      javaHome: javaHome,
      sdkRoot: sdkPath,
      onLog: (line) {
        if (line.trim().isNotEmpty) addLog(line.trim());
      },
    );
    addLog('Android SDK licenses accepted.');

    // Step 5: Install packages via sdkmanager
    yield SdkInstallProgress(
      step: SdkInstallStep.installingPackages,
      currentStepIndex: 5,
      totalSteps: totalSteps,
      description: 'Installing platform-tools, emulator, and Google APIs system image (API $apiLevel)...',
      logs: logs,
    );

    final systemImagePkg = 'system-images;android-$apiLevel;google_apis;$abi';
    final packagesToInstall = [
      'platform-tools',
      'emulator',
      systemImagePkg,
    ];

    addLog('Installing SDK packages: ${packagesToInstall.join(', ')}');
    final env = Map<String, String>.from(Platform.environment);
    env['JAVA_HOME'] = javaHome;
    env['ANDROID_HOME'] = sdkPath;
    env['ANDROID_SDK_ROOT'] = sdkPath;

    final installProcess = await Process.start(
      canonicalSdkManager.path,
      [
        '--install',
        ...packagesToInstall,
        '--sdk_root=$sdkPath',
      ],
      environment: env,
      runInShell: Platform.isWindows,
    );

    final compStream = installProcess.stdout.transform(utf8.decoder).transform(const LineSplitter());
    await for (final line in compStream) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty) {
        addLog(trimmed);
        yield SdkInstallProgress(
          step: SdkInstallStep.installingPackages,
          currentStepIndex: 5,
          totalSteps: totalSteps,
          description: 'Installing packages via sdkmanager...',
          currentOutput: trimmed,
          logs: logs,
        );
      }
    }

    final exitCode = await installProcess.exitCode;
    if (exitCode != 0) {
      addLog('Warning: sdkmanager exited with code $exitCode');
    }

    // Ensure permissions on platform-tools and emulator on macOS/Linux
    if (!Platform.isWindows) {
      final adbFile = File(p.join(sdkPath, 'platform-tools', 'adb'));
      if (await adbFile.exists()) {
        await Process.run('chmod', ['+x', adbFile.path]);
      }
      final emuFile = File(p.join(sdkPath, 'emulator', 'emulator'));
      if (await emuFile.exists()) {
        await Process.run('chmod', ['+x', emuFile.path]);
      }
    }

    // Step 6: Create default AVD
    yield SdkInstallProgress(
      step: SdkInstallStep.creatingAvd,
      currentStepIndex: 6,
      totalSteps: totalSteps,
      description: 'Creating initial Android Virtual Device (AVD)...',
      logs: logs,
    );

    final finalAvdName = avdName ?? 'Pixel_7_API_$apiLevel';
    addLog('Creating AVD: $finalAvdName with image $systemImagePkg');

    // Launch avdmanager and pipe 'no' to stdin so it doesn't hang on:
    // "Do you wish to create a custom hardware profile? [no]"
    final createAvdProc = await Process.start(
      canonicalAvdManager.path,
      [
        'create',
        'avd',
        '-n',
        finalAvdName,
        '-k',
        systemImagePkg,
        '--device',
        'pixel_7',
        '--force',
      ],
      environment: env,
      runInShell: Platform.isWindows,
    );

    // Bypass interactive hardware profile prompt immediately
    createAvdProc.stdin.writeln('no');
    await createAvdProc.stdin.flush();
    await createAvdProc.stdin.close();

    final stdoutBuf = StringBuffer();
    final stderrBuf = StringBuffer();
    createAvdProc.stdout.transform(utf8.decoder).listen((data) => stdoutBuf.write(data));
    createAvdProc.stderr.transform(utf8.decoder).listen((data) => stderrBuf.write(data));

    final avdExitCode = await createAvdProc.exitCode.timeout(
      const Duration(minutes: 2),
      onTimeout: () {
        createAvdProc.kill();
        return -1;
      },
    );

    addLog(stdoutBuf.toString().trim());
    if (avdExitCode != 0 && stderrBuf.isNotEmpty) {
      addLog('avdmanager notice: ${stderrBuf.toString().trim()}');
    }

    // Write optimal config.ini
    final avdHome = PlatformPaths.defaultAvdHome();
    final avdConfig = File(p.join(avdHome, '$finalAvdName.avd', 'config.ini'));
    if (await avdConfig.exists()) {
      try {
        final content = await avdConfig.readAsString();
        final updated = StringBuffer(content);
        if (!content.contains('hw.ramSize')) {
          updated.writeln('hw.ramSize = 4096');
        }
        if (!content.contains('hw.keyboard')) {
          updated.writeln('hw.keyboard = yes');
        }
        if (!content.contains('hw.gpu.enabled')) {
          updated.writeln('hw.gpu.enabled = yes');
          updated.writeln('hw.gpu.mode = auto');
        }
        await avdConfig.writeAsString(updated.toString());
        addLog('Customized AVD hardware configuration (4096MB RAM, hardware keyboard, GPU auto).');
      } catch (_) {}
    }

    addLog('Android standalone environment setup complete! You are ready to launch.');
    yield SdkInstallProgress(
      step: SdkInstallStep.completed,
      currentStepIndex: 6,
      totalSteps: totalSteps,
      description: 'Setup successfully completed!',
      logs: logs,
    );
  }

  /// Locates the `sdkmanager` executable within the given SDK root.
  File? findSdkManager(String sdkRoot) {
    final exe = Platform.isWindows ? 'sdkmanager.bat' : 'sdkmanager';
    final candidates = [
      p.join(sdkRoot, 'cmdline-tools', 'latest', 'bin', exe),
      p.join(sdkRoot, 'cmdline-tools', 'bin', exe),
      p.join(sdkRoot, 'tools', 'bin', exe),
    ];
    for (final c in candidates) {
      final f = File(c);
      if (f.existsSync()) return f;
    }
    final cmdlineDir = Directory(p.join(sdkRoot, 'cmdline-tools'));
    if (cmdlineDir.existsSync()) {
      try {
        for (final entry in cmdlineDir.listSync()) {
          if (entry is Directory) {
            final f = File(p.join(entry.path, 'bin', exe));
            if (f.existsSync()) return f;
          }
        }
      } catch (_) {}
    }
    return null;
  }

  /// Checks if a system image package is already downloaded on disk in the SDK.
  /// Format: `system-images;android-<api>;google_apis;<abi>`
  bool isSystemImageInstalled({
    required String sdkRoot,
    required String systemImagePkg,
  }) {
    final parts = systemImagePkg.split(';');
    if (parts.length >= 4) {
      final apiFolder = parts[1];
      final variantFolder = parts[2];
      final abiFolder = parts[3];
      final dir = Directory(p.join(sdkRoot, 'system-images', apiFolder, variantFolder, abiFolder));
      return dir.existsSync();
    }
    return false;
  }

  /// Downloads and installs a system image package using `sdkmanager` without Android Studio.
  Future<void> installSystemImagePackage({
    required String sdkRoot,
    required String javaHome,
    required String package,
    void Function(String message)? onProgress,
  }) async {
    final sdkManagerFile = findSdkManager(sdkRoot);
    if (sdkManagerFile == null) {
      throw StateError('sdkmanager executable not found in $sdkRoot');
    }

    final env = Map<String, String>.from(Platform.environment);
    env['JAVA_HOME'] = javaHome;
    env['ANDROID_HOME'] = sdkRoot;
    env['ANDROID_SDK_ROOT'] = sdkRoot;

    // Ensure licenses are accepted
    await writeSdkLicenses(Directory(sdkRoot));

    onProgress?.call('Starting download of $package via sdkmanager...');
    final proc = await Process.start(
      sdkManagerFile.path,
      [
        '--install',
        package,
        '--sdk_root=$sdkRoot',
      ],
      environment: env,
      runInShell: Platform.isWindows,
    );

    proc.stdin.writeln('y');
    await proc.stdin.flush();
    await proc.stdin.close();

    final lines = proc.stdout.transform(utf8.decoder).transform(const LineSplitter());
    await for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty) {
        onProgress?.call(trimmed);
      }
    }

    final exitCode = await proc.exitCode;
    if (exitCode != 0) {
      throw ProcessException(
        sdkManagerFile.path,
        ['--install', package],
        'sdkmanager install failed with exit code $exitCode',
        exitCode,
      );
    }
  }

  /// Create an AVD manually using avdmanager.
  Future<void> createCustomAvd({
    required String avdManagerPath,
    required String javaHome,
    required String sdkRoot,
    required String name,
    required String systemImage,
    String device = 'pixel_7',
    int ramMb = 4096,
  }) async {
    final env = Map<String, String>.from(Platform.environment);
    env['JAVA_HOME'] = javaHome;
    env['ANDROID_HOME'] = sdkRoot;
    env['ANDROID_SDK_ROOT'] = sdkRoot;

    final proc = await Process.start(
      avdManagerPath,
      [
        'create',
        'avd',
        '-n',
        name,
        '-k',
        systemImage,
        '--device',
        device,
        '--force',
      ],
      environment: env,
      runInShell: Platform.isWindows,
    );

    // Bypass interactive hardware profile question
    proc.stdin.writeln('no');
    await proc.stdin.flush();
    await proc.stdin.close();

    final stdoutBuf = StringBuffer();
    final stderrBuf = StringBuffer();
    proc.stdout.transform(utf8.decoder).listen((data) => stdoutBuf.write(data));
    proc.stderr.transform(utf8.decoder).listen((data) => stderrBuf.write(data));

    final exitCode = await proc.exitCode.timeout(
      const Duration(minutes: 2),
      onTimeout: () {
        proc.kill();
        return -1;
      },
    );

    if (exitCode != 0) {
      final err = stderrBuf.toString().trim().isNotEmpty
          ? stderrBuf.toString().trim()
          : stdoutBuf.toString().trim();
      throw ProcessException(avdManagerPath, ['create', 'avd'], err, exitCode);
    }

    // Enhance config.ini
    final avdHome = PlatformPaths.defaultAvdHome();
    final avdConfig = File(p.join(avdHome, '$name.avd', 'config.ini'));
    if (await avdConfig.exists()) {
      try {
        final lines = await avdConfig.readAsLines();
        final map = <String, String>{};
        for (final line in lines) {
          final idx = line.indexOf('=');
          if (idx != -1) {
            map[line.substring(0, idx).trim()] = line.substring(idx + 1).trim();
          }
        }
        map['hw.ramSize'] = ramMb.toString();
        map['hw.keyboard'] = 'yes';
        map['hw.gpu.enabled'] = 'yes';
        map['hw.gpu.mode'] = 'auto';

        final buffer = StringBuffer();
        for (final entry in map.entries) {
          buffer.writeln('${entry.key} = ${entry.value}');
        }
        await avdConfig.writeAsString(buffer.toString());
      } catch (_) {}
    }
  }
}
