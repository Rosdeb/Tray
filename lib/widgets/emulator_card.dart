import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
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
    this.assignedPort,
    super.key,
  });

  final Emulator emulator;
  final VoidCallback onFavorite;
  final VoidCallback onLaunch;
  final VoidCallback onColdBoot;
  final VoidCallback onStop;
  final VoidCallback? onMirror;
  final bool isLaunching;
  final int? assignedPort;

  @override
  Widget build(BuildContext context) {
    final isBooting = emulator.isBooting;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: emulator.isRunning
              ? Colors.green.withValues(alpha: 0.4)
              : isBooting
                  ? Colors.orange.withValues(alpha: 0.4)
                  : Theme.of(context).dividerColor,
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 12,
            color: Colors.black.withValues(alpha: 0.04),
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _showDetails(context),
        child: Row(
          children: <Widget>[
            CircleAvatar(
              radius: 26,
              backgroundColor: emulator.isRunning
                  ? Colors.green.withValues(alpha: 0.15)
                  : Theme.of(context).colorScheme.primaryContainer,
              child: Icon(
                _deviceIcon(),
                color: emulator.isRunning
                    ? Colors.green
                    : Theme.of(context).colorScheme.onPrimaryContainer,
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
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _StatusChip(status: emulator.status, isBooting: isBooting),
                      if (assignedPort != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            ':$assignedPort',
                            style: const TextStyle(fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.bold),
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
                      _Meta(text: emulator.androidVersion ?? 'Unknown Android'),
                      _Meta(text: emulator.architecture ?? 'Unknown ABI'),
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
              icon: Icon(emulator.isFavorite ? CupertinoIcons.star_fill : CupertinoIcons.star),
            ),

            // Mirror button (scrcpy)
            if (emulator.isRunning && onMirror != null) ...[
              OutlinedButton.icon(
                onPressed: onMirror,
                icon: const Icon(CupertinoIcons.tv, size: 16),
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
                icon: const Icon(CupertinoIcons.stop_fill, color: Colors.red),
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
                    : const Icon(CupertinoIcons.play_fill),
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
        ),
      ),
    );
  }

  IconData _deviceIcon() {
    return switch (emulator.deviceType) {
      EmulatorDeviceType.tablet => CupertinoIcons.device_phone_landscape,
      EmulatorDeviceType.foldable => CupertinoIcons.device_phone_landscape,
      EmulatorDeviceType.wear => CupertinoIcons.time,
      EmulatorDeviceType.tv => CupertinoIcons.tv,
      EmulatorDeviceType.automotive => CupertinoIcons.car_fill,
      EmulatorDeviceType.phone || EmulatorDeviceType.unknown => CupertinoIcons.device_phone_portrait,
    };
  }

  void _showDetails(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(emulator.name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            _DetailRow(label: 'Status', value: emulator.status.name),
            if (assignedPort != null) _DetailRow(label: 'Port', value: assignedPort.toString()),
            _DetailRow(
              label: 'Android',
              value: emulator.androidVersion ?? 'Unknown',
            ),
            _DetailRow(
              label: 'API',
              value: emulator.apiLevel?.toString() ?? 'Unknown',
            ),
            _DetailRow(
              label: 'Architecture',
              value: emulator.architecture ?? 'Unknown',
            ),
            _DetailRow(
              label: 'Resolution',
              value: emulator.resolution ?? 'Unknown',
            ),
            _DetailRow(label: 'RAM', value: emulator.ram ?? 'Unknown'),
            _DetailRow(
              label: 'Storage',
              value: emulator.internalStorage ?? 'Unknown',
            ),
            _DetailRow(label: 'Path', value: emulator.path ?? 'Unknown'),
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
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
              style: TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    final color = switch (status) {
      EmulatorStatus.running => Colors.green,
      EmulatorStatus.booting => Colors.orange,
      EmulatorStatus.disconnected => Colors.red,
      EmulatorStatus.offline => Theme.of(context).colorScheme.outline,
    };

    return Chip(
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      labelPadding: const EdgeInsets.only(right: 8, left: 4),
      avatar: Icon(CupertinoIcons.circle_fill, size: 8, color: color),
      label: Text(
        status.name,
        style: TextStyle(fontSize: 11, color: status == EmulatorStatus.running ? Colors.green : null),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 11,
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }
}
