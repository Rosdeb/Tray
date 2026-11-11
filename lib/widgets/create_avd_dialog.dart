import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';

class CreateAvdDialog extends ConsumerStatefulWidget {
  const CreateAvdDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (context) => const CreateAvdDialog(),
    );
  }

  @override
  ConsumerState<CreateAvdDialog> createState() => _CreateAvdDialogState();
}

class _CreateAvdDialogState extends ConsumerState<CreateAvdDialog> {
  final _nameController = TextEditingController(text: 'Pixel_8_API_34');
  String _selectedDevice = 'pixel_8';
  String _selectedApi = '34';
  int _ramMb = 4096;
  bool _isLoading = false;
  String? _progressMessage;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String _formatName(String deviceId, String api) {
    final devName = deviceId
        .replaceAll('pixel_', 'Pixel_')
        .replaceAll('pro', 'Pro')
        .replaceAll('fold', 'Fold')
        .replaceAll('tablet', 'Tablet')
        .replaceAll('medium_', 'Medium_');
    return '${devName}_API_$api';
  }

  bool _isImageDownloaded(String api) {
    final sdk = ref.read(emulatorControllerProvider).value?.sdk;
    if (sdk == null) return false;
    final envService = ref.read(systemEnvironmentServiceProvider);
    final abi = envService.getHostAbi();
    final systemImagePkg = 'system-images;android-$api;google_apis;$abi';
    return ref.read(sdkInstallerServiceProvider).isSystemImageInstalled(
      sdkRoot: sdk.path,
      systemImagePkg: systemImagePkg,
    );
  }

  Future<void> _createAvd() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() {
      _isLoading = true;
      _progressMessage = 'Preparing environment...';
      _errorMessage = null;
    });

    try {
      final envService = ref.read(systemEnvironmentServiceProvider);
      final abi = envService.getHostAbi();
      final systemImage = 'system-images;android-$_selectedApi;google_apis;$abi';

      await ref.read(emulatorControllerProvider.notifier).createDevice(
        name: name,
        systemImage: systemImage,
        device: _selectedDevice,
        ramMb: _ramMb,
        onProgress: (msg) {
          if (mounted) {
            setState(() {
              _progressMessage = msg;
            });
          }
        },
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(CupertinoIcons.checkmark_circle_fill, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('Virtual Device "$name" created successfully!')),
              ],
            ),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDownloaded = _isImageDownloaded(_selectedApi);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(CupertinoIcons.device_phone_portrait, color: Colors.blueAccent),
          SizedBox(width: 10),
          Text('Create Android Virtual Device'),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameController,
                enabled: !_isLoading,
                decoration: const InputDecoration(
                  labelText: 'AVD Name',
                  hintText: 'e.g. Pixel_8_API_34',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedDevice,
                decoration: const InputDecoration(
                  labelText: 'Device Hardware Profile',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(value: 'pixel_9_pro', child: Text('Google Pixel 9 Pro (6.3" Flagship)')),
                  DropdownMenuItem(value: 'pixel_9', child: Text('Google Pixel 9 (6.3" Phone)')),
                  DropdownMenuItem(value: 'pixel_8_pro', child: Text('Google Pixel 8 Pro (6.7" Flagship)')),
                  DropdownMenuItem(value: 'pixel_8', child: Text('Google Pixel 8 (6.2" Phone)')),
                  DropdownMenuItem(value: 'pixel_7_pro', child: Text('Google Pixel 7 Pro (6.7" Phone)')),
                  DropdownMenuItem(value: 'pixel_7', child: Text('Google Pixel 7 (6.3" Phone)')),
                  DropdownMenuItem(value: 'pixel_6_pro', child: Text('Google Pixel 6 Pro (6.7" Phone)')),
                  DropdownMenuItem(value: 'pixel_6', child: Text('Google Pixel 6 (6.4" Phone)')),
                  DropdownMenuItem(value: 'pixel_fold', child: Text('Google Pixel Fold (7.6" Foldable)')),
                  DropdownMenuItem(value: 'pixel_tablet', child: Text('Google Pixel Tablet (10.95" Tablet)')),
                  DropdownMenuItem(value: 'resizable', child: Text('Resizable Display (Adaptive Phone/Tablet)')),
                  DropdownMenuItem(value: 'medium_phone', child: Text('Medium Phone (6.0" Display)')),
                  DropdownMenuItem(value: 'medium_tablet', child: Text('Medium Tablet (10.1" Display)')),
                  DropdownMenuItem(value: 'nexus_5', child: Text('Nexus 5 (Classic)')),
                  DropdownMenuItem(value: 'tv_1080p', child: Text('Android TV (1080p)')),
                ],
                onChanged: _isLoading
                    ? null
                    : (val) {
                        if (val != null) {
                          setState(() {
                            _selectedDevice = val;
                            _nameController.text = _formatName(val, _selectedApi);
                          });
                        }
                      },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedApi,
                decoration: const InputDecoration(
                  labelText: 'Android API Version',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(value: '35', child: Text('Android 15 (API 35 Google APIs)')),
                  DropdownMenuItem(value: '34', child: Text('Android 14 (API 34 Google APIs - Recommended)')),
                  DropdownMenuItem(value: '33', child: Text('Android 13 (API 33 Google APIs)')),
                  DropdownMenuItem(value: '31', child: Text('Android 12 (API 31 Google APIs)')),
                  DropdownMenuItem(value: '30', child: Text('Android 11 (API 30 Google APIs)')),
                  DropdownMenuItem(value: '29', child: Text('Android 10 (API 29 Google APIs)')),
                ],
                onChanged: _isLoading
                    ? null
                    : (val) {
                        if (val != null) {
                          setState(() {
                            _selectedApi = val;
                            _nameController.text = _formatName(_selectedDevice, val);
                          });
                        }
                      },
              ),
              const SizedBox(height: 8),

              // System Image Download Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: isDownloaded
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDownloaded
                        ? Colors.green.withValues(alpha: 0.3)
                        : Colors.orange.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isDownloaded
                          ? CupertinoIcons.checkmark_seal_fill
                          : CupertinoIcons.arrow_down_circle_fill,
                      color: isDownloaded ? Colors.green : Colors.orange,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isDownloaded
                            ? 'System Image Ready on Disk (Fast Creation)'
                            : 'Will auto-download system image via sdkmanager without Android Studio (~800MB - 1.4GB)',
                        style: TextStyle(
                          color: isDownloaded ? Colors.green.shade800 : Colors.orange.shade800,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: _ramMb,
                decoration: const InputDecoration(
                  labelText: 'Allocated RAM',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(value: 2048, child: Text('2048 MB (2 GB)')),
                  DropdownMenuItem(value: 4096, child: Text('4096 MB (4 GB - Recommended)')),
                  DropdownMenuItem(value: 6144, child: Text('6144 MB (6 GB)')),
                  DropdownMenuItem(value: 8192, child: Text('8192 MB (8 GB - High Performance)')),
                ],
                onChanged: _isLoading ? null : (val) {
                  if (val != null) setState(() => _ramMb = val);
                },
              ),

              if (_isLoading && _progressMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _progressMessage!,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (_errorMessage != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(CupertinoIcons.exclamationmark_circle, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _isLoading ? null : _createAvd,
          icon: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(CupertinoIcons.checkmark),
          label: Text(
            _isLoading
                ? 'Creating...'
                : (isDownloaded ? 'Create Device' : 'Download & Create Device'),
          ),
        ),
      ],
    );
  }
}
