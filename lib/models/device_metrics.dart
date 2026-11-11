class MetricDataPoint {
  const MetricDataPoint({
    required this.timestamp,
    required this.value,
  });

  final DateTime timestamp;
  final double value;
}

class TopProcessItem {
  const TopProcessItem({
    required this.pid,
    required this.name,
    required this.cpuPercent,
    required this.memoryMb,
    this.user = 'system',
  });

  final int pid;
  final String name;
  final double cpuPercent;
  final double memoryMb;
  final String user;
}

class DeviceRealtimeMetrics {
  const DeviceRealtimeMetrics({
    required this.targetName,
    required this.isEmulatorOrDevice,
    this.deviceSerial,
    this.cpuPercent = 0.0,
    this.totalRamBytes = 0,
    this.usedRamBytes = 0,
    this.networkRxSpeedKbps = 0.0,
    this.networkTxSpeedKbps = 0.0,
    this.batteryLevel = 100,
    this.batteryTempC = 25.0,
    this.batteryStatus = 'Discharging',
    this.fps = 60.0,
    this.topProcesses = const <TopProcessItem>[],
    required this.timestamp,
  });

  final String targetName;
  final bool isEmulatorOrDevice;
  final String? deviceSerial;
  final double cpuPercent;
  final int totalRamBytes;
  final int usedRamBytes;
  final double networkRxSpeedKbps;
  final double networkTxSpeedKbps;
  final int batteryLevel;
  final double batteryTempC;
  final String batteryStatus;
  final double fps;
  final List<TopProcessItem> topProcesses;
  final DateTime timestamp;

  double get ramUsagePercent {
    if (totalRamBytes <= 0) return 0.0;
    return (usedRamBytes / totalRamBytes) * 100.0;
  }

  String get formattedTotalRam {
    final gb = totalRamBytes / (1024 * 1024 * 1024);
    if (gb >= 1.0) return '${gb.toStringAsFixed(1)} GB';
    return '${(totalRamBytes / (1024 * 1024)).toStringAsFixed(0)} MB';
  }

  String get formattedUsedRam {
    final gb = usedRamBytes / (1024 * 1024 * 1024);
    if (gb >= 1.0) return '${gb.toStringAsFixed(1)} GB';
    return '${(usedRamBytes / (1024 * 1024)).toStringAsFixed(0)} MB';
  }
}

class MonitorWidgetConfig {
  const MonitorWidgetConfig({
    this.showCpuChart = true,
    this.showRamGauge = true,
    this.showNetworkTraffic = true,
    this.showBatteryThermal = true,
    this.showTopProcesses = true,
    this.showDisplayFps = true,
    this.refreshIntervalSeconds = 2,
  });

  final bool showCpuChart;
  final bool showRamGauge;
  final bool showNetworkTraffic;
  final bool showBatteryThermal;
  final bool showTopProcesses;
  final bool showDisplayFps;
  final int refreshIntervalSeconds;

  MonitorWidgetConfig copyWith({
    bool? showCpuChart,
    bool? showRamGauge,
    bool? showNetworkTraffic,
    bool? showBatteryThermal,
    bool? showTopProcesses,
    bool? showDisplayFps,
    int? refreshIntervalSeconds,
  }) {
    return MonitorWidgetConfig(
      showCpuChart: showCpuChart ?? this.showCpuChart,
      showRamGauge: showRamGauge ?? this.showRamGauge,
      showNetworkTraffic: showNetworkTraffic ?? this.showNetworkTraffic,
      showBatteryThermal: showBatteryThermal ?? this.showBatteryThermal,
      showTopProcesses: showTopProcesses ?? this.showTopProcesses,
      showDisplayFps: showDisplayFps ?? this.showDisplayFps,
      refreshIntervalSeconds: refreshIntervalSeconds ?? this.refreshIntervalSeconds,
    );
  }
}
