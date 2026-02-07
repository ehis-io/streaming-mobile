import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../models/media.dart';
import '../../details/presentation/details_screen.dart';
import '../data/discover_providers.dart';

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  final Map<String, String> _typeLabels = {
    'movies': 'Movies',
    'tv': 'TV Shows',
    'anime': 'Anime',
  };

  final Map<String, String> _yearLabels = {
    'all': 'All Years',
    'current': 'Current Year',
    'last_year': 'Last Year',
    'last2': 'Last 2 Years',
    'last5': 'Last 5 Years',
  };

  final Map<String, String> _sortLabels = {
    'popularity.desc': 'Popularity',
    'vote_average.desc': 'Rating',
    'primary_release_date.desc': 'Newest',
    'primary_release_date.asc': 'Oldest',
  };

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(discoverFilterProvider);
    final contentAsync = ref.watch(discoverContentProvider(filter));
    final genresAsync = ref.watch(genresProvider(filter.type));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
               ref.invalidate(discoverContentProvider(filter));
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Bar
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildDropdown<String>(
                  label: 'Type',
                  value: filter.type,
                  items: _typeLabels,
                  onChanged: (val) {
                    if (val != null) {
                      ref.read(discoverFilterProvider.notifier).state = filter.copyWith(
                        type: val, 
                        genreId: '', 
                        studioId: '', 
                        page: 1
                      );
                    }
                  },
                ),
                const SizedBox(width: 8),
                _buildDropdown<String>(
                  label: 'Year',
                  value: filter.year,
                  items: _yearLabels,
                  onChanged: (val) {
                    if (val != null) {
                      ref.read(discoverFilterProvider.notifier).state = filter.copyWith(year: val, page: 1);
                    }
                  },
                ),
                const SizedBox(width: 8),
                 // Genre Dropdown
                genresAsync.when(
                  data: (genres) {
                    final Map<String, String> genreMap = {'': 'All Genres'};
                    for (var g in genres) {
                      genreMap[g['id'].toString()] = g['name'];
                    }
                    return _buildDropdown<String>(
                      label: 'Genre',
                      value: filter.genreId,
                      items: genreMap,
                      onChanged: (val) {
                         if (val != null) {
                           ref.read(discoverFilterProvider.notifier).state = filter.copyWith(genreId: val, page: 1);
                         }
                      },
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                 const SizedBox(width: 8),
                 _buildDropdown<String>(
                  label: 'Sort',
                  value: filter.sortBy,
                  items: _sortLabels,
                  onChanged: (val) {
                    if (val != null) {
                      ref.read(discoverFilterProvider.notifier).state = filter.copyWith(sortBy: val);
                    }
                  },
                ),
              ],
            ),
          ),
          
          Expanded(
            child: contentAsync.when(
              data: (data) {
                final List<Media> items = data['results'] ?? [];
                if (items.isEmpty) {
                  return const Center(child: Text('No results found'));
                }
                return GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.7,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    return _MediaCard(media: items[index]);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(color: Colors.red)),
              error: (err, stack) => Center(child: Text('Error: $err')),
            ),
          ),
          
          // Pagination
          Container(
             padding: const EdgeInsets.all(8),
             color: Colors.black54,
             child: Row(
               mainAxisAlignment: MainAxisAlignment.center,
               children: [
                 IconButton(
                   icon: const Icon(Icons.arrow_back_ios),
                   onPressed: filter.page > 1 
                     ? () => ref.read(discoverFilterProvider.notifier).state = filter.copyWith(page: filter.page - 1)
                     : null,
                 ),
                 Text('Page ${filter.page}'),
                 IconButton(
                   icon: const Icon(Icons.arrow_forward_ios),
                   onPressed: () => ref.read(discoverFilterProvider.notifier).state = filter.copyWith(page: filter.page + 1),
                 ),
               ],
             ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T value,
    required Map<T, String> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: items.containsKey(value) ? value : null,
          hint: Text(label, style: const TextStyle(fontSize: 12)),
          isDense: true,
          dropdownColor: Colors.grey[900],
          style: const TextStyle(color: Colors.white, fontSize: 13),
          items: items.entries.map((e) {
            return DropdownMenuItem<T>(
              value: e.key,
              child: Text(e.value),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: media.posterUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(color: Colors.grey[850]),
              errorWidget: (context, url, _) => const Icon(Icons.broken_image),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 10),
                    const SizedBox(width: 2),
                    Text(
                      (media.voteAverage ?? 0.0).toStringAsFixed(1),
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
