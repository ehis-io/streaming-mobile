import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/media.dart';
import '../../../core/network/api_client.dart';

final trendingMoviesProvider = FutureProvider<List<Media>>((ref) async {
  final client = ref.watch(apiClientProvider);
  return client.getTrendingMovies();
});

final trendingTvShowsProvider = FutureProvider<List<Media>>((ref) async {
  final client = ref.watch(apiClientProvider);
  return client.getTrendingTvShows();
});

final trendingAnimeProvider = FutureProvider<List<Media>>((ref) async {
  final client = ref.watch(apiClientProvider);
  return client.getTrendingAnime();
});
