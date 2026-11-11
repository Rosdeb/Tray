enum AccelerationStatus {
  available,
  unavailable,
  unknown,
}

class HardwareAccelerationInfo {
  const HardwareAccelerationInfo({
    required this.status,
    required this.message,
    required this.details,
    this.hypervisorType,
    this.howToFix,
  });

  final AccelerationStatus status;
  final String message;
  final String details;
  final String? hypervisorType; // e.g. WHPX, AEHD, Hypervisor.framework, KVM
  final String? howToFix;

  bool get isAvailable => status == AccelerationStatus.available;
}
