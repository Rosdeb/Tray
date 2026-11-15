import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/emulator.dart';
import '../providers/app_providers.dart';

class WirelessConnectDialog extends ConsumerStatefulWidget {
  const WirelessConnectDialog({super.key});

  @override
  ConsumerState<WirelessConnectDialog> createState() => _WirelessConnectDialogState();
}

class _WirelessConnectDialogState extends ConsumerState<WirelessConnectDialog> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _portController = TextEditingController(text: '5555');

  // Android 11+ Pairing controllers
  final TextEditingController _pairIpController = TextEditingController();
  final TextEditingController _pairPortController = TextEditingController();
  final TextEditingController _pairCodeController = TextEditingController();

  bool _isLoading = false;
  String? _statusMessage;
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _ipController.dispose();
    _portController.dispose();
    _pairIpController.dispose();
    _pairPortController.dispose();
    _pairCodeController.dispose();
    super.dispose();
  }

  Future<void> _handleSwitchUsbToWifi(Emulator emulator) async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Switching ${emulator.displayName} to Wi-Fi mode...';
      _isSuccess = false;
    });

    final res = await ref.read(emulatorControllerProvider.notifier).switchDeviceToWifi(emulator);

    if (mounted) {
      setState(() {
        _isLoading = false;
        _isSuccess = res.success;
        _statusMessage = res.message ?? (res.success ? 'Connected wirelessly!' : 'Failed to connect');
      });
      if (res.success) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.of(context).pop();
        });
      }
    }
  }

  Future<void> _handleDirectConnect() async {
    final ip = _ipController.text.trim();
    final port = int.tryParse(_portController.text.trim()) ?? 5555;

    if (ip.isEmpty) {
      setState(() {
        _statusMessage = 'Please enter an IP address';
        _isSuccess = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Connecting to $ip:$port...';
      _isSuccess = false;
    });

    final res = await ref.read(emulatorControllerProvider.notifier).connectWireless(ip, port: port);

    if (mounted) {
      setState(() {
        _isLoading = false;
        _isSuccess = res.success;
        _statusMessage = res.message ?? (res.success ? 'Connected!' : 'Connection failed');
      });
      if (res.success) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.of(context).pop();
        });
      }
    }
  }

  Future<void> _handlePairAndConnect() async {
    final ip = _pairIpController.text.trim();
    final pairPort = int.tryParse(_pairPortController.text.trim());
    final code = _pairCodeController.text.trim();

    if (ip.isEmpty || pairPort == null || code.isEmpty) {
      setState(() {
        _statusMessage = 'Please fill in IP address, pairing port, and 6-digit code';
        _isSuccess = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Pairing with device at $ip:$pairPort...';
      _isSuccess = false;
    });

    final pairRes = await ref.read(emulatorControllerProvider.notifier).pairWirelessDevice(ip, pairPort, code);

    if (!pairRes.success) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isSuccess = false;
          _statusMessage = pairRes.message ?? 'Pairing failed. Ensure code and port match phone.';
        });
      }
      return;
    }

    // After pairing, connect to standard ADB port (usually 5555 or pairPort)
    if (mounted) {
      setState(() {
        _statusMessage = 'Paired successfully! Connecting to $ip:5555...';
      });
    }

    final connectRes = await ref.read(emulatorControllerProvider.notifier).connectWireless(ip, port: 5555);

    if (mounted) {
      setState(() {
        _isLoading = false;
        _isSuccess = connectRes.success;
        _statusMessage = connectRes.success
            ? 'Paired and connected wirelessly!'
            : 'Paired! (Note: ${connectRes.message ?? "Use device IP to connect"}).';
      });
      if (connectRes.success) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.of(context).pop();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final emuState = ref.watch(emulatorControllerProvider).value;

    final usbDevices = emuState?.emulators
            .where((e) => e.isPhysical && !e.isUnauthorized && e.connectionType != 'Wi-Fi')
            .toList() ??
        const <Emulator>[];

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 540),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.teal.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(CupertinoIcons.wifi, color: Colors.teal, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Wireless ADB Connection', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        Text('Connect real phones on the same Wi-Fi without cables', style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(CupertinoIcons.xmark, size: 16),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Tab Bar
              TabBar(
                controller: _tabController,
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(icon: Icon(CupertinoIcons.bolt_fill, size: 14), text: '1-Click / IP Connect'),
                  Tab(icon: Icon(CupertinoIcons.qrcode, size: 14), text: 'Android 11+ Pairing'),
                ],
              ),

              const SizedBox(height: 12),

              // Tab Views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 1: USB Switch & Manual IP Connect
                    SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (usbDevices.isNotEmpty) ...[
                            Text(
                              'Connected USB Phones (1-Click Wi-Fi Switch):',
                              style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            ...usbDevices.map((dev) => Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: theme.dividerColor.withValues(alpha: 0.3)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(CupertinoIcons.device_phone_portrait, size: 18),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(dev.displayName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                            Text('USB Serial: ${dev.serial ?? dev.name}', style: TextStyle(fontSize: 11, color: theme.hintColor)),
                                          ],
                                        ),
                                      ),
                                      FilledButton.icon(
                                        style: FilledButton.styleFrom(
                                          backgroundColor: Colors.teal.shade700,
                                          visualDensity: VisualDensity.compact,
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        ),
                                        onPressed: _isLoading ? null : () => _handleSwitchUsbToWifi(dev),
                                        icon: const Icon(CupertinoIcons.wifi, size: 14),
                                        label: const Text('Switch to Wi-Fi', style: TextStyle(fontSize: 12)),
                                      ),
                                    ],
                                  ),
                                )),
                            const Divider(height: 20),
                          ],

                          Text(
                            'Or Connect via Local IP Address:',
                            style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: TextField(
                                  controller: _ipController,
                                  style: const TextStyle(fontSize: 13),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    labelText: 'Phone IP Address',
                                    hintText: '192.168.1.100',
                                    prefixIcon: const Icon(CupertinoIcons.wifi, size: 16),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 1,
                                child: TextField(
                                  controller: _portController,
                                  style: const TextStyle(fontSize: 13),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    labelText: 'Port',
                                    hintText: '5555',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton.icon(
                              onPressed: _isLoading ? null : _handleDirectConnect,
                              icon: const Icon(CupertinoIcons.link, size: 14),
                              label: const Text('Connect Wireless'),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Tab 2: Android 11+ Pairing Code
                    SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                            ),
                            child: const Row(
                              children: [
                                Icon(CupertinoIcons.info_circle_fill, color: Colors.blue, size: 16),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'On phone: Developer options > Wireless debugging > "Pair device with pairing code".',
                                    style: TextStyle(fontSize: 11, color: Colors.blue),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: TextField(
                                  controller: _pairIpController,
                                  style: const TextStyle(fontSize: 13),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    labelText: 'Device IP',
                                    hintText: '192.168.1.100',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 1,
                                child: TextField(
                                  controller: _pairPortController,
                                  style: const TextStyle(fontSize: 13),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    labelText: 'Pairing Port',
                                    hintText: '37123',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _pairCodeController,
                            style: const TextStyle(fontSize: 13, letterSpacing: 2),
                            maxLength: 6,
                            decoration: InputDecoration(
                              isDense: true,
                              labelText: '6-digit Pairing Code',
                              hintText: '123456',
                              counterText: '',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton.icon(
                              onPressed: _isLoading ? null : _handlePairAndConnect,
                              icon: const Icon(CupertinoIcons.checkmark_shield_fill, size: 14),
                              label: const Text('Pair & Connect'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Status / Feedback Area
              if (_statusMessage != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _isSuccess
                        ? Colors.green.withValues(alpha: 0.12)
                        : (_isLoading ? Colors.blue.withValues(alpha: 0.12) : Colors.red.withValues(alpha: 0.12)),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _isSuccess
                          ? Colors.green.withValues(alpha: 0.3)
                          : (_isLoading ? Colors.blue.withValues(alpha: 0.3) : Colors.red.withValues(alpha: 0.3)),
                    ),
                  ),
                  child: Row(
                    children: [
                      if (_isLoading)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        Icon(
                          _isSuccess ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.exclamationmark_circle_fill,
                          color: _isSuccess ? Colors.green : Colors.red,
                          size: 16,
                        ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _statusMessage!,
                          style: TextStyle(
                            fontSize: 12,
                            color: _isSuccess
                                ? Colors.green.shade800
                                : (_isLoading ? Colors.blue.shade800 : Colors.red.shade800),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
