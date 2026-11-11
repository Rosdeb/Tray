class AndroidSdk {
  const AndroidSdk({
    required this.path,
    required this.emulatorPath,
    required this.adbPath,
    this.sdkManagerPath,
    this.avdManagerPath,
    this.javaHome,
    this.version,
  });

  final String path;
  final String emulatorPath;
  final String adbPath;
  final String? sdkManagerPath;
  final String? avdManagerPath;
  final String? javaHome;
  final String? version;

  bool get hasEmulator => emulatorPath.isNotEmpty;
  bool get hasAdb => adbPath.isNotEmpty;
  bool get hasCmdlineTools =>
      sdkManagerPath != null &&
      sdkManagerPath!.isNotEmpty &&
      avdManagerPath != null &&
      avdManagerPath!.isNotEmpty;

  AndroidSdk copyWith({
    String? path,
    String? emulatorPath,
    String? adbPath,
    String? sdkManagerPath,
    String? avdManagerPath,
    String? javaHome,
    String? version,
  }) {
    return AndroidSdk(
      path: path ?? this.path,
      emulatorPath: emulatorPath ?? this.emulatorPath,
      adbPath: adbPath ?? this.adbPath,
      sdkManagerPath: sdkManagerPath ?? this.sdkManagerPath,
      avdManagerPath: avdManagerPath ?? this.avdManagerPath,
      javaHome: javaHome ?? this.javaHome,
      version: version ?? this.version,
    );
  }
}
