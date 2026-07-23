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
  String _letterboxdRawCookies = '';
  String _letterboxdUserAgent = '';
  bool _isLetterboxdVerified = false;
  String _letterboxdAuthError = '';

  List<UpcomingMovieModel> _upcomingMovies = [];
  List<LetterboxdItem> _recentlyWatched = [];

  bool _isSearching = false;
  String _searchQuery = '';
  List<AfterCreditsSearchResult> _searchResults = [];

  bool _isLoadingRss = false;

  bool get isDarkMode => _isDarkMode;
  String get letterboxdUsername => _letterboxdUsername;
  String get letterboxdRawCookies => _letterboxdRawCookies;
  String get letterboxdUserAgent => _letterboxdUserAgent;
  bool get isLetterboxdAuthenticated =>
      _isLetterboxdVerified && _letterboxdUsername.isNotEmpty && _letterboxdRawCookies.isNotEmpty;
  String get letterboxdAuthError => _letterboxdAuthError;
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
    _letterboxdRawCookies = prefs.getString('letterboxd_raw_cookies') ?? '';
    _letterboxdUserAgent = prefs.getString('letterboxd_user_agent') ?? '';
    _isLetterboxdVerified = prefs.getBool('is_letterboxd_verified') ?? false;
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

  Future<bool> verifyAndSaveLetterboxdCredentials({
    required String username,
    required String rawCookies,
    String? userAgent,
  }) async {
    final cleanUser = username.trim();
    final cleanCookies = rawCookies.trim();
    final cleanUA = userAgent?.trim() ?? '';

    if (cleanUser.isEmpty) {
      _letterboxdUsername = '';
      _letterboxdRawCookies = '';
      _letterboxdUserAgent = '';
      _isLetterboxdVerified = false;
      _letterboxdAuthError = '';
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('letterboxd_username', '');
      await prefs.setString('letterboxd_raw_cookies', '');
      await prefs.setString('letterboxd_user_agent', '');
      await prefs.setBool('is_letterboxd_verified', false);
      _recentlyWatched = [];
      notifyListeners();
      return true;
    }

    if (cleanCookies.isEmpty) {
      // Username only (RSS feed mode)
      _letterboxdUsername = cleanUser;
      _letterboxdRawCookies = '';
      _letterboxdUserAgent = cleanUA;
      _isLetterboxdVerified = false;
      _letterboxdAuthError = '';
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('letterboxd_username', cleanUser);
      await prefs.setString('letterboxd_raw_cookies', '');
      await prefs.setString('letterboxd_user_agent', cleanUA);
      await prefs.setBool('is_letterboxd_verified', false);
      refreshRecentlyWatched();
      notifyListeners();
      return true;
    }

    final auth = await LetterboxdService.verifyCredentials(
      username: cleanUser,
      rawCookies: cleanCookies,
      userAgent: cleanUA,
    );
    final prefs = await SharedPreferences.getInstance();

    if (auth.success) {
      _letterboxdUsername = cleanUser;
      _letterboxdRawCookies = cleanCookies;
      _letterboxdUserAgent = cleanUA;
      _isLetterboxdVerified = true;
      _letterboxdAuthError = '';
      await prefs.setString('letterboxd_username', cleanUser);
      await prefs.setString('letterboxd_raw_cookies', cleanCookies);
      await prefs.setString('letterboxd_user_agent', cleanUA);
      await prefs.setBool('is_letterboxd_verified', true);
      refreshRecentlyWatched();
      notifyListeners();
      return true;
    } else {
      _letterboxdUsername = cleanUser;
      _letterboxdRawCookies = '';
      _letterboxdUserAgent = cleanUA;
      _isLetterboxdVerified = false;
      _letterboxdAuthError = auth.errorMessage ?? 'Invalid session cookies.';
      await prefs.setString('letterboxd_username', cleanUser);
      await prefs.setString('letterboxd_raw_cookies', '');
      await prefs.setString('letterboxd_user_agent', cleanUA);
      await prefs.setBool('is_letterboxd_verified', false);
      notifyListeners();
      return false;
    }
  }

  Future<void> clearLetterboxdCredentials() async {
    _letterboxdUsername = '';
    _letterboxdRawCookies = '';
    _letterboxdUserAgent = '';
    _isLetterboxdVerified = false;
    _letterboxdAuthError = '';
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('letterboxd_username');
    await prefs.remove('letterboxd_raw_cookies');
    await prefs.remove('letterboxd_user_agent');
    await prefs.remove('is_letterboxd_verified');
    refreshRecentlyWatched();
    notifyListeners();
  }

  Future<void> setLetterboxdUsername(String username) async {
    await verifyAndSaveLetterboxdCredentials(
      username: username,
      rawCookies: _letterboxdRawCookies,
      userAgent: _letterboxdUserAgent,
    );
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

    await _autoRemoveWatchedFromUpcoming();

    LetterboxdService.resolveAfterCreditsStatusForItems(
      _recentlyWatched,
      onUpdate: () => notifyListeners(),
    );
  }

  Future<void> _autoRemoveWatchedFromUpcoming() async {
    if (_recentlyWatched.isEmpty || _upcomingMovies.isEmpty) return;

    String normalize(String title) {
      var clean = title.replaceAll(RegExp(r'\s*\(\d{4}\)\s*'), ' ').replaceAll('*', '').trim().toLowerCase();
      return clean.replaceAll(RegExp(r'[^a-z0-9]+'), '');
    }

    final watchedNormalized = _recentlyWatched.map((w) => normalize(w.filmTitle)).toSet();
    final toDelete = <int>[];

    for (final upcoming in _upcomingMovies) {
      if (upcoming.id == null) continue;
      final upcomingNorm = normalize(upcoming.movieTitle);
      if (watchedNormalized.contains(upcomingNorm)) {
        toDelete.add(upcoming.id!);
      }
    }

    if (toDelete.isNotEmpty) {
      for (final id in toDelete) {
        await DatabaseHelper.instance.deleteUpcomingMovie(id);
      }
      await loadUpcomingMovies();
    }
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
