import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';

class DeviceProfileInfo {
  const DeviceProfileInfo({
    required this.id,
    required this.name,
    required this.category,
    required this.screenSize,
    required this.resolution,
    required this.density,
    required this.icon,
  });

  final String id;
  final String name;
  final String category; // 'Phone', 'Tablet', 'Foldable', 'TV'
  final String screenSize;
  final String resolution;
  final String density;
  final IconData icon;
}

class AndroidVersionInfo {
  const AndroidVersionInfo({
    required this.api,
    required this.versionName,
    required this.dessertName,
    this.isRecommended = false,
  });

  final String api;
  final String versionName;
  final String dessertName;
  final bool isRecommended;
}

class CreateAvdDialog extends ConsumerStatefulWidget {
  const CreateAvdDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const CreateAvdDialog(),
    );
  }

  @override
  ConsumerState<CreateAvdDialog> createState() => _CreateAvdDialogState();
}

class _CreateAvdDialogState extends ConsumerState<CreateAvdDialog> {
  static const List<DeviceProfileInfo> _devices = [
    DeviceProfileInfo(
      id: 'pixel_9_pro',
      name: 'Google Pixel 9 Pro',
      category: 'Phone',
      screenSize: '6.3"',
      resolution: '1280 × 2856',
      density: '495 dpi',
      icon: CupertinoIcons.device_phone_portrait,
    ),
    DeviceProfileInfo(
      id: 'pixel_9',
      name: 'Google Pixel 9',
      category: 'Phone',
      screenSize: '6.3"',
      resolution: '1080 × 2424',
      density: '422 dpi',
      icon: CupertinoIcons.device_phone_portrait,
    ),
    DeviceProfileInfo(
      id: 'pixel_8_pro',
      name: 'Google Pixel 8 Pro',
      category: 'Phone',
      screenSize: '6.7"',
      resolution: '1344 × 2992',
      density: '489 dpi',
      icon: CupertinoIcons.device_phone_portrait,
    ),
    DeviceProfileInfo(
      id: 'pixel_8',
      name: 'Google Pixel 8',
      category: 'Phone',
      screenSize: '6.2"',
      resolution: '1080 × 2400',
      density: '428 dpi',
      icon: CupertinoIcons.device_phone_portrait,
    ),
    DeviceProfileInfo(
      id: 'pixel_7_pro',
      name: 'Google Pixel 7 Pro',
      category: 'Phone',
      screenSize: '6.7"',
      resolution: '1440 × 3120',
      density: '512 dpi',
      icon: CupertinoIcons.device_phone_portrait,
    ),
    DeviceProfileInfo(
      id: 'pixel_7',
      name: 'Google Pixel 7',
      category: 'Phone',
      screenSize: '6.3"',
      resolution: '1080 × 2400',
      density: '416 dpi',
      icon: CupertinoIcons.device_phone_portrait,
    ),
    DeviceProfileInfo(
      id: 'pixel_6_pro',
      name: 'Google Pixel 6 Pro',
      category: 'Phone',
      screenSize: '6.7"',
      resolution: '1440 × 3120',
      density: '512 dpi',
      icon: CupertinoIcons.device_phone_portrait,
    ),
    DeviceProfileInfo(
      id: 'pixel_6',
      name: 'Google Pixel 6',
      category: 'Phone',
      screenSize: '6.4"',
      resolution: '1080 × 2400',
      density: '411 dpi',
      icon: CupertinoIcons.device_phone_portrait,
    ),
    DeviceProfileInfo(
      id: 'pixel_fold',
      name: 'Google Pixel Fold',
      category: 'Foldable',
      screenSize: '7.6" / 5.8"',
      resolution: '1840 × 2208',
      density: '380 dpi',
      icon: CupertinoIcons.rectangle_split_3x1,
    ),
    DeviceProfileInfo(
      id: 'pixel_tablet',
      name: 'Google Pixel Tablet',
      category: 'Tablet',
      screenSize: '10.95"',
      resolution: '2560 × 1600',
      density: '276 dpi',
      icon: CupertinoIcons.device_phone_landscape,
    ),
    DeviceProfileInfo(
      id: 'resizable',
      name: 'Resizable Display',
      category: 'Phone',
      screenSize: 'Adaptive',
      resolution: 'Multi-window',
      density: 'Auto dpi',
      icon: CupertinoIcons.arrow_up_left_arrow_down_right,
    ),
    DeviceProfileInfo(
      id: 'medium_phone',
      name: 'Medium Phone',
      category: 'Phone',
      screenSize: '6.0"',
      resolution: '1080 × 2400',
      density: '420 dpi',
      icon: CupertinoIcons.device_phone_portrait,
    ),
    DeviceProfileInfo(
      id: 'medium_tablet',
      name: 'Medium Tablet',
      category: 'Tablet',
      screenSize: '10.1"',
      resolution: '1920 × 1200',
      density: '224 dpi',
      icon: CupertinoIcons.device_phone_landscape,
    ),
    DeviceProfileInfo(
      id: 'nexus_5',
      name: 'Nexus 5 Classic',
      category: 'Phone',
      screenSize: '4.95"',
      resolution: '1080 × 1920',
      density: '445 dpi',
      icon: CupertinoIcons.device_phone_portrait,
    ),
    DeviceProfileInfo(
      id: 'tv_1080p',
      name: 'Android TV 1080p',
      category: 'TV',
      screenSize: '1080p',
      resolution: '1920 × 1080',
      density: '320 dpi',
      icon: CupertinoIcons.tv,
    ),
  ];

  static const List<AndroidVersionInfo> _versions = [
    AndroidVersionInfo(api: '35', versionName: 'Android 15', dessertName: 'Vanilla Ice Cream'),
    AndroidVersionInfo(api: '34', versionName: 'Android 14', dessertName: 'Upside Down Cake', isRecommended: true),
    AndroidVersionInfo(api: '33', versionName: 'Android 13', dessertName: 'Tiramisu'),
    AndroidVersionInfo(api: '31', versionName: 'Android 12', dessertName: 'Snow Cone'),
    AndroidVersionInfo(api: '30', versionName: 'Android 11', dessertName: 'Red Velvet Cake'),
  ];

  late TextEditingController _nameController;
  DeviceProfileInfo _selectedDevice = _devices[3]; // Pixel 8
  AndroidVersionInfo _selectedVersion = _versions[1]; // Android 14 (API 34)
  String _categoryFilter = 'All';

  int _ramMb = 4096;
  int _cpuCores = 4;
  int _internalStorageMb = 16384;
  String _gpuMode = 'auto';
  bool _hardwareKeyboard = true;

  bool _isLoading = false;
  String? _progressMessage;
  final List<String> _liveLogs = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: _formatName(_selectedDevice.name, _selectedVersion.api));
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String _formatName(String deviceName, String api) {
    return '${deviceName.replaceAll(' ', '_')}_API_$api';
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
      _progressMessage = 'Initializing environment...';
      _errorMessage = null;
      _liveLogs.clear();
    });

    try {
      final envService = ref.read(systemEnvironmentServiceProvider);
      final abi = envService.getHostAbi();
      final systemImage = 'system-images;android-${_selectedVersion.api};google_apis;$abi';

      await ref.read(emulatorControllerProvider.notifier).createDevice(
        name: name,
        systemImage: systemImage,
        device: _selectedDevice.id,
        ramMb: _ramMb,
        cpuCores: _cpuCores,
        internalStorageMb: _internalStorageMb,
        gpuMode: _gpuMode,
        hardwareKeyboard: _hardwareKeyboard,
        onProgress: (msg) {
          if (mounted) {
            setState(() {
              _progressMessage = msg;
              _liveLogs.add(msg);
              if (_liveLogs.length > 50) {
                _liveLogs.removeAt(0);
              }
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
                Expanded(child: Text('Virtual Device "$name" created successfully! Ready to launch.')),
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
    final theme = Theme.of(context);
    final isDownloaded = _isImageDownloaded(_selectedVersion.api);

    final filteredDevices = _devices.where((d) {
      if (_categoryFilter == 'All') return true;
      if (_categoryFilter == 'Phones') return d.category == 'Phone';
      if (_categoryFilter == 'Tablets & Fold') return d.category == 'Tablet' || d.category == 'Foldable';
      if (_categoryFilter == 'Other') return d.category == 'TV';
      return true;
    }).toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: theme.colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960, maxHeight: 720),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            _buildDialogHeader(theme),
            const Divider(height: 1),

            // Content body: 2-column or live progress
            Expanded(
              child: _isLoading
                  ? _buildLoadingState(theme)
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Left Column: Device Hardware Catalog
                        SizedBox(
                          width: 360,
                          child: _buildDeviceCatalog(theme, filteredDevices),
                        ),
                        const VerticalDivider(width: 1),

                        // Right Column: Configuration & Specs
                        Expanded(
                          child: _buildConfigurationPanel(theme, isDownloaded),
                        ),
                      ],
                    ),
            ),
            const Divider(height: 1),

            // Footer
            _buildDialogFooter(theme, isDownloaded),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 16, 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(CupertinoIcons.device_phone_portrait, color: theme.colorScheme.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create Android Virtual Device',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 2),
                Text(
                  'Select device hardware profile, Android OS image, and configure performance.',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
            icon: const Icon(CupertinoIcons.xmark, size: 20),
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceCatalog(ThemeData theme, List<DeviceProfileInfo> filteredDevices) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category chips
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '1. Choose Device Hardware Profile',
                style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['All', 'Phones', 'Tablets & Fold', 'Other'].map((cat) {
                    final selected = _categoryFilter == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        selected: selected,
                        label: Text(cat, style: TextStyle(fontSize: 12, fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
                        onSelected: (_) => setState(() => _categoryFilter = cat),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        visualDensity: VisualDensity.compact,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Device List
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: filteredDevices.length,
            separatorBuilder: (_, _) => const SizedBox(height: 6),
            itemBuilder: (context, index) {
              final device = filteredDevices[index];
              final isSelected = _selectedDevice.id == device.id;

              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  setState(() {
                    _selectedDevice = device;
                    _nameController.text = _formatName(device.name, _selectedVersion.api);
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.primary.withValues(alpha: 0.1)
                        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? theme.colorScheme.primary : theme.dividerColor.withValues(alpha: 0.4),
                      width: isSelected ? 1.8 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isSelected ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          device.icon,
                          size: 18,
                          color: isSelected ? Colors.white : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              device.name,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                color: isSelected ? theme.colorScheme.primary : null,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${device.screenSize} • ${device.resolution} • ${device.density}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.outline,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        Icon(CupertinoIcons.checkmark_circle_fill, size: 18, color: theme.colorScheme.primary),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildConfigurationPanel(ThemeData theme, bool isDownloaded) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section 2: Name
          Row(
            children: [
              Expanded(
                child: Text(
                  '2. Virtual Device Name',
                  style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _nameController.text = _formatName(_selectedDevice.name, _selectedVersion.api);
                  });
                },
                icon: const Icon(CupertinoIcons.arrow_counterclockwise, size: 14),
                label: const Text('Reset Name', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              prefixIcon: const Icon(CupertinoIcons.pencil, size: 18),
              isDense: true,
              hintText: 'e.g. Pixel_8_API_34',
            ),
          ),
          const SizedBox(height: 24),

          // Section 3: Android Version (System Image)
          Text(
            '3. Choose Android OS Version',
            style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          _buildAndroidVersionGrid(theme),
          const SizedBox(height: 10),

          // System Image download badge
          _buildImageStatusCard(theme, isDownloaded),
          const SizedBox(height: 24),

          // Section 4: Hardware & Performance Tweaks
          Text(
            '4. Hardware & Performance Allocation',
            style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          _buildHardwareOptions(theme),

          if (_errorMessage != null) ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(CupertinoIcons.exclamationmark_circle, color: Colors.red, size: 20),
                  const SizedBox(width: 10),
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
    );
  }

  Widget _buildAndroidVersionGrid(ThemeData theme) {
    return Column(
      children: _versions.map((ver) {
        final isSelected = _selectedVersion.api == ver.api;
        final hasImg = _isImageDownloaded(ver.api);

        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () {
              setState(() {
                _selectedVersion = ver;
                _nameController.text = _formatName(_selectedDevice.name, ver.api);
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? theme.colorScheme.primary.withValues(alpha: 0.1)
                    : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? theme.colorScheme.primary : theme.dividerColor.withValues(alpha: 0.4),
                  width: isSelected ? 1.6 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isSelected ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.circle,
                    size: 20,
                    color: isSelected ? theme.colorScheme.primary : theme.dividerColor,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '${ver.versionName} (API ${ver.api})',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                              ),
                            ),
                            if (ver.isRecommended) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Recommended',
                                  style: TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          'Google APIs • ${ver.dessertName}',
                          style: TextStyle(fontSize: 11, color: theme.colorScheme.outline),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: hasImg ? Colors.green.withValues(alpha: 0.12) : Colors.orange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: hasImg ? Colors.green.withValues(alpha: 0.3) : Colors.orange.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          hasImg ? CupertinoIcons.checkmark_alt : CupertinoIcons.arrow_down_to_line,
                          size: 12,
                          color: hasImg ? Colors.green : Colors.orange.shade800,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          hasImg ? 'Ready' : 'Download (~1.2 GB)',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: hasImg ? Colors.green : Colors.orange.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildImageStatusCard(ThemeData theme, bool isDownloaded) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDownloaded
            ? Colors.green.withValues(alpha: 0.08)
            : Colors.amber.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDownloaded
              ? Colors.green.withValues(alpha: 0.3)
              : Colors.amber.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isDownloaded ? CupertinoIcons.checkmark_seal_fill : CupertinoIcons.cloud_download_fill,
            color: isDownloaded ? Colors.green : Colors.amber.shade900,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isDownloaded
                  ? 'System image already installed on disk. AVD will be created in seconds.'
                  : 'System image will be automatically downloaded and verified via sdkmanager before device creation.',
              style: TextStyle(
                fontSize: 12,
                color: isDownloaded ? Colors.green.shade900 : Colors.amber.shade900,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHardwareOptions(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // RAM selector
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('RAM Size', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<int>(
                    initialValue: _ramMb,
                    isDense: true,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    items: const [
                      DropdownMenuItem(value: 2048, child: Text('2 GB (Light)')),
                      DropdownMenuItem(value: 4096, child: Text('4 GB (Recommended)')),
                      DropdownMenuItem(value: 6144, child: Text('6 GB (Fast)')),
                      DropdownMenuItem(value: 8192, child: Text('8 GB (High Performance)')),
                      DropdownMenuItem(value: 12288, child: Text('12 GB (Heavy Multitask)')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _ramMb = val);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('CPU Cores', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<int>(
                    initialValue: _cpuCores,
                    isDense: true,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    items: const [
                      DropdownMenuItem(value: 2, child: Text('2 Cores')),
                      DropdownMenuItem(value: 4, child: Text('4 Cores (Recommended)')),
                      DropdownMenuItem(value: 6, child: Text('6 Cores')),
                      DropdownMenuItem(value: 8, child: Text('8 Cores (Ultra)')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _cpuCores = val);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Storage & GPU
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Internal Storage', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<int>(
                    initialValue: _internalStorageMb,
                    isDense: true,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    items: const [
                      DropdownMenuItem(value: 8192, child: Text('8 GB')),
                      DropdownMenuItem(value: 16384, child: Text('16 GB (Recommended)')),
                      DropdownMenuItem(value: 32768, child: Text('32 GB')),
                      DropdownMenuItem(value: 65536, child: Text('64 GB (Large)')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _internalStorageMb = val);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Graphics Mode', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: _gpuMode,
                    isDense: true,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'auto', child: Text('Auto (Hardware Accelerated)')),
                      DropdownMenuItem(value: 'host', child: Text('Host GPU (Native Passthrough)')),
                      DropdownMenuItem(value: 'swiftshader_indirect', child: Text('Software (SwiftShader)')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _gpuMode = val);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Keyboard toggle
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          dense: true,
          value: _hardwareKeyboard,
          title: const Text('Enable physical PC / Mac keyboard passthrough', style: TextStyle(fontSize: 13)),
          onChanged: (val) => setState(() => _hardwareKeyboard = val),
        ),
      ],
    );
  }

  Widget _buildLoadingState(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          const SizedBox(height: 20),
          Text(
            'Setting up Virtual Device',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _progressMessage ?? 'Working...',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Live log viewer
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: ListView.builder(
                itemCount: _liveLogs.length,
                itemBuilder: (context, idx) {
                  return Text(
                    _liveLogs[idx],
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
      ),
    );
  }

  Widget _buildDialogFooter(ThemeData theme, bool isDownloaded) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 14, 20, 16),
      child: Row(
        children: [
          // Selected summary
          Expanded(
            child: Row(
              children: [
                Icon(_selectedDevice.icon, size: 16, color: theme.colorScheme.outline),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    '${_selectedDevice.name} • ${_selectedVersion.versionName} • ${_ramMb ~/ 1024}GB RAM • $_cpuCores Cores',
                    style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          TextButton(
            onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _isLoading ? null : _createAvd,
            icon: Icon(
              isDownloaded ? CupertinoIcons.checkmark_alt : CupertinoIcons.arrow_down_to_line,
              size: 16,
            ),
            label: Text(
              _isLoading
                  ? 'Processing...'
                  : (isDownloaded ? 'Create Device' : 'Download & Create Device'),
            ),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }
}
