class AppConstants {
  const AppConstants._();

  static const appName = 'Simulation Tray';
  static const appShortName = 'Tray';
  static const defaultRefreshInterval = Duration(seconds: 5);
  static const defaultWindowsSdkSuffix = r'AppData\Local\Android\Sdk';

  static const maxLogEntries = 2000;
  static const logBatchInterval = Duration(milliseconds: 100);
  static const monitorMaxHistory = 30;
}
