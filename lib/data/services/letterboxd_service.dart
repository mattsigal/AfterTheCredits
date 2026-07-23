import 'dart:convert';
import 'package:html/parser.dart' as hp;
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart' as xml;
import '../models/letterboxd_item.dart';
import 'aftercredits_scraper.dart';
import '../database/database_helper.dart';
import '../../utils/title_formatter.dart';

class LetterboxdAuthResult {
  final bool success;
  final String? sessionCookie;
  final String? csrfToken;
  final String? errorMessage;

  LetterboxdAuthResult({
    required this.success,
    this.sessionCookie,
    this.csrfToken,
    this.errorMessage,
  });
}

class LetterboxdLogResult {
  final bool success;
  final String? errorMessage;

  LetterboxdLogResult({
    required this.success,
    this.errorMessage,
  });
}

class _CleanedFilmInfo {
  final String title;
  final String? year;

  _CleanedFilmInfo(this.title, this.year);
}

class _FilmDetails {
  final String filmId;
  final String slug;
  final String? csrf;

  _FilmDetails({
    required this.filmId,
    required this.slug,
    this.csrf,
  });
}

class LetterboxdService {
  static const String _defaultUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36';

  /// Verifies Letterboxd session via raw cookies and optional custom user agent
  static Future<LetterboxdAuthResult> verifyCredentials({
    required String username,
    required String rawCookies,
    String? userAgent,
  }) async {
    final cleanUser = username.trim();
    final cleanCookies = rawCookies.replaceAll('\r', '').replaceAll('\n', ' ').trim();
    final cleanUA = (userAgent != null && userAgent.trim().isNotEmpty)
        ? userAgent.replaceAll('\r', '').replaceAll('\n', ' ').trim()
        : _defaultUserAgent;

    if (cleanUser.isEmpty) {
      return LetterboxdAuthResult(
        success: false,
        errorMessage: 'Letterboxd username cannot be empty.',
      );
    }

    if (cleanCookies.isEmpty) {
      return LetterboxdAuthResult(
        success: false,
        errorMessage: 'Raw cookies cannot be empty.',
      );
    }

    String? csrfToken;
    final csrfMatch = RegExp(r'(?:com\.xk72\.webparts\.csrf|__csrf|csrf)=([a-f0-9]+)', caseSensitive: false)
        .firstMatch(cleanCookies);
    if (csrfMatch != null) {
      csrfToken = csrfMatch.group(1);
    }

    final hasUserOrSessionKey = cleanCookies.contains('letterboxd.user') ||
        cleanCookies.contains('letterboxd.signed.in.as') ||
        cleanCookies.contains('letterboxd.session') ||
        cleanCookies.contains('com.xk72.webparts.csrf');

    try {
      final uri = Uri.parse('https://letterboxd.com/');
      final response = await http.get(uri, headers: {
        'User-Agent': cleanUA,
        'Cookie': cleanCookies,
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.9',
        'sec-ch-ua': '"Chromium";v="146", "Not?A_Brand";v="24"',
        'sec-ch-ua-mobile': '?0',
        'sec-ch-ua-platform': '"Windows"',
        'sec-fetch-dest': 'document',
        'sec-fetch-mode': 'navigate',
        'sec-fetch-site': 'none',
        'sec-fetch-user': '?1',
        'upgrade-insecure-requests': '1',
      });

      if (response.statusCode == 200) {
        final doc = hp.parse(response.body);
        final csrfElem = doc.querySelector('input[name="__csrf"]') ??
            doc.querySelector('meta[name="csrf-token"]');
        final pageCsrf = csrfElem?.attributes['value'] ?? csrfElem?.attributes['content'];

        return LetterboxdAuthResult(
          success: true,
          sessionCookie: cleanCookies,
          csrfToken: pageCsrf ?? csrfToken,
        );
      }
    } catch (_) {}

    // Fallback: If HTTP GET returns 403 due to Cloudflare IP binding/challenge, but cookies contain Letterboxd session keys
    if (hasUserOrSessionKey) {
      return LetterboxdAuthResult(
        success: true,
        sessionCookie: cleanCookies,
        csrfToken: csrfToken,
      );
    }

    return LetterboxdAuthResult(
      success: false,
      errorMessage: 'Raw cookies do not contain a valid Letterboxd session (missing letterboxd.user or csrf token).',
    );
  }

  static String? _extractFilmIdFromPosterUrl(String? posterUrl) {
    if (posterUrl == null || posterUrl.isEmpty) return null;

    final match1 = RegExp(r'/(\d{4,9})-[a-z0-9\-]+\.', caseSensitive: false)
        .firstMatch(posterUrl);
    if (match1 != null) return match1.group(1);

    final match2 = RegExp(r'film-poster/(?:\d+/)+(\d+)', caseSensitive: false)
        .firstMatch(posterUrl);
    if (match2 != null) return match2.group(1);

    final match3 = RegExp(r'/(?:film-poster/)?(\d{4,9})[/\._\-]', caseSensitive: false)
        .firstMatch(posterUrl);
    if (match3 != null) return match3.group(1);

    return null;
  }

  /// Logs a film rating and review to Letterboxd using raw cookies
  static Future<LetterboxdLogResult> logFilm({
    required String username,
    required String rawCookies,
    String? userAgent,
    required String filmTitle,
    String? filmYear,
    String? posterUrl,
    String? viewId,
    String? link,
    DateTime? watchedDate,
    bool isRewatch = false,
    String review = '',
    List<String> tags = const [],
    double rating = 0.0,
    bool isLiked = false,
  }) async {
    final cleanCookies = rawCookies.replaceAll('\r', '').replaceAll('\n', ' ').trim();
    var cleanUA = (userAgent != null && userAgent.trim().isNotEmpty)
        ? userAgent.replaceAll('\r', '').replaceAll('\n', ' ').trim()
        : _defaultUserAgent;
    // Strip WebView markers that trigger Cloudflare WAF 403
    cleanUA = cleanUA.replaceAll('; wv', '').replaceAll(RegExp(r'\s*Version/\d+\.\d+\s*'), ' ');

    if (cleanCookies.isEmpty) {
      return LetterboxdLogResult(
        success: false,
        errorMessage: 'Raw cookies are required for logging. Please update Settings.',
      );
    }

    try {
      final cleanedInfo = _cleanTitleAndYear(filmTitle, filmYear);
      String? filmId = _extractFilmIdFromPosterUrl(posterUrl);
      String filmSlug = _extractSlugFromUrl(link) ?? '';
      String? csrfToken;

      if (filmId == null || filmId.isEmpty) {
        final details = await _resolveFilmDetails(
          cleanTitle: cleanedInfo.title,
          year: cleanedInfo.year,
          link: link,
          rawCookies: cleanCookies,
          userAgent: cleanUA,
        );

        if (details != null) {
          filmId = details.filmId;
          csrfToken = details.csrf;
          if (filmSlug.isEmpty) filmSlug = details.slug;
        }
      }

      if ((filmId == null || filmId.isEmpty) && (viewId == null || viewId.isEmpty)) {
        return LetterboxdLogResult(
          success: false,
          errorMessage: 'Could not find film "${cleanedInfo.title}" on Letterboxd.',
        );
      }

      if (csrfToken == null || csrfToken.isEmpty) {
        final csrfMatch = RegExp(r'(?:com\.xk72\.webparts\.csrf|__csrf|csrf)=([a-f0-9]+)', caseSensitive: false)
            .firstMatch(cleanCookies);
        if (csrfMatch != null) {
          csrfToken = csrfMatch.group(1)!;
        }
      }

      final desktopCookies = cleanCookies
          .replaceAll('useMobileSite=yes', 'useMobileSite=no')
          .replaceAll('useMobileSite=true', 'useMobileSite=no');

      final ratingOutOfTen = (rating * 2).round();

      final payload = <String, String>{
        if (csrfToken != null && csrfToken.isNotEmpty) '__csrf': csrfToken,
        if (viewId != null && viewId.isNotEmpty) ...{
          'viewingId': viewId,
          'viewId': viewId,
        },
        if (filmId != null && filmId.isNotEmpty) ...{
          'viewingableUid': filmId.startsWith('film:') ? filmId : 'film:$filmId',
          'filmId': filmId,
        },
        'specifiedDate': watchedDate != null ? 'true' : 'false',
        if (watchedDate != null)
          'viewDateStr':
              '${watchedDate.year}-${watchedDate.month.toString().padLeft(2, '0')}-${watchedDate.day.toString().padLeft(2, '0')}',
        'rewatch': isRewatch ? 'true' : 'false',
        'review': review,
        'tags': tags.join(', '),
        'rating': ratingOutOfTen > 0 ? ratingOutOfTen.toString() : '',
        'liked': isLiked ? 'true' : 'false',
      };

      final logs = <String>[];

      // Attempt 1: Desktop endpoint https://letterboxd.com/s/save-diary-entry with desktopCookies
      try {
        final saveRes = await http.post(
          Uri.parse('https://letterboxd.com/s/save-diary-entry'),
          headers: {
            'User-Agent': cleanUA,
            'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
            'X-Requested-With': 'XMLHttpRequest',
            if (csrfToken != null && csrfToken.isNotEmpty) 'x-csrf-token': csrfToken,
            'Cookie': desktopCookies,
            'Referer': filmSlug.isNotEmpty ? 'https://letterboxd.com/film/$filmSlug/' : 'https://letterboxd.com/',
            'Origin': 'https://letterboxd.com',
            'sec-fetch-dest': 'empty',
            'sec-fetch-mode': 'cors',
            'sec-fetch-site': 'same-origin',
          },
          body: payload,
        );

        if (saveRes.statusCode == 200) {
          try {
            final data = json.decode(saveRes.body) as Map<String, dynamic>;
            if (data['result'] == true || data['result'] == 'success' || data['url'] != null) {
              return LetterboxdLogResult(success: true);
            } else if (data['messages'] != null) {
              final msgs = (data['messages'] as List).join(', ');
              return LetterboxdLogResult(success: false, errorMessage: msgs);
            }
          } catch (_) {
            return LetterboxdLogResult(success: true);
          }
        }
        final snippet = saveRes.body.length > 60 ? saveRes.body.substring(0, 60) : saveRes.body;
        logs.add('EP1: ${saveRes.statusCode} [$snippet]');
      } catch (e) {
        logs.add('EP1 Err: $e');
      }

      // Attempt 2: Mobile endpoint https://m.letterboxd.com/s/save-diary-entry
      try {
        final mobileRes = await http.post(
          Uri.parse('https://m.letterboxd.com/s/save-diary-entry'),
          headers: {
            'User-Agent': cleanUA,
            'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
            'X-Requested-With': 'XMLHttpRequest',
            if (csrfToken != null && csrfToken.isNotEmpty) 'x-csrf-token': csrfToken,
            'Cookie': cleanCookies,
            'Referer': filmSlug.isNotEmpty ? 'https://m.letterboxd.com/film/$filmSlug/' : 'https://m.letterboxd.com/',
            'Origin': 'https://m.letterboxd.com',
          },
          body: payload,
        );

        if (mobileRes.statusCode == 200) {
          try {
            final data = json.decode(mobileRes.body) as Map<String, dynamic>;
            if (data['result'] == true || data['result'] == 'success' || data['url'] != null) {
              return LetterboxdLogResult(success: true);
            }
          } catch (_) {
            return LetterboxdLogResult(success: true);
          }
        }
        final snippet = mobileRes.body.length > 60 ? mobileRes.body.substring(0, 60) : mobileRes.body;
        logs.add('EP2: ${mobileRes.statusCode} [$snippet]');
      } catch (e) {
        logs.add('EP2 Err: $e');
      }

      // Attempt 3: Jellyfin JSON API endpoint https://letterboxd.com/api/v0/production-log-entries
      if (filmId != null && filmId.isNotEmpty) {
        try {
          final apiUri = Uri.parse('https://letterboxd.com/api/v0/production-log-entries');
          final dateStr = watchedDate != null
              ? '${watchedDate.year}-${watchedDate.month.toString().padLeft(2, '0')}-${watchedDate.day.toString().padLeft(2, '0')}'
              : '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';

          final jsonPayload = json.encode({
            'productionId': filmId.startsWith('film:') ? filmId : 'film:$filmId',
            if (viewId != null && viewId.isNotEmpty) 'viewId': viewId,
            'diaryDetails': {
              'diaryDate': dateStr,
              'rewatch': isRewatch,
            },
            if (review.isNotEmpty) 'review': review,
            'tags': tags,
            'like': isLiked,
            if (ratingOutOfTen > 0) 'rating': ratingOutOfTen,
          });

          final apiRes = await http.post(
            apiUri,
            headers: {
              'User-Agent': cleanUA,
              'Content-Type': 'application/json; charset=UTF-8',
              'X-Requested-With': 'XMLHttpRequest',
              if (csrfToken != null && csrfToken.isNotEmpty) 'x-csrf-token': csrfToken,
              'Cookie': cleanCookies,
              'Referer': filmSlug.isNotEmpty ? 'https://letterboxd.com/film/$filmSlug/review/' : 'https://letterboxd.com/',
              'Origin': 'https://letterboxd.com',
            },
            body: jsonPayload,
          );

          if (apiRes.statusCode == 200 || apiRes.statusCode == 201) {
            return LetterboxdLogResult(success: true);
          }
          final snippet = apiRes.body.length > 60 ? apiRes.body.substring(0, 60) : apiRes.body;
          logs.add('EP3: ${apiRes.statusCode} [$snippet]');
        } catch (e) {
          logs.add('EP3 Err: $e');
        }
      }

      return LetterboxdLogResult(
        success: false,
        errorMessage: 'Log failed — ${logs.join(" | ")}',
      );
    } catch (e) {
      return LetterboxdLogResult(
        success: false,
        errorMessage: 'Error: $e',
      );
    }
  }

  static _CleanedFilmInfo _cleanTitleAndYear(String inputTitle, String? yearParam) {
    var title = inputTitle.trim();
    String? year = yearParam?.trim();

    final regExp = RegExp(r'\s*[\(\[]?(\d{4})[\)\]]?\s*$');
    final match = regExp.firstMatch(title);
    if (match != null) {
      year ??= match.group(1);
      title = title.substring(0, match.start).trim();
    }

    title = TitleFormatter.formatDisplayTitle(title);
    return _CleanedFilmInfo(title, year);
  }

  static String? _extractSlugFromUrl(String? urlStr) {
    if (urlStr == null || urlStr.isEmpty) return null;
    try {
      final uri = Uri.parse(urlStr);
      final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      final filmIdx = segments.indexOf('film');
      if (filmIdx != -1 && filmIdx + 1 < segments.length) {
        return segments[filmIdx + 1];
      }
    } catch (_) {}
    return null;
  }

  static Future<_FilmDetails?> _resolveFilmDetails({
    required String cleanTitle,
    String? year,
    String? link,
    required String rawCookies,
    required String userAgent,
  }) async {
    final candidates = <String>[];

    final linkSlug = _extractSlugFromUrl(link);
    if (linkSlug != null && linkSlug.isNotEmpty) {
      candidates.add(linkSlug);
    }

    final slugFromTitle = cleanTitle
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');

    if (year != null && year.isNotEmpty) {
      final titleYearSlug = '$slugFromTitle-$year';
      if (!candidates.contains(titleYearSlug)) {
        candidates.add(titleYearSlug);
      }
    }
    if (!candidates.contains(slugFromTitle)) {
      candidates.add(slugFromTitle);
    }

    for (final slug in candidates) {
      // Method A: JSON endpoint
      try {
        final jsonUri = Uri.parse('https://letterboxd.com/film/$slug/json/');
        final res = await http.get(jsonUri, headers: {
          'User-Agent': userAgent,
          'Cookie': rawCookies,
          'X-Requested-With': 'XMLHttpRequest',
          'Accept': 'application/json, text/javascript, */*; q=0.01',
          'Referer': 'https://letterboxd.com/film/$slug/',
          'sec-ch-ua': '"Chromium";v="146", "Not?A_Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"Windows"',
          'sec-fetch-dest': 'empty',
          'sec-fetch-mode': 'cors',
          'sec-fetch-site': 'same-origin',
        });

        if (res.statusCode == 200) {
          final data = json.decode(res.body) as Map<String, dynamic>;
          final idVal = data['id']?.toString() ?? data['filmId']?.toString();
          final csrfVal = data['csrf']?.toString();
          if (idVal != null && idVal.isNotEmpty) {
            return _FilmDetails(filmId: idVal, slug: slug, csrf: csrfVal);
          }
        }
      } catch (_) {}

      // Method B: HTML page endpoint
      try {
        final filmUri = Uri.parse('https://letterboxd.com/film/$slug/');
        final res = await http.get(filmUri, headers: {
          'User-Agent': userAgent,
          'Cookie': rawCookies,
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
          'Accept-Language': 'en-US,en;q=0.9',
          'sec-ch-ua': '"Chromium";v="146", "Not?A_Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"Windows"',
          'sec-fetch-dest': 'document',
          'sec-fetch-mode': 'navigate',
          'sec-fetch-site': 'same-origin',
          'sec-fetch-user': '?1',
          'upgrade-insecure-requests': '1',
        });

        if (res.statusCode == 200) {
          final doc = hp.parse(res.body);
          final elem = doc.querySelector(
            'div.film-poster[data-film-id], span.film-poster[data-film-id], div[data-film-id], body[data-film-id], body[data-type="film"]',
          );
          final directId = elem?.attributes['data-film-id'];
          final csrfElem = doc.querySelector('input[name="__csrf"]') ??
              doc.querySelector('meta[name="csrf-token"]');
          final csrfVal = csrfElem?.attributes['value'] ?? csrfElem?.attributes['content'];

          if (directId != null && directId.isNotEmpty) {
            return _FilmDetails(filmId: directId, slug: slug, csrf: csrfVal);
          }
        }
      } catch (_) {}
    }

    // Method C: Search fallback
    try {
      final searchUri = Uri.parse('https://letterboxd.com/search/film/${Uri.encodeComponent(cleanTitle)}/');
      final searchRes = await http.get(searchUri, headers: {
        'User-Agent': userAgent,
        'Cookie': rawCookies,
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.9',
        'sec-ch-ua': '"Chromium";v="146", "Not?A_Brand";v="24"',
        'sec-ch-ua-mobile': '?0',
        'sec-ch-ua-platform': '"Windows"',
        'sec-fetch-dest': 'document',
        'sec-fetch-mode': 'navigate',
        'sec-fetch-site': 'same-origin',
      });

      if (searchRes.statusCode == 200) {
        final searchDoc = hp.parse(searchRes.body);

        final posterElem = searchDoc.querySelector(
            'div.film-poster[data-film-id], span.film-poster[data-film-id], div[data-film-id], li.film-detail[data-film-id]');
        final directId = posterElem?.attributes['data-film-id'];
        final directSlug = posterElem?.attributes['data-film-slug'];

        if (directId != null && directId.isNotEmpty) {
          return _FilmDetails(filmId: directId, slug: directSlug ?? slugFromTitle);
        }

        final firstFilmLink = searchDoc.querySelector('ul.results li a[href*="/film/"], a[href*="/film/"]');
        final href = firstFilmLink?.attributes['href'];
        if (href != null && href.contains('/film/')) {
          final foundSlug = _extractSlugFromUrl(href);
          if (foundSlug != null && foundSlug.isNotEmpty) {
            final jsonUri = Uri.parse('https://letterboxd.com/film/$foundSlug/json/');
            final jsonRes = await http.get(jsonUri, headers: {
              'User-Agent': userAgent,
              'Cookie': rawCookies,
              'X-Requested-With': 'XMLHttpRequest',
            });
            if (jsonRes.statusCode == 200) {
              final data = json.decode(jsonRes.body) as Map<String, dynamic>;
              final idVal = data['id']?.toString() ?? data['filmId']?.toString();
              final csrfVal = data['csrf']?.toString();
              if (idVal != null && idVal.isNotEmpty) {
                return _FilmDetails(filmId: idVal, slug: foundSlug, csrf: csrfVal);
              }
            }
          }
        }
      }
    } catch (_) {}

    return null;
  }

  /// Resolves the exact Letterboxd film page URL for a title and optional year
  static Future<String> resolveFilmUrl(String title, {String? year}) async {
    final cleanTitle = title.replaceAll(RegExp(r'\s*\(\d{4}\)\s*'), ' ').trim();
    final slugFromTitle = cleanTitle
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');

    // Extract year from title if not explicitly passed
    final yearMatch = RegExp(r'\((\d{4})\)').firstMatch(title);
    final effectiveYear = year ?? yearMatch?.group(1);

    if (effectiveYear != null && effectiveYear.isNotEmpty) {
      final titleYearSlug = '$slugFromTitle-$effectiveYear';
      try {
        final url = 'https://letterboxd.com/film/$titleYearSlug/';
        final res = await http.get(
          Uri.parse(url),
          headers: {'User-Agent': _defaultUserAgent},
        );
        if (res.statusCode == 200) {
          return url;
        }
      } catch (_) {}
    }

    try {
      final url = 'https://letterboxd.com/film/$slugFromTitle/';
      final res = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': _defaultUserAgent},
      );
      if (res.statusCode == 200) {
        return url;
      }
    } catch (_) {}

    // Search fallback
    try {
      final searchUri = Uri.parse('https://letterboxd.com/search/film/${Uri.encodeComponent(cleanTitle)}/');
      final searchRes = await http.get(searchUri, headers: {'User-Agent': _defaultUserAgent});
      if (searchRes.statusCode == 200) {
        final doc = hp.parse(searchRes.body);
        final firstFilmLink = doc.querySelector('ul.results li a[href*="/film/"], a[href*="/film/"]');
        final href = firstFilmLink?.attributes['href'];
        if (href != null && href.contains('/film/')) {
          final foundSlug = href.split('/film/').last.replaceAll('/', '').trim();
          if (foundSlug.isNotEmpty) {
            return 'https://letterboxd.com/film/$foundSlug/';
          }
        }
      }
    } catch (_) {}

    return 'https://letterboxd.com/film/$slugFromTitle/';
  }

  /// Fetches Letterboxd RSS items for [username]
  static Future<List<LetterboxdItem>> fetchUserRss(String username) async {
    final cleanUser = username.trim().toLowerCase();
    if (cleanUser.isEmpty) return [];

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final url = Uri.parse('https://letterboxd.com/$cleanUser/rss/?_cb=$timestamp');
    try {
      final response = await http.get(
        url,
        headers: {
          'User-Agent': _defaultUserAgent,
          'Cache-Control': 'no-cache, no-store, must-revalidate',
          'Pragma': 'no-cache',
        },
      );
      if (response.statusCode != 200) return [];

      final document = xml.XmlDocument.parse(response.body);
      final items = <LetterboxdItem>[];

      for (final node in document.findAllElements('item')) {
        final title = _getElementText(node, 'title');
        final filmTitle = _getElementText(node, 'filmTitle') ?? _cleanTitleFromRss(title);
        final filmYear = _getElementText(node, 'filmYear');
        final watchedDateStr = _getElementText(node, 'watchedDate');
        final memberRatingStr = _getElementText(node, 'memberRating');
        final link = _getElementText(node, 'link') ?? '';

        DateTime? watchedDate;
        if (watchedDateStr != null) {
          watchedDate = DateTime.tryParse(watchedDateStr);
        }

        double? memberRating;
        if (memberRatingStr != null) {
          memberRating = double.tryParse(memberRatingStr);
        }

        String? posterUrl;
        String? review;
        final description = _getElementText(node, 'description');
        if (description != null) {
          final descDoc = hp.parse(description);
          final img = descDoc.querySelector('img');
          posterUrl = img?.attributes['src'];

          final paragraphs = descDoc.querySelectorAll('p');
          final reviewTexts = paragraphs
              .map((p) => p.text.trim())
              .where((t) => t.isNotEmpty && !t.startsWith('Watched on'))
              .toList();
          if (reviewTexts.isNotEmpty) {
            review = reviewTexts.join('\n\n');
          }
        }

        final guidStr = _getElementText(node, 'guid');
        String? viewId;
        if (guidStr != null) {
          final match = RegExp(r'\d+').stringMatch(guidStr);
          if (match != null && match.isNotEmpty) {
            viewId = match;
          }
        }

        final item = LetterboxdItem(
          filmTitle: filmTitle,
          filmYear: filmYear,
          watchedDate: watchedDate,
          memberRating: memberRating,
          posterUrl: posterUrl,
          link: link,
          guid: guidStr,
          viewId: viewId,
          review: review,
        );

        items.add(item);
      }

      return items;
    } catch (_) {
      return [];
    }
  }

  static String? _getElementText(xml.XmlElement parent, String name) {
    for (final child in parent.children) {
      if (child is xml.XmlElement && child.name.local == name) {
        return child.innerText;
      }
    }
    return null;
  }

  static String _cleanTitleFromRss(String? title) {
    if (title == null) return 'Untitled';
    final dashIdx = title.indexOf(' - ');
    var clean = dashIdx != -1 ? title.substring(0, dashIdx) : title;
    final commaIdx = clean.lastIndexOf(',');
    if (commaIdx != -1) {
      clean = clean.substring(0, commaIdx);
    }
    return clean.trim();
  }

  static Future<void> resolveAfterCreditsStatusForItems(
      List<LetterboxdItem> items, {Function()? onUpdate}) async {
    for (final item in items) {
      try {
        final cached = await DatabaseHelper.instance.searchCachedMovieByTitle(item.filmTitle);
        if (cached != null) {
          item.duringCreditsYesNo = cached.duringCreditsYesNo;
          item.afterCreditsYesNo = cached.afterCreditsYesNo;
          item.afterCreditsPageUrl = cached.url;
          if (onUpdate != null) onUpdate();
          continue;
        }

        final search = await AfterCreditsScraper.searchMovies(item.filmTitle);
        final match = AfterCreditsScraper.findBestMatch(item.filmTitle, search);
        if (match != null) {
          item.afterCreditsPageUrl = match.url;
          final details = await AfterCreditsScraper.fetchMovieDetails(match.url);
          if (details != null) {
            item.duringCreditsYesNo = details.duringCreditsYesNo;
            item.afterCreditsYesNo = details.afterCreditsYesNo;
          }
          if (onUpdate != null) onUpdate();
        }
      } catch (_) {}
    }
  }
}
