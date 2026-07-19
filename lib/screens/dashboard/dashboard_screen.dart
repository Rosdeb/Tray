import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/emulator.dart';
import '../../providers/app_providers.dart';
import '../../widgets/emulator_card.dart';
import '../../widgets/stat_tile.dart';

enum EmulatorFilter { all, running, offline, favorites }

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final _searchController = TextEditingController();
  EmulatorFilter _filter = EmulatorFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(emulatorControllerProvider);

    return state.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => _ErrorState(
        message: error.toString(),
        onRetry: () => ref.read(emulatorControllerProvider.notifier).refresh(),
      ),
      data: (data) {
        final emulators = _applyFilters(data.emulators);
        return RefreshIndicator(
          onRefresh: () => ref.read(emulatorControllerProvider.notifier).refresh(),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: <Widget>[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(28, 24, 28, 16),
                sliver: SliverToBoxAdapter(
                  child: _Header(
                    sdkPath: data.sdk?.path,
                    onRefresh: () => ref.read(emulatorControllerProvider.notifier).refresh(),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                sliver: SliverGrid.count(
                  crossAxisCount: MediaQuery.sizeOf(context).width > 1100 ? 4 : 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 2.8,
                  children: <Widget>[
                    StatTile(label: 'Installed', value: data.statistics.installed.toString(), icon: Icons.devices),
                    StatTile(label: 'Running', value: data.statistics.running.toString(), icon: Icons.play_circle),
                    StatTile(label: 'Favorites', value: data.statistics.favorites.toString(), icon: Icons.star),
                    StatTile(label: 'Booting', value: data.statistics.booting.toString(), icon: Icons.sync),
                  ],
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(28, 20, 28, 8),
                sliver: SliverToBoxAdapter(
                  child: _Toolbar(
                    searchController: _searchController,
                    filter: _filter,
                    onChanged: () => setState(() {}),
                    onFilterChanged: (filter) => setState(() => _filter = filter),
                  ),
                ),
              ),
              if (data.message != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyState(message: data.message!),
                )
              else if (emulators.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyState(message: 'No emulators match the current search and filter.'),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(28, 8, 28, 28),
                  sliver: SliverList.separated(
                    itemCount: emulators.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final emulator = emulators[index];
                      return EmulatorCard(
                        emulator: emulator,
                        isLaunching: data.launching.contains(emulator.name),
                        onFavorite: () => ref
                            .read(settingsControllerProvider.notifier)
                            .toggleFavorite(emulator.name),
                        onLaunch: () => ref.read(emulatorControllerProvider.notifier).launch(emulator),
                        onColdBoot: () => ref.read(emulatorControllerProvider.notifier).launch(emulator, coldBoot: true),
                        onStop: () => ref.read(emulatorControllerProvider.notifier).stop(emulator),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  List<Emulator> _applyFilters(List<Emulator> emulators) {
    final query = _searchController.text.trim().toLowerCase();
    return emulators.where((emulator) {
      final matchesQuery = query.isEmpty ||
          emulator.name.toLowerCase().contains(query) ||
          (emulator.androidVersion ?? '').toLowerCase().contains(query) ||
          (emulator.architecture ?? '').toLowerCase().contains(query) ||
          (emulator.apiLevel?.toString() ?? '').contains(query);
      final matchesFilter = switch (_filter) {
        EmulatorFilter.all => true,
        EmulatorFilter.running => emulator.status == EmulatorStatus.running,
        EmulatorFilter.offline => emulator.status == EmulatorStatus.offline,
        EmulatorFilter.favorites => emulator.isFavorite,
      };
      return matchesQuery && matchesFilter;
    }).toList(growable: false);
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.sdkPath, required this.onRefresh});

  final String? sdkPath;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Android Emulator Manager', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 6),
              Text(
                sdkPath == null ? 'Android SDK not configured' : sdkPath!,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
        FilledButton.icon(
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text(
            'Refresh',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ).copyWith(
            overlayColor: WidgetStateProperty.resolveWith<Color?>(
                  (Set<WidgetState> states) {
                if (states.contains(WidgetState.hovered)) {
                  return Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.08);
                }
                return null;
              },
            ),
          ),
        )
      ],
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.searchController,
    required this.filter,
    required this.onChanged,
    required this.onFilterChanged,
  });

  final TextEditingController searchController;
  final EmulatorFilter filter;
  final VoidCallback onChanged;
  final ValueChanged<EmulatorFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: TextField(
            controller: searchController,
            onChanged: (_) => onChanged(),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search by name, API, Android version, or architecture',
            ),
          ),
        ),
        const SizedBox(width: 12),
        SegmentedButton<EmulatorFilter>(
          segments: const <ButtonSegment<EmulatorFilter>>[
            ButtonSegment(value: EmulatorFilter.all, label: Text('All')),
            ButtonSegment(value: EmulatorFilter.running, label: Text('Running')),
            ButtonSegment(value: EmulatorFilter.offline, label: Text('Offline')),
            ButtonSegment(value: EmulatorFilter.favorites, label: Text('Favorites')),
          ],
          selected: <EmulatorFilter>{filter},
          onSelectionChanged: (selection) => onFilterChanged(selection.first),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.phonelink_off, size: 56, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.error_outline, size: 56),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
