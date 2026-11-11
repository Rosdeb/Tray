import 'package:flutter/cupertino.dart';

enum ProcessCategory {
  emulator(
    label: 'Android Emulators (QEMU)',
    icon: CupertinoIcons.device_phone_portrait,
    description: 'Running Android Virtual Devices and QEMU hypervisor engines',
  ),
  adb(
    label: 'ADB Bridges & Daemons',
    icon: CupertinoIcons.link,
    description: 'Android Debug Bridge server and connected device relays',
  ),
  javaGradle(
    label: 'Java & Gradle Daemons',
    icon: CupertinoIcons.layers_alt_fill,
    description: 'Background build servers, JDK runtimes, and Gradle workers',
  ),
  scrcpy(
    label: 'Screen Mirroring (scrcpy)',
    icon: CupertinoIcons.tv,
    description: 'Active USB/TCP screen mirroring sessions',
  ),
  other(
    label: 'Other Android SDK Tools',
    icon: CupertinoIcons.square_stack_3d_up_fill,
    description: 'SDK manager, AVD manager, or platform utility background tasks',
  );

  const ProcessCategory({
    required this.label,
    required this.icon,
    required this.description,
  });

  final String label;
  final IconData icon;
  final String description;
}

class SystemProcessItem {
  const SystemProcessItem({
    required this.pid,
    required this.name,
    required this.category,
    this.cpuPercent = 0.0,
    this.memoryBytes = 0,
    this.commandLine = '',
  });

  final int pid;
  final String name;
  final ProcessCategory category;
  final double cpuPercent;
  final int memoryBytes;
  final String commandLine;

  String get formattedMemory {
    if (memoryBytes <= 0) return '0 MB';
    final mb = memoryBytes / (1024 * 1024);
    if (mb >= 1024) {
      return '${(mb / 1024).toStringAsFixed(1)} GB';
    }
    return '${mb.toStringAsFixed(0)} MB';
  }

  String get formattedCpu {
    if (cpuPercent <= 0.0) return '0.0%';
    return '${cpuPercent.toStringAsFixed(1)}%';
  }

  bool matchesQuery(String query) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase();
    return name.toLowerCase().contains(q) ||
        pid.toString().contains(q) ||
        category.label.toLowerCase().contains(q) ||
        commandLine.toLowerCase().contains(q);
  }

  SystemProcessItem copyWith({
    int? pid,
    String? name,
    ProcessCategory? category,
    double? cpuPercent,
    int? memoryBytes,
    String? commandLine,
  }) {
    return SystemProcessItem(
      pid: pid ?? this.pid,
      name: name ?? this.name,
      category: category ?? this.category,
      cpuPercent: cpuPercent ?? this.cpuPercent,
      memoryBytes: memoryBytes ?? this.memoryBytes,
      commandLine: commandLine ?? this.commandLine,
    );
  }
}
