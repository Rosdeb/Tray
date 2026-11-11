class BiosAndHardwareInfo {
  const BiosAndHardwareInfo({
    this.motherboardManufacturer,
    this.motherboardProduct,
    this.biosVendor,
    this.biosVersion,
    this.biosReleaseDate,
    this.cpuName,
    this.isVirtualizationFirmwareEnabled = false,
    this.isHypervisorPresent = false,
    this.whpxFeatureStatus,
    this.recommendedBiosKey = 'F2 or Del',
  });

  final String? motherboardManufacturer;
  final String? motherboardProduct;
  final String? biosVendor;
  final String? biosVersion;
  final String? biosReleaseDate;
  final String? cpuName;
  final bool isVirtualizationFirmwareEnabled;
  final bool isHypervisorPresent;
  final String? whpxFeatureStatus;
  final String recommendedBiosKey;

  String get motherboardSummary {
    final mfr = motherboardManufacturer?.trim() ?? '';
    final prod = motherboardProduct?.trim() ?? '';
    if (mfr.isNotEmpty && prod.isNotEmpty) {
      if (prod.toLowerCase().contains(mfr.toLowerCase())) {
        return prod;
      }
      return '$mfr $prod';
    }
    return mfr.isNotEmpty ? mfr : (prod.isNotEmpty ? prod : 'Standard Motherboard');
  }

  String get biosSummary {
    final v = biosVersion?.trim() ?? '';
    final d = biosReleaseDate?.trim() ?? '';
    if (v.isNotEmpty && d.isNotEmpty) {
      return '$v ($d)';
    }
    return v.isNotEmpty ? v : (d.isNotEmpty ? d : 'Unknown');
  }

  bool get isVirtualizationActive => isVirtualizationFirmwareEnabled || isHypervisorPresent;
}
