import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../models/log_entry.dart';
import '../../providers/app_providers.dart';
import '../../services/device_log_service.dart';

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
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    ref.read(deviceLogsControllerProvider.notifier).setSearchQuery(_searchController.text);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
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

  List<LogEntry> _filterEntries(DeviceLogsState logsState, LogTarget selectedTarget) {
    final query = logsState.searchQuery.trim().toLowerCase();
    return logsState.entries.where((entry) {
      if (entry.level.priority < logsState.filterLevel.priority) return false;
      if (!selectedTarget.isAppLogs) {
        if (!DeviceLogService.matchesAppFilter(
          entry: entry,
          mode: logsState.filterMode,
          packageName: logsState.selectedPackage,
          pid: logsState.activeAppPid,
        )) {
          return false;
        }
      }
      if (query.isNotEmpty) {
        final inMsg = entry.message.toLowerCase().contains(query);
        final inTag = entry.tag?.toLowerCase().contains(query) ?? false;
        final inPid = entry.pid?.contains(query) ?? false;
        return inMsg || inTag || inPid;
      }
      return true;
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final logsState = ref.watch(deviceLogsControllerProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final selectedTarget = logsState.targets.firstWhere(
      (t) => t.id == logsState.selectedTargetId,
      orElse: () => LogTarget(
        id: logsState.selectedTargetId ?? 'app',
        displayName: logsState.selectedTargetId ?? 'Simulation Tray System Logs',
        isAppLogs: logsState.selectedTargetId == 'app',
      ),
    );

    final filtered = _filterEntries(logsState, selectedTarget);

    _scrollToBottomIfNeeded(filtered.length, logsState.autoScroll);

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
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: colorScheme.outlineVariant, width: 0.5),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: logsState.selectedTargetId,
                            isDense: true,
                            icon: const Icon(Icons.keyboard_arrow_down, size: 16),
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
                    IconButton.filledTonal(
                      tooltip: logsState.isPaused ? 'Resume log stream' : 'Pause log stream',
                      onPressed: selectedTarget.isAppLogs
                          ? null
                          : () => ref.read(deviceLogsControllerProvider.notifier).togglePause(),
                      icon: Icon(
                        logsState.isPaused ? Icons.play_arrow : Icons.pause,
                        size: 16,
                      ),
                    ),
                    IconButton.filledTonal(
                      tooltip: logsState.autoScroll ? 'Auto-scroll ON (click to disable)' : 'Auto-scroll OFF (click to enable)',
                      style: logsState.autoScroll
                          ? IconButton.styleFrom(
                              backgroundColor: colorScheme.primaryContainer,
                              foregroundColor: colorScheme.onPrimaryContainer,
                            )
                          : null,
                      onPressed: () => ref.read(deviceLogsControllerProvider.notifier).toggleAutoScroll(),
                      icon: const Icon(Icons.vertical_align_bottom, size: 16),
                    ),
                    IconButton.filledTonal(
                      tooltip: 'Clear log output (adb logcat -c)',
                      onPressed: () => ref.read(deviceLogsControllerProvider.notifier).clearLogs(),
                      icon: const Icon(Icons.delete_outline, size: 16),
                    ),
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
                                  ),
                                );
                              }
                            },
                      icon: const Icon(Icons.copy_outlined, size: 16),
                    ),
                    IconButton.filledTonal(
                      tooltip: 'Restart logcat stream',
                      onPressed: () async {
                        await ref.read(emulatorControllerProvider.notifier).refresh();
                        await ref.read(deviceLogsControllerProvider.notifier).restartStream();
                      },
                      icon: const Icon(Icons.refresh, size: 16),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Search & Log Level Filter Bar
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: TextField(
                      controller: _searchController,
                      style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Filter by message, tag (e.g. Flutter), or PID...',
                        prefixIcon: const Icon(Icons.search, size: 16),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 14),
                                onPressed: () {
                                  _searchController.clear();
                                },
                              )
                            : null,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: colorScheme.outlineVariant, width: 0.5),
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

                Text(
                  '${filtered.length} lines',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),

            if (!selectedTarget.isAppLogs) ...[
              const SizedBox(height: 10),
              _AppFilterBar(
                state: logsState,
                onModeChanged: (mode) =>
                    ref.read(deviceLogsControllerProvider.notifier).setFilterMode(mode),
                onAutoDetect: () =>
                    ref.read(deviceLogsControllerProvider.notifier).autoDetectApp(),
                onSelectPackage: (pkg) =>
                    ref.read(deviceLogsControllerProvider.notifier).setSelectedPackage(pkg),
                onRefreshPid: () =>
                    ref.read(deviceLogsControllerProvider.notifier).refreshPid(),
                onLoadPackages: () =>
                    ref.read(deviceLogsControllerProvider.notifier).loadInstalledPackages(),
              ),
            ],

            if (logsState.errorMessage != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber, color: Colors.red, size: 16),
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
                  color: colorScheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: colorScheme.outlineVariant, width: 0.5),
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
                                return RepaintBoundary(
                                  child: _LogLineRow(entry: filtered[index]),
                                );
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
      if (logsState.filterMode == LogFilterMode.appOnly && logsState.selectedPackage == null) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Iconsax.mobile, size: 44, color: Colors.grey),
              const SizedBox(height: 12),
              Text(
                'No Project App Selected',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'Open your app on the device and click "Auto-Detect App" to stream only your project logs.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () => ref.read(deviceLogsControllerProvider.notifier).autoDetectApp(),
                icon: const Icon(Iconsax.scan, size: 15),
                label: const Text('Auto-Detect Active App'),
              ),
            ],
          ),
        );
      }

      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, size: 40, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              'No logs matching the current filter.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () {
                _searchController.clear();
                ref.read(deviceLogsControllerProvider.notifier).setFilterLevel(LogLevel.verbose);
                ref.read(deviceLogsControllerProvider.notifier).setFilterMode(LogFilterMode.all);
              },
              child: const Text('Reset All Filters'),
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
              const Icon(Iconsax.mobile, size: 48, color: Colors.grey),
              const SizedBox(height: 14),
              Text(
                'No Android Devices or Emulators Active',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'Connect a physical phone via USB/Wi-Fi or launch an emulator from the Dashboard to stream real-time logcat output.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FilledButton.icon(
                    onPressed: () {
                      ref.read(selectedNavIndexProvider.notifier).selectTab(0);
                    },
                    icon: const Icon(Icons.play_arrow, size: 14),
                    label: const Text('Go to Dashboard'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      ref.read(deviceLogsControllerProvider.notifier).selectTarget('app');
                    },
                    icon: const Icon(Iconsax.monitor, size: 14),
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
          const Icon(Iconsax.document_text, size: 40, color: Colors.grey),
          const SizedBox(height: 12),
          Text(
            selectedTarget.isAppLogs
                ? 'No system logs recorded for this session.'
                : 'Waiting for device log output...',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              ref.read(deviceLogsControllerProvider.notifier).restartStream();
            },
            icon: const Icon(Icons.refresh, size: 14),
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
            Icon(Icons.circle, color: Colors.green, size: 8),
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

  static const _monoStyle = TextStyle(fontFamily: 'monospace', fontSize: 11);
  static const _monoSmallStyle = TextStyle(fontFamily: 'monospace', fontSize: 10);
  static const _timestampStyle = TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.grey);
  static const _tagStyle = TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.w600, color: Colors.cyan);
  static const _pidStyle = TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.grey);
  static const _separatorStyle = TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.grey);

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
          if (entry.timeFormatted != null) ...[
            Text(entry.timeFormatted!, style: _timestampStyle),
            const SizedBox(width: 8),
          ],

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              entry.level.shortCode,
              style: _monoSmallStyle.copyWith(fontWeight: FontWeight.bold, color: badgeFg),
            ),
          ),
          const SizedBox(width: 8),

          if (entry.tag != null && entry.tag!.isNotEmpty) ...[
            Text(entry.tag!, style: _tagStyle),
            if (entry.pid != null && entry.pid!.isNotEmpty)
              Text('(${entry.pid})', style: _pidStyle),
            const Text(': ', style: _separatorStyle),
          ],

          Expanded(
            child: Text(
              entry.message,
              style: messageColor != null ? _monoStyle.copyWith(color: messageColor) : _monoStyle,
            ),
          ),
        ],
      ),
    );
  }
}

class _AppFilterBar extends StatelessWidget {
  const _AppFilterBar({
    required this.state,
    required this.onModeChanged,
    required this.onAutoDetect,
    required this.onSelectPackage,
    required this.onRefreshPid,
    required this.onLoadPackages,
  });

  final DeviceLogsState state;
  final ValueChanged<LogFilterMode> onModeChanged;
  final VoidCallback onAutoDetect;
  final ValueChanged<String?> onSelectPackage;
  final VoidCallback onRefreshPid;
  final Future<void> Function() onLoadPackages;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final currentMode = state.filterMode;
    final isAppMode = currentMode == LogFilterMode.appOnly;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: colorScheme.outlineVariant, width: 0.5),
                ),
                padding: const EdgeInsets.all(2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ModeChip(
                      label: 'All Logs',
                      icon: Icons.list,
                      isSelected: currentMode == LogFilterMode.all,
                      onTap: () => onModeChanged(LogFilterMode.all),
                    ),
                    _ModeChip(
                      label: 'Project App',
                      icon: Iconsax.mobile,
                      isSelected: currentMode == LogFilterMode.appOnly,
                      onTap: () => onModeChanged(LogFilterMode.appOnly),
                    ),
                    _ModeChip(
                      label: 'Flutter',
                      icon: Iconsax.code,
                      isSelected: currentMode == LogFilterMode.flutterOnly,
                      onTap: () => onModeChanged(LogFilterMode.flutterOnly),
                    ),
                    _ModeChip(
                      label: 'React Native',
                      icon: Iconsax.mobile,
                      isSelected: currentMode == LogFilterMode.reactNativeOnly,
                      onTap: () => onModeChanged(LogFilterMode.reactNativeOnly),
                    ),
                  ],
                ),
              ),

              if (isAppMode) ...[
                const SizedBox(width: 10),

                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                    minimumSize: const Size(0, 32),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: state.isDetectingApp ? null : onAutoDetect,
                  icon: state.isDetectingApp
                      ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Iconsax.scan, size: 14),
                  label: Text(
                    state.isDetectingApp ? 'Detecting...' : 'Auto-Detect App',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),

                const SizedBox(width: 8),

                if (state.selectedPackage != null) ...[
                  Container(
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: colorScheme.primary.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: state.activeAppPid != null ? Colors.green : Colors.grey,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          state.selectedPackage!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'monospace',
                            color: colorScheme.onSurface,
                          ),
                        ),
                        if (state.activeAppPid != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'PID: ${state.activeAppPid}',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(width: 4),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                          iconSize: 13,
                          tooltip: 'Refresh PID',
                          onPressed: onRefreshPid,
                          icon: const Icon(Icons.refresh),
                        ),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                          iconSize: 13,
                          tooltip: 'Clear filter',
                          onPressed: () => onSelectPackage(null),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                      minimumSize: const Size(0, 32),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _openPackagePicker(context),
                    icon: const Icon(Icons.list, size: 14),
                    label: const Text('Choose App...', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ],
            ],
          ),
        ),
        if (isAppMode && state.detectionStatusMessage != null) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              state.detectionStatusMessage!,
              style: theme.textTheme.labelSmall?.copyWith(fontStyle: FontStyle.italic),
            ),
          ),
        ],
      ],
    );
  }

  void _openPackagePicker(BuildContext context) async {
    await onLoadPackages();
    if (!context.mounted) return;

    showDialog<void>(
      context: context,
      builder: (ctx) => _PackagePickerDialog(
        installedPackages: state.installedPackages,
        onSelect: (pkg) {
          Navigator.of(ctx).pop();
          onSelectPackage(pkg);
        },
        onAutoDetect: () {
          Navigator.of(ctx).pop();
          onAutoDetect();
        },
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PackagePickerDialog extends StatefulWidget {
  const _PackagePickerDialog({
    required this.installedPackages,
    required this.onSelect,
    required this.onAutoDetect,
  });

  final List<String> installedPackages;
  final ValueChanged<String> onSelect;
  final VoidCallback onAutoDetect;

  @override
  State<_PackagePickerDialog> createState() => _PackagePickerDialogState();
}

class _PackagePickerDialogState extends State<_PackagePickerDialog> {
  final TextEditingController _customController = TextEditingController();
  String _filter = '';

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtered = widget.installedPackages.where((p) => p.toLowerCase().contains(_filter.toLowerCase())).toList();

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Iconsax.mobile, size: 20),
          SizedBox(width: 8),
          Text('Select Project App'),
        ],
      ),
      content: SizedBox(
        width: 440,
        height: 380,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _customController,
                    style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: 'Enter package (e.g. com.example.app)',
                    ),
                    onSubmitted: (val) {
                      if (val.trim().isNotEmpty) widget.onSelect(val.trim());
                    },
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () {
                    final text = _customController.text.trim();
                    if (text.isNotEmpty) widget.onSelect(text);
                  },
                  child: const Text('Apply'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(36),
              ),
              onPressed: widget.onAutoDetect,
              icon: const Icon(Iconsax.scan, size: 15),
              label: const Text('Detect Currently Active Phone App'),
            ),
            const SizedBox(height: 12),
            Text(
              'Installed User Apps (${widget.installedPackages.length}):',
              style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            TextField(
              style: const TextStyle(fontSize: 11),
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'Filter installed apps...',
                prefixIcon: Icon(Icons.search, size: 14),
              ),
              onChanged: (val) => setState(() => _filter = val),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        widget.installedPackages.isEmpty
                            ? 'No 3rd-party apps found. Enter package manually above.'
                            : 'No apps matching "$_filter"',
                        style: theme.textTheme.bodySmall,
                      ),
                    )
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (ctx, i) {
                        final pkg = filtered[i];
                        return ListTile(
                          dense: true,
                          visualDensity: VisualDensity.compact,
                          title: Text(
                            pkg,
                            style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                          ),
                          onTap: () => widget.onSelect(pkg),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
