import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../models/media.dart';
import '../../../core/network/api_client.dart';

// Filter State
class DiscoverFilter {
  final String type;
  final String year;
  final String genreId;
  final String rating;
  final String sortBy;
  final String studioId;
  final int page;

  DiscoverFilter({
    this.type = 'movies',
    this.year = 'all',
    this.genreId = '',
    this.rating = '0',
    this.sortBy = 'popularity.desc',
    this.studioId = '',
    this.page = 1,
  });

  DiscoverFilter copyWith({
    String? type,
    String? year,
    String? genreId,
    String? rating,
    String? sortBy,
    String? studioId,
    int? page,
  }) {
    return DiscoverFilter(
      type: type ?? this.type,
      year: year ?? this.year,
      genreId: genreId ?? this.genreId,
      rating: rating ?? this.rating,
      sortBy: sortBy ?? this.sortBy,
      studioId: studioId ?? this.studioId,
      page: page ?? this.page,
    );
  }
}

final discoverFilterProvider = StateProvider<DiscoverFilter>((ref) => DiscoverFilter());

// Data Providers
final genresProvider = FutureProvider.family<List<dynamic>, String>((ref, type) async {
  final client = ref.read(apiClientProvider);
  final response = await client.getGenres(type);
  return response['genres'] ?? [];
});

final producersProvider = FutureProvider<List<dynamic>>((ref) async {
  final client = ref.read(apiClientProvider);
  final response = await client.getProducers();
  return response['producers'] ?? [];
});

final discoverContentProvider = FutureProvider.family<Map<String, dynamic>, DiscoverFilter>((ref, filter) async {
  final client = ref.read(apiClientProvider);
  return client.discoverContent(
    type: filter.type,
    page: filter.page,
    sortBy: filter.sortBy,
    genreId: filter.genreId.isEmpty ? null : filter.genreId,
    year: filter.year,
    rating: filter.rating,
    studioId: filter.studioId.isEmpty ? null : filter.studioId,
  );
});
