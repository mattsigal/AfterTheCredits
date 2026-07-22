import 'package:flutter_test/flutter_test.dart';
import 'package:after_the_credits/utils/title_formatter.dart';

void main() {
  group('TitleFormatter Tests', () {
    test('Formats trailing articles correctly', () {
      expect(TitleFormatter.formatDisplayTitle('Odyssey, The'), equals('The Odyssey'));
      expect(TitleFormatter.formatDisplayTitle('Matrix, The (1999)'), equals('The Matrix (1999)'));
      expect(TitleFormatter.formatDisplayTitle('Quiet Place, A'), equals('A Quiet Place'));
      expect(TitleFormatter.formatDisplayTitle('American in Paris, An'), equals('An American in Paris'));
    });

    test('Leaves unchanged standard titles without trailing articles', () {
      expect(TitleFormatter.formatDisplayTitle('Mulholland Drive'), equals('Mulholland Drive'));
      expect(TitleFormatter.formatDisplayTitle('Star Wars: Episode IV'), equals('Star Wars: Episode IV'));
    });

    test('Strips trailing asterisks from scraped titles', () {
      expect(TitleFormatter.formatDisplayTitle('Odyssey, The *'), equals('The Odyssey'));
      expect(TitleFormatter.formatDisplayTitle('Dune *'), equals('Dune'));
    });
  });
}
