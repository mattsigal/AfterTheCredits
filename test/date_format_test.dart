import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:after_the_credits/utils/ymd_date_localizations.dart';

void main() {
  testWidgets('DatePicker in input mode with YmdLocalizationsDelegate in showDatePicker builder', (tester) async {
    DateTime? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                selected = await showDatePicker(
                  context: context,
                  initialDate: DateTime(2026, 9, 28),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                  initialEntryMode: DatePickerEntryMode.input,
                  builder: (context, child) {
                    return Localizations.override(
                      context: context,
                      delegates: const [YmdLocalizationsDelegate()],
                      child: child,
                    );
                  },
                );
              },
              child: const Text('Open Picker'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Picker'));
    await tester.pumpAndSettle();

    // Check that dateHelpText shows yyyy/mm/dd
    expect(find.text('yyyy/mm/dd'), findsOneWidget);
    expect(find.text('2026/09/28'), findsOneWidget);

    // Enter a new date using yyyy/mm/dd
    await tester.enterText(find.byType(TextField), '2026/10/31');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(selected, DateTime(2026, 10, 31));
  });

  test('YmdMaterialLocalizations parseCompactDate parsing', () {
    const loc = YmdMaterialLocalizations();
    expect(loc.formatCompactDate(DateTime(2026, 9, 28)), '2026/09/28');
    expect(loc.dateHelpText, 'yyyy/mm/dd');
    expect(loc.parseCompactDate('2026/09/28'), DateTime(2026, 9, 28));
    expect(loc.parseCompactDate('2026-09-28'), DateTime(2026, 9, 28));
    expect(loc.parseCompactDate('invalid'), null);
  });

  test('Upcoming movie matching normalizes titles and URLs', () {
    String normalizeUrl(String url) {
      return url
          .trim()
          .toLowerCase()
          .replaceAll(RegExp(r'^https?://'), '')
          .replaceAll(RegExp(r'/+$'), '');
    }

    String normalizeTitle(String text) {
      return text
          .replaceAll(RegExp(r'\s*\(\d{4}\)\s*'), ' ')
          .replaceAll('*', '')
          .trim()
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '');
    }

    expect(
      normalizeUrl('https://aftercredits.com/2026/09/test-movie/'),
      normalizeUrl('http://aftercredits.com/2026/09/test-movie'),
    );
    expect(
      normalizeTitle('Alien: Romulus (2024)*'),
      normalizeTitle('Alien: Romulus'),
    );
  });
}

