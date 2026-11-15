import 'package:flutter_test/flutter_test.dart';
import 'package:tray/services/adb_wireless_service.dart';

void main() {
  group('AdbWirelessService IPv4 validation', () {
    test('accepts valid IPv4 addresses', () {
      expect(AdbWirelessService.isValidIpv4('192.168.1.1'), isTrue);
      expect(AdbWirelessService.isValidIpv4('10.0.0.15'), isTrue);
      expect(AdbWirelessService.isValidIpv4('172.16.254.1'), isTrue);
      expect(AdbWirelessService.isValidIpv4('0.0.0.0'), isTrue);
      expect(AdbWirelessService.isValidIpv4('255.255.255.255'), isTrue);
    });

    test('rejects invalid IPv4 addresses', () {
      expect(AdbWirelessService.isValidIpv4(''), isFalse);
      expect(AdbWirelessService.isValidIpv4('   '), isFalse);
      expect(AdbWirelessService.isValidIpv4('192.168.1'), isFalse);
      expect(AdbWirelessService.isValidIpv4('192.168.1.1.1'), isFalse);
      expect(AdbWirelessService.isValidIpv4('192.168.1.256'), isFalse);
      expect(AdbWirelessService.isValidIpv4('-1.0.0.1'), isFalse);
      expect(AdbWirelessService.isValidIpv4('192.168.1.abc'), isFalse);
      expect(AdbWirelessService.isValidIpv4('192.168. 1.1'), isFalse);
    });
  });

  group('AdbWirelessService validation guards', () {
    const service = AdbWirelessService();

    test('connect returns early error on invalid IP without spawning process', () async {
      final result = await service.connect('non_existent_adb_path', 'invalid_ip');
      expect(result.success, isFalse);
      expect(result.message, contains('Invalid IP address format'));
    });

    test('pair returns early error on invalid IP without spawning process', () async {
      final result = await service.pair('non_existent_adb_path', 'bad_ip', 5555, '123456');
      expect(result.success, isFalse);
      expect(result.message, contains('Invalid IP address'));
    });

    test('pair returns early error when pairing code is not 6 digits', () async {
      final shortCode = await service.pair('non_existent_adb_path', '192.168.1.50', 5555, '12345');
      expect(shortCode.success, isFalse);
      expect(shortCode.message, contains('Pairing code must be a 6-digit number'));

      final nonNumeric = await service.pair('non_existent_adb_path', '192.168.1.50', 5555, 'abcdef');
      expect(nonNumeric.success, isFalse);
      expect(nonNumeric.message, contains('Pairing code must be a 6-digit number'));

      final longCode = await service.pair('non_existent_adb_path', '192.168.1.50', 5555, '1234567');
      expect(longCode.success, isFalse);
      expect(longCode.message, contains('Pairing code must be a 6-digit number'));
    });
  });

  group('AdbWirelessResult model', () {
    test('instantiates with expected default values', () {
      const result = AdbWirelessResult(success: true);
      expect(result.success, isTrue);
      expect(result.ip, isNull);
      expect(result.port, 5555);
      expect(result.message, isNull);
    });

    test('instantiates with custom parameters', () {
      const result = AdbWirelessResult(
        success: true,
        ip: '192.168.1.100',
        port: 4321,
        message: 'Connected successfully',
      );
      expect(result.success, isTrue);
      expect(result.ip, '192.168.1.100');
      expect(result.port, 4321);
      expect(result.message, 'Connected successfully');
    });
  });
}
