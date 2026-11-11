import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tray/main.dart';
import 'package:tray/models/android_sdk.dart';
import 'package:tray/models/emulator.dart';
import 'package:tray/providers/app_providers.dart';

class _FakeEmulatorController extends EmulatorController {
  @override
  Future<EmulatorState> build() async {
    return const EmulatorState(
      sdk: AndroidSdk(
        path: r'C:\Android\Sdk',
        emulatorPath: r'C:\Android\Sdk\emulator\emulator.exe',
        adbPath: r'C:\Android\Sdk\platform-tools\adb.exe',
      ),
      emulators: [
        Emulator(
          name: 'Pixel_7_API_34',
          androidVersion: 'API 34',
          apiLevel: 34,
          architecture: 'x86_64',
          status: EmulatorStatus.offline,
        ),
      ],
    );
  }
}

void main() {
  testWidgets('AEM shell renders dashboard and settings', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    SharedPreferences.setMockInitialValues(<String, Object>{});
    final preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          emulatorControllerProvider.overrideWith(_FakeEmulatorController.new),
        ],
        child: const AemApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Android Emulator Manager'), findsWidgets);
    expect(find.text('Dashboard'), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Android SDK'), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.folder), findsWidgets);

    // Test Monitor screen at 988x545 (width ~886 after sidebar)
    tester.view.physicalSize = const Size(988, 545);
    await tester.tap(find.text('Monitor'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Real-Time Device Monitor'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Test Monitor screen at narrow 750x500 viewport
    tester.view.physicalSize = const Size(750, 500);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);

    // Test Customize Widgets dialog on small height viewport (500px)
    await tester.tap(find.text('Customize'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Customize Monitor Widgets'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Cancel'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
  });
}
