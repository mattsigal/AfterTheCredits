class LetterboxdItem {
  final String filmTitle;
  final String? filmYear;
  final DateTime? watchedDate;
  final double? memberRating;
  final String? posterUrl;
  final String link;
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
    this.duringCreditsYesNo,
    this.afterCreditsYesNo,
    this.afterCreditsPageUrl,
  });

  bool get hasStingerContent =>
      (duringCreditsYesNo == true) || (afterCreditsYesNo == true);
}
