import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/platform_paths.dart';
import '../../providers/app_providers.dart';
import '../../widgets/process_manager_section.dart';
import '../../widgets/sdk_setup_dialog.dart';
import '../../widgets/setting_switch_tile.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final controller = ref.read(settingsControllerProvider.notifier);
    final emuState = ref.watch(emulatorControllerProvider).value;
    final accelAsync = ref.watch(hardwareAccelerationProvider);
    final scrcpyAsync = ref.watch(scrcpyAvailableProvider);

    return ListView(
      padding: const EdgeInsets.all(28),
      children: <Widget>[
        Text('Settings', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 20),

        // Standalone Android Environment Management Section
        _Section(
          title: 'Standalone Android Environment',
          children: <Widget>[
            const SizedBox(height: 10),
            Text(
              'No Android Studio is needed. AEM installs and manages Temurin JDK 17, Google cmdline-tools, the QEMU emulator binary, platform-tools, and system images directly.',
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            _EnvironmentDetailRow(
              icon: CupertinoIcons.layers_alt_fill,
              label: 'JDK 17+ (Java Home)',
              value: emuState?.sdk?.javaHome ?? 'Portable JDK / System JDK',
              statusOk: emuState?.sdk?.javaHome != null,
            ),
            const Divider(height: 16),
            _EnvironmentDetailRow(
              icon: CupertinoIcons.folder,
              label: 'Android SDK Root',
              value: emuState?.sdk?.path ?? 'Not configured',
              statusOk: emuState?.sdk != null,
            ),
            const Divider(height: 16),
            _EnvironmentDetailRow(
              icon: CupertinoIcons.chevron_left_slash_chevron_right,
              label: 'cmdline-tools (sdkmanager & avdmanager)',
              value: emuState?.sdk?.hasCmdlineTools == true ? 'Installed' : 'Missing',
              statusOk: emuState?.sdk?.hasCmdlineTools == true,
            ),
            const Divider(height: 16),
            _EnvironmentDetailRow(
              icon: CupertinoIcons.macwindow,
              label: 'Emulator Binary',
              value: emuState?.sdk?.hasEmulator == true
                  ? (emuState?.sdk?.version ?? emuState!.sdk!.emulatorPath)
                  : 'Missing',
              statusOk: emuState?.sdk?.hasEmulator == true,
            ),
            const Divider(height: 16),
            _EnvironmentDetailRow(
              icon: CupertinoIcons.link,
              label: 'Platform Tools (ADB)',
              value: emuState?.sdk?.hasAdb == true ? emuState!.sdk!.adbPath : 'Missing',
              statusOk: emuState?.sdk?.hasAdb == true,
            ),
            const Divider(height: 16),
            accelAsync.when(
              data: (info) => _EnvironmentDetailRow(
                icon: CupertinoIcons.speedometer,
                label: 'Hardware Acceleration',
                value: info.isAvailable ? info.hypervisorType ?? 'Active' : info.message,
                statusOk: info.isAvailable,
              ),
              loading: () => const _EnvironmentDetailRow(
                icon: CupertinoIcons.speedometer,
                label: 'Hardware Acceleration',
                value: 'Checking...',
                statusOk: true,
              ),
              error: (_, _) => const _EnvironmentDetailRow(
                icon: CupertinoIcons.speedometer,
                label: 'Hardware Acceleration',
                value: 'Check failed',
                statusOk: false,
              ),
            ),
            const Divider(height: 16),
            scrcpyAsync.when(
              data: (available) => _EnvironmentDetailRow(
                icon: CupertinoIcons.tv,
                label: 'Screen Mirroring (scrcpy)',
                value: available ? 'Installed and available' : 'Not detected in PATH (optional)',
                statusOk: available,
              ),
              loading: () => const _EnvironmentDetailRow(
                icon: CupertinoIcons.tv,
                label: 'Screen Mirroring (scrcpy)',
                value: 'Checking...',
                statusOk: true,
              ),
              error: (_, _) => const _EnvironmentDetailRow(
                icon: CupertinoIcons.tv,
                label: 'Screen Mirroring (scrcpy)',
                value: 'Not found',
                statusOk: false,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                FilledButton.icon(
                  onPressed: () => SdkSetupDialog.show(context),
                  icon: const Icon(CupertinoIcons.wrench_fill),
                  label: const Text('Setup / Repair Android Environment'),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    ref.invalidate(hardwareAccelerationProvider);
                    ref.read(emulatorControllerProvider.notifier).refresh();
                  },
                  icon: const Icon(CupertinoIcons.refresh),
                  label: const Text('Re-check System'),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ),

        const SizedBox(height: 18),
        _Section(
          title: 'Android SDK',
          children: <Widget>[
            const SizedBox(height: 10),
            Builder(
              builder: (innerContext) {
                final isCustom = settings.sdkPath != null && settings.sdkPath!.trim().isNotEmpty;
                final detectedSdk = emuState?.sdk;
                final isSdkConfigured = detectedSdk != null;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: (isCustom ? Colors.purple : Theme.of(innerContext).colorScheme.primary).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            isCustom ? CupertinoIcons.folder_badge_person_crop : CupertinoIcons.folder,
                            color: isCustom ? Colors.purple : Theme.of(innerContext).colorScheme.primary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  Text(
                                    isCustom ? 'Custom SDK Path' : 'Auto Detect (Default)',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isCustom
                                          ? Colors.purple.withValues(alpha: 0.15)
                                          : Theme.of(innerContext).colorScheme.primaryContainer,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      isCustom ? 'CUSTOM' : 'AUTO',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: isCustom
                                            ? Colors.purple.shade700
                                            : Theme.of(innerContext).colorScheme.onPrimaryContainer,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              SelectableText(
                                isCustom
                                    ? settings.sdkPath!
                                    : (isSdkConfigured
                                        ? detectedSdk.path
                                        : 'No SDK detected automatically. Check standard locations or choose manually.'),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontFamily: isCustom || isSdkConfigured ? 'monospace' : null,
                                  color: isSdkConfigured
                                      ? null
                                      : Theme.of(innerContext).colorScheme.error,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: <Widget>[
                                  Icon(
                                    isSdkConfigured ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.exclamationmark_triangle_fill,
                                    size: 16,
                                    color: isSdkConfigured ? Colors.green : Colors.amber.shade800,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      isSdkConfigured
                                          ? 'SDK Active • Emulator: ${detectedSdk.hasEmulator ? "Ready" : "Missing"} • ADB: ${detectedSdk.hasAdb ? "Ready" : "Missing"}'
                                          : (isCustom
                                              ? 'Selected folder is missing emulator or adb binary.'
                                              : 'ANDROID_HOME, ANDROID_SDK_ROOT, and default platform paths were checked.'),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isSdkConfigured
                                            ? Colors.green.shade800
                                            : Colors.amber.shade900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Wrap(
                          spacing: 8,
                          children: <Widget>[
                            OutlinedButton.icon(
                              onPressed: () async {
                                String? rawPath;
                                try {
                                  rawPath = await FilePicker.getDirectoryPath(
                                    dialogTitle: 'Select Android SDK root folder',
                                  );
                                } catch (e) {
                                  if (innerContext.mounted) {
                                    ScaffoldMessenger.of(innerContext).showSnackBar(
                                      SnackBar(
                                        content: Text('Could not open folder picker: $e'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                  return;
                                }
                                if (rawPath == null) return;

                                final resolved = PlatformPaths.resolveSdkRoot(rawPath);
                                final sdk = await ref.read(sdkDetectionServiceProvider).validate(resolved);

                                if (sdk != null) {
                                  await controller.setSdkPath(resolved);
                                  await ref.read(emulatorControllerProvider.notifier).refresh();
                                  if (innerContext.mounted) {
                                    ScaffoldMessenger.of(innerContext).showSnackBar(
                                      SnackBar(
                                        content: Text('Android SDK configured: $resolved'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                } else {
                                  if (innerContext.mounted) {
                                    showDialog<void>(
                                      context: innerContext,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('Missing SDK Components'),
                                        content: Text(
                                          'The selected folder does not appear to contain a valid Android SDK.\n\n'
                                          'Path: $rawPath\n\n'
                                          'A valid SDK root must contain an "emulator" folder and a "platform-tools" (adb) folder.\n\n'
                                          'Would you like to keep this folder anyway?',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(ctx),
                                            child: const Text('Cancel'),
                                          ),
                                          FilledButton(
                                            onPressed: () async {
                                              Navigator.pop(ctx);
                                              await controller.setSdkPath(resolved);
                                              await ref.read(emulatorControllerProvider.notifier).refresh();
                                            },
                                            child: const Text('Use Anyway'),
                                          ),
                                        ],
                                      ),
                                    );
                                  }
                                }
                              },
                              icon: const Icon(CupertinoIcons.folder_open, size: 16),
                              label: const Text('Choose Folder'),
                            ),
                            FilledButton.tonal(
                              style: FilledButton.styleFrom(
                                backgroundColor: !isCustom
                                    ? Theme.of(innerContext).colorScheme.primaryContainer
                                    : null,
                              ),
                              onPressed: !isCustom
                                  ? null
                                  : () async {
                                      await controller.setSdkPath(null);
                                      await ref.read(emulatorControllerProvider.notifier).refresh();
                                      if (innerContext.mounted) {
                                        final newSdk = ref.read(emulatorControllerProvider).value?.sdk;
                                        ScaffoldMessenger.of(innerContext).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              newSdk != null
                                                  ? 'Switched to Auto Detect. Found SDK: ${newSdk.path}'
                                                  : 'Switched to Auto Detect. No SDK found in standard locations.',
                                            ),
                                            backgroundColor: newSdk != null ? Colors.green : Colors.orange,
                                          ),
                                        );
                                      }
                                    },
                              child: const Text('Auto Detect'),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Background Processes & CPU Task Manager
        const ProcessManagerSection(),

        const SizedBox(height: 24),
        _Section(
          title: 'Appearance',
          children: <Widget>[
            const SizedBox(height: 18),
            SegmentedButton<ThemeMode>(
              segments: const <ButtonSegment<ThemeMode>>[
                ButtonSegment(value: ThemeMode.system, label: Text('System'), icon: Icon(CupertinoIcons.circle_righthalf_fill)),
                ButtonSegment(value: ThemeMode.light, label: Text('Light'), icon: Icon(CupertinoIcons.sun_max)),
                ButtonSegment(value: ThemeMode.dark, label: Text('Dark'), icon: Icon(CupertinoIcons.moon)),
              ],
              selected: <ThemeMode>{settings.themeMode},
              onSelectionChanged: (selection) => controller.setThemeMode(selection.first),
            ),
            const SizedBox(height: 8),
          ],
        ),
        const SizedBox(height: 18),
        _Section(
          title: 'Behavior',
          children: [
            const SizedBox(height: 18),
            SettingSwitchTile(
              title: 'Start with Windows',
              subtitle: 'Launch automatically when Windows starts.',
              value: settings.startWithWindows,
              onChanged: controller.setStartWithWindows,
            ),
            const SizedBox(height: 12),
            SettingSwitchTile(
              title: 'Notifications',
              subtitle: 'Show desktop notifications for emulator events.',
              value: settings.notificationsEnabled,
              onChanged: (value) =>
                  controller.update(settings.copyWith(notificationsEnabled: value)),
            ),
            const SizedBox(height: 12),
            SettingSwitchTile(
              title: 'Minimize to tray',
              subtitle: 'Closing the window hides it in the system tray.',
              value: settings.minimizeToTray,
              onChanged: (value) =>
                  controller.update(settings.copyWith(minimizeToTray: value)),
            ),
            const SizedBox(height: 18),
          ],
        ),
        const SizedBox(height: 18),
        _Section(
          title: 'Refresh Interval',
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(CupertinoIcons.timer),
                Expanded(
                  child: Slider(
                    min: 3,
                    max: 60,
                    divisions: 57,
                    label: '${settings.refreshIntervalSeconds}s',
                    value: settings.refreshIntervalSeconds.toDouble(),
                    onChanged: (value) => controller.setRefreshInterval(value.round()),
                  ),
                ),
                SizedBox(
                  width: 56,
                  child: Text('${settings.refreshIntervalSeconds}s', textAlign: TextAlign.end),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 18),
        _Section(
          title: 'About AEM',
          children: const <Widget>[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(CupertinoIcons.info_circle),
              title: Text('Android Emulator Manager (AEM)'),
              subtitle: Text('Autonomous Android Emulator and Environment Manager. No Android Studio required.'),
            ),
          ],
        ),
      ],
    );
  }
}

class _EnvironmentDetailRow extends StatelessWidget {
  const _EnvironmentDetailRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.statusOk,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool statusOk;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: statusOk ? Colors.green : Colors.amber),
          const SizedBox(width: 12),
          SizedBox(
            width: 220,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(
                fontSize: 12,
                color: statusOk ? null : Colors.amber.shade800,
                fontFamily: value.contains('/') || value.contains('\\') ? 'monospace' : null,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            statusOk ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.exclamationmark_triangle_fill,
            size: 16,
            color: statusOk ? Colors.green : Colors.amber,
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            ...children,
          ],
        ),
      ),
    );
  }
}
