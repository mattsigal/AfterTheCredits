class MovieModel {
  final String title;
  final String url;
  final String? posterUrl;
  final String? rating;
  final String? director;
  final String? writers;
  final String? starring;
  final String? releaseDate;
  final String? runningTime;
  final String? officialSiteUrl;
  final String? imdbUrl;
  final String? synopsis;
  final bool? duringCreditsYesNo;
  final String? duringCreditsText;
  final bool? afterCreditsYesNo;
  final String? afterCreditsText;
  final String? stingerRatingText;
  final DateTime? cachedAt;

  MovieModel({
    required this.title,
    required this.url,
    this.posterUrl,
    this.rating,
    this.director,
    this.writers,
    this.starring,
    this.releaseDate,
    this.runningTime,
    this.officialSiteUrl,
    this.imdbUrl,
    this.synopsis,
    this.duringCreditsYesNo,
    this.duringCreditsText,
    this.afterCreditsYesNo,
    this.afterCreditsText,
    this.stingerRatingText,
    this.cachedAt,
  });

  bool get hasStingerContent =>
      (duringCreditsYesNo == true) || (afterCreditsYesNo == true);

  bool get hasMidCredits => duringCreditsYesNo == true;
  bool get hasAfterCredits => afterCreditsYesNo == true;

  Map<String, dynamic> toMap() {
    return {
      'url': url,
      'title': title,
      'posterUrl': posterUrl,
      'rating': rating,
      'director': director,
      'writers': writers,
      'starring': starring,
      'releaseDate': releaseDate,
      'runningTime': runningTime,
      'officialSiteUrl': officialSiteUrl,
      'imdbUrl': imdbUrl,
      'synopsis': synopsis,
      'duringCreditsYesNo': duringCreditsYesNo == null ? null : (duringCreditsYesNo! ? 1 : 0),
      'duringCreditsText': duringCreditsText,
      'afterCreditsYesNo': afterCreditsYesNo == null ? null : (afterCreditsYesNo! ? 1 : 0),
      'afterCreditsText': afterCreditsText,
      'stingerRatingText': stingerRatingText,
      'cachedAt': (cachedAt ?? DateTime.now()).millisecondsSinceEpoch,
    };
  }

  factory MovieModel.fromMap(Map<String, dynamic> map) {
    return MovieModel(
      url: map['url'] as String,
      title: map['title'] as String,
      posterUrl: map['posterUrl'] as String?,
      rating: map['rating'] as String?,
      director: map['director'] as String?,
      writers: map['writers'] as String?,
      starring: map['starring'] as String?,
      releaseDate: map['releaseDate'] as String?,
      runningTime: map['runningTime'] as String?,
      officialSiteUrl: map['officialSiteUrl'] as String?,
      imdbUrl: map['imdbUrl'] as String?,
      synopsis: map['synopsis'] as String?,
      duringCreditsYesNo: map['duringCreditsYesNo'] == null
          ? null
          : (map['duringCreditsYesNo'] as int == 1),
      duringCreditsText: map['duringCreditsText'] as String?,
      afterCreditsYesNo: map['afterCreditsYesNo'] == null
          ? null
          : (map['afterCreditsYesNo'] as int == 1),
      afterCreditsText: map['afterCreditsText'] as String?,
      stingerRatingText: map['stingerRatingText'] as String?,
      cachedAt: map['cachedAt'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(map['cachedAt'] as int),
    );
  }
}
