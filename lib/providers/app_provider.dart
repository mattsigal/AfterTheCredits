import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/database/database_helper.dart';
import '../data/models/letterboxd_item.dart';
import '../data/models/upcoming_movie_model.dart';
import '../data/services/aftercredits_scraper.dart';
import '../data/services/letterboxd_service.dart';

class AppProvider with ChangeNotifier {
  bool _isDarkMode = true;
  String _letterboxdUsername = '';

  List<UpcomingMovieModel> _upcomingMovies = [];
  List<LetterboxdItem> _recentlyWatched = [];

  bool _isSearching = false;
  String _searchQuery = '';
  List<AfterCreditsSearchResult> _searchResults = [];

  bool _isLoadingRss = false;

  bool get isDarkMode => _isDarkMode;
  String get letterboxdUsername => _letterboxdUsername;
  List<UpcomingMovieModel> get upcomingMovies => _upcomingMovies;
  List<LetterboxdItem> get recentlyWatched => _recentlyWatched;
  bool get isSearching => _isSearching;
  String get searchQuery => _searchQuery;
  List<AfterCreditsSearchResult> get searchResults => _searchResults;
  bool get isLoadingRss => _isLoadingRss;

  AppProvider() {
    _loadPreferences();
    loadUpcomingMovies();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('is_dark_mode') ?? true;
    _letterboxdUsername = prefs.getString('letterboxd_username') ?? '';
    notifyListeners();

    if (_letterboxdUsername.isNotEmpty) {
      refreshRecentlyWatched();
    }
  }

  Future<void> setDarkMode(bool value) async {
    _isDarkMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_dark_mode', value);
    notifyListeners();
  }

  Future<void> setLetterboxdUsername(String username) async {
    _letterboxdUsername = username.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('letterboxd_username', _letterboxdUsername);
    notifyListeners();

    if (_letterboxdUsername.isNotEmpty) {
      refreshRecentlyWatched();
    } else {
      _recentlyWatched = [];
      notifyListeners();
    }
  }

  Future<void> loadUpcomingMovies() async {
    _upcomingMovies = await DatabaseHelper.instance.getUpcomingMovies();

    // Background update stinger statuses for upcoming movies if missing
    for (final item in _upcomingMovies) {
      if (item.duringCreditsYesNo == null || item.afterCreditsYesNo == null) {
        AfterCreditsScraper.fetchMovieDetails(item.movieUrl).then((details) {
          if (details != null) {
            DatabaseHelper.instance.updateUpcomingStingerStatus(
              item.movieUrl,
              details.duringCreditsYesNo,
              details.afterCreditsYesNo,
            ).then((_) => loadUpcomingMovies());
          }
        });
      }
    }

    notifyListeners();
  }

  Future<void> addUpcomingMovie({
    required String movieUrl,
    required String movieTitle,
    String? posterUrl,
    required DateTime plannedDate,
    bool? duringCredits,
    bool? afterCredits,
    String? notes,
  }) async {
    final upcoming = UpcomingMovieModel(
      movieUrl: movieUrl,
      movieTitle: movieTitle,
      posterUrl: posterUrl,
      plannedDate: plannedDate,
      duringCreditsYesNo: duringCredits,
      afterCreditsYesNo: afterCredits,
      notes: notes,
    );

    await DatabaseHelper.instance.insertUpcomingMovie(upcoming);
    await loadUpcomingMovies();
  }

  Future<void> deleteUpcomingMovie(int id) async {
    await DatabaseHelper.instance.deleteUpcomingMovie(id);
    await loadUpcomingMovies();
  }

  Future<void> refreshRecentlyWatched() async {
    if (_letterboxdUsername.isEmpty) return;
    _isLoadingRss = true;
    notifyListeners();

    _recentlyWatched = await LetterboxdService.fetchUserRss(_letterboxdUsername);

    _isLoadingRss = false;
    notifyListeners();

    LetterboxdService.resolveAfterCreditsStatusForItems(
      _recentlyWatched,
      onUpdate: () => notifyListeners(),
    );
  }

  Future<void> search(String query) async {
    _searchQuery = query.trim();
    if (_searchQuery.isEmpty) {
      _isSearching = false;
      _searchResults = [];
      notifyListeners();
      return;
    }

    _isSearching = true;
    notifyListeners();

    _searchResults = await AfterCreditsScraper.searchMovies(_searchQuery);

    _isSearching = false;
    notifyListeners();
  }

  void clearSearch() {
    _searchQuery = '';
    _searchResults = [];
    _isSearching = false;
    notifyListeners();
  }

  Future<void> forceRefreshAll() async {
    await loadUpcomingMovies();
    await refreshRecentlyWatched();
  }
}
