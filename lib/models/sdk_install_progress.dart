enum SdkInstallStep {
  idle,
  checkingSystem,
  downloadingJdk,
  extractingJdk,
  downloadingCmdlineTools,
  extractingCmdlineTools,
  acceptingLicenses,
  installingPackages,
  creatingAvd,
  completed,
  error,
}

class SdkInstallProgress {
  const SdkInstallProgress({
    required this.step,
    required this.currentStepIndex,
    required this.totalSteps,
    required this.description,
    this.progress,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.currentOutput = '',
    this.logs = const <String>[],
    this.errorMessage,
  });

  final SdkInstallStep step;
  final int currentStepIndex;
  final int totalSteps;
  final String description;
  final double? progress; // 0.0 to 1.0, null if indeterminate
  final int downloadedBytes;
  final int totalBytes;
  final String currentOutput;
  final List<String> logs;
  final String? errorMessage;

  bool get isDone => step == SdkInstallStep.completed;
  bool get hasError => step == SdkInstallStep.error;

  SdkInstallProgress copyWith({
    SdkInstallStep? step,
    int? currentStepIndex,
    int? totalSteps,
    String? description,
    double? progress,
    bool clearProgress = false,
    int? downloadedBytes,
    int? totalBytes,
    String? currentOutput,
    List<String>? logs,
    String? errorMessage,
  }) {
    return SdkInstallProgress(
      step: step ?? this.step,
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      totalSteps: totalSteps ?? this.totalSteps,
      description: description ?? this.description,
      progress: clearProgress ? null : progress ?? this.progress,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      currentOutput: currentOutput ?? this.currentOutput,
      logs: logs ?? this.logs,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
