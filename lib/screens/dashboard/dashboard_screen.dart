import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/emulator.dart';
import '../../providers/app_providers.dart';
import '../../widgets/create_avd_dialog.dart';
import '../../widgets/emulator_card.dart';
import '../../widgets/hardware_accel_banner.dart';
import '../../widgets/sdk_setup_dialog.dart';
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
      loading: () => Padding(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Android Emulator Manager', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 6),
            const Text('Loading emulators and environment...'),
            const SizedBox(height: 40),
            const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
      error: (error, stackTrace) => _ErrorState(
        message: error.toString(),
        onRetry: () => ref.read(emulatorControllerProvider.notifier).refresh(),
      ),
      data: (data) {
        final emulators = _applyFilters(data.emulators);
        final hasSdk = data.sdk != null;

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
                    hasSdk: hasSdk,
                    onRefresh: () => ref.read(emulatorControllerProvider.notifier).refresh(),
                    onCreateAvd: () => CreateAvdDialog.show(context),
                    onSetupSdk: () => SdkSetupDialog.show(context),
                  ),
                ),
              ),

              if (data.hardwareAccelInfo != null)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(28, 0, 28, 16),
                  sliver: SliverToBoxAdapter(
                    child: HardwareAccelBanner(info: data.hardwareAccelInfo!),
                  ),
                ),

              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                sliver: SliverGrid.count(
                  crossAxisCount: 4,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 2.8,
                  children: <Widget>[
                    StatTile(
                      label: 'Installed',
                      value: data.statistics.installed.toString(),
                      icon: CupertinoIcons.device_phone_portrait,
                    ),
                    StatTile(
                      label: 'Running',
                      value: data.statistics.running.toString(),
                      icon: CupertinoIcons.play_circle_fill,
                    ),
                    StatTile(
                      label: 'Favorites',
                      value: data.statistics.favorites.toString(),
                      icon: CupertinoIcons.star_fill,
                    ),
                    StatTile(
                      label: 'Booting',
                      value: (data.statistics.booting + data.booting.length).toString(),
                      icon: CupertinoIcons.arrow_2_circlepath,
                    ),
                  ],
                ),
              ),

              // Setup hero card if no SDK is configured
              if (!hasSdk)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(28, 20, 28, 12),
                  sliver: SliverToBoxAdapter(
                    child: _StandaloneSetupHeroCard(
                      onSetup: () => SdkSetupDialog.show(context),
                    ),
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
                    onCreateDevice: hasSdk ? () => CreateAvdDialog.show(context) : null,
                  ),
                ),
              ),

              if (hasSdk && emulators.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyState(
                    message: data.message ?? 'No virtual devices found.',
                    actionLabel: '+ Create Virtual Device',
                    onAction: () => CreateAvdDialog.show(context),
                  ),
                )
              else if (emulators.isNotEmpty)
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
                        assignedPort: data.assignedPorts[emulator.name],
                        onFavorite: () => ref
                            .read(settingsControllerProvider.notifier)
                            .toggleFavorite(emulator.name),
                        onLaunch: () => ref.read(emulatorControllerProvider.notifier).launch(emulator),
                        onColdBoot: () => ref.read(emulatorControllerProvider.notifier).launch(emulator, coldBoot: true),
                        onStop: () => ref.read(emulatorControllerProvider.notifier).stop(emulator),
                        onMirror: () => ref.read(emulatorControllerProvider.notifier).mirrorWithScrcpy(emulator),
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

class _StandaloneSetupHeroCard extends StatelessWidget {
  const _StandaloneSetupHeroCard({required this.onSetup});

  final VoidCallback onSetup;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.6),
            Theme.of(context).colorScheme.surfaceContainerHighest,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: const Icon(CupertinoIcons.rocket_fill, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No Android Studio Needed! Standalone Environment',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Android Studio is just a GUI around command-line tools. This manager automatically installs portable OpenJDK 17, Google cmdline-tools, emulator, and Google APIs images.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          FilledButton.icon(
            onPressed: onSetup,
            icon: const Icon(CupertinoIcons.arrow_down_to_line),
            label: const Text('Setup Environment Now'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.sdkPath,
    required this.hasSdk,
    required this.onRefresh,
    required this.onCreateAvd,
    required this.onSetupSdk,
  });

  final String? sdkPath;
  final bool hasSdk;
  final VoidCallback onRefresh;
  final VoidCallback onCreateAvd;
  final VoidCallback onSetupSdk;

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
              Row(
                children: [
                  Icon(
                    hasSdk ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.exclamationmark_triangle_fill,
                    size: 16,
                    color: hasSdk ? Colors.green : Colors.amber,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      sdkPath == null ? 'Android SDK not configured (Standalone mode available)' : sdkPath!,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (hasSdk) ...[
          FilledButton.icon(
            onPressed: onCreateAvd,
            icon: const Icon(CupertinoIcons.add, size: 18),
            label: const Text('Create Device'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(width: 10),
        ] else ...[
          FilledButton.icon(
            onPressed: onSetupSdk,
            icon: const Icon(CupertinoIcons.wrench_fill, size: 18),
            label: const Text('Setup SDK'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(width: 10),
        ],
        FilledButton.tonalIcon(
          onPressed: onRefresh,
          icon: const Icon(CupertinoIcons.refresh, size: 18),
          label: const Text('Refresh'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          ),
        ),
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
    this.onCreateDevice,
  });

  final TextEditingController searchController;
  final EmulatorFilter filter;
  final VoidCallback onChanged;
  final ValueChanged<EmulatorFilter> onFilterChanged;
  final VoidCallback? onCreateDevice;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: TextField(
            controller: searchController,
            onChanged: (_) => onChanged(),
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: const Icon(CupertinoIcons.search, size: 20),
              hintText: 'Search by name, API, Android version, or architecture',
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28),
                borderSide: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.5)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28),
                borderSide: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.5)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28),
                borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.5),
              ),
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
  const _EmptyState({
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(CupertinoIcons.device_phone_portrait, size: 56, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(CupertinoIcons.add),
                label: Text(actionLabel!),
              ),
            ],
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
            const Icon(CupertinoIcons.exclamationmark_circle, size: 56),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(onPressed: onRetry, icon: const Icon(CupertinoIcons.refresh), label: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
