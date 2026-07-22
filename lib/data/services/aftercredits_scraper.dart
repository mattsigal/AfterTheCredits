import 'package:html/parser.dart' as hp;
import 'package:http/http.dart' as http;
import '../models/movie_model.dart';
import '../database/database_helper.dart';
import '../../utils/title_formatter.dart';

class AfterCreditsSearchResult {
  final String title;
  final String url;
  final String? posterUrl;
  final String? snippet;

  AfterCreditsSearchResult({
    required this.title,
    required this.url,
    this.posterUrl,
    this.snippet,
  });

  String get displayTitle => TitleFormatter.formatDisplayTitle(title);
}

class AfterCreditsScraper {
  static const Map<String, String> _headers = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
  };

  static String normalizeTitle(String title) {
    var t = title.replaceAll(RegExp(r'\(\d{4}\)'), '').replaceAll(RegExp(r'[*?]'), '');
    if (t.contains(', The')) {
      t = 'The ${t.replaceAll(', The', '')}';
    }
    if (t.contains(', A')) {
      t = 'A ${t.replaceAll(', A', '')}';
    }
    t = t.replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), '');
    return t.toLowerCase().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).join(' ');
  }

  static AfterCreditsSearchResult? findBestMatch(
      String filmTitle, List<AfterCreditsSearchResult> searchResults) {
    final normTarget = normalizeTitle(filmTitle);
    if (normTarget.isEmpty) return null;

    // 1. Exact normalized title match
    for (final result in searchResults) {
      final normCandidate = normalizeTitle(result.title);
      if (normCandidate == normTarget) {
        return result;
      }
    }

    // 2. Starts with / prefix match
    for (final result in searchResults) {
      final normCandidate = normalizeTitle(result.title);
      if (normCandidate.startsWith(normTarget) || normTarget.startsWith(normCandidate)) {
        return result;
      }
    }

    return null;
  }

  /// Searches aftercredits.com for [query]
  static Future<List<AfterCreditsSearchResult>> searchMovies(String query) async {
    final searchUrl = Uri.parse('https://aftercredits.com/?s=${Uri.encodeComponent(query)}');
    try {
      final response = await http.get(searchUrl, headers: _headers);
      if (response.statusCode != 200) return [];

      final document = hp.parse(response.body);
      final results = <AfterCreditsSearchResult>[];

      final links = document.querySelectorAll('h3.entry-title a, h2.entry-title a, h1.entry-title a, header h2 a');
      for (final a in links) {
        final title = a.text.trim();
        final url = a.attributes['href'] ?? '';
        if (title.isEmpty || url.isEmpty || !url.contains('aftercredits.com')) continue;

        final parent = a.parent?.parent;
        final imgElem = parent?.querySelector('img');
        var posterUrl = imgElem?.attributes['src'] ?? imgElem?.attributes['data-src'];
        if (posterUrl != null && posterUrl.startsWith('data:image')) {
          posterUrl = null;
        }

        if (results.every((r) => r.url != url)) {
          results.add(
            AfterCreditsSearchResult(
              title: title,
              url: url,
              posterUrl: posterUrl,
            ),
          );
        }
      }

      return results;
    } catch (_) {
      return [];
    }
  }

  /// Scrapes movie detail page from aftercredits.com with DB cache support
  static Future<MovieModel?> fetchMovieDetails(String url, {bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = await DatabaseHelper.instance.getCachedMovie(url);
      if (cached != null) {
        return cached;
      }
    }

    try {
      final response = await http.get(Uri.parse(url), headers: _headers);
      if (response.statusCode != 200) return null;

      final doc = hp.parse(response.body);
      final content = doc.querySelector('div.td-post-content');
      if (content == null) return null;

      // Extract raw text
      final fullText = content.text;

      // Extract Title
      final titleElem = doc.querySelector('h1.entry-title');
      String title = titleElem?.text.trim() ?? '';
      if (title.endsWith('*')) title = title.substring(0, title.length - 1).trim();

      // Extract metadata fields using Regex
      final ratingMatch = RegExp(r'Rating:\s*([^\n\r]+)').firstMatch(fullText);
      final rating = ratingMatch?.group(1)?.replaceAll('\uFFFD', '').trim();

      final directorMatch = RegExp(r'Directed by:\s*([^\n\r]+)').firstMatch(fullText);
      final director = directorMatch?.group(1)?.replaceAll('\uFFFD', '').trim();

      final writersMatch = RegExp(r'Written by:\s*([^\n\r]+)').firstMatch(fullText);
      final writers = writersMatch?.group(1)?.replaceAll('\uFFFD', '').trim();

      final starringMatch = RegExp(r'Starring:\s*([^\n\r]+)').firstMatch(fullText);
      final starring = starringMatch?.group(1)?.replaceAll('\uFFFD', '').trim();

      final releaseDateMatch = RegExp(r'Release Date:\s*([^\n\r]+)').firstMatch(fullText);
      final releaseDate = releaseDateMatch?.group(1)?.replaceAll('\uFFFD', '').trim();

      final runningTimeMatch = RegExp(r'Running Time:\s*([^\n\r]+)').firstMatch(fullText);
      final runningTime = runningTimeMatch?.group(1)?.replaceAll('\uFFFD', '').trim();

      // Extract Links
      String? officialSiteUrl;
      String? imdbUrl;
      final links = content.querySelectorAll('a');
      for (final a in links) {
        final text = a.text.toLowerCase();
        final href = a.attributes['href'];
        if (text.contains('official site') || text.contains('official website')) {
          officialSiteUrl = href;
        } else if (text.contains('imdb') || (href != null && href.contains('imdb.com'))) {
          imdbUrl = href;
        }
      }

      // Extract Poster URL
      final imgElem = doc.querySelector('div.td-post-featured-image img, div.td-post-content img');
      final posterUrl = imgElem?.attributes['src'] ?? imgElem?.attributes['data-src'];

      // Extract Synopsis
      String? synopsis;
      final paragraphs = content.querySelectorAll('p');
      for (final p in paragraphs) {
        final text = p.text.trim();
        if (text.length > 80 &&
            !text.contains('Rating:') &&
            !text.contains('Directed by:') &&
            !text.contains('Extras') &&
            !text.contains('Credits')) {
          synopsis = text.replaceAll('\uFFFD', '').trim();
          break;
        }
      }

      // Extract Stingers
      bool? duringYesNo;
      String? duringText;
      bool? afterYesNo;
      String? afterText;

      final pList = content.querySelectorAll('p, div.spoiler-wrap');
      for (int i = 0; i < pList.length; i++) {
        final text = pList[i].text.trim();

        if (text.contains('Are There Any Extras During The Credits?')) {
          duringYesNo = text.toLowerCase().contains('yes');
        } else if (text.contains('Are There Any Extras After The Credits?')) {
          afterYesNo = text.toLowerCase().contains('yes');
        }

        // Spoiler text
        if (pList[i].classes.contains('spoiler-wrap')) {
          final sText = pList[i].text.replaceAll('Click to see what\'s during the credits', '')
              .replaceAll('Click to see what\'s after the credits', '')
              .replaceAll('\uFFFD', '')
              .trim();
          if (duringText == null && (duringYesNo == true || text.contains('during'))) {
            duringText = sText;
          } else {
            afterText = sText;
          }
        }
      }

      // Stinger Voting / Rating
      String? stingerRatingText;
      final ratingMatch2 = RegExp(r'(\+\d+\s+rating,\s*\d+\s+votes)').firstMatch(fullText);
      if (ratingMatch2 != null) {
        stingerRatingText = ratingMatch2.group(1);
      }

      final movie = MovieModel(
        title: title,
        url: url,
        posterUrl: posterUrl,
        rating: rating,
        director: director,
        writers: writers,
        starring: starring,
        releaseDate: releaseDate,
        runningTime: runningTime,
        officialSiteUrl: officialSiteUrl,
        imdbUrl: imdbUrl,
        synopsis: synopsis,
        duringCreditsYesNo: duringYesNo,
        duringCreditsText: duringText,
        afterCreditsYesNo: afterYesNo,
        afterCreditsText: afterText,
        stingerRatingText: stingerRatingText,
        cachedAt: DateTime.now(),
      );

      await DatabaseHelper.instance.saveCachedMovie(movie);
      return movie;
    } catch (_) {
      return null;
    }
  }
}
