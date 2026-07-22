import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/models/movie_model.dart';
import '../../data/services/aftercredits_scraper.dart';
import '../../providers/app_provider.dart';
import '../widgets/stinger_badge.dart';

class MovieDetailScreen extends StatefulWidget {
  final String movieUrl;
  final String? initialTitle;
  final String? initialPosterUrl;

  const MovieDetailScreen({
    super.key,
    required this.movieUrl,
    this.initialTitle,
    this.initialPosterUrl,
  });

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  bool _isLoading = true;
  MovieModel? _movie;

  bool _showDuringSpoiler = false;
  bool _showAfterSpoiler = false;

  @override
  void initState() {
    super.initState();
    _loadMovie();
  }

  Future<void> _loadMovie({bool forceRefresh = false}) async {
    setState(() => _isLoading = true);
    final data = await AfterCreditsScraper.fetchMovieDetails(
      widget.movieUrl,
      forceRefresh: forceRefresh,
    );
    if (mounted) {
      setState(() {
        _movie = data;
        _isLoading = false;
      });
    }
  }

  Future<void> _launchUrlStr(String? urlStr) async {
    if (urlStr == null || urlStr.isEmpty) return;
    final uri = Uri.parse(urlStr);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _showAddCalendarDialog() async {
    final now = DateTime.now();
    DateTime selectedDate = now;

    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
    );

    if (picked != null && mounted) {
      selectedDate = picked;
      final provider = Provider.of<AppProvider>(context, listen: false);
      await provider.addUpcomingMovie(
        movieUrl: widget.movieUrl,
        movieTitle: _movie?.title ?? widget.initialTitle ?? 'Upcoming Movie',
        posterUrl: _movie?.posterUrl ?? widget.initialPosterUrl,
        plannedDate: selectedDate,
        duringCredits: _movie?.duringCreditsYesNo,
        afterCredits: _movie?.afterCreditsYesNo,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Added ${_movie?.title ?? widget.initialTitle} to Theatre Calendar for ${DateFormat('MMM d, yyyy').format(selectedDate)}!',
            ),
            backgroundColor: const Color(0xFF00E676),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = Theme.of(context).cardColor;

    final displayTitle = _movie?.title ?? widget.initialTitle ?? 'Movie Details';
    final posterUrl = _movie?.posterUrl ?? widget.initialPosterUrl;

    return Scaffold(
      appBar: AppBar(
        title: Text(displayTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Force Refresh Data',
            onPressed: () => _loadMovie(forceRefresh: true),
          ),
          IconButton(
            icon: const Icon(Icons.calendar_month),
            tooltip: 'Add to Theatre Calendar',
            onPressed: _showAddCalendarDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _movie == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                      const SizedBox(height: 12),
                      const Text('Failed to load movie details'),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () => _loadMovie(forceRefresh: true),
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Section with Poster and Metadata (No duplicate title)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (posterUrl != null)
                            SizedBox(
                              width: 120,
                              height: 175,
                              child: StingerPosterBorder(
                                duringCredits: _movie?.duringCreditsYesNo,
                                afterCredits: _movie?.afterCreditsYesNo,
                                child: Image.network(
                                  posterUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: Colors.grey.shade800,
                                    child: const Icon(Icons.movie, size: 40),
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (_movie!.rating != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'Rating: ${_movie!.rating}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                  ),
                                const SizedBox(height: 8),
                                if (_movie!.director != null)
                                  Text(
                                    'Directed by: ${_movie!.director}',
                                    style: const TextStyle(fontSize: 13, height: 1.3, fontWeight: FontWeight.w600),
                                  ),
                                if (_movie!.writers != null)
                                  Text(
                                    'Written by: ${_movie!.writers}',
                                    style: const TextStyle(fontSize: 13, height: 1.3),
                                  ),
                                const SizedBox(height: 6),
                                if (_movie!.releaseDate != null)
                                  Text(
                                    'Release Date: ${_movie!.releaseDate}',
                                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                                  ),
                                if (_movie!.runningTime != null)
                                  Text(
                                    'Running Time: ${_movie!.runningTime}',
                                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Links (Official, Letterboxd, IMDb)
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            if (_movie!.officialSiteUrl != null)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.public, size: 16),
                                  label: const Text('Official'),
                                  onPressed: () => _launchUrlStr(_movie!.officialSiteUrl),
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.movie_outlined, size: 16),
                                label: const Text('Letterboxd'),
                                onPressed: () {
                                  final lbUrl = 'https://letterboxd.com/search/${Uri.encodeComponent(_movie!.title)}/';
                                  _launchUrlStr(lbUrl);
                                },
                              ),
                            ),
                            if (_movie!.imdbUrl != null)
                              OutlinedButton.icon(
                                icon: const Icon(Icons.movie_creation, size: 16),
                                label: const Text('IMDb'),
                                onPressed: () => _launchUrlStr(_movie!.imdbUrl),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Starring Container
                      if (_movie!.starring != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Starring', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                              const SizedBox(height: 4),
                              Text(_movie!.starring!, style: const TextStyle(fontSize: 14, height: 1.3)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Synopsis Section (Placed directly after Starring)
                      if (_movie!.synopsis != null) ...[
                        Text(
                          'SYNOPSIS',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _movie!.synopsis!,
                          style: const TextStyle(fontSize: 14, height: 1.5),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // STINGER SECTION (AfterCredits.com Stinger Data)
                      Text(
                        'AFTER CREDITS STINGER DATA',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                          color: const Color(0xFFFF3B5C),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // 1. During Credits Extras
                      _buildStingerBox(
                        title: 'Are There Extras During The Credits?',
                        yesNo: _movie!.duringCreditsYesNo,
                        spoilerText: _movie!.duringCreditsText,
                        isExpanded: _showDuringSpoiler,
                        onToggle: () => setState(() => _showDuringSpoiler = !_showDuringSpoiler),
                      ),
                      const SizedBox(height: 12),

                      // 2. After Credits Extras
                      _buildStingerBox(
                        title: 'Are There Extras After The Credits?',
                        yesNo: _movie!.afterCreditsYesNo,
                        spoilerText: _movie!.afterCreditsText,
                        isExpanded: _showAfterSpoiler,
                        onToggle: () => setState(() => _showAfterSpoiler = !_showAfterSpoiler),
                      ),
                      const SizedBox(height: 12),

                      // Stinger Worth Rating
                      if (_movie!.stingerRatingText != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E202A) : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.thumb_up_alt_outlined, size: 18, color: Colors.amber),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Is this stinger worth waiting around for?\n(${_movie!.stingerRatingText})',
                                  style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
    );
  }

  Widget _buildStingerBox({
    required String title,
    required bool? yesNo,
    required String? spoilerText,
    required bool isExpanded,
    required VoidCallback onToggle,
  }) {
    final cardBg = Theme.of(context).cardColor;
    final isYes = yesNo == true;
    final isNo = yesNo == false;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isYes
              ? const Color(0xFFFF3B5C).withValues(alpha: 0.6)
              : isNo
                  ? const Color(0xFF00E676).withValues(alpha: 0.6)
                  : Colors.grey.shade700,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isYes
                        ? const Color(0xFFFF3B5C)
                        : isNo
                            ? const Color(0xFF00E676)
                            : Colors.grey,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isYes ? 'YES' : isNo ? 'NO' : 'UNKNOWN',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Spoiler Toggle Box
          if (spoilerText != null && spoilerText.isNotEmpty) ...[
            InkWell(
              onTap: onToggle,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.black26
                      : Colors.grey.shade100,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
                ),
                child: Row(
                  children: [
                    Icon(
                      isExpanded ? Icons.remove : Icons.add,
                      size: 16,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isExpanded ? 'Hide credit details' : '+ Click to see credit details',
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
            if (isExpanded)
              Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  spoilerText,
                  style: const TextStyle(fontSize: 14, height: 1.4),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
