import '../../utils/title_formatter.dart';

class UpcomingMovieModel {
  final int? id;
  final String movieUrl;
  final String movieTitle;
  final String? posterUrl;
  final DateTime plannedDate;
  final bool? duringCreditsYesNo;
  final bool? afterCreditsYesNo;
  final String? notes;

  UpcomingMovieModel({
    this.id,
    required this.movieUrl,
    required this.movieTitle,
    this.posterUrl,
    required this.plannedDate,
    this.duringCreditsYesNo,
    this.afterCreditsYesNo,
    this.notes,
  });

  String get displayTitle => TitleFormatter.formatDisplayTitle(movieTitle);

  bool get hasStingerContent =>
      (duringCreditsYesNo == true) || (afterCreditsYesNo == true);

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'movieUrl': movieUrl,
      'movieTitle': movieTitle,
      'posterUrl': posterUrl,
      'plannedDate': plannedDate.millisecondsSinceEpoch,
      'duringCreditsYesNo': duringCreditsYesNo == null ? null : (duringCreditsYesNo! ? 1 : 0),
      'afterCreditsYesNo': afterCreditsYesNo == null ? null : (afterCreditsYesNo! ? 1 : 0),
      'notes': notes,
    };
  }

  factory UpcomingMovieModel.fromMap(Map<String, dynamic> map) {
    return UpcomingMovieModel(
      id: map['id'] as int?,
      movieUrl: map['movieUrl'] as String,
      movieTitle: map['movieTitle'] as String,
      posterUrl: map['posterUrl'] as String?,
      plannedDate: DateTime.fromMillisecondsSinceEpoch(map['plannedDate'] as int),
      duringCreditsYesNo: map['duringCreditsYesNo'] == null
          ? null
          : (map['duringCreditsYesNo'] as int == 1),
      afterCreditsYesNo: map['afterCreditsYesNo'] == null
          ? null
          : (map['afterCreditsYesNo'] as int == 1),
      notes: map['notes'] as String?,
    );
  }
}
