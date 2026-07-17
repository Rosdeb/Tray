import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:window_manager/window_manager.dart';
import '../core/constants/app_constants.dart';
import '../providers/app_providers.dart';
import '../services/update_service.dart';
import 'dashboard/dashboard_screen.dart';
import 'logs/logs_screen.dart';
import 'settings/settings_screen.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell>
    with WindowListener {
  int _selectedIndex = 0;
  bool _allowClose = false;

  @override
  void initState() {
    super.initState();
    _initializeTray();

    if (Platform.isWindows) {
      windowManager.addListener(this);
      windowManager.setPreventClose(true);
    }
  }

  Future<void> _initializeTray() async {
    await ref.read(trayServiceProvider).initialize(
      onRefresh: () =>
          ref.read(emulatorControllerProvider.notifier).refresh(),
      onExit: () async {
        _allowClose = true;
        if (Platform.isWindows) {
          await windowManager.destroy();
        }
      },
    );
  }

  @override
  Future<void> onWindowClose() async {
    if (_allowClose || !Platform.isWindows) return;

    final settings = ref.read(settingsControllerProvider);

    if (settings.minimizeToTray) {
      await windowManager.hide();
    } else {
      _allowClose = true;
      await windowManager.destroy();
    }
  }

  @override
  void dispose() {
    if (Platform.isWindows) {
      windowManager.removeListener(this);
    }

    ref.read(trayServiceProvider).dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      const DashboardScreen(),
      const SettingsScreen(),
      const LogsScreen(),
    ];

    return Scaffold(
      body: Row(
        children: [
          AppSidebar(
            selectedIndex: _selectedIndex,
            onChanged: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
          ),

          VerticalDivider(
            width: 1,
            color: Theme.of(context).dividerColor,
          ),

          Expanded(
            child: Column(
              children: [
                if (Platform.isWindows)
                  const DragToMoveArea(
                    child: SizedBox(
                      height: 36,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          WindowCaptionButtons(),
                        ],
                      ),
                    ),
                  ),

                Expanded(
                  child: pages[_selectedIndex],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AppSidebar extends ConsumerWidget {
  const AppSidebar({
    super.key,
    required this.selectedIndex,
    required this.onChanged,
  });

  final int selectedIndex;
  final ValueChanged<int> onChanged;

  static const items = [
    SidebarItem(
      icon: Iconsax.element_4_copy,
      selectedIcon: Iconsax.element_4,
      title: 'Dashboard',
    ),
    SidebarItem(
      icon: Iconsax.setting_2_copy,
      selectedIcon: Iconsax.setting_2,
      title: 'Settings',
    ),
    SidebarItem(
      icon: Iconsax.document_copy,
      selectedIcon: Iconsax.document,
      title: 'Logs',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 180,
      color: colorScheme.surface,
      child: Column(
        children: [
          const SizedBox(height: 24),

          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              itemCount: items.length,
              itemBuilder: (_, index) {
                return SidebarTile(
                  item: items[index],
                  active: selectedIndex == index,
                  onTap: () => onChanged(index),
                );
              },
            ),
          ),

          const VersionUpdateTile(),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class VersionUpdateTile extends ConsumerStatefulWidget {
  const VersionUpdateTile({super.key});

  @override
  ConsumerState<VersionUpdateTile> createState() => _VersionUpdateTileState();
}

class _VersionUpdateTileState extends ConsumerState<VersionUpdateTile> {
  String _currentVersion = "";
  bool _downloading = false;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    setState(() => _currentVersion = info.version);
  }

  Future<void> _handleUpdate(UpdateInfo update) async {
    final service = ref.read(updateServiceProvider);

    setState(() {
      _downloading = true;
      _progress = 0;
    });

    try {
      final path = await service.downloadInstaller(
        update.downloadUrl,
        onProgress: (p) => setState(() => _progress = p),
      );
      await service.runInstallerAndExit(path);
    } catch (e) {
      setState(() => _downloading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Update failed: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final updateAsync = ref.watch(updateCheckProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "v$_currentVersion",
            style: TextStyle(
              fontSize: 11,
              color: colorScheme.onSurfaceVariant.withOpacity(.6),
            ),
          ),
          const SizedBox(height: 6),

          updateAsync.when(
            data: (update) {
              if (update == null) return const SizedBox.shrink();

              if (_downloading) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LinearProgressIndicator(value: _progress),
                    const SizedBox(height: 4),
                    Text(
                      "${(_progress * 100).toStringAsFixed(0)}%",
                      style: const TextStyle(fontSize: 10),
                    ),
                  ],
                );
              }

              return GestureDetector(
                onTap: () => _handleUpdate(update),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.system_update_alt,
                          size: 14, color: colorScheme.primary),
                      const SizedBox(width: 6),
                      Text(
                        "Update to v${update.latestVersion}",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}


class SidebarTile extends StatefulWidget {
  const SidebarTile({
    super.key,
    required this.item,
    required this.active,
    required this.onTap,
  });

  final SidebarItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  State<SidebarTile> createState() => _SidebarTileState();
}

class _SidebarTileState extends State<SidebarTile> {
  bool hover = false;
  bool pressed = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => hover = true),
      onExit: (_) => setState(() => hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => pressed = true),
        onTapUp: (_) => setState(() => pressed = false),
        onTapCancel: () => setState(() => pressed = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          transform: pressed
              ? (Matrix4.identity()..scale(.96))
              : Matrix4.identity(),
          decoration: BoxDecoration(
            color: widget.active
                ? colorScheme.primary.withOpacity(.10)
                : hover
                ? colorScheme.primary.withOpacity(.04)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border(
              left: BorderSide(
                color: widget.active
                    ? colorScheme.primary
                    : Colors.transparent,
                width: 4,
              ),
            ),
          ),
          child: Row(
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                child: Icon(
                  widget.active
                      ? widget.item.selectedIcon
                      : widget.item.icon,
                  key: ValueKey(widget.active),
                  color: widget.active
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                widget.item.title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight:
                  widget.active ? FontWeight.w600 : FontWeight.w500,
                  color: widget.active
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SidebarItem {
  final IconData icon;
  final IconData selectedIcon;
  final String title;

  const SidebarItem({
    required this.icon,
    required this.selectedIcon,
    required this.title,
  });
}

class WindowCaptionButtons extends StatelessWidget {
  const WindowCaptionButtons({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? Colors.white : Colors.black87;

    return Row(
      children: [
        IconButton(
          padding: EdgeInsets.zero,
          alignment: Alignment.center,
          constraints: const BoxConstraints(
            minWidth: 46,
            minHeight: 46,
          ),
          style: IconButton.styleFrom(
            fixedSize: const Size(46, 46),
            hoverColor: isDark
                ? Colors.white.withOpacity(0.1)
                : Colors.black.withOpacity(0.05),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
            ),
          ),
          onPressed: () => windowManager.minimize(),
          icon: Image.asset(
            'assets/icons/minize.png',
            width: 14,
            height: 14,
            color: iconColor, // Remove this if your PNG already has the desired color
            filterQuality: FilterQuality.high,
          ),
        ),

        IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 46, minHeight: 46),
          icon: const Icon(Icons.close, size: 16),
          style: IconButton.styleFrom(
            hoverColor: Colors.red,
            foregroundColor: iconColor,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
            ),
          ).copyWith(
            iconColor: WidgetStateProperty.resolveWith<Color?>((states) {
              if (states.contains(WidgetState.hovered)) return Colors.white;
              return iconColor;
            }),
          ),
          onPressed: () => windowManager.close(),
        ),
      ],
    );
  }
}