import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../models/emulator.dart';
import '../../providers/app_providers.dart';
import '../../widgets/create_avd_dialog.dart';
import '../../widgets/emulator_card.dart';
import '../../widgets/hardware_accel_banner.dart';
import '../../widgets/scrcpy_install_dialog.dart';
import '../../widgets/sdk_setup_dialog.dart';
import '../../widgets/stat_tile.dart';
import '../../widgets/wireless_connect_dialog.dart';

enum EmulatorFilter { all, running, physical, offline, favorites }

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final _searchController = TextEditingController();
  final _searchQuery = ValueNotifier<String>('');
  EmulatorFilter _filter = EmulatorFilter.all;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      _searchQuery.value = _searchController.text;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchQuery.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(emulatorControllerProvider);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.02),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: state.when(
        loading: () => const _DashboardSkeleton(key: ValueKey('skeleton')),
        error: (error, stackTrace) => _ErrorState(
          key: const ValueKey('error'),
          message: error.toString(),
          onRetry: () => ref.read(emulatorControllerProvider.notifier).refresh(),
        ),
        data: (data) {
          final hasSdk = data.sdk != null;

          return RefreshIndicator(
            key: const ValueKey('data'),
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
                    onConnectWireless: () => showDialog<void>(
                      context: context,
                      builder: (_) => const WirelessConnectDialog(),
                    ),
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
                sliver: SliverToBoxAdapter(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      final crossAxisCount = width > 800 ? 5 : width > 500 ? 3 : 2;
                      final aspectRatio = width > 800 ? 2.3 : 2.5;

                      return GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: crossAxisCount,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: aspectRatio,
                        children: <Widget>[
                          StatTile(
                            label: 'Installed AVDs',
                            value: data.statistics.installed.toString(),
                            icon: Iconsax.layer,
                          ),
                          StatTile(
                            label: 'Physical Devices',
                            value: data.statistics.physical.toString(),
                            icon: Iconsax.mobile,
                          ),
                          StatTile(
                            label: 'Running',
                            value: data.statistics.running.toString(),
                            icon: Iconsax.play_circle,
                          ),
                          StatTile(
                            label: 'Favorites',
                            value: data.statistics.favorites.toString(),
                            icon: Iconsax.star_1,
                          ),
                          StatTile(
                            label: 'Booting',
                            value: (data.statistics.booting + data.booting.length).toString(),
                            icon: Iconsax.refresh_circle,
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),

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
                    onFilterChanged: (filter) => setState(() => _filter = filter),
                    onCreateDevice: hasSdk ? () => CreateAvdDialog.show(context) : null,
                  ),
                ),
              ),

              ValueListenableBuilder<String>(
                valueListenable: _searchQuery,
                builder: (context, query, _) {
                  final emulators = _applyFilters(data.emulators, query);

                  if (hasSdk && emulators.isEmpty) {
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyState(
                        message: data.message ?? 'No virtual devices found.',
                        actionLabel: '+ Create Virtual Device',
                        onAction: () => CreateAvdDialog.show(context),
                      ),
                    );
                  }

                  if (emulators.isEmpty) {
                    return const SliverToBoxAdapter(child: SizedBox.shrink());
                  }

                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(28, 8, 28, 28),
                    sliver: SliverList.separated(
                      itemCount: emulators.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
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
                          onMirror: () => _handleMirror(context, emulator),
                          onViewLogs: () {
                            ref.read(selectedNavIndexProvider.notifier).selectTab(3);
                            ref.read(deviceLogsControllerProvider.notifier).selectTarget(
                              emulator.serial ?? emulator.name,
                            );
                          },
                          onSwitchToWifi: () async {
                            final res = await ref.read(emulatorControllerProvider.notifier).switchDeviceToWifi(emulator);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(res.message ?? (res.success ? 'Connected wirelessly!' : 'Failed to switch to Wi-Fi')),
                                  backgroundColor: res.success ? Colors.teal : Colors.red,
                                ),
                              );
                            }
                          },
                          onDisconnectWifi: () async {
                            final res = await ref.read(emulatorControllerProvider.notifier).disconnectWireless(emulator);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(res ? 'Wireless device disconnected' : 'Failed to disconnect'),
                                ),
                              );
                            }
                          },
                        );
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    ));
  }

  Future<void> _handleMirror(BuildContext context, Emulator emulator) async {
    final scrcpyInfo = await ref.read(scrcpyInfoProvider.future);
    if (!scrcpyInfo.isAvailable) {
      if (!context.mounted) return;
      final shouldInstall = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              Icon(Iconsax.monitor, size: 22, color: Theme.of(ctx).colorScheme.primary),
              const SizedBox(width: 10),
              const Text('scrcpy Required'),
            ],
          ),
          content: Text(
            Platform.isWindows
                ? 'Screen mirroring requires scrcpy, which was not found on your system.\n\nWould you like Tray to automatically download and install official standalone scrcpy now (~6.6 MB)?'
                : 'Screen mirroring requires scrcpy. Please install scrcpy (brew install scrcpy) or configure its path in Settings.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            if (Platform.isWindows)
              FilledButton.icon(
                onPressed: () => Navigator.of(ctx).pop(true),
                icon: const Icon(Icons.download, size: 16),
                label: const Text('Install Automatically'),
              ),
          ],
        ),
      );

      if (shouldInstall == true && context.mounted) {
        await ScrcpyInstallDialog.show(
          context,
          onSuccess: () {
            ref.read(emulatorControllerProvider.notifier).mirrorWithScrcpy(emulator);
          },
        );
      }
      return;
    }

    ref.read(emulatorControllerProvider.notifier).mirrorWithScrcpy(emulator);
  }

  List<Emulator> _applyFilters(List<Emulator> emulators, String queryText) {
    final query = queryText.trim().toLowerCase();
    return emulators.where((emulator) {
      final matchesQuery = query.isEmpty ||
          emulator.name.toLowerCase().contains(query) ||
          (emulator.androidVersion ?? '').toLowerCase().contains(query) ||
          (emulator.architecture ?? '').toLowerCase().contains(query) ||
          (emulator.apiLevel?.toString() ?? '').contains(query);
      final matchesFilter = switch (_filter) {
        EmulatorFilter.all => true,
        EmulatorFilter.running => emulator.status == EmulatorStatus.running,
        EmulatorFilter.physical => emulator.isPhysical,
        EmulatorFilter.offline => emulator.status == EmulatorStatus.offline && !emulator.isPhysical,
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
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primaryContainer.withValues(alpha: 0.6),
            colorScheme.surfaceContainerHigh,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.rocket_launch, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No Android Studio Needed! Standalone Environment',
                  style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Android Studio is just a GUI around command-line tools. This manager automatically installs portable OpenJDK 17, Google cmdline-tools, emulator, and Google APIs images.',
                  style: textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          FilledButton.icon(
            onPressed: onSetup,
            icon: const Icon(Icons.download, size: 18),
            label: const Text('Setup Environment Now'),
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
    required this.onConnectWireless,
  });

  final String? sdkPath;
  final bool hasSdk;
  final VoidCallback onRefresh;
  final VoidCallback onCreateAvd;
  final VoidCallback onSetupSdk;
  final VoidCallback onConnectWireless;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Simulation Tray', style: textTheme.headlineSmall),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    hasSdk ? Icons.check_circle : Icons.warning_amber_rounded,
                    size: 16,
                    color: hasSdk ? Colors.green : Colors.amber,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      sdkPath == null ? 'Android SDK not configured (Standalone mode available)' : sdkPath!,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall,
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
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Create Device'),
          ),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            onPressed: onConnectWireless,
            icon: const Icon(Icons.wifi, size: 18),
            label: const Text('Connect Wi-Fi'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.teal,
              side: BorderSide(color: Colors.teal.withValues(alpha: 0.5)),
            ),
          ),
          const SizedBox(width: 10),
        ] else ...[
          FilledButton.icon(
            onPressed: onSetupSdk,
            icon: const Icon(Icons.build, size: 18),
            label: const Text('Setup SDK'),
          ),
          const SizedBox(width: 10),
        ],
        FilledButton.tonalIcon(
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('Refresh'),
        ),
      ],
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.searchController,
    required this.filter,
    required this.onFilterChanged,
    this.onCreateDevice,
  });

  final TextEditingController searchController;
  final EmulatorFilter filter;
  final ValueChanged<EmulatorFilter> onFilterChanged;
  final VoidCallback? onCreateDevice;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: <Widget>[
        Expanded(
          child: TextField(
            controller: searchController,
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: const Icon(Icons.search, size: 20),
              hintText: 'Search by name, API, Android version, or architecture',
              filled: true,
              fillColor: colorScheme.surfaceContainerLow,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: colorScheme.outlineVariant, width: 0.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: colorScheme.outlineVariant, width: 0.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SegmentedButton<EmulatorFilter>(
          segments: const <ButtonSegment<EmulatorFilter>>[
            ButtonSegment(value: EmulatorFilter.all, label: Text('All')),
            ButtonSegment(value: EmulatorFilter.running, label: Text('Running')),
            ButtonSegment(value: EmulatorFilter.physical, label: Text('Physical')),
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
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Iconsax.mobile, size: 56, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center, style: textTheme.titleMedium),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add),
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
  const _ErrorState({super.key, required this.message, required this.onRetry});

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

class _DashboardSkeleton extends StatefulWidget {
  const _DashboardSkeleton({super.key});

  @override
  State<_DashboardSkeleton> createState() => _DashboardSkeletonState();
}

class _DashboardSkeletonState extends State<_DashboardSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.35, end: 0.8).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Widget _box({required double width, required double height, double radius = 8}) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        final colorScheme = Theme.of(context).colorScheme;
        return Opacity(
          opacity: _pulseAnimation.value,
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(radius),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Simulation Tray', style: theme.textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    _box(width: 260, height: 14, radius: 4),
                  ],
                ),
              ),
              _box(width: 140, height: 42, radius: 10),
              const SizedBox(width: 10),
              _box(width: 100, height: 42, radius: 10),
            ],
          ),
          const SizedBox(height: 24),

          Row(
            children: List.generate(4, (index) {
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: index < 3 ? 10 : 0),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: colorScheme.outlineVariant, width: 0.5),
                  ),
                  child: Row(
                    children: [
                      _box(width: 32, height: 32, radius: 8),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _box(width: 36, height: 18, radius: 4),
                            const SizedBox(height: 6),
                            _box(width: 64, height: 12, radius: 4),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 24),

          Row(
            children: [
              Expanded(
                child: _box(width: double.infinity, height: 46, radius: 10),
              ),
              const SizedBox(width: 12),
              _box(width: 220, height: 40, radius: 10),
            ],
          ),
          const SizedBox(height: 20),

          ...List.generate(2, (index) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colorScheme.outlineVariant, width: 0.5),
              ),
              child: Row(
                children: [
                  _box(width: 44, height: 44, radius: 10),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _box(width: 180, height: 18, radius: 4),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _box(width: 64, height: 16, radius: 6),
                            const SizedBox(width: 6),
                            _box(width: 72, height: 16, radius: 6),
                            const SizedBox(width: 6),
                            _box(width: 58, height: 16, radius: 6),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _box(width: 100, height: 38, radius: 10),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
