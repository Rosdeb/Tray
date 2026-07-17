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
    super.key,
  });

  final Emulator emulator;
  final VoidCallback onFavorite;
  final VoidCallback onLaunch;
  final VoidCallback onColdBoot;
  final VoidCallback onStop;
  final bool isLaunching;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
        boxShadow: [
          BoxShadow(
            blurRadius: 12,
            color: Colors.black.withOpacity(.04),
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
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Icon(
                _deviceIcon(),
                color: Theme.of(context).colorScheme.onPrimaryContainer,
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
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _StatusChip(status: emulator.status),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: <Widget>[
                      _Meta(text: emulator.androidVersion ?? 'Unknown Android'),
                      _Meta(text: emulator.architecture ?? 'Unknown ABI'),
                      if (emulator.resolution != null)
                        _Meta(text: emulator.resolution!),
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
              icon: Icon(emulator.isFavorite ? Icons.star : Icons.star_border),
            ),
            FilledButton.tonalIcon(
              onPressed: emulator.isRunning || isLaunching ? null : onLaunch,
              icon: isLaunching
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow),
              label: Text(isLaunching ? "Starting..." : "Run"),
            ),

            const SizedBox(width: 8),
            PopupMenuButton<String>(
              tooltip: 'More actions',
              onSelected: (value) {
                switch (value) {
                  case 'cold_boot':
                    onColdBoot();
                  case 'stop':
                    onStop();
                  case 'details':
                    _showDetails(context);
                }
              },
              itemBuilder: (context) => <PopupMenuEntry<String>>[
                const PopupMenuItem(
                  value: 'cold_boot',
                  child: Text('Cold boot'),
                ),
                PopupMenuItem(
                  value: 'stop',
                  enabled: emulator.isRunning,
                  child: const Text('Stop'),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(value: 'details', child: Text('Details')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _deviceIcon() {
    return switch (emulator.deviceType) {
      EmulatorDeviceType.tablet => Icons.tablet_mac,
      EmulatorDeviceType.foldable => Icons.unfold_more,
      EmulatorDeviceType.wear => Icons.watch,
      EmulatorDeviceType.tv => Icons.tv,
      EmulatorDeviceType.automotive => Icons.directions_car,
      EmulatorDeviceType.phone ||
      EmulatorDeviceType.unknown => Icons.smartphone,
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
  const _StatusChip({required this.status});

  final EmulatorStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      EmulatorStatus.running => Colors.green,
      EmulatorStatus.booting => Colors.orange,
      EmulatorStatus.disconnected => Colors.red,
      EmulatorStatus.offline => Theme.of(context).colorScheme.outline,
    };
    return Chip(
      visualDensity: VisualDensity.compact,
      avatar: Icon(Icons.circle, size: 10, color: color),
      label: Text(status.name),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
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
