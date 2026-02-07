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
    final streams = ref.watch(streamsProvider(widget.media));

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
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PlayerScreen(streams: links),
                        ),
                      );
                    }
                  } else {
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
                                        season: widget.media.mediaType == MediaType.tv ? 1 : null,
                                        episode: widget.media.mediaType == MediaType.tv ? 1 : null,
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


