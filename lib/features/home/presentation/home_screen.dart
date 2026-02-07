import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/home_providers.dart';
import '../../../models/media.dart';
import '../../../core/widgets/hero_section.dart';
import '../../../core/widgets/skeleton_card.dart';
import '../../../core/providers/providers.dart';
import '../../details/presentation/details_screen.dart';
import '../../downloads/presentation/downloads_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _refreshContent(WidgetRef ref) async {
    ref.invalidate(trendingMoviesProvider);
    ref.invalidate(trendingTvShowsProvider);
    ref.invalidate(trendingAnimeProvider);
    ref.invalidate(watchHistoryProvider);
    ref.invalidate(watchlistProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trendingMovies = ref.watch(trendingMoviesProvider);
    final trendingTvShows = ref.watch(trendingTvShowsProvider);
    final trendingAnime = ref.watch(trendingAnimeProvider);
    final watchHistory = ref.watch(watchHistoryProvider);
    final watchlist = ref.watch(watchlistProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => _refreshContent(ref),
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              floating: true,
              title: const Text(
                'STREAM HUB',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              centerTitle: true,
              backgroundColor: Colors.transparent,
              elevation: 0,
              actions: [
                IconButton(
                  icon: const Icon(Icons.download_rounded, color: Colors.white),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const DownloadsScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          // Hero Section
          SliverToBoxAdapter(
            child: trendingMovies.when(
              data: (movies) => movies.isNotEmpty 
                ? HeroSection(media: movies.first)
                : const SizedBox.shrink(),
              loading: () => Container(
                height: 400,
                color: Colors.grey[900],
              ),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),
          // Continue Watching Section
          SliverToBoxAdapter(
            child: watchHistory.when(
              data: (history) => history.isNotEmpty
                ? _Section(
                    title: 'Continue Watching',
                    mediaList: AsyncValue.data(history),
                  )
                : const SizedBox.shrink(),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),
          // My List Section
          SliverToBoxAdapter(
            child: watchlist.when(
              data: (list) => list.isNotEmpty
                ? _Section(
                    title: 'My List',
                    mediaList: AsyncValue.data(list),
                  )
                : const SizedBox.shrink(),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),
          SliverToBoxAdapter(
            child: _Section(
              title: 'Trending Movies',
              mediaList: trendingMovies,
            ),
          ),
          SliverToBoxAdapter(
            child: _Section(
              title: 'Trending TV Shows',
              mediaList: trendingTvShows,
            ),
          ),
          SliverToBoxAdapter(
            child: _Section(
              title: 'Trending Anime',
              mediaList: trendingAnime,
            ),
          ),
        ],
      ),
    ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final AsyncValue<List<Media>> mediaList;

  const _Section({required this.title, required this.mediaList});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        SizedBox(
          height: 220,
          child: mediaList.when(
            data: (items) => ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final media = items[index];
                return _MediaCard(media: media);
              },
            ),
            loading: () => ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: 5,
              itemBuilder: (context, index) => const SkeletonCard(),
            ),
            error: (err, stack) => Center(child: Text('Error: $err')),
          ),
        ),
      ],
    );
  }
}

class _MediaCard extends StatelessWidget {
  final Media media;

  const _MediaCard({required this.media});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DetailsScreen(media: media),
          ),
        );
      },
      child: Container(
        width: 150,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: media.posterUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(color: Colors.grey[900]),
                      errorWidget: (context, url, error) => const Icon(Icons.error),
                    ),
                    // Subtle gradient overlay
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 60,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withOpacity(0.6),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              media.displayTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
