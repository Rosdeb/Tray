import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/device_metrics.dart';
import '../../providers/app_providers.dart';
import '../../widgets/monitor_sparkline_painter.dart';

class MonitorScreen extends ConsumerStatefulWidget {
  const MonitorScreen({super.key});

  @override
  ConsumerState<MonitorScreen> createState() => _MonitorScreenState();
}

class _MonitorScreenState extends ConsumerState<MonitorScreen> {
  DeviceMonitorController? _monitorController;

  @override
  void initState() {
    super.initState();
    _monitorController = ref.read(deviceMonitorControllerProvider.notifier);
    Future.microtask(() {
      if (mounted) {
        _monitorController?.resumePolling();
      }
    });
  }

  @override
  void dispose() {
    _monitorController?.pausePolling();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(deviceMonitorControllerProvider);
    final controller = ref.read(deviceMonitorControllerProvider.notifier);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final metrics = state.currentMetrics;
    final config = state.config;

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Header Bar
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 780;

              if (isCompact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Real-Time Device Monitor',
                            style: theme.textTheme.headlineSmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 10),
                        _LiveBadge(isLive: !state.isPaused),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Real-time telemetry, CPU/RAM waveform analysis, and network traffic monitor.',
                      style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTargetDropdown(context, state, controller, colorScheme, theme),
                        ),
                        const SizedBox(width: 8),
                        IconButton.outlined(
                          tooltip: state.isPaused ? 'Resume monitoring' : 'Pause monitoring',
                          onPressed: () => controller.togglePause(),
                          icon: Icon(
                            state.isPaused ? CupertinoIcons.play_fill : CupertinoIcons.pause_fill,
                            color: state.isPaused ? Colors.green : Colors.orange,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.tonalIcon(
                          onPressed: () => _showCustomizeWidgetsDialog(context, config, controller),
                          icon: const Icon(CupertinoIcons.slider_horizontal_3, size: 16),
                          label: const Text('Customize', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ],
                );
              }

              return Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Flexible(
                              child: Text(
                                'Real-Time Device Monitor',
                                style: theme.textTheme.headlineSmall,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 12),
                            _LiveBadge(isLive: !state.isPaused),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Real-time telemetry, CPU/RAM waveform analysis, and network traffic monitor.',
                          style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),

                  _buildTargetDropdown(context, state, controller, colorScheme, theme),

                  const SizedBox(width: 8),

                  // Pause / Play
                  IconButton.outlined(
                    tooltip: state.isPaused ? 'Resume monitoring' : 'Pause monitoring',
                    onPressed: () => controller.togglePause(),
                    icon: Icon(
                      state.isPaused ? CupertinoIcons.play_fill : CupertinoIcons.pause_fill,
                      color: state.isPaused ? Colors.green : Colors.orange,
                      size: 20,
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Customize Widgets Button
                  FilledButton.tonalIcon(
                    onPressed: () => _showCustomizeWidgetsDialog(context, config, controller),
                    icon: const Icon(CupertinoIcons.slider_horizontal_3, size: 16),
                    label: const Text('Customize Widgets', style: TextStyle(fontSize: 12)),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 20),

          // Content Area (Scrollable Widgets Grid)
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final stackVertical = constraints.maxWidth < 820;

                return ListView(
                  children: <Widget>[
                    // Row 1: CPU Waveform & RAM Gauge
                    if (config.showCpuChart || config.showRamGauge)
                      if (stackVertical) ...[
                        if (config.showCpuChart)
                          _CpuWaveformCard(
                            cpuPercent: metrics?.cpuPercent ?? 0.0,
                            history: state.cpuHistory,
                          ),
                        if (config.showCpuChart && config.showRamGauge)
                          const SizedBox(height: 16),
                        if (config.showRamGauge)
                          _RamUtilizationCard(
                            metrics: metrics,
                            history: state.ramHistory,
                          ),
                      ] else
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            if (config.showCpuChart)
                              Expanded(
                                flex: 3,
                                child: _CpuWaveformCard(
                                  cpuPercent: metrics?.cpuPercent ?? 0.0,
                                  history: state.cpuHistory,
                                ),
                              ),
                            if (config.showCpuChart && config.showRamGauge)
                              const SizedBox(width: 16),
                            if (config.showRamGauge)
                              Expanded(
                                flex: 2,
                                child: _RamUtilizationCard(
                                  metrics: metrics,
                                  history: state.ramHistory,
                                ),
                              ),
                          ],
                        ),

                    if (config.showCpuChart || config.showRamGauge)
                      const SizedBox(height: 16),

                    // Row 2: Network Traffic & Battery/Thermal
                    if (config.showNetworkTraffic || config.showBatteryThermal)
                      if (stackVertical) ...[
                        if (config.showNetworkTraffic)
                          _NetworkTrafficCard(
                            rxSpeed: metrics?.networkRxSpeedKbps ?? 0.0,
                            txSpeed: metrics?.networkTxSpeedKbps ?? 0.0,
                            rxHistory: state.rxHistory,
                            txHistory: state.txHistory,
                            isDevice: metrics?.isEmulatorOrDevice == true,
                          ),
                        if (config.showNetworkTraffic && config.showBatteryThermal)
                          const SizedBox(height: 16),
                        if (config.showBatteryThermal)
                          _BatteryThermalCard(
                            metrics: metrics,
                          ),
                      ] else
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            if (config.showNetworkTraffic)
                              Expanded(
                                flex: 3,
                                child: _NetworkTrafficCard(
                                  rxSpeed: metrics?.networkRxSpeedKbps ?? 0.0,
                                  txSpeed: metrics?.networkTxSpeedKbps ?? 0.0,
                                  rxHistory: state.rxHistory,
                                  txHistory: state.txHistory,
                                  isDevice: metrics?.isEmulatorOrDevice == true,
                                ),
                              ),
                            if (config.showNetworkTraffic && config.showBatteryThermal)
                              const SizedBox(width: 16),
                            if (config.showBatteryThermal)
                              Expanded(
                                flex: 2,
                                child: _BatteryThermalCard(
                                  metrics: metrics,
                                ),
                              ),
                          ],
                        ),

                    if (config.showNetworkTraffic || config.showBatteryThermal)
                      const SizedBox(height: 16),

                    // Row 3: Top Processes & Display Telemetry
                    if (config.showTopProcesses || config.showDisplayFps)
                      if (stackVertical) ...[
                        if (config.showTopProcesses)
                          _TopProcessesCard(
                            processes: metrics?.topProcesses ?? const [],
                            isDevice: metrics?.isEmulatorOrDevice == true,
                          ),
                        if (config.showTopProcesses && config.showDisplayFps)
                          const SizedBox(height: 16),
                        if (config.showDisplayFps)
                          _DisplayFpsCard(
                            fps: metrics?.fps ?? 60.0,
                            isDevice: metrics?.isEmulatorOrDevice == true,
                          ),
                      ] else
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            if (config.showTopProcesses)
                              Expanded(
                                flex: 3,
                                child: _TopProcessesCard(
                                  processes: metrics?.topProcesses ?? const [],
                                  isDevice: metrics?.isEmulatorOrDevice == true,
                                ),
                              ),
                            if (config.showTopProcesses && config.showDisplayFps)
                              const SizedBox(width: 16),
                            if (config.showDisplayFps)
                              Expanded(
                                flex: 2,
                                child: _DisplayFpsCard(
                                  fps: metrics?.fps ?? 60.0,
                                  isDevice: metrics?.isEmulatorOrDevice == true,
                                ),
                              ),
                          ],
                        ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTargetDropdown(
    BuildContext context,
    DeviceMonitorState state,
    DeviceMonitorController controller,
    ColorScheme colorScheme,
    ThemeData theme,
  ) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isDense: true,
          isExpanded: true,
          value: state.selectedTargetId,
          icon: Icon(CupertinoIcons.chevron_down, size: 16, color: colorScheme.onSurfaceVariant),
          focusColor: Colors.transparent,
          dropdownColor: colorScheme.surface,
          borderRadius: BorderRadius.circular(10),
          onChanged: (id) {
            if (id != null) {
              final target = state.targets.firstWhere((t) => t.id == id);
              controller.setTarget(target.id, target.displayName);
            }
          },
          items: state.targets.map((target) {
            return DropdownMenuItem<String>(
              value: target.id,
              child: Row(
                children: [
                  Icon(
                    target.isEmulator ? CupertinoIcons.device_phone_portrait : CupertinoIcons.device_desktop,
                    size: 16,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      target.displayName,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showCustomizeWidgetsDialog(
    BuildContext context,
    MonitorWidgetConfig config,
    DeviceMonitorController controller,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        var cur = config;
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(CupertinoIcons.slider_horizontal_3),
                  SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      'Customize Monitor Widgets',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 440,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Personalize your real-time telemetry dashboard by choosing which performance widgets to display.',
                        style: TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      _buildToggleOption(
                        icon: CupertinoIcons.speedometer,
                        title: 'Live CPU Load & Waveform Chart',
                        subtitle: 'Real-time rolling CPU history curve',
                        value: cur.showCpuChart,
                        onChanged: (v) => setModalState(() => cur = cur.copyWith(showCpuChart: v)),
                        colorScheme: colorScheme,
                      ),
                      _buildToggleOption(
                        icon: CupertinoIcons.waveform_path_ecg,
                        title: 'RAM Usage & Memory Breakdown',
                        subtitle: 'Used vs Free RAM with saturation gauge',
                        value: cur.showRamGauge,
                        onChanged: (v) => setModalState(() => cur = cur.copyWith(showRamGauge: v)),
                        colorScheme: colorScheme,
                      ),
                      _buildToggleOption(
                        icon: CupertinoIcons.arrow_right_arrow_left,
                        title: 'Network I/O & Bandwidth (RX / TX)',
                        subtitle: 'Real-time upload and download speeds',
                        value: cur.showNetworkTraffic,
                        onChanged: (v) => setModalState(() => cur = cur.copyWith(showNetworkTraffic: v)),
                        colorScheme: colorScheme,
                      ),
                      _buildToggleOption(
                        icon: CupertinoIcons.battery_charging,
                        title: 'Battery & Thermal State',
                        subtitle: 'Battery level, temperature, and charging status',
                        value: cur.showBatteryThermal,
                        onChanged: (v) => setModalState(() => cur = cur.copyWith(showBatteryThermal: v)),
                        colorScheme: colorScheme,
                      ),
                      _buildToggleOption(
                        icon: CupertinoIcons.chart_bar_alt_fill,
                        title: 'Top Active Processes',
                        subtitle: 'Processes consuming CPU on target',
                        value: cur.showTopProcesses,
                        onChanged: (v) => setModalState(() => cur = cur.copyWith(showTopProcesses: v)),
                        colorScheme: colorScheme,
                      ),
                      _buildToggleOption(
                        icon: CupertinoIcons.tv,
                        title: 'Display & Refresh Telemetry (FPS)',
                        subtitle: 'Estimated frame rendering rates and state',
                        value: cur.showDisplayFps,
                        onChanged: (v) => setModalState(() => cur = cur.copyWith(showDisplayFps: v)),
                        colorScheme: colorScheme,
                      ),
                      const SizedBox(height: 8),
                      const Divider(),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Flexible(
                            child: Text(
                              'Refresh Rate: ',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          SegmentedButton<int>(
                            style: const ButtonStyle(
                              visualDensity: VisualDensity.compact,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            segments: const [
                              ButtonSegment(value: 1, label: Text('1s', style: TextStyle(fontSize: 11))),
                              ButtonSegment(value: 2, label: Text('2s', style: TextStyle(fontSize: 11))),
                              ButtonSegment(value: 5, label: Text('5s', style: TextStyle(fontSize: 11))),
                            ],
                            selected: {cur.refreshIntervalSeconds},
                            onSelectionChanged: (s) => setModalState(() => cur = cur.copyWith(refreshIntervalSeconds: s.first)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    controller.setConfig(cur);
                    Navigator.pop(ctx);
                  },
                  child: const Text('Apply Changes'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildToggleOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required ColorScheme colorScheme,
  }) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        child: Row(
          children: [
            Icon(icon, size: 18, color: value ? colorScheme.primary : colorScheme.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Transform.scale(
              scale: 0.72,
              child: Switch(
                value: value,
                onChanged: onChanged,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge({required this.isLive});
  final bool isLive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (isLive ? Colors.green : Colors.orange).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: (isLive ? Colors.green : Colors.orange).withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isLive ? Colors.green : Colors.orange,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isLive ? 'LIVE STREAMING' : 'PAUSED',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isLive ? Colors.green.shade800 : Colors.orange.shade800,
            ),
          ),
        ],
      ),
    );
  }
}

class _CpuWaveformCard extends StatelessWidget {
  const _CpuWaveformCard({
    required this.cpuPercent,
    required this.history,
  });

  final double cpuPercent;
  final List<MetricDataPoint> history;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final color = cpuPercent > 75
        ? Colors.red
        : cpuPercent > 40
            ? Colors.orange
            : Colors.green;

    return Container(
      height: 210,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(CupertinoIcons.speedometer, color: color, size: 20),
              const SizedBox(width: 8),
              const Flexible(
                child: Text(
                  'CPU Utilization',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${cpuPercent.toStringAsFixed(1)}%',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CustomPaint(
                painter: MonitorSparklinePainter(
                  data: history,
                  lineColor: color,
                  fillGradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      color.withValues(alpha: 0.35),
                      color.withValues(alpha: 0.0),
                    ],
                  ),
                  maxValue: 100.0,
                  minValue: 0.0,
                ),
                child: Container(),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('30s ago', style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant)),
              Text('Rolling CPU load', style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant)),
              Text('Now', style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant)),
            ],
          ),
        ],
      ),
    );
  }
}

class _RamUtilizationCard extends StatelessWidget {
  const _RamUtilizationCard({
    required this.metrics,
    required this.history,
  });

  final DeviceRealtimeMetrics? metrics;
  final List<MetricDataPoint> history;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final percent = metrics?.ramUsagePercent ?? 0.0;
    const color = Colors.blue;

    return Container(
      height: 210,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(CupertinoIcons.waveform_path_ecg, color: color, size: 20),
              const SizedBox(width: 8),
              const Flexible(
                child: Text(
                  'Memory (RAM)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${percent.toStringAsFixed(1)}%',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Used: ${metrics?.formattedUsedRam ?? "0 MB"}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Total: ${metrics?.formattedTotalRam ?? "0 MB"}',
                  style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: percent / 100.0,
              minHeight: 10,
              backgroundColor: color.withValues(alpha: 0.15),
              valueColor: const AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CustomPaint(
                painter: MonitorSparklinePainter(
                  data: history,
                  lineColor: color,
                  fillGradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      color.withValues(alpha: 0.3),
                      color.withValues(alpha: 0.0),
                    ],
                  ),
                  maxValue: 100.0,
                  minValue: 0.0,
                ),
                child: Container(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NetworkTrafficCard extends StatelessWidget {
  const _NetworkTrafficCard({
    required this.rxSpeed,
    required this.txSpeed,
    required this.rxHistory,
    required this.txHistory,
    required this.isDevice,
  });

  final double rxSpeed;
  final double txSpeed;
  final List<MetricDataPoint> rxHistory;
  final List<MetricDataPoint> txHistory;
  final bool isDevice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      height: 190,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(CupertinoIcons.arrow_right_arrow_left, color: Colors.teal, size: 20),
              const SizedBox(width: 8),
              const Flexible(
                child: Text(
                  'Network Bandwidth I/O',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '↓ ${_formatSpeed(rxSpeed)}',
                  style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '↑ ${_formatSpeed(txSpeed)}',
                  style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CustomPaint(
                painter: MonitorSparklinePainter(
                  data: rxHistory,
                  lineColor: Colors.teal,
                  fillGradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.teal.withValues(alpha: 0.3),
                      Colors.teal.withValues(alpha: 0.0),
                    ],
                  ),
                  maxValue: 500.0,
                  minValue: 0.0,
                  unit: 'KB/s',
                ),
                child: Container(),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isDevice ? 'Live telemetry from /proc/net/dev' : 'Live telemetry from host network adapter',
            style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  String _formatSpeed(double kbps) {
    if (kbps >= 1024) {
      return '${(kbps / 1024).toStringAsFixed(1)} MB/s';
    }
    return '${kbps.toStringAsFixed(1)} KB/s';
  }
}

class _BatteryThermalCard extends StatelessWidget {
  const _BatteryThermalCard({required this.metrics});
  final DeviceRealtimeMetrics? metrics;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final lvl = metrics?.batteryLevel ?? 100;
    final temp = metrics?.batteryTempC ?? 26.0;

    return Container(
      height: 190,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(CupertinoIcons.battery_charging, color: Colors.amber, size: 20),
              SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Battery & Thermals',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Text('$lvl%', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.amber)),
                  const SizedBox(height: 4),
                  Text(metrics?.batteryStatus ?? 'Connected', style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
                ],
              ),
              Container(width: 1, height: 40, color: theme.dividerColor),
              Column(
                children: [
                  Text('${temp.toStringAsFixed(1)}°C', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                  const SizedBox(height: 4),
                  const Text('Optimal Temp', style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(CupertinoIcons.thermometer, size: 16, color: Colors.deepOrange),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    temp < 40.0 ? 'Thermals: Normal / Safe' : 'Thermals: Elevated',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopProcessesCard extends StatelessWidget {
  const _TopProcessesCard({
    required this.processes,
    required this.isDevice,
  });

  final List<TopProcessItem> processes;
  final bool isDevice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      height: 230,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(CupertinoIcons.chart_bar_alt_fill, color: Colors.indigo, size: 20),
              const SizedBox(width: 8),
              const Text('Active Device Processes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const Spacer(),
              Text('${processes.length} active', style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: processes.isEmpty
              ? Center(
                  child: Text(
                    isDevice ? 'Loading active processes...' : 'Select a running emulator to view live process telemetry.',
                    style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                  ),
                )
              : ListView.separated(
                  itemCount: processes.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (ctx, index) {
                    final p = processes[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${p.pid}',
                              style: const TextStyle(fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              p.name,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${p.cpuPercent.toStringAsFixed(1)}% CPU',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.indigo),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '${p.memoryMb.toStringAsFixed(0)} MB',
                            style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }
}

class _DisplayFpsCard extends StatelessWidget {
  const _DisplayFpsCard({required this.fps, required this.isDevice});
  final double fps;
  final bool isDevice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      height: 230,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(CupertinoIcons.tv, color: Colors.purple, size: 20),
              SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Display & Frame Latency',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Center(
            child: Column(
              children: [
                Text(
                  '${fps.toStringAsFixed(0)} FPS',
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.purple),
                ),
                const SizedBox(height: 4),
                const Text('Smooth 60Hz Render Cadence', style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    'Render Target',
                    style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    isDevice ? 'QEMU OpenGL ES' : 'Host Display',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
