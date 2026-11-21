import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';

import '../models/emulator.dart';

class EmulatorCard extends StatelessWidget {
  const EmulatorCard({
    required this.emulator,
    required this.onFavorite,
    required this.onLaunch,
    required this.onColdBoot,
    required this.isLaunching,
    required this.onStop,
    this.onMirror,
    this.onViewLogs,
    this.onSwitchToWifi,
    this.onDisconnectWifi,
    this.assignedPort,
    super.key,
  });

  final Emulator emulator;
  final VoidCallback onFavorite;
  final VoidCallback onLaunch;
  final VoidCallback onColdBoot;
  final VoidCallback onStop;
  final VoidCallback? onMirror;
  final VoidCallback? onViewLogs;
  final VoidCallback? onSwitchToWifi;
  final VoidCallback? onDisconnectWifi;
  final bool isLaunching;
  final int? assignedPort;

  @override
  Widget build(BuildContext context) {
    final isBooting = emulator.isBooting;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final borderColor = emulator.isRunning
        ? Colors.green.withValues(alpha: 0.35)
        : isBooting
            ? Colors.orange.withValues(alpha: 0.35)
            : colorScheme.outlineVariant;

    return RepaintBoundary(
      child: Material(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor, width: 0.5),
          ),
          child: InkWell(
            onTap: () => _showDetails(context),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: <Widget>[
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: emulator.isRunning
                        ? Colors.green.withValues(alpha: 0.1)
                        : colorScheme.primaryContainer,
                    child: Icon(
                      _deviceIcon(),
                      color: emulator.isRunning
                          ? Colors.green
                          : colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Flexible(
                              child: Text(
                                emulator.name,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                            const SizedBox(width: 10),
                            _StatusChip(status: emulator.status, isBooting: isBooting),
                            if (emulator.isPhysical) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.teal.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.teal.withValues(alpha: 0.25), width: 0.5),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      emulator.connectionType == 'Wi-Fi' ? Icons.wifi : Icons.bolt,
                                      size: 10,
                                      color: Colors.teal.shade700,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'PHYSICAL (${emulator.connectionType ?? "USB"})',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.teal.shade800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            if (assignedPort != null) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainerHigh,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  ':$assignedPort',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: <Widget>[
                            if (emulator.isPhysical && emulator.serial != null)
                              _Meta(text: 'Serial: ${emulator.serial}'),
                            _Meta(text: emulator.androidVersion ?? 'Unknown Android'),
                            if (emulator.apiLevel != null) _Meta(text: 'API ${emulator.apiLevel}'),
                            if (emulator.architecture != null) _Meta(text: emulator.architecture!),
                            if (emulator.resolution != null) _Meta(text: emulator.resolution!),
                            if (emulator.ram != null) _Meta(text: emulator.ram!),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    tooltip: emulator.isFavorite ? 'Unpin favorite' : 'Pin favorite',
                    onPressed: onFavorite,
                    icon: Icon(
                      emulator.isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: emulator.isFavorite ? Colors.amber : null,
                    ),
                  ),

                  if (emulator.isPhysical) ...[
                    if (emulator.isUnauthorized) ...[
                      Tooltip(
                        message: 'Please unlock your phone and tap "Allow" on the USB Debugging prompt',
                        child: FilledButton.tonalIcon(
                          onPressed: null,
                          icon: const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 16),
                          label: const Text('Authorize on Phone', style: TextStyle(color: Colors.amber)),
                        ),
                      ),
                    ] else if (onMirror != null) ...[
                      FilledButton.icon(
                        onPressed: onMirror,
                        icon: const Icon(Iconsax.monitor, size: 16),
                        label: const Text('Mirror Screen'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.teal.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                    if (onSwitchToWifi != null && !emulator.isUnauthorized && emulator.connectionType != 'Wi-Fi') ...[
                      const SizedBox(width: 8),
                      Tooltip(
                        message: 'Switch to Wireless Wi-Fi ADB mode',
                        child: OutlinedButton.icon(
                          onPressed: onSwitchToWifi,
                          icon: const Icon(Icons.wifi, size: 14),
                          label: const Text('Wi-Fi', style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.teal,
                            side: BorderSide(color: Colors.teal.withValues(alpha: 0.4)),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: 8),
                    PopupMenuButton<String>(
                      tooltip: 'More actions',
                      onSelected: (value) {
                        switch (value) {
                          case 'mirror':
                            onMirror?.call();
                          case 'wifi_switch':
                            onSwitchToWifi?.call();
                          case 'wifi_disconnect':
                            onDisconnectWifi?.call();
                          case 'logs':
                            onViewLogs?.call();
                          case 'details':
                            _showDetails(context);
                        }
                      },
                      itemBuilder: (context) => <PopupMenuEntry<String>>[
                        if (onMirror != null && !emulator.isUnauthorized)
                          const PopupMenuItem(
                            value: 'mirror',
                            child: Text('Mirror screen with scrcpy'),
                          ),
                        if (!emulator.isUnauthorized && emulator.connectionType != 'Wi-Fi' && onSwitchToWifi != null)
                          const PopupMenuItem(
                            value: 'wifi_switch',
                            child: Text('Switch to Wireless Wi-Fi Mode'),
                          ),
                        if (emulator.connectionType == 'Wi-Fi' && onDisconnectWifi != null)
                          const PopupMenuItem(
                            value: 'wifi_disconnect',
                            child: Text('Disconnect Wireless (adb disconnect)'),
                          ),
                        if (!emulator.isUnauthorized && onViewLogs != null)
                          const PopupMenuItem(
                            value: 'logs',
                            child: Text('View Device Logs (logcat)'),
                          ),
                        const PopupMenuItem(value: 'details', child: Text('View Details')),
                      ],
                    ),
                  ] else ...[
                    if (emulator.isRunning && onMirror != null) ...[
                      OutlinedButton.icon(
                        onPressed: onMirror,
                        icon: const Icon(Iconsax.monitor, size: 16),
                        label: const Text('Mirror'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],

                    if (emulator.isRunning)
                      FilledButton.tonalIcon(
                        onPressed: onStop,
                        icon: const Icon(Icons.stop_rounded, color: Colors.red),
                        label: const Text('Stop', style: TextStyle(color: Colors.red)),
                      )
                    else
                      FilledButton.tonalIcon(
                        onPressed: isBooting || isLaunching ? null : onLaunch,
                        icon: isLaunching || isBooting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.play_arrow_rounded),
                        label: Text(
                          isLaunching
                              ? 'Starting...'
                              : isBooting
                                  ? 'Booting...'
                                  : 'Run',
                        ),
                      ),

                    const SizedBox(width: 8),
                    PopupMenuButton<String>(
                      tooltip: 'More actions',
                      onSelected: (value) {
                        switch (value) {
                          case 'cold_boot':
                            onColdBoot();
                          case 'mirror':
                            onMirror?.call();
                          case 'logs':
                            onViewLogs?.call();
                          case 'stop':
                            onStop();
                          case 'details':
                            _showDetails(context);
                        }
                      },
                      itemBuilder: (context) => <PopupMenuEntry<String>>[
                        const PopupMenuItem(
                          value: 'cold_boot',
                          child: Text('Cold boot (-no-snapshot-load)'),
                        ),
                        if (emulator.isRunning && onMirror != null)
                          const PopupMenuItem(
                            value: 'mirror',
                            child: Text('Mirror screen with scrcpy'),
                          ),
                        if (emulator.isRunning && onViewLogs != null)
                          const PopupMenuItem(
                            value: 'logs',
                            child: Text('View Device Logs (logcat)'),
                          ),
                        PopupMenuItem(
                          value: 'stop',
                          enabled: emulator.isRunning || isBooting,
                          child: const Text('Stop (adb emu kill)'),
                        ),
                        const PopupMenuDivider(),
                        const PopupMenuItem(value: 'details', child: Text('View Details')),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _deviceIcon() {
    if (emulator.isPhysical) {
      return emulator.connectionType == 'Wi-Fi'
          ? Icons.wifi
          : Iconsax.mobile;
    }
    return switch (emulator.deviceType) {
      EmulatorDeviceType.tablet => Icons.tablet_android,
      EmulatorDeviceType.foldable => Icons.tablet_android,
      EmulatorDeviceType.wear => Icons.watch,
      EmulatorDeviceType.tv => Icons.tv,
      EmulatorDeviceType.automotive => Icons.directions_car,
      EmulatorDeviceType.phone || EmulatorDeviceType.unknown => Iconsax.mobile,
    };
  }

  void _showDetails(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(emulator.name),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _DetailRow(
                label: 'Type',
                value: emulator.isPhysical
                    ? 'Physical Device (${emulator.connectionType ?? "USB"})'
                    : 'Android Virtual Device (AVD)',
              ),
              if (emulator.serial != null) _DetailRow(label: 'Serial', value: emulator.serial!),
              if (emulator.model != null) _DetailRow(label: 'Model', value: emulator.model!),
              if (emulator.manufacturer != null)
                _DetailRow(label: 'Manufacturer', value: emulator.manufacturer!),
              _DetailRow(label: 'Status', value: emulator.status.name),
              if (assignedPort != null) _DetailRow(label: 'Port', value: assignedPort.toString()),
              _DetailRow(label: 'Android', value: emulator.androidVersion ?? 'Unknown'),
              _DetailRow(label: 'API', value: emulator.apiLevel?.toString() ?? 'Unknown'),
              _DetailRow(label: 'Architecture', value: emulator.architecture ?? 'Unknown'),
              _DetailRow(label: 'Resolution', value: emulator.resolution ?? 'Unknown'),
              _DetailRow(label: 'RAM', value: emulator.ram ?? 'Unknown'),
              _DetailRow(label: 'Storage', value: emulator.internalStorage ?? 'Unknown'),
              if (emulator.path != null) _DetailRow(label: 'Path', value: emulator.path!),
              if (emulator.createdAt != null)
                _DetailRow(
                  label: 'Created',
                  value: DateFormat.yMMMd().add_jm().format(emulator.createdAt!),
                ),
              if (emulator.lastUsedAt != null)
                _DetailRow(
                  label: 'Last used',
                  value: DateFormat.yMMMd().add_jm().format(emulator.lastUsedAt!),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, this.isBooting = false});

  final EmulatorStatus status;
  final bool isBooting;

  @override
  Widget build(BuildContext context) {
    if (isBooting || status == EmulatorStatus.booting) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.3), width: 0.5),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange),
            ),
            SizedBox(width: 6),
            Text(
              'Booting...',
              style: TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    final (color, bgAlpha) = switch (status) {
      EmulatorStatus.running => (Colors.green, 0.1),
      EmulatorStatus.booting => (Colors.orange, 0.1),
      EmulatorStatus.disconnected => (Colors.red, 0.1),
      EmulatorStatus.unauthorized => (Colors.amber.shade800, 0.1),
      EmulatorStatus.offline => (Theme.of(context).colorScheme.outline, 0.06),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: bgAlpha),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 7, color: color),
          const SizedBox(width: 5),
          Text(
            status.name,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
