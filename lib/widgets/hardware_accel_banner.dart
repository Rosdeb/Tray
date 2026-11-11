import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/hardware_acceleration.dart';

class HardwareAccelBanner extends StatelessWidget {
  const HardwareAccelBanner({
    required this.info,
    super.key,
  });

  final HardwareAccelerationInfo info;

  @override
  Widget build(BuildContext context) {
    if (info.isAvailable) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(CupertinoIcons.checkmark_circle, color: Colors.green, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Hardware Acceleration: ${info.hypervisorType ?? "Active"}',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.green),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(CupertinoIcons.exclamationmark_triangle_fill, color: Colors.amber, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Hardware Acceleration Warning',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.amber),
                ),
                const SizedBox(height: 2),
                Text(
                  info.message,
                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          if (info.howToFix != null) ...[
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: () => _showFixDialog(context),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                side: BorderSide(color: Colors.amber.withValues(alpha: 0.6)),
              ),
              child: const Text('How to Fix', style: TextStyle(color: Colors.amber, fontSize: 12)),
            ),
          ],
        ],
      ),
    );
  }

  void _showFixDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(CupertinoIcons.speedometer, color: Colors.amber),
            SizedBox(width: 10),
            Text('Hardware Acceleration Setup'),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hardware acceleration is required for the Android Emulator to run smoothly. Without it, emulation will be extremely slow.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              const Text('Instructions:', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  info.howToFix ?? 'Enable virtualization in BIOS/UEFI.',
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
              if (info.details.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('accel-check details:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11)),
                const SizedBox(height: 4),
                SelectableText(
                  info.details,
                  style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.outline),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
