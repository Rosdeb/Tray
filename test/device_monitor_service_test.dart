import 'package:flutter_test/flutter_test.dart';
import 'package:tray/models/device_metrics.dart';
import 'package:tray/services/adb_service.dart';
import 'package:tray/services/device_monitor_service.dart';

void main() {
  group('DeviceMonitorService & Models', () {
    final adbService = AdbService();
    final monitorService = DeviceMonitorService(adbService);

    test('getAvailableTargets always contains Host System', () async {
      final targets = await monitorService.getAvailableTargets(null);
      expect(targets.any((t) => t.id == 'host'), isTrue);
    });

    test('polls host metrics correctly across consecutive ticks', () async {
      // First tick sets baseline ticks
      final tick1 = await monitorService.pollMetrics(
        targetId: 'host',
        targetName: 'Host Machine',
      );

      expect(tick1.targetName, equals('Host Machine'));
      expect(tick1.totalRamBytes, greaterThan(0));
      expect(tick1.usedRamBytes, greaterThan(0));
      expect(tick1.ramUsagePercent, inInclusiveRange(0.0, 100.0));
      expect(tick1.formattedTotalRam, isNotEmpty);
      expect(tick1.formattedUsedRam, isNotEmpty);

      // Short wait to allow ticks to elapse
      await Future.delayed(const Duration(milliseconds: 300));

      // Second tick calculates instantaneous delta
      final tick2 = await monitorService.pollMetrics(
        targetId: 'host',
        targetName: 'Host Machine',
      );

      expect(tick2.cpuPercent, inInclusiveRange(0.0, 100.0));
      expect(tick2.networkRxSpeedKbps, greaterThanOrEqualTo(0.0));
      expect(tick2.networkTxSpeedKbps, greaterThanOrEqualTo(0.0));

      // Test resetDeltas
      monitorService.resetDeltas();
    });

    test('MonitorWidgetConfig toggle and copyWith', () {
      const config = MonitorWidgetConfig();
      expect(config.showCpuChart, isTrue);
      expect(config.refreshIntervalSeconds, equals(2));

      final updated = config.copyWith(
        showCpuChart: false,
        refreshIntervalSeconds: 1,
      );
      expect(updated.showCpuChart, isFalse);
      expect(updated.refreshIntervalSeconds, equals(1));
      expect(updated.showRamGauge, isTrue);
    });
  });
}
