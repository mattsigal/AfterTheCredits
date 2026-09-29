import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:after_the_credits/data/services/aftercredits_scraper.dart';

class _RealHttpOverrides extends HttpOverrides {}

void main() {
  setUpAll(() {
    HttpOverrides.global = _RealHttpOverrides();
  });

  group('AfterCreditsScraper title normalization and matching', () {
    test('normalizes movie titles removing year, asterisks, and articles', () {
      expect(AfterCreditsScraper.normalizeTitle('Avatar (2009)*'), 'avatar');
      expect(AfterCreditsScraper.normalizeTitle('Dark Knight, The (2008)'), 'the dark knight');
      expect(AfterCreditsScraper.normalizeTitle('Deadpool & Wolverine (2024)*'), 'deadpool wolverine');
    });

    test('finds exact and prefix matches', () {
      final results = [
        AfterCreditsSearchResult(
          title: 'Avatar (2009)*',
          url: 'https://aftercredits.com/2011/04/avatar-2009/',
        ),
        AfterCreditsSearchResult(
          title: 'Avatar: The Way of Water (2022)*',
          url: 'https://aftercredits.com/2022/12/avatar-the-way-of-water-2022/',
        ),
      ];

      final exact = AfterCreditsScraper.findBestMatch('Avatar', results);
      expect(exact, isNotNull);
      expect(exact!.url, 'https://aftercredits.com/2011/04/avatar-2009/');

      final sequel = AfterCreditsScraper.findBestMatch('Avatar: The Way of Water', results);
      expect(sequel, isNotNull);
      expect(sequel!.url, 'https://aftercredits.com/2022/12/avatar-the-way-of-water-2022/');
    });
  });

  group('AfterCreditsScraper live WP REST API verification', () {
    test('searchMovies returns valid results for query', () async {
      final results = await AfterCreditsScraper.searchMovies('Deadpool');
      expect(results, isNotEmpty);
      expect(results.any((r) => r.title.contains('Deadpool')), isTrue);
      for (final r in results) {
        expect(r.url, startsWith('https://aftercredits.com'));
      }
    });

    test('fetchMovieDetails fetches and parses stinger data via WP REST API', () async {
      final movie = await AfterCreditsScraper.fetchMovieDetails(
        'https://aftercredits.com/2011/04/avatar-2009/',
        forceRefresh: true,
      );

      expect(movie, isNotNull);
      expect(movie!.title, contains('Avatar'));
      expect(movie.duringCreditsYesNo, isTrue);
      expect(movie.afterCreditsYesNo, isFalse);
      expect(movie.director, 'James Cameron');
      expect(movie.rating, 'PG-13');
    });
  });
}
