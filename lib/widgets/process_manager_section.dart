import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/system_process.dart';
import '../providers/app_providers.dart';

class ProcessManagerSection extends ConsumerStatefulWidget {
  const ProcessManagerSection({super.key});

  @override
  ConsumerState<ProcessManagerSection> createState() => _ProcessManagerSectionState();
}

class _ProcessManagerSectionState extends ConsumerState<ProcessManagerSection> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(processControllerProvider);
    final controller = ref.read(processControllerProvider.notifier);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final grouped = state.groupedProcesses;
    final totalProcesses = state.processes.length;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.6)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Header Row
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(CupertinoIcons.square_stack_3d_up_fill, color: colorScheme.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Background Processes & Task Manager',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Inspect CPU and memory, stop zombie emulators, or kill entire process groups.',
                      style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (state.selectedPids.isNotEmpty) ...[
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red.withValues(alpha: 0.15),
                    foregroundColor: Colors.red.shade700,
                  ),
                  onPressed: () => _confirmKillSelected(state.selectedPids.length),
                  icon: const Icon(CupertinoIcons.trash, size: 18),
                  label: Text('Kill Selected (${state.selectedPids.length})'),
                ),
                const SizedBox(width: 8),
              ],
              IconButton.outlined(
                tooltip: 'Refresh processes',
                onPressed: state.isLoading ? null : () => controller.refresh(),
                icon: state.isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(CupertinoIcons.refresh, size: 18),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Overview Metrics Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: <Widget>[
                _StatBadge(
                  icon: CupertinoIcons.square_grid_2x2,
                  label: 'Detected Processes',
                  value: totalProcesses.toString(),
                ),
                const SizedBox(width: 20),
                _StatBadge(
                  icon: CupertinoIcons.chart_pie,
                  label: 'Total RAM',
                  value: state.formattedTotalMemory,
                ),
                const Spacer(),
                if (state.processes.isNotEmpty)
                  TextButton.icon(
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                    onPressed: state.selectedPids.length == state.filteredProcesses.length
                        ? () => controller.deselectAll()
                        : () => controller.selectAll(),
                    icon: Icon(
                      state.selectedPids.length == state.filteredProcesses.length && state.filteredProcesses.isNotEmpty
                          ? CupertinoIcons.clear
                          : CupertinoIcons.checkmark_rectangle,
                      size: 16,
                    ),
                    label: Text(
                      state.selectedPids.length == state.filteredProcesses.length && state.filteredProcesses.isNotEmpty
                          ? 'Deselect All'
                          : 'Select All',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Search & Filter Row
          Row(
            children: <Widget>[
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by process name, PID, or args...',
                      hintStyle: const TextStyle(fontSize: 12),
                      prefixIcon: const Icon(CupertinoIcons.search, size: 18),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(CupertinoIcons.clear, size: 16),
                              onPressed: () {
                                _searchController.clear();
                                controller.setSearchQuery('');
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onChanged: (val) => controller.setSearchQuery(val),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Category Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                FilterChip(
                  label: const Text('All Groups', style: TextStyle(fontSize: 11)),
                  selected: state.filterCategory == null,
                  onSelected: (_) => controller.setFilterCategory(null),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 6),
                ...ProcessCategory.values.map((cat) {
                  final isSelected = state.filterCategory == cat;
                  final count = state.processes.where((p) => p.category == cat).length;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      avatar: Icon(cat.icon, size: 14),
                      label: Text('${cat.label} ($count)', style: const TextStyle(fontSize: 11)),
                      selected: isSelected,
                      onSelected: (_) => controller.setFilterCategory(isSelected ? null : cat),
                      visualDensity: VisualDensity.compact,
                    ),
                  );
                }),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Process List / Empty State
          if (state.isLoading && state.processes.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            )
          else if (grouped.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28),
              alignment: Alignment.center,
              child: Column(
                children: <Widget>[
                  Icon(CupertinoIcons.checkmark_circle, size: 40, color: Colors.green.withValues(alpha: 0.6)),
                  const SizedBox(height: 10),
                  Text(
                    state.searchQuery.isNotEmpty || state.filterCategory != null
                        ? 'No processes matched your filter.'
                        : 'No background Android or emulator processes detected.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: grouped.entries.length,
              separatorBuilder: (_, _) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final entry = grouped.entries.elementAt(index);
                final category = entry.key;
                final items = entry.value;

                final groupRamBytes = items.fold(0, (sum, p) => sum + p.memoryBytes);
                final groupRamMb = groupRamBytes / (1024 * 1024);
                final groupRamStr = groupRamMb >= 1024
                    ? '${(groupRamMb / 1024).toStringAsFixed(1)} GB'
                    : '${groupRamMb.toStringAsFixed(0)} MB';

                return Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: ExpansionTile(
                    initiallyExpanded: true,
                    leading: Icon(category.icon, color: colorScheme.primary),
                    title: Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            category.label,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${items.length}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSecondaryContainer,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '($groupRamStr RAM)',
                          style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                    trailing: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                        side: BorderSide(color: Colors.red.withValues(alpha: 0.4)),
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      ),
                      onPressed: () => _confirmKillGroup(category, items.length),
                      icon: const Icon(CupertinoIcons.stop_circle, size: 14),
                      label: const Text('Kill Group', style: TextStyle(fontSize: 11)),
                    ),
                    children: items.map((process) {
                      final isSelected = state.selectedPids.contains(process.pid);
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          border: Border(top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.3))),
                          color: isSelected ? colorScheme.primary.withValues(alpha: 0.05) : null,
                        ),
                        child: Row(
                          children: <Widget>[
                            Checkbox(
                              value: isSelected,
                              onChanged: (_) => controller.toggleSelect(process.pid),
                              visualDensity: VisualDensity.compact,
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'PID ${process.pid}',
                                style: const TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    process.name,
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (process.commandLine.isNotEmpty && process.commandLine != process.name)
                                    Text(
                                      process.commandLine,
                                      style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            // CPU Chip
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: process.cpuPercent > 10
                                    ? Colors.orange.withValues(alpha: 0.15)
                                    : colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'CPU ${process.formattedCpu}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: process.cpuPercent > 10 ? Colors.orange.shade800 : null,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            // RAM Chip
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'RAM ${process.formattedMemory}',
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Kill Button
                            IconButton(
                              tooltip: 'Kill process #${process.pid}',
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(CupertinoIcons.xmark, size: 16, color: Colors.red),
                              onPressed: () => _confirmKillProcess(process),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Future<void> _confirmKillProcess(SystemProcessItem process) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Terminate Process?'),
        content: Text('Are you sure you want to kill "${process.name}" (PID: ${process.pid})?'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Kill Process'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await ref.read(processControllerProvider.notifier).killProcess(process.pid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Terminated process #${process.pid}' : 'Failed to terminate process #${process.pid}'),
            backgroundColor: success ? Colors.green : Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _confirmKillGroup(ProcessCategory category, int count) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Kill All in ${category.label}?'),
        content: Text('This will force terminate all $count process(es) in this group. Continue?'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Kill Entire Group'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final killedCount = await ref.read(processControllerProvider.notifier).killGroup(category);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully terminated $killedCount process(es) in ${category.label}.'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _confirmKillSelected(int count) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kill Selected Processes?'),
        content: Text('This will force terminate $count selected process(es). Continue?'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Kill Selected'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final killedCount = await ref.read(processControllerProvider.notifier).killSelected();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Terminated $killedCount selected process(es).'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }
}

class _StatBadge extends StatelessWidget {
  const _StatBadge({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: <Widget>[
        Icon(icon, size: 16, color: theme.colorScheme.primary),
        const SizedBox(width: 6),
        Text('$label: ', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
