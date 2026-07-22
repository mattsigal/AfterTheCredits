import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:after_the_credits/main.dart';
import 'package:after_the_credits/providers/app_provider.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppProvider(),
        child: const AfterTheCreditsApp(),
      ),
    );

    expect(find.text('After The Credits'), findsOneWidget);
  });
}
