import 'dart:convert';
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
    'User-Agent': 'AfterTheCredits/1.2.1 (Android; Mobile)',
    'Accept': 'application/json, text/html, */*',
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

  /// Searches aftercredits.com for [query] using WordPress REST API with fallback to HTML
  static Future<List<AfterCreditsSearchResult>> searchMovies(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    // 1. Try WordPress REST API (bypasses Automattic/nginx HTML bot challenges)
    try {
      final searchApiUrl = Uri.parse(
        'https://aftercredits.com/wp-json/wp/v2/posts?search=${Uri.encodeComponent(trimmed)}&_fields=id,title,link,jetpack_featured_media_url,content,slug',
      );
      final response = await http.get(searchApiUrl, headers: _headers);
      if (response.statusCode == 200) {
        final posts = json.decode(response.body) as List<dynamic>;
        final results = <AfterCreditsSearchResult>[];

        for (final post in posts) {
          final titleRaw = post['title']?['rendered'] as String? ?? '';
          final title = hp.parse(titleRaw).body?.text.trim() ?? titleRaw.trim();
          final url = post['link'] as String? ?? '';
          if (title.isEmpty || url.isEmpty) continue;

          var posterUrl = post['jetpack_featured_media_url'] as String?;
          final contentHtml = post['content']?['rendered'] as String? ?? '';
          if (posterUrl == null || posterUrl.isEmpty) {
            if (contentHtml.isNotEmpty) {
              final contentDoc = hp.parse(contentHtml);
              final img = contentDoc.querySelector('img');
              posterUrl = img?.attributes['src'] ?? img?.attributes['data-src'];
            }
          }
          if (posterUrl != null && posterUrl.startsWith('data:image')) {
            posterUrl = null;
          }

          // Pre-cache full movie details if available in post data to make opening detail instantaneous
          if (contentHtml.isNotEmpty) {
            try {
              final movie = _parseMoviePostData(post as Map<String, dynamic>, url);
              await DatabaseHelper.instance.saveCachedMovie(movie);
            } catch (_) {}
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

        if (results.isNotEmpty) {
          return results;
        }
      }
    } catch (_) {}

    // 2. Fallback to HTML scraping
    try {
      final searchUrl = Uri.parse('https://aftercredits.com/?s=${Uri.encodeComponent(trimmed)}');
      final response = await http.get(searchUrl, headers: _headers);
      if (response.statusCode != 200) return [];

      final document = hp.parse(response.body);
      final results = <AfterCreditsSearchResult>[];

      final links = document.querySelectorAll(
          'h3.entry-title a, h2.entry-title a, h1.entry-title a, header h2 a');
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
      try {
        final cached = await DatabaseHelper.instance.getCachedMovie(url);
        if (cached != null) {
          return cached;
        }
      } catch (_) {}
    }

    try {
      Map<String, dynamic>? postData;

      // Extract slug from URL if possible (e.g. /2025/12/avatar-fire-and-ash-2025/)
      final uri = Uri.tryParse(url);
      final segments = uri?.pathSegments.where((s) => s.isNotEmpty).toList() ?? [];
      final slug = segments.isNotEmpty ? segments.last : null;

      if (slug != null && slug.isNotEmpty) {
        final apiUrl = Uri.parse(
          'https://aftercredits.com/wp-json/wp/v2/posts?slug=${Uri.encodeComponent(slug)}&_fields=id,title,link,jetpack_featured_media_url,content',
        );
        final response = await http.get(apiUrl, headers: _headers);
        if (response.statusCode == 200) {
          final list = json.decode(response.body) as List<dynamic>;
          if (list.isNotEmpty) {
            postData = list.first as Map<String, dynamic>;
          }
        }
      }

      // If slug lookup returned nothing, try REST API search by slug keywords
      if (postData == null && slug != null && slug.isNotEmpty) {
        final searchWords = slug.replaceAll('-', ' ');
        final searchUrl = Uri.parse(
          'https://aftercredits.com/wp-json/wp/v2/posts?search=${Uri.encodeComponent(searchWords)}&_fields=id,title,link,jetpack_featured_media_url,content',
        );
        final response = await http.get(searchUrl, headers: _headers);
        if (response.statusCode == 200) {
          final list = json.decode(response.body) as List<dynamic>;
          for (final item in list) {
            final link = item['link'] as String? ?? '';
            if (link == url || link.contains(slug)) {
              postData = item as Map<String, dynamic>;
              break;
            }
          }
          if (postData == null && list.isNotEmpty) {
            postData = list.first as Map<String, dynamic>;
          }
        }
      }

      if (postData != null) {
        final movie = _parseMoviePostData(postData, url);
        try {
          await DatabaseHelper.instance.saveCachedMovie(movie);
        } catch (_) {}
        return movie;
      }

      // Fallback: direct HTTP get in case URL is outside WP or challenge is disabled
      final response = await http.get(Uri.parse(url), headers: _headers);
      if (response.statusCode == 200) {
        final movie = _parseMovieHtml(response.body, url);
        if (movie != null) {
          try {
            await DatabaseHelper.instance.saveCachedMovie(movie);
          } catch (_) {}
          return movie;
        }
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  static MovieModel _parseMoviePostData(Map<String, dynamic> postData, String url) {
    final titleRaw = postData['title']?['rendered'] as String? ?? '';
    String title = hp.parse(titleRaw).body?.text.trim() ?? titleRaw.trim();
    if (title.endsWith('*')) title = title.substring(0, title.length - 1).trim();

    final contentHtml = postData['content']?['rendered'] as String? ?? '';
    final doc = hp.parse(contentHtml);
    final content = doc.body ?? doc;
    final fullText = content.text ?? '';

    if (title.isEmpty) {
      final titleElem = doc.querySelector('h1.entry-title');
      title = titleElem?.text.trim() ?? '';
      if (title.endsWith('*')) title = title.substring(0, title.length - 1).trim();
    }

    return _extractMovieFields(
      title: title,
      url: url,
      content: content,
      fullText: fullText,
      featuredPosterUrl: postData['jetpack_featured_media_url'] as String?,
    );
  }

  static MovieModel? _parseMovieHtml(String htmlBody, String url) {
    final doc = hp.parse(htmlBody);
    final content = doc.querySelector('div.td-post-content') ?? doc.body;
    if (content == null) return null;

    final titleElem = doc.querySelector('h1.entry-title');
    String title = titleElem?.text.trim() ?? '';
    if (title.endsWith('*')) title = title.substring(0, title.length - 1).trim();

    final featuredImg = doc.querySelector('div.td-post-featured-image img');
    final featuredPosterUrl = featuredImg?.attributes['src'] ?? featuredImg?.attributes['data-src'];

    return _extractMovieFields(
      title: title,
      url: url,
      content: content,
      fullText: content.text,
      featuredPosterUrl: featuredPosterUrl,
    );
  }

  static MovieModel _extractMovieFields({
    required String title,
    required String url,
    required dynamic content,
    required String fullText,
    String? featuredPosterUrl,
  }) {
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
      if (href == null) continue;

      if (text.contains('official site') || text.contains('official website')) {
        officialSiteUrl = href;
      } else if (imdbUrl == null && href.contains('imdb.com/title/')) {
        imdbUrl = href;
      } else if (imdbUrl == null && text.contains('imdb') && !href.contains('imdb.com/name/')) {
        if (href.contains('imdb.com/title/') || href.contains('/title/tt')) {
          imdbUrl = href;
        }
      }
    }

    // Extract Poster URL
    var posterUrl = featuredPosterUrl;
    if (posterUrl == null || posterUrl.isEmpty) {
      final imgElem = content.querySelector('div.td-post-featured-image img, div.td-post-content img, img');
      posterUrl = imgElem?.attributes['src'] ?? imgElem?.attributes['data-src'];
    }
    if (posterUrl != null && posterUrl.startsWith('data:image')) {
      posterUrl = null;
    }

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
        final bodyElem = pList[i].querySelector('.spoiler-body');
        final sText = (bodyElem?.text ?? pList[i].text)
            .replaceAll('Click to see what\'s during the credits', '')
            .replaceAll('Click to see what\'s after the credits', '')
            .replaceAll('\uFFFD', '')
            .trim();
        final headText = (pList[i].querySelector('.spoiler-head')?.text ?? text).toLowerCase();
        if (headText.contains('during')) {
          duringText = sText;
        } else if (headText.contains('after')) {
          afterText = sText;
        } else if (duringText == null && (duringYesNo == true || text.contains('during'))) {
          duringText = sText;
        } else {
          afterText = sText;
        }
      }
    }

    // Stinger Voting / Rating
    String? stingerRatingText;
    final ratingMatch2 = RegExp(r'([+-]?\d+\s+rating,\s*\d+\s+votes)').firstMatch(fullText);
    if (ratingMatch2 != null) {
      stingerRatingText = ratingMatch2.group(1);
    }

    return MovieModel(
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
  }
}
