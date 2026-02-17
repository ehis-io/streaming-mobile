import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/media.dart';
import '../../../models/stream_info.dart';
import '../../../core/providers/providers.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../player/presentation/player_screen.dart';
import '../data/details_providers.dart';

class DetailsScreen extends ConsumerStatefulWidget {
  final Media media;

  const DetailsScreen({super.key, required this.media});

  @override
  ConsumerState<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends ConsumerState<DetailsScreen> {
  bool _isInWatchlist = false;
  bool _isLoading = true;
  int _selectedSeason = 1;
  int _selectedEpisode = 1;
  bool _isOpeningPlayer = false;

  @override
  void initState() {
    super.initState();
    _checkWatchlistStatus();
  }

  Future<void> _checkWatchlistStatus() async {
    final storage = ref.read(storageServiceProvider);
    final inList = await storage.isInWatchlist(widget.media);
    if (mounted) {
      setState(() {
        _isInWatchlist = inList;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleWatchlist() async {
    final storage = ref.read(storageServiceProvider);
    if (_isInWatchlist) {
      await storage.removeFromWatchlist(widget.media);
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Removed from My List',
          type: SnackbarType.info,
        );
      }
    } else {
      await storage.addToWatchlist(widget.media);
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Added to My List',
          type: SnackbarType.success,
        );
      }
    }
    setState(() {
      _isInWatchlist = !_isInWatchlist;
    });
    // Refresh watchlist provider
    ref.invalidate(watchlistProvider);
  }

  @override
  Widget build(BuildContext context) {
    // If it's TV/Anime, we might want to fetch full details to get seasons
    final isTV = widget.media.mediaType == MediaType.tv || widget.media.mediaType == MediaType.anime;
    
    AsyncValue<Media>? fullDetails;
    if (isTV) {
      fullDetails = ref.watch(tvDetailsProvider(widget.media.id));
    }

    final streams = ref.watch(streamsProvider((
      media: widget.media,
      season: isTV ? _selectedSeason : null,
      episode: isTV ? _selectedEpisode : null,
    )));

    return Scaffold(
      body: Stack(
        children: [
          // Backdrop
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                // Auto-play first available stream
                 streams.whenData((links) async {
                  if (links.isNotEmpty) {
                    // Add to watch history
                    final storage = ref.read(storageServiceProvider);
                    await storage.addToHistory(widget.media);
                    ref.invalidate(watchHistoryProvider);
                    
                    if (context.mounted) {
                      setState(() => _isOpeningPlayer = false);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PlayerScreen(
                            streams: links,
                            media: widget.media,
                            season: isTV ? _selectedSeason : null,
                            episode: isTV ? _selectedEpisode : null,
                          ),
                        ),
                      );
                    }
                  } else {
                    if (mounted) setState(() => _isOpeningPlayer = false);
                    AppSnackbar.show(context, message: 'No streams found', type: SnackbarType.error);
                  }
                });
              },
              child: CachedNetworkImage(
                imageUrl: widget.media.backdropUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(color: Colors.black),
                errorWidget: (context, url, error) => Container(color: Colors.black),
              ),
            ),
          ),
          // Gradient overlap
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.3),
                    Colors.black.withOpacity(0.6),
                    Colors.black,
                  ],
                  stops: const [0.0, 0.4, 0.8],
                ),
              ),
            ),
          ),
          // Content
          CustomScrollView(
            slivers: [
              SliverAppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                pinned: true,
                leading: Container(
                  margin: const EdgeInsets.only(left: 8),
                  child: CircleAvatar(
                    backgroundColor: Colors.black.withOpacity(0.5),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
                actions: [
                  if (!_isLoading)
                    Container(
                      margin: const EdgeInsets.only(right: 16),
                      child: CircleAvatar(
                        backgroundColor: Colors.black.withOpacity(0.5),
                        child: IconButton(
                          icon: Icon(
                            _isInWatchlist ? Icons.bookmark : Icons.bookmark_border,
                            color: _isInWatchlist ? Colors.red : Colors.white,
                          ),
                          onPressed: _toggleWatchlist,
                        ),
                      ),
                    ),
                ],
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: MediaQuery.of(context).size.height * 0.35),
                      Text(
                        widget.media.displayTitle,
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              shadows: [
                                const Shadow(
                                  blurRadius: 10.0,
                                  color: Colors.black,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          if (widget.media.voteAverage != null) ...[
                            const Icon(Icons.star, color: Colors.amber, size: 20),
                            const SizedBox(width: 4),
                            Text(
                              widget.media.voteAverage!.toStringAsFixed(1),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 16),
                          ],
                          Text(
                            widget.media.displayDate.split('-')[0],
                            style: TextStyle(
                              color: Colors.grey[300],
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[500]!),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              widget.media.mediaType == MediaType.anime 
                                ? 'Anime' 
                                : (widget.media.mediaType == MediaType.movie ? 'Movie' : 'TV'),
                              style: TextStyle(
                                color: Colors.grey[300],
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        widget.media.overview ?? 'No overview available.',
                        style: TextStyle(
                          height: 1.5,
                          fontSize: 16,
                          color: Colors.grey[100],
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Play Button/Streams
                      streams.when(
                        data: (links) {
                          if (links.isEmpty) {
                            return Center(
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.grey[900],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text('No streams available yet.'),
                              ),
                            );
                          }
                          return Center(
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                final storage = ref.read(storageServiceProvider);
                                await storage.addToHistory(widget.media);
                                ref.invalidate(watchHistoryProvider);

                                if (context.mounted) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => PlayerScreen(
                                        streams: links,
                                        media: widget.media,
                                        season: isTV ? _selectedSeason : null,
                                        episode: isTV ? _selectedEpisode : null,
                                      ),
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(Icons.play_arrow, color: Colors.white, size: 32),
                              label: const Text(
                                'Watch Now',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                elevation: 8,
                                shadowColor: Colors.red.withOpacity(0.5),
                              ),
                            ),
                          );
                        },
                        loading: () => const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32.0),
                            child: CircularProgressIndicator(),
                          ),
                        ),
                        error: (err, stack) => Center(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            margin: const EdgeInsets.symmetric(vertical: 20),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.red.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, color: Colors.red),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Failed to load streams: $err',
                                    style: const TextStyle(color: Colors.redAccent),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.refresh, color: Colors.redAccent),
                                  onPressed: () => ref.refresh(streamsProvider(widget.media)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      if (isTV && fullDetails != null)
                        fullDetails.when(
                          data: (data) {
                            final seasons = data.seasons?.where((s) => s.seasonNumber > 0).toList() ?? [];
                            if (seasons.isEmpty) return const SizedBox.shrink();
                            
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Episodes',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    DropdownButtonHideUnderline(
                                      child: DropdownButton<int>(
                                        value: _selectedSeason,
                                        dropdownColor: Colors.grey[900],
                                        style: const TextStyle(color: Colors.white, fontSize: 16),
                                        items: seasons.map((s) => DropdownMenuItem(
                                          value: s.seasonNumber,
                                          child: Text('Season ${s.seasonNumber}'),
                                        )).toList(),
                                        onChanged: (val) {
                                          if (val != null) {
                                            setState(() {
                                              _selectedSeason = val;
                                              _selectedEpisode = 1;
                                            });
                                          }
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Consumer(
                                  builder: (context, ref, child) {
                                    final episodes = ref.watch(seasonDetailsProvider((id: widget.media.id, season: _selectedSeason)));
                                    return episodes.when(
                                      data: (list) {
                                        return ListView.builder(
                                          shrinkWrap: true,
                                          physics: const NeverScrollableScrollPhysics(),
                                          itemCount: list.length,
                                          itemBuilder: (context, index) {
                                            final ep = list[index];
                                            final isSelected = _selectedEpisode == ep.episodeNumber;
                                            return ListTile(
                                              contentPadding: EdgeInsets.zero,
                                              leading: Container(
                                                width: 100,
                                                height: 56,
                                                decoration: BoxDecoration(
                                                  borderRadius: BorderRadius.circular(4),
                                                  image: DecorationImage(
                                                    image: NetworkImage(ep.stillUrl),
                                                    fit: BoxFit.cover,
                                                  ),
                                                ),
                                                child: isSelected ? Container(
                                                  color: Colors.black45,
                                                  child: const Icon(Icons.play_circle_fill, color: Colors.red, size: 30),
                                                ) : null,
                                              ),
                                              title: Text(
                                                '${ep.episodeNumber}. ${ep.name ?? 'Episode ${ep.episodeNumber}'}',
                                                style: TextStyle(
                                                  color: isSelected ? Colors.red : Colors.white,
                                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                                ),
                                              ),
                                              subtitle: Text(
                                                ep.airDate ?? '',
                                                style: TextStyle(color: Colors.grey[400], fontSize: 12),
                                              ),
                                              onTap: () async {
                                                if (_isOpeningPlayer) return;
                                                
                                                final targetEpisode = ep.episodeNumber;
                                                
                                                // Update selected episode first
                                                setState(() {
                                                  _selectedEpisode = targetEpisode;
                                                  _isOpeningPlayer = true;
                                                });
                                                
                                                // Wait for next frame to allow Riverpod to rebuild with new parameters
                                                await Future.delayed(Duration.zero);
                                                
                                                // Now fetch fresh streams with the correct episode number
                                                if (!mounted) return;
                                                
                                                try {
                                                  final freshStreams = await ref.read(streamsProvider((
                                                    media: widget.media,
                                                    season: _selectedSeason,
                                                    episode: targetEpisode,
                                                  )).future);
                                                  
                                                  if (freshStreams.isNotEmpty) {
                                                    final storage = ref.read(storageServiceProvider);
                                                    await storage.addToHistory(widget.media);
                                                    ref.invalidate(watchHistoryProvider);
                                                    
                                                    if (context.mounted) {
                                                      setState(() => _isOpeningPlayer = false);
                                                      Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder: (context) => PlayerScreen(
                                                            streams: freshStreams,
                                                            media: widget.media,
                                                            season: _selectedSeason,
                                                            episode: targetEpisode,
                                                          ),
                                                        ),
                                                      );
                                                    }
                                                  } else {
                                                    if (mounted) {
                                                      setState(() => _isOpeningPlayer = false);
                                                      AppSnackbar.show(context, message: 'No streams found for Episode ${targetEpisode}', type: SnackbarType.error);
                                                    }
                                                  }
                                                } catch (e) {
                                                  if (mounted) {
                                                    setState(() => _isOpeningPlayer = false);
                                                    AppSnackbar.show(context, message: 'Failed to load Episode ${targetEpisode}: $e', type: SnackbarType.error);
                                                  }
                                                }
                                              },
                                            );
                                          },
                                        );
                                      },
                                      loading: () => const Center(child: CircularProgressIndicator()),
                                      error: (err, stack) => Text('Error loading episodes: $err', style: const TextStyle(color: Colors.red)),
                                    );
                                  },
                                ),
                              ],
                            );
                          },
                          loading: () => const Center(child: CircularProgressIndicator()),
                          error: (err, stack) => const SizedBox.shrink(),
                        ),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


