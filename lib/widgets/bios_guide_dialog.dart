import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/bios_hardware_info.dart';
import '../providers/app_providers.dart';
import '../services/system_environment_service.dart';

class BiosGuideDialog extends ConsumerStatefulWidget {
  const BiosGuideDialog({super.key, this.initialVendor});

  final String? initialVendor;

  static Future<void> show(BuildContext context, {String? initialVendor}) {
    return showDialog<void>(
      context: context,
      builder: (context) => BiosGuideDialog(initialVendor: initialVendor),
    );
  }

  @override
  ConsumerState<BiosGuideDialog> createState() => _BiosGuideDialogState();
}

class _BiosGuideDialogState extends ConsumerState<BiosGuideDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const List<Map<String, dynamic>> _brands = [
    {
      'name': 'ASUS / ROG',
      'key': 'F2 or Del',
      'intelPath': 'Advanced Mode (F7) → Advanced → CPU Configuration → Intel Virtualization Technology → Enabled',
      'amdPath': 'Advanced Mode (F7) → Advanced → CPU Configuration → SVM Mode → Enabled',
      'saveKey': 'F10 (Save & Exit)',
      'notes': 'For ROG/TUF motherboards, press F7 first to switch from EZ Mode to Advanced Mode.',
      'vendorQuery': 'asus',
    },
    {
      'name': 'MSI',
      'key': 'Del',
      'intelPath': 'OC (Overclocking) → CPU Features → Intel Virtualization Tech → Enabled',
      'amdPath': 'OC (Overclocking) → CPU Features → SVM Mode → Enabled',
      'saveKey': 'F10 (Save & Exit)',
      'notes': 'If using MSI Click BIOS, switch to Advanced view to reveal the OC CPU Features submenu.',
      'vendorQuery': 'msi',
    },
    {
      'name': 'Gigabyte / AORUS',
      'key': 'Del or F12',
      'intelPath': 'Tweaker → Advanced CPU Settings → Intel Virtualization Technology → Enabled',
      'amdPath': 'Tweaker → Advanced CPU Settings → SVM Mode → Enabled',
      'saveKey': 'F10 (Save & Exit)',
      'notes': 'On older classic BIOS, locate under "M.I.T." → "Advanced Frequency Settings".',
      'vendorQuery': 'gigabyte',
    },
    {
      'name': 'Lenovo / ThinkPad',
      'key': 'F1, F2 or Enter',
      'intelPath': 'Security → Virtualization → Intel (R) Virtualization Technology → Enabled',
      'amdPath': 'Security → Virtualization → AMD V(TM) Technology → Enabled',
      'saveKey': 'F10 (Save & Exit)',
      'notes': 'On Legion laptops, press F2 repeatedly at power on. On ThinkPads, press Enter then F1.',
      'vendorQuery': 'lenovo',
    },
    {
      'name': 'Dell / Alienware',
      'key': 'F2 or F12',
      'intelPath': 'Virtualization Support → Virtualization → Check "Enable Intel Virtualization Technology"',
      'amdPath': 'Virtualization Support → Virtualization → Check "Enable AMD-V"',
      'saveKey': 'Apply Changes → Exit',
      'notes': 'Also enable "VT for Direct I/O" if available for best emulator acceleration.',
      'vendorQuery': 'dell',
    },
    {
      'name': 'HP / OMEN',
      'key': 'F10 or Esc',
      'intelPath': 'Configuration (or Security) → Virtualization Technology (VTx/VTd) → Enabled',
      'amdPath': 'Configuration (or Security) → Virtualization Technology (SVM) → Enabled',
      'saveKey': 'F10 (Save & Exit)',
      'notes': 'Press Esc immediately after powering on to show the Startup Menu, then press F10.',
      'vendorQuery': 'hp',
    },
    {
      'name': 'ASRock',
      'key': 'F2 or Del',
      'intelPath': 'Advanced → CPU Configuration → Intel Virtualization Technology → Enabled',
      'amdPath': 'Advanced → CPU Configuration → SVM Mode → Enabled',
      'saveKey': 'F10 (Save & Exit)',
      'notes': 'Navigate to the Advanced tab at the top and select CPU Configuration.',
      'vendorQuery': 'asrock',
    },
  ];

  @override
  void initState() {
    super.initState();
    int initialIndex = 0;
    if (widget.initialVendor != null) {
      final v = widget.initialVendor!.toLowerCase();
      for (int i = 0; i < _brands.length; i++) {
        if (v.contains(_brands[i]['vendorQuery'] as String)) {
          initialIndex = i;
          break;
        }
      }
    }
    _tabController = TabController(length: _brands.length, vsync: this, initialIndex: initialIndex);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _handleRebootToBios() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(CupertinoIcons.exclamationmark_triangle_fill, color: Colors.amber),
            SizedBox(width: 10),
            Text('Reboot to UEFI / BIOS?'),
          ],
        ),
        content: const Text(
          'Your PC will restart immediately and enter the motherboard UEFI / BIOS setup screen automatically.\n\nPlease save all open work and files before proceeding.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.amber.shade900),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Restart into BIOS Now'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await ref.read(systemEnvironmentServiceProvider).rebootToBios();
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not trigger automated UEFI reboot. Try running the app as Administrator, or restart manually pressing your BIOS key.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final biosInfoAsync = ref.watch(biosAndHardwareInfoProvider);
    final biosInfo = biosInfoAsync.value ?? const BiosAndHardwareInfo();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(CupertinoIcons.speedometer, color: colorScheme.primary, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hardware Virtualization & BIOS Setup',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Enable VT-x / AMD-V / SVM in your motherboard firmware for maximum emulator performance.',
                          style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(CupertinoIcons.xmark, size: 20),
                    tooltip: 'Close',
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Hardware detected pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    Icon(
                      biosInfo.isVirtualizationActive
                          ? CupertinoIcons.checkmark_seal_fill
                          : CupertinoIcons.exclamationmark_triangle_fill,
                      color: biosInfo.isVirtualizationActive ? Colors.green : Colors.amber.shade800,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Motherboard: ${biosInfo.motherboardSummary} • BIOS: ${biosInfo.biosSummary}',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            biosInfo.isVirtualizationActive
                                ? 'Hardware Virtualization is ENABLED and active on this system.'
                                : 'Virtualization is DISABLED in firmware. Follow the instructions below to enable it.',
                            style: TextStyle(
                              fontSize: 11,
                              color: biosInfo.isVirtualizationActive ? Colors.green.shade800 : Colors.amber.shade900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Brand Tabs
              TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: colorScheme.primary,
                unselectedLabelColor: colorScheme.onSurfaceVariant,
                indicatorColor: colorScheme.primary,
                tabs: _brands.map((b) => Tab(text: b['name'] as String)).toList(),
              ),
              const SizedBox(height: 12),

              // Tab contents
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: _brands.map((brand) {
                    return ListView(
                      padding: const EdgeInsets.only(top: 8, bottom: 8),
                      children: [
                        // BIOS Key callout
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(CupertinoIcons.keyboard, size: 18),
                              const SizedBox(width: 10),
                              Text(
                                'BIOS Key: ',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: colorScheme.surface,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: colorScheme.outlineVariant),
                                ),
                                child: Text(
                                  brand['key'] as String,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace', fontSize: 12),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '(Press repeatedly when powering on PC)',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Intel Step
                        Text(
                          'For Intel CPUs (VT-x / Intel Virtualization):',
                          style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: SelectableText(
                            brand['intelPath'] as String,
                            style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // AMD Step
                        Text(
                          'For AMD CPUs (AMD-V / SVM Mode):',
                          style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: SelectableText(
                            brand['amdPath'] as String,
                            style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Save & Notes
                        Row(
                          children: [
                            const Icon(CupertinoIcons.floppy_disk, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'Save Key: ${brand['saveKey']}',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          brand['notes'] as String,
                          style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),

              // Bottom safety notice & actions
              const Divider(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Direct BIOS flashing cannot be done safely by userland apps (it can brick your motherboard). Use your manufacturer\'s official flash tool or click reboot below to enter BIOS.',
                      style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                    ),
                  ),
                  const SizedBox(width: 14),
                  if (Platform.isWindows)
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.amber.shade900,
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: _handleRebootToBios,
                      icon: const Icon(CupertinoIcons.arrow_2_circlepath, size: 16),
                      label: const Text('Reboot into BIOS Now'),
                    ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                    onPressed: () => SystemEnvironmentService.openMotherboardBiosSupportPage(biosInfo.motherboardManufacturer),
                    icon: const Icon(CupertinoIcons.globe, size: 16),
                    label: const Text('Vendor Support'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
