import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/log_entry.dart';
import '../../providers/app_providers.dart';

class LogsScreen extends ConsumerStatefulWidget {
  const LogsScreen({super.key});

  @override
  ConsumerState<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends ConsumerState<LogsScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  int _lastEntryCount = 0;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      ref.read(deviceLogsControllerProvider.notifier).setSearchQuery(_searchController.text);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _scrollToBottomIfNeeded(int currentCount, bool autoScroll) {
    if (autoScroll && currentCount > _lastEntryCount && _scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });
    }
    _lastEntryCount = currentCount;
  }

  @override
  Widget build(BuildContext context) {
    final logsState = ref.watch(deviceLogsControllerProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final query = logsState.searchQuery.trim().toLowerCase();
    final filtered = logsState.entries.where((entry) {
      if (entry.level.priority < logsState.filterLevel.priority) return false;
      if (query.isNotEmpty) {
        final inMsg = entry.message.toLowerCase().contains(query);
        final inTag = entry.tag?.toLowerCase().contains(query) ?? false;
        final inPid = entry.pid?.contains(query) ?? false;
        return inMsg || inTag || inPid;
      }
      return true;
    }).toList(growable: false);

    _scrollToBottomIfNeeded(filtered.length, logsState.autoScroll);

    final selectedTarget = logsState.targets.firstWhere(
      (t) => t.id == logsState.selectedTargetId,
      orElse: () => LogTarget(
        id: logsState.selectedTargetId ?? 'app',
        displayName: logsState.selectedTargetId ?? 'Simulation Tray System Logs',
        isAppLogs: logsState.selectedTargetId == 'app',
      ),
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Bar: Title & Target Dropdown & Control Actions
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        'Device Logs',
                        style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 16),
                      // Target Device Selector Dropdown
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.3)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: logsState.selectedTargetId,
                            isDense: true,
                            icon: const Icon(CupertinoIcons.chevron_down, size: 14),
                            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                            items: logsState.targets.map((target) {
                              return DropdownMenuItem<String>(
                                value: target.id,
                                child: Text(target.displayName),
                              );
                            }).toList(),
                            onChanged: (newId) {
                              if (newId != null) {
                                ref.read(deviceLogsControllerProvider.notifier).selectTarget(newId);
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Status Badge
                      _StatusBadge(
                        isStreaming: logsState.isStreaming,
                        isPaused: logsState.isPaused,
                        isAppLogs: selectedTarget.isAppLogs,
                      ),
                    ],
                  ),
                ),

                // Control Action Buttons
                Wrap(
                  spacing: 6,
                  children: [
                    // Pause / Resume Button
                    IconButton.filledTonal(
                      tooltip: logsState.isPaused ? 'Resume log stream' : 'Pause log stream',
                      onPressed: selectedTarget.isAppLogs
                          ? null
                          : () => ref.read(deviceLogsControllerProvider.notifier).togglePause(),
                      icon: Icon(
                        logsState.isPaused ? CupertinoIcons.play_fill : CupertinoIcons.pause_fill,
                        size: 16,
                      ),
                    ),
                    // Auto-Scroll Toggle Button
                    IconButton.filledTonal(
                      tooltip: logsState.autoScroll ? 'Auto-scroll ON (click to disable)' : 'Auto-scroll OFF (click to enable)',
                      style: logsState.autoScroll
                          ? IconButton.styleFrom(
                              backgroundColor: colorScheme.primaryContainer,
                              foregroundColor: colorScheme.onPrimaryContainer,
                            )
                          : null,
                      onPressed: () => ref.read(deviceLogsControllerProvider.notifier).toggleAutoScroll(),
                      icon: const Icon(CupertinoIcons.arrow_down_to_line, size: 16),
                    ),
                    // Clear Logs Button
                    IconButton.filledTonal(
                      tooltip: 'Clear log output (adb logcat -c)',
                      onPressed: () => ref.read(deviceLogsControllerProvider.notifier).clearLogs(),
                      icon: const Icon(CupertinoIcons.trash, size: 16),
                    ),
                    // Copy All Filtered Logs Button
                    IconButton.filledTonal(
                      tooltip: 'Copy visible logs to clipboard',
                      onPressed: filtered.isEmpty
                          ? null
                          : () async {
                              final text = filtered
                                  .map((e) => e.raw ?? '${e.timeFormatted ?? ""} [${e.level.shortCode}] ${e.tag ?? ""}: ${e.message}')
                                  .join('\n');
                              await Clipboard.setData(ClipboardData(text: text));
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Copied ${filtered.length} log lines to clipboard'),
                                    duration: const Duration(seconds: 2),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            },
                      icon: const Icon(CupertinoIcons.doc_on_clipboard, size: 16),
                    ),
                    // Restart / Refresh Button
                    IconButton.filledTonal(
                      tooltip: 'Restart logcat stream',
                      onPressed: () async {
                        await ref.read(emulatorControllerProvider.notifier).refresh();
                        await ref.read(deviceLogsControllerProvider.notifier).restartStream();
                      },
                      icon: const Icon(CupertinoIcons.refresh, size: 16),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Search & Log Level Filter Bar
            Row(
              children: [
                // Search Input
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: TextField(
                      controller: _searchController,
                      style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Filter by message, tag (e.g. Flutter), or PID...',
                        hintStyle: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                        prefixIcon: const Icon(CupertinoIcons.search, size: 16),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(CupertinoIcons.clear_circled_solid, size: 14),
                                onPressed: () {
                                  _searchController.clear();
                                  ref.read(deviceLogsControllerProvider.notifier).setSearchQuery('');
                                },
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                // Log Level Selector
                Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: theme.dividerColor.withValues(alpha: 0.3)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<LogLevel>(
                      value: logsState.filterLevel,
                      isDense: true,
                      style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                      items: const [
                        DropdownMenuItem(value: LogLevel.verbose, child: Text('Level: Verbose+')),
                        DropdownMenuItem(value: LogLevel.debug, child: Text('Level: Debug+')),
                        DropdownMenuItem(value: LogLevel.info, child: Text('Level: Info+')),
                        DropdownMenuItem(value: LogLevel.warning, child: Text('Level: Warning+')),
                        DropdownMenuItem(value: LogLevel.error, child: Text('Level: Error+')),
                      ],
                      onChanged: (lvl) {
                        if (lvl != null) {
                          ref.read(deviceLogsControllerProvider.notifier).setFilterLevel(lvl);
                        }
                      },
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                // Line Counter
                Text(
                  '${filtered.length} lines',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                ),
              ],
            ),

            if (logsState.errorMessage != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(CupertinoIcons.exclamationmark_triangle_fill, color: Colors.red, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        logsState.errorMessage!,
                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Main Console Terminal Box
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: theme.brightness == Brightness.dark
                      ? const Color(0xFF14171A)
                      : const Color(0xFFF7F9FA),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: theme.dividerColor.withValues(alpha: 0.4),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: filtered.isEmpty
                      ? _buildEmptyState(context, logsState, selectedTarget)
                      : NotificationListener<ScrollNotification>(
                          onNotification: (notification) {
                            if (notification is UserScrollNotification) {
                              if (_scrollController.hasClients &&
                                  _scrollController.position.maxScrollExtent -
                                          _scrollController.position.pixels >
                                      120) {
                                if (logsState.autoScroll) {
                                  ref.read(deviceLogsControllerProvider.notifier).toggleAutoScroll();
                                }
                              }
                            }
                            return false;
                          },
                          child: SelectionArea(
                            child: ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                return _LogLineRow(entry: filtered[index]);
                              },
                            ),
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    DeviceLogsState logsState,
    LogTarget selectedTarget,
  ) {
    final theme = Theme.of(context);
    final isStreaming = logsState.isStreaming;

    if (isStreaming) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(CupertinoIcons.search, size: 40, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              'No logs matching the current filter.',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () {
                _searchController.clear();
                ref.read(deviceLogsControllerProvider.notifier).setSearchQuery('');
                ref.read(deviceLogsControllerProvider.notifier).setFilterLevel(LogLevel.verbose);
              },
              child: const Text('Reset Filters'),
            ),
          ],
        ),
      );
    }

    if (!selectedTarget.isAppLogs && logsState.targets.length <= 1) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(CupertinoIcons.device_phone_portrait, size: 48, color: Colors.grey),
              const SizedBox(height: 14),
              Text(
                'No Android Devices or Emulators Active',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'Connect a physical phone via USB/Wi-Fi or launch an emulator from the Dashboard to stream real-time logcat output.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FilledButton.icon(
                    onPressed: () {
                      ref.read(selectedNavIndexProvider.notifier).selectTab(0);
                    },
                    icon: const Icon(CupertinoIcons.play_fill, size: 14),
                    label: const Text('Go to Dashboard'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      ref.read(deviceLogsControllerProvider.notifier).selectTarget('app');
                    },
                    icon: const Icon(CupertinoIcons.macwindow, size: 14),
                    label: const Text('View App System Logs'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(CupertinoIcons.doc_text, size: 40, color: Colors.grey),
          const SizedBox(height: 12),
          Text(
            selectedTarget.isAppLogs
                ? 'No system logs recorded for this session.'
                : 'Waiting for device log output...',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              ref.read(deviceLogsControllerProvider.notifier).restartStream();
            },
            icon: const Icon(CupertinoIcons.refresh, size: 14),
            label: const Text('Start / Reconnect'),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.isStreaming,
    required this.isPaused,
    required this.isAppLogs,
  });

  final bool isStreaming;
  final bool isPaused;
  final bool isAppLogs;

  @override
  Widget build(BuildContext context) {
    if (isAppLogs) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.blueGrey.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text('System', style: TextStyle(fontSize: 11, color: Colors.blueGrey, fontWeight: FontWeight.bold)),
      );
    }

    if (isPaused) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text('PAUSED', style: TextStyle(fontSize: 11, color: Colors.amber, fontWeight: FontWeight.bold)),
      );
    }

    if (isStreaming) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.circle_fill, color: Colors.green, size: 8),
            SizedBox(width: 4),
            Text('LIVE', style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text('OFFLINE', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
    );
  }
}

class _LogLineRow extends StatelessWidget {
  const _LogLineRow({required this.entry});

  final LogEntry entry;

  @override
  Widget build(BuildContext context) {
    final (badgeBg, badgeFg) = switch (entry.level) {
      LogLevel.verbose => (Colors.grey.withValues(alpha: 0.15), Colors.grey),
      LogLevel.debug => (Colors.teal.withValues(alpha: 0.15), Colors.teal),
      LogLevel.info => (Colors.blue.withValues(alpha: 0.15), Colors.blue),
      LogLevel.warning => (Colors.amber.withValues(alpha: 0.15), Colors.amber.shade800),
      LogLevel.error || LogLevel.fatal => (Colors.red.withValues(alpha: 0.18), Colors.red.shade600),
    };

    final messageColor = switch (entry.level) {
      LogLevel.error || LogLevel.fatal => Colors.redAccent,
      LogLevel.warning => Colors.orangeAccent,
      _ => null,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timestamp
          if (entry.timeFormatted != null) ...[
            Text(
              entry.timeFormatted!,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: Colors.grey,
              ),
            ),
            const SizedBox(width: 8),
          ],

          // Level badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              entry.level.shortCode,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: badgeFg,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Tag
          if (entry.tag != null && entry.tag!.isNotEmpty) ...[
            Text(
              entry.tag!,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.cyan,
              ),
            ),
            if (entry.pid != null && entry.pid!.isNotEmpty)
              Text(
                '(${entry.pid})',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10,
                  color: Colors.grey,
                ),
              ),
            const Text(
              ': ',
              style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.grey),
            ),
          ],

          // Message
          Expanded(
            child: Text(
              entry.message,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: messageColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
