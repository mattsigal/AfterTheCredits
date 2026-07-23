import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/models/movie_model.dart';
import '../../data/services/aftercredits_scraper.dart';
import '../../providers/app_provider.dart';
import '../../utils/title_formatter.dart';
import '../widgets/letterboxd_log_dialog.dart';
import '../widgets/stinger_badge.dart';
import 'settings_screen.dart';

import '../../data/models/letterboxd_item.dart';

class MovieDetailScreen extends StatefulWidget {
  final String movieUrl;
  final String? initialTitle;
  final String? initialPosterUrl;
  final LetterboxdItem? existingLetterboxdItem;

  const MovieDetailScreen({
    super.key,
    required this.movieUrl,
    this.initialTitle,
    this.initialPosterUrl,
    this.existingLetterboxdItem,
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
    var formattedUrl = urlStr.trim();
    if (!formattedUrl.startsWith('http://') && !formattedUrl.startsWith('https://')) {
      formattedUrl = 'https://$formattedUrl';
    }
    final uri = Uri.parse(formattedUrl);
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (_) {
      try {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      } catch (_) {}
    }
  }

  Future<void> _showLetterboxdLogDialog() async {
    final provider = Provider.of<AppProvider>(context, listen: false);
    if (!provider.isLetterboxdAuthenticated) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: const [
              Icon(Icons.lock_outline, color: Colors.amber),
              SizedBox(width: 8),
              Text('Authentication Required'),
            ],
          ),
          content: const Text(
            'You must configure your Letterboxd username and Cloudflare session cookies in Settings before sending ratings or reviews.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E676),
                foregroundColor: Colors.black,
              ),
              icon: const Icon(Icons.settings),
              label: const Text('Go to Settings'),
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
            ),
          ],
        ),
      );
      return;
    }

    final title = _movie?.displayTitle ??
        TitleFormatter.formatDisplayTitle(widget.initialTitle ?? 'Movie');
    final poster = _movie?.posterUrl ?? widget.initialPosterUrl;

    final result = await showDialog<bool>(
      context: context,
      builder: (_) => LetterboxdLogDialog(
        filmTitle: title,
        filmYear: _movie?.releaseDate,
        posterUrl: poster,
        existingItem: widget.existingLetterboxdItem,
      ),
    );

    if (result == true && mounted) {
      provider.refreshRecentlyWatched();
      Navigator.of(context).popUntil((route) => route.isFirst);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.existingLetterboxdItem != null
                ? 'Updated Letterboxd entry for "$title"!'
                : 'Logged "$title" to Letterboxd!',
          ),
          backgroundColor: const Color(0xFF00E676),
        ),
      );
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

  Future<void> _handleFullRefresh() async {
    final provider = Provider.of<AppProvider>(context, listen: false);
    setState(() => _isLoading = true);
    await Future.wait([
      _loadMovie(forceRefresh: true),
      if (provider.letterboxdUsername.isNotEmpty)
        provider.refreshRecentlyWatched(),
    ]);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Refreshed AfterCredits and Letterboxd data!'),
          duration: Duration(seconds: 2),
          backgroundColor: Color(0xFF00E676),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = Theme.of(context).cardColor;

    final displayTitle = _movie?.displayTitle ??
        TitleFormatter.formatDisplayTitle(widget.initialTitle ?? 'Movie Details');
    final posterUrl = _movie?.posterUrl ?? widget.initialPosterUrl;

    return Scaffold(
      appBar: AppBar(
        title: Text(displayTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Force Refresh Data',
            onPressed: _handleFullRefresh,
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
                      Center(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
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
                                    final lbUrl =
                                        'https://letterboxd.com/search/${Uri.encodeComponent(displayTitle)}/';
                                    _launchUrlStr(lbUrl);
                                  },
                                ),
                              ),
                               OutlinedButton.icon(
                                 icon: const Icon(Icons.movie_creation, size: 16),
                                 label: const Text('IMDb'),
                                 onPressed: () {
                                   final url = (_movie?.imdbUrl != null && _movie!.imdbUrl!.contains('imdb.com/title/'))
                                       ? _movie!.imdbUrl!
                                       : 'https://www.imdb.com/find/?q=${Uri.encodeComponent(displayTitle)}';
                                   _launchUrlStr(url);
                                 },
                               ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Update Letterboxd Rating Button (only for items with existing Letterboxd activity)
                      if (widget.existingLetterboxdItem != null) ...[
                        Center(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.rate_review, size: 18),
                            label: const Text('Update Letterboxd Entry'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00E676),
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            ),
                            onPressed: _showLetterboxdLogDialog,
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

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
                      const SizedBox(height: 20),

                      // 3. Letterboxd Review & Rating Summary Card (only for existing Letterboxd items)
                      if (widget.existingLetterboxdItem != null) ...[
                        _buildLetterboxdSummaryCard(),
                        const SizedBox(height: 30),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _buildLetterboxdSummaryCard() {
    final item = widget.existingLetterboxdItem;
    const accentGreen = Color(0xFF00E676);
    final cardBg = Theme.of(context).cardColor;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: item != null ? accentGreen.withValues(alpha: 0.5) : Colors.grey.shade800,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF1E252C),
              borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Row(
              children: [
                const Icon(Icons.movie_creation_outlined, color: accentGreen, size: 20),
                const SizedBox(width: 10),
                const Text(
                  'LETTERBOXD ACTIVITY',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: accentGreen,
                  ),
                ),
                const Spacer(),
                if (item != null)
                  InkWell(
                    onTap: _showLetterboxdLogDialog,
                    child: Row(
                      children: const [
                        Icon(Icons.edit, size: 14, color: Colors.grey),
                        SizedBox(width: 4),
                        Text(
                          'Edit',
                          style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: item != null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Date & Rating Row
                      Row(
                        children: [
                          if (item.watchedDate != null) ...[
                            Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade400),
                            const SizedBox(width: 6),
                            Text(
                              'Watched ${DateFormat('d MMM yyyy').format(item.watchedDate!)}',
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade300, fontWeight: FontWeight.w500),
                            ),
                          ],
                          const Spacer(),
                          if (item.memberRating != null && item.memberRating! > 0) ...[
                            Row(
                              children: List.generate(5, (idx) {
                                final starVal = (idx + 1).toDouble();
                                IconData icon;
                                if (item.memberRating! >= starVal) {
                                  icon = Icons.star;
                                } else if (item.memberRating! >= starVal - 0.5) {
                                  icon = Icons.star_half;
                                } else {
                                  icon = Icons.star_border;
                                }
                                return Icon(icon, color: accentGreen, size: 18);
                              }),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${item.memberRating! % 1 == 0 ? item.memberRating!.toInt() : item.memberRating}/5',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: accentGreen),
                            ),
                          ],
                        ],
                      ),

                      // Review Text Box (if present)
                      if (item.review != null && item.review!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF181D23),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade800),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '"',
                                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: accentGreen, height: 0.8),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  item.review!,
                                  style: const TextStyle(fontSize: 13, height: 1.4, fontStyle: FontStyle.italic, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Have you watched this movie? Log your watch date, star rating, and review directly to your Letterboxd account.',
                        style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.4),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentGreen,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Log or Rate on Letterboxd', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          onPressed: _showLetterboxdLogDialog,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
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
