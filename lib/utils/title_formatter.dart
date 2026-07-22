class TitleFormatter {
  /// Transforms titles rearranged by scrapers/databases (e.g. "Odyssey, The")
  /// into standard natural title display (e.g. "The Odyssey").
  static String formatDisplayTitle(String rawTitle) {
    var t = rawTitle.trim();
    if (t.isEmpty) return t;

    // Strip trailing asterisk if present from aftercredits scraping
    if (t.endsWith('*')) {
      t = t.substring(0, t.length - 1).trim();
    }

    // Check for trailing article format: "Title, The", "Title, A (2020)", "Title, An"
    final regex = RegExp(
      r'^(.*),\s*(The|A|An)(\s*\(\d{4}\))?$',
      caseSensitive: false,
    );

    final match = regex.firstMatch(t);
    if (match != null) {
      final mainTitle = match.group(1)!.trim();
      final articleRaw = match.group(2)!;
      final yearStr = match.group(3) ?? '';

      final article = articleRaw.substring(0, 1).toUpperCase() +
          articleRaw.substring(1).toLowerCase();

      return '$article $mainTitle$yearStr'.trim();
    }

    return t;
  }
}
