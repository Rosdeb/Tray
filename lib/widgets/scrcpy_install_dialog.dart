import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';

class ScrcpyInstallDialog extends ConsumerStatefulWidget {
  const ScrcpyInstallDialog({super.key, this.onSuccess});

  final VoidCallback? onSuccess;

  static Future<void> show(BuildContext context, {VoidCallback? onSuccess}) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ScrcpyInstallDialog(onSuccess: onSuccess),
    );
  }

  @override
  ConsumerState<ScrcpyInstallDialog> createState() => _ScrcpyInstallDialogState();
}

class _ScrcpyInstallDialogState extends ConsumerState<ScrcpyInstallDialog> {
  double _progress = 0.0;
  String _statusMessage = 'Initializing...';
  bool _isDownloading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startInstallation();
  }

  Future<void> _startInstallation() async {
    setState(() {
      _progress = 0.05;
      _statusMessage = 'Starting download...';
      _error = null;
      _isDownloading = true;
    });

    try {
      final scrcpyService = ref.read(scrcpyServiceProvider);
      final path = await scrcpyService.installStandaloneScrcpy(
        onProgress: (msg, pct) {
          if (mounted) {
            setState(() {
              _statusMessage = msg;
              _progress = pct;
            });
          }
        },
      );

      // Save custom path in settings
      await ref.read(settingsControllerProvider.notifier).setScrcpyPath(path);
      ref.invalidate(scrcpyInfoProvider);

      if (mounted) {
        setState(() {
          _isDownloading = false;
          _progress = 1.0;
          _statusMessage = 'scrcpy configured successfully!';
        });

        await Future<void>.delayed(const Duration(milliseconds: 700));
        if (mounted) {
          Navigator.of(context).pop();
          widget.onSuccess?.call();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(CupertinoIcons.tv, color: theme.colorScheme.primary, size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Screen Mirroring Setup',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Downloading and configuring the official standalone scrcpy package for Windows (~6.6 MB).',
              style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: theme.colorScheme.error.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    Icon(CupertinoIcons.exclamationmark_triangle_fill, color: theme.colorScheme.error, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Installation failed: $_error',
                        style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _statusMessage,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${(_progress * 100).toInt()}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _progress,
                  minHeight: 6,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (_error != null) ...[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: _startInstallation,
            icon: const Icon(CupertinoIcons.refresh, size: 16),
            label: const Text('Retry Download'),
          ),
        ] else if (!_isDownloading) ...[
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ],
    );
  }
}
