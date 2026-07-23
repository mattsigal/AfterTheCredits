import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../data/models/upcoming_movie_model.dart';
import '../../providers/app_provider.dart';
import '../../data/services/aftercredits_scraper.dart';
import '../widgets/stinger_badge.dart';
import 'movie_detail_screen.dart';
import 'settings_screen.dart';
import '../widgets/letterboxd_log_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'After The Credits',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Force Refresh Feed',
            onPressed: () => provider.forceRefreshAll(),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: provider.forceRefreshAll,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search Input Field
              TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                autofocus: false,
                decoration: InputDecoration(
                  hintText: 'Search for a movie...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _searchFocusNode.unfocus();
                            provider.clearSearch();
                          },
                        )
                      : null,
                ),
                onChanged: (val) => provider.search(val),
              ),
              const SizedBox(height: 16),

              // Search Results List (if active)
              if (provider.searchQuery.isNotEmpty) ...[
                Text(
                  'SEARCH RESULTS',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                    color: const Color(0xFFFF3B5C),
                  ),
                ),
                const SizedBox(height: 8),
                if (provider.isSearching)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (provider.searchResults.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'No AfterCredits.com entry found for "${provider.searchQuery}".',
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: provider.searchResults.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = provider.searchResults[index];
                      return Card(
                        child: ListTile(
                          leading: item.posterUrl != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.network(
                                    item.posterUrl!,
                                    width: 40,
                                    height: 60,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        const Icon(Icons.movie, size: 30),
                                  ),
                                )
                              : const Icon(Icons.movie, size: 30),
                          title: Text(
                            item.displayTitle,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: item.snippet != null
                              ? Text(
                                  item.snippet!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12),
                                )
                              : null,
                          onTap: () {
                            _searchController.clear();
                            _searchFocusNode.unfocus();
                            provider.clearSearch();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MovieDetailScreen(
                                  movieUrl: item.url,
                                  initialTitle: item.title,
                                  initialPosterUrl: item.posterUrl,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 24),
              ],

              // UPCOMING THEATRE VISITS SECTION
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'UPCOMING THEATRE VISITS',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  Text(
                    '${provider.upcomingMovies.length} Planned',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              if (provider.upcomingMovies.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.calendar_month_outlined,
                          size: 36, color: Colors.grey.shade500),
                      const SizedBox(height: 8),
                      const Text(
                        'No upcoming theatre visits planned.',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Search for a movie above to add it to your calendar.',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              else
                SizedBox(
                  height: 335,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: provider.upcomingMovies.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 14),
                    itemBuilder: (context, index) {
                      final movie = provider.upcomingMovies[index];
                      return _buildUpcomingPosterCard(context, movie, provider);
                    },
                  ),
                ),
              const SizedBox(height: 28),

              // RECENTLY WATCHED (LETTERBOXD) SECTION
              if (provider.letterboxdUsername.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'RECENTLY WATCHED (${provider.letterboxdUsername.toUpperCase()})',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                    if (provider.isLoadingRss)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 335,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: provider.recentlyWatched.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(width: 14),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return _buildAddLetterboxdCard(context);
                      }
                      final item = provider.recentlyWatched[index - 1];
                      return _buildLetterboxdPosterCard(context, item);
                    },
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddLetterboxdCard(BuildContext context) {
    return InkWell(
      onTap: () async {
        final result = await showDialog<bool>(
          context: context,
          builder: (_) => const LetterboxdLogDialog(
            filmTitle: '',
          ),
        );
        if (result == true && context.mounted) {
          final provider = Provider.of<AppProvider>(context, listen: false);
          provider.refreshRecentlyWatched();
        }
      },
      child: SizedBox(
        width: 180,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 180,
              height: 260,
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFF00E676).withValues(alpha: 0.6),
                  width: 2,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E676).withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      size: 38,
                      color: Color(0xFF00E676),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Log Film',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF00E676),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'Tap to search or log on Letterboxd',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Add to Letterboxd',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingPosterCard(
    BuildContext context,
    UpcomingMovieModel movie,
    AppProvider provider,
  ) {
    final dateStr = DateFormat('MMM d, yyyy').format(movie.plannedDate);

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MovieDetailScreen(
              movieUrl: movie.movieUrl,
              initialTitle: movie.movieTitle,
              initialPosterUrl: movie.posterUrl,
            ),
          ),
        );
      },
      child: SizedBox(
        width: 180,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                SizedBox(
                  width: 180,
                  height: 260,
                  child: StingerPosterBorder(
                    duringCredits: movie.duringCreditsYesNo,
                    afterCredits: movie.afterCreditsYesNo,
                    child: movie.posterUrl != null
                        ? Image.network(
                            movie.posterUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: Colors.grey.shade800,
                              child: const Icon(Icons.movie, size: 40),
                            ),
                          )
                        : Container(
                            color: Colors.grey.shade800,
                            child: const Icon(Icons.movie, size: 40),
                          ),
                  ),
                ),
                // Stinger Badge Overlay (MID / AFTER)
                Positioned(
                  top: 6,
                  left: 6,
                  child: StingerBadgeOverlay(
                    duringCredits: movie.duringCreditsYesNo,
                    afterCredits: movie.afterCreditsYesNo,
                  ),
                ),
                // Delete button
                Positioned(
                  top: 4,
                  right: 4,
                  child: InkWell(
                    onTap: () {
                      if (movie.id != null) {
                        provider.deleteUpcomingMovie(movie.id!);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, size: 14, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              movie.displayTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            Row(
              children: [
                const Icon(Icons.event, size: 12, color: Color(0xFFFF3B5C)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    dateStr,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLetterboxdPosterCard(BuildContext context, item) {
    return InkWell(
      onTap: () async {
        _searchFocusNode.unfocus();
        if (item.afterCreditsPageUrl != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MovieDetailScreen(
                movieUrl: item.afterCreditsPageUrl!,
                initialTitle: item.filmTitle,
                initialPosterUrl: item.posterUrl,
                existingLetterboxdItem: item,
              ),
            ),
          );
        } else {
          final provider = Provider.of<AppProvider>(context, listen: false);
          _searchController.text = item.filmTitle;
          await provider.search(item.filmTitle);
          final match = AfterCreditsScraper.findBestMatch(item.filmTitle, provider.searchResults);
          if (match != null) {
            item.afterCreditsPageUrl = match.url;
            if (context.mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MovieDetailScreen(
                    movieUrl: match.url,
                    initialTitle: item.filmTitle,
                    initialPosterUrl: item.posterUrl,
                    existingLetterboxdItem: item,
                  ),
                ),
              );
            }
          }
        }
      },
      child: SizedBox(
        width: 180,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                SizedBox(
                  width: 180,
                  height: 260,
                  child: StingerPosterBorder(
                    duringCredits: item.duringCreditsYesNo,
                    afterCredits: item.afterCreditsYesNo,
                    child: item.posterUrl != null
                        ? Image.network(
                            item.posterUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: Colors.grey.shade800,
                              child: const Icon(Icons.movie, size: 40),
                            ),
                          )
                        : Container(
                            color: Colors.grey.shade800,
                            child: const Icon(Icons.movie, size: 40),
                          ),
                  ),
                ),
                Positioned(
                  top: 6,
                  left: 6,
                  child: StingerBadgeOverlay(
                    duringCredits: item.duringCreditsYesNo,
                    afterCredits: item.afterCreditsYesNo,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              item.displayTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            Row(
              children: [
                if (item.memberRating != null) ...[
                  const Icon(Icons.star, size: 12, color: Colors.amber),
                  const SizedBox(width: 3),
                  Text(
                    '${item.memberRating}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
                if (item.memberRating != null && item.watchedDate != null) ...[
                  const SizedBox(width: 4),
                  const Text('•', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  const SizedBox(width: 4),
                ],
                if (item.watchedDate != null)
                  Expanded(
                    child: Text(
                      DateFormat('MMM d, yyyy').format(item.watchedDate!),
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
