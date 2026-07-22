import '../../utils/title_formatter.dart';

class LetterboxdItem {
  final String filmTitle;
  final String? filmYear;
  final DateTime? watchedDate;
  final double? memberRating;
  final String? posterUrl;
  final String link;
  final String? guid;
  final String? viewId;
  final String? review;
  bool? duringCreditsYesNo;
  bool? afterCreditsYesNo;
  String? afterCreditsPageUrl;

  LetterboxdItem({
    required this.filmTitle,
    this.filmYear,
    this.watchedDate,
    this.memberRating,
    this.posterUrl,
    required this.link,
    this.guid,
    this.viewId,
    this.review,
    this.duringCreditsYesNo,
    this.afterCreditsYesNo,
    this.afterCreditsPageUrl,
  });

  String get displayTitle => TitleFormatter.formatDisplayTitle(filmTitle);

  bool get hasStingerContent =>
      (duringCreditsYesNo == true) || (afterCreditsYesNo == true);
}
