import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/platform_paths.dart';
import '../models/sdk_install_progress.dart';
import '../providers/app_providers.dart';
import '../services/sdk_installer_service.dart';

class SdkSetupDialog extends ConsumerStatefulWidget {
  const SdkSetupDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const SdkSetupDialog(),
    );
  }

  @override
  ConsumerState<SdkSetupDialog> createState() => _SdkSetupDialogState();
}

class _SdkSetupDialogState extends ConsumerState<SdkSetupDialog> {
  int _currentStep = 0;
  late final TextEditingController _pathController;
  bool _acceptedLicense = false;
  bool _isInstalling = false;
  SdkInstallProgress? _progress;
  StreamSubscription<SdkInstallProgress>? _subscription;
  final ScrollController _logScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    final defaultPath = PlatformPaths.defaultSdkPath();
    _pathController = TextEditingController(text: defaultPath);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _pathController.dispose();
    _logScrollController.dispose();
    super.dispose();
  }

  Future<void> _pickDirectory() async {
    try {
      final selected = await FilePicker.getDirectoryPath(
        dialogTitle: 'Select Target Android SDK Folder',
        initialDirectory: _pathController.text,
      );
      if (selected != null && mounted) {
        setState(() {
          _pathController.text = selected;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open folder picker: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _startSetup() {
    setState(() {
      _currentStep = 2; // Step 2 is the live installation view
      _isInstalling = true;
    });

    final repo = ref.read(emulatorRepositoryProvider);
    final sdkPath = _pathController.text.trim();

    _subscription = repo
        .setupEnvironment(
      sdkPath: sdkPath,
    )
        .listen(
      (progress) {
        setState(() {
          _progress = progress;
        });

        // Auto-scroll logs to bottom
        if (_logScrollController.hasClients) {
          _logScrollController.jumpTo(_logScrollController.position.maxScrollExtent);
        }

        if (progress.isDone) {
          setState(() {
            _isInstalling = false;
          });
          // Update SDK path in settings
          ref.read(settingsControllerProvider.notifier).setSdkPath(sdkPath);
          ref.read(emulatorControllerProvider.notifier).refresh();
        }
      },
      onError: (err) {
        setState(() {
          _isInstalling = false;
          _progress = SdkInstallProgress(
            step: SdkInstallStep.error,
            currentStepIndex: _progress?.currentStepIndex ?? 0,
            totalSteps: 6,
            description: 'Setup encountered an error.',
            errorMessage: err.toString(),
            logs: [...?_progress?.logs, 'ERROR: $err'],
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              Expanded(
                child: _buildCurrentView(),
              ),
              const SizedBox(height: 16),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            CupertinoIcons.device_phone_portrait,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
            size: 28,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Standalone Android Environment Setup',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(
                'Install JDK 17, cmdline-tools, emulator, and Google APIs without Android Studio.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
        if (!_isInstalling)
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(CupertinoIcons.xmark),
          ),
      ],
    );
  }

  Widget _buildCurrentView() {
    if (_currentStep == 0) {
      return _buildStepPathAndSpecs();
    } else if (_currentStep == 1) {
      return _buildStepLicense();
    } else {
      return _buildStepInstallation();
    }
  }

  Widget _buildStepPathAndSpecs() {
    final envService = ref.read(systemEnvironmentServiceProvider);
    final abi = envService.getHostAbi();

    return ListView(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Components Managed & Installed:',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              _buildComponentRow(CupertinoIcons.layers_alt_fill, 'Eclipse Temurin OpenJDK 17+', 'Java runtime for sdkmanager and avdmanager'),
              _buildComponentRow(CupertinoIcons.chevron_left_slash_chevron_right, 'Android cmdline-tools', 'sdkmanager and avdmanager binaries from Google'),
              _buildComponentRow(CupertinoIcons.macwindow, 'Official Android Emulator', 'Google QEMU-based hardware-accelerated emulator'),
              _buildComponentRow(CupertinoIcons.link, 'Android Platform Tools', 'ADB (Android Debug Bridge) for state tracking & control'),
              _buildComponentRow(CupertinoIcons.photo, 'System Image (Google APIs)', 'Android 34 Google APIs ($abi) for full compatibility'),
              _buildComponentRow(CupertinoIcons.device_phone_portrait, 'Initial Virtual Device (AVD)', 'Configured Pixel profile ready to boot'),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text('Target SDK Installation Folder:', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _pathController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                  prefixIcon: Icon(CupertinoIcons.folder_open),
                  hintText: 'Enter destination path',
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonalIcon(
              onPressed: _pickDirectory,
              icon: const Icon(CupertinoIcons.folder),
              label: const Text('Browse'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(CupertinoIcons.info_circle, size: 16, color: Theme.of(context).colorScheme.outline),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Requires ~5-8 GB free disk space for SDK, tools, system image, and device storage.',
                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildComponentRow(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: Theme.of(context).textTheme.bodySmall,
                children: [
                  TextSpan(text: '$title: ', style: const TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(text: subtitle),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepLicense() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Android SDK License Agreement',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          'Google requires each user to download the SDK on their own machine and accept the official license terms before installation.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: const SingleChildScrollView(
              child: SelectableText(
                SdkInstallerService.androidSdkLicenseAgreementText,
                style: TextStyle(fontFamily: 'monospace', fontSize: 11, height: 1.4),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: () => setState(() => _acceptedLicense = !_acceptedLicense),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Checkbox(
                  value: _acceptedLicense,
                  onChanged: (val) => setState(() => _acceptedLicense = val ?? false),
                ),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'I have read and accept the Android Software Development Kit License Agreement.',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStepInstallation() {
    final p = _progress;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (_isInstalling)
              const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            else if (p?.isDone == true)
              const Icon(CupertinoIcons.checkmark_circle_fill, color: Colors.green)
            else if (p?.hasError == true)
              const Icon(CupertinoIcons.exclamationmark_circle_fill, color: Colors.red),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                p?.description ?? 'Setting up environment...',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
            if (p != null)
              Text(
                'Step ${p.currentStepIndex}/${p.totalSteps}',
                style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 12),
              ),
          ],
        ),
        const SizedBox(height: 10),
        LinearProgressIndicator(
          value: p?.progress,
          borderRadius: BorderRadius.circular(4),
        ),
        const SizedBox(height: 16),
        Text('Installation Logs:', style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 6),
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white12),
            ),
            child: ListView.builder(
              controller: _logScrollController,
              itemCount: p?.logs.length ?? 0,
              itemBuilder: (context, index) {
                final line = p!.logs[index];
                return Text(
                  line,
                  style: const TextStyle(
                    color: Colors.lightGreenAccent,
                    fontFamily: 'monospace',
                    fontSize: 11,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    if (_currentStep == 0) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: _pathController.text.trim().isEmpty
                ? null
                : () => setState(() => _currentStep = 1),
            icon: const Icon(CupertinoIcons.arrow_right),
            label: const Text('Next: Review License'),
          ),
        ],
      );
    } else if (_currentStep == 1) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          OutlinedButton.icon(
            onPressed: () => setState(() => _currentStep = 0),
            icon: const Icon(CupertinoIcons.arrow_left),
            label: const Text('Back'),
          ),
          FilledButton.icon(
            onPressed: _acceptedLicense ? _startSetup : null,
            icon: const Icon(CupertinoIcons.arrow_down_to_line),
            label: const Text('Accept & Start Setup'),
          ),
        ],
      );
    } else {
      final isDone = _progress?.isDone == true;
      final hasError = _progress?.hasError == true;

      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (hasError)
            OutlinedButton(
              onPressed: () => setState(() => _currentStep = 0),
              child: const Text('Retry'),
            ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: isDone
                ? () {
                    Navigator.of(context).pop();
                  }
                : null,
            child: Text(isDone ? 'Finished & Ready' : 'Installing...'),
          ),
        ],
      );
    }
  }
}
