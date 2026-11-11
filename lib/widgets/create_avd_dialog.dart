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
  final _nameController = TextEditingController(text: 'Pixel_7_API_34');
  String _selectedDevice = 'pixel_7';
  String _selectedApi = '34';
  int _ramMb = 4096;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _createAvd() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() {
      _isLoading = true;
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
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Virtual Device "$name" created successfully!'),
            backgroundColor: Colors.green,
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
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'AVD Name',
                  hintText: 'e.g. Pixel_7_API_34',
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
                  DropdownMenuItem(value: 'pixel_7', child: Text('Google Pixel 7 (Phone)')),
                  DropdownMenuItem(value: 'pixel_8', child: Text('Google Pixel 8 (Phone)')),
                  DropdownMenuItem(value: 'pixel_fold', child: Text('Google Pixel Fold (Foldable)')),
                  DropdownMenuItem(value: 'pixel_tablet', child: Text('Google Pixel Tablet (Tablet)')),
                  DropdownMenuItem(value: 'nexus_5', child: Text('Nexus 5 (Classic)')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _selectedDevice = val);
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
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedApi = val;
                      _nameController.text = '${_selectedDevice.replaceAll('_', ' ').toUpperCase()}_API_$val'.replaceAll(' ', '_');
                    });
                  }
                },
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
                  DropdownMenuItem(value: 8192, child: Text('8192 MB (8 GB - High Performance)')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _ramMb = val);
                },
              ),
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
          label: Text(_isLoading ? 'Creating...' : 'Create Device'),
        ),
      ],
    );
  }
}
