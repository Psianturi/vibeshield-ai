// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vibeshield_app/main.dart';
import 'package:vibeshield_app/providers/market_prices_provider.dart';
import 'package:vibeshield_app/models/vibe_models.dart';


void main() {
  testWidgets('App boots and shows HomeScreen', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          marketPricesProvider.overrideWith(
            (ref) => Stream.value(const <PriceData>[]),
          ),
        ],
        child: const MyApp(),
      ),
    );

    expect(find.text('🛡️ VibeShield AI'), findsOneWidget);
  });
}
