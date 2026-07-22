import 'package:html/parser.dart' as hp;
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart' as xml;
import '../models/letterboxd_item.dart';
import 'aftercredits_scraper.dart';
import '../database/database_helper.dart';

class LetterboxdService {
  static const Map<String, String> _headers = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
  };

  /// Fetches Letterboxd RSS items for [username]
  static Future<List<LetterboxdItem>> fetchUserRss(String username) async {
    final cleanUser = username.trim().toLowerCase();
    if (cleanUser.isEmpty) return [];

    final url = Uri.parse('https://letterboxd.com/$cleanUser/rss/');
    try {
      final response = await http.get(url, headers: _headers);
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

        // Extract poster URL from CDATA description HTML
        String? posterUrl;
        final description = _getElementText(node, 'description');
        if (description != null) {
          final descDoc = hp.parse(description);
          final img = descDoc.querySelector('img');
          posterUrl = img?.attributes['src'];
        }

        final item = LetterboxdItem(
          filmTitle: filmTitle,
          filmYear: filmYear,
          watchedDate: watchedDate,
          memberRating: memberRating,
          posterUrl: posterUrl,
          link: link,
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
    // e.g. "Obsession, 2025 - ★★★½" -> "Obsession"
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
