import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
// Transitive dependencies of url_launcher: the documented way to fake it.
// ignore: depend_on_referenced_packages
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';
import 'package:blukios_marketplace/features/account/screens/account_screen.dart';
import 'package:blukios_marketplace/features/account/viewmodels/account_viewmodel.dart';
import 'package:blukios_marketplace/features/balance/viewmodels/buyer_balance_viewmodel.dart';

class _FakeLauncher extends Fake
    with MockPlatformInterfaceMixin
    implements UrlLauncherPlatform {
  final launched = <String>[];

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launched.add(url);
    return true;
  }
}

// The screen refreshes both on open; neither is under test.
class _IdleAccount extends AccountNotifier {
  @override
  Future<void> loadProfile() async {}
}

class _IdleBalance extends BuyerBalanceNotifier {
  @override
  Future<void> load() async {}
}

void main() {
  late _FakeLauncher launcher;

  setUp(() {
    launcher = _FakeLauncher();
    UrlLauncherPlatform.instance = launcher;
  });

  Future<void> pumpAccount(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountProvider.overrideWith(_IdleAccount.new),
          buyerBalanceProvider.overrideWith(_IdleBalance.new),
        ],
        child: const MaterialApp(home: AccountScreen()),
      ),
    );
    await tester.pump();
  }

  // Web routes in fe-blue/src/router/routes/buyer.js, on the API's host.
  const links = {
    'Kebijakan Privasi': 'https://blukios.store/privacy',
    'Syarat & Ketentuan': 'https://blukios.store/terms',
  };
  for (final MapEntry(:key, :value) in links.entries) {
    testWidgets('"$key" opens $value', (tester) async {
      await pumpAccount(tester);

      await tester.scrollUntilVisible(find.text(key), 200);
      await tester.tap(find.text(key));
      await tester.pump();

      expect(launcher.launched, [value]);
    });
  }
}
