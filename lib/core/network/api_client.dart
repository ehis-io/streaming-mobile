import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/media.dart';
import '../../models/stream_info.dart';

final apiClientProvider = Provider((ref) => ApiClient());

class ApiClient {
  final Dio _dio = Dio(
    BaseOptions(
      // Default for Android Emulator to host machine
      baseUrl: 'https://api.filmstreamer.org/api/v1',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  // Simple in-memory cache
  final Map<String, _CacheEntry> _cache = {};
  static const Duration _cacheDuration = Duration(minutes: 5);

  Future<List<Media>> getTrendingMovies({int page = 1}) async {
    const key = 'trending_movies';
    if (page == 1 && _hasValidCache(key)) {
      return _cache[key]!.data as List<Media>;
    }

    try {
      final response = await _dio.get(
        '/movies/trending',
        queryParameters: {'page': page},
      );
      final List results = response.data['results'] ?? [];
      final mediaList = results.map((e) => Media.fromJson(e)).toList();
      
      if (page == 1) {
        _cache[key] = _CacheEntry(
          data: mediaList,
          timestamp: DateTime.now(),
        );
      }
      
      return mediaList;
    } catch (e) {
      if (page == 1 && _cache.containsKey(key)) {
        return _cache[key]!.data as List<Media>;
      }
      rethrow;
    }
  }

  Future<List<Media>> getTrendingTvShows({int page = 1}) async {
    const key = 'trending_tv';
    if (page == 1 && _hasValidCache(key)) {
      return _cache[key]!.data as List<Media>;
    }

    try {
      final response = await _dio.get(
        '/tv/trending',
        queryParameters: {'page': page},
      );
      final List results = response.data['results'] ?? [];
      final mediaList = results.map((e) => Media.fromJson(e)).toList();

      if (page == 1) {
        _cache[key] = _CacheEntry(
          data: mediaList,
          timestamp: DateTime.now(),
        );
      }

      return mediaList;
    } catch (e) {
      if (page == 1 && _cache.containsKey(key)) {
        return _cache[key]!.data as List<Media>;
      }
      rethrow;
    }
  }

  Future<List<Media>> getTrendingAnime({int page = 1}) async {
    const key = 'trending_anime';
    if (page == 1 && _hasValidCache(key)) {
      return _cache[key]!.data as List<Media>;
    }

    try {
      final response = await _dio.get(
        '/animes/trending',
        queryParameters: {'page': page},
      );
      
      // Handle Jikan/Anime response structure
      final List results = response.data['data'] ?? response.data['results'] ?? [];
      final mediaList = results.map((e) {
        return Media(
          id: e['mal_id'] ?? e['id'],
          title: e['title'] ?? e['name'],
          posterPath: e['images']?['jpg']?['large_image_url'] ?? e['poster_path'],
          backdropPath: e['images']?['jpg']?['large_image_url'] ?? e['backdrop_path'], // Fallback to poster if no backdrop
          voteAverage: (e['score'] ?? e['vote_average'] ?? 0).toDouble(),
          firstAirDate: e['aired']?['from'] ?? e['first_air_date'],
          overview: e['synopsis'] ?? e['overview'],
          mediaType: MediaType.anime,
        );
      }).toList();

      if (page == 1) {
        _cache[key] = _CacheEntry(
          data: mediaList,
          timestamp: DateTime.now(),
        );
      }

      return mediaList;
    } catch (e) {
      if (page == 1 && _cache.containsKey(key)) {
        return _cache[key]!.data as List<Media>;
      }
      return [];
    }
  }

  bool _hasValidCache(String key) {
    if (!_cache.containsKey(key)) return false;
    final entry = _cache[key]!;
    return DateTime.now().difference(entry.timestamp) < _cacheDuration;
  }

  Future<List<Media>> search(String query, {int page = 1}) async {
    try {
      final response = await _dio.get(
        '/movies/search',
        queryParameters: {'q': query, 'page': page},
      );
      final List results = response.data['results'] ?? [];
      return results.map((e) => Media.fromJson(e)).toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<Media> getMovieDetails(int id) async {
    final response = await _dio.get('/movies/$id');
    return Media.fromJson(response.data);
  }

  Future<List<StreamInfo>> getStreams(
    String id, {
    int? season,
    int? episode,
    String? mediaType,
  }) async {
    final response = await _dio.get(
      '/streams/$id',
      queryParameters: {
        if (season != null) 'season': season,
        if (episode != null) 'episode': episode,
        if (mediaType != null) 'mediaType': mediaType,
      },
    );
    final List results = response.data as List;
    return results.map((e) => StreamInfo.fromJson(e)).toList();
  }
  Future<Map<String, dynamic>> getGenres(String type) async {
    final endpoint = type == 'anime' ? 'animes' : (type == 'tv' ? 'tv' : 'movies');
    final response = await _dio.get('/$endpoint/genres');
    return response.data;
  }

  Future<Map<String, dynamic>> getProducers() async {
    final response = await _dio.get('/animes/producers');
    return response.data;
  }

  Future<Map<String, dynamic>> discoverContent({
    required String type,
    int page = 1,
    String? sortBy,
    String? genreId,
    String? year,
    String? rating,
    String? studioId,
  }) async {
    final endpoint = type == 'anime' ? 'animes' : (type == 'tv' ? 'tv' : 'movies');
    
    // Calculate date params based on year filter
    final Map<String, dynamic> queryParams = {
      'page': page,
      'sort_by': sortBy ?? 'popularity.desc',
      'vote_average.gte': rating ?? '0',
    };

    if (genreId != null && genreId.isNotEmpty) {
      queryParams['with_genres'] = genreId;
    }

    if (studioId != null && studioId.isNotEmpty && type == 'anime') {
      queryParams['producers'] = studioId;
    }

    if (year != null && year != 'all') {
      final now = DateTime.now();
      final currentYear = now.year;
      int startYear = currentYear;
      int? endYear = currentYear;

      if (year == 'current') {
        startYear = currentYear;
        endYear = currentYear;
      } else if (year == 'last_year') {
        startYear = currentYear - 1;
        endYear = currentYear - 1;
      } else if (year == 'last2') {
        startYear = currentYear - 2;
        endYear = null;
      } else if (year == 'last5') {
        startYear = currentYear - 5;
        endYear = null;
      }

      final dateGte = '$startYear-01-01';
      final dateLte = endYear != null ? '$endYear-12-31' : null;

      if (type == 'tv') {
        queryParams['first_air_date.gte'] = dateGte;
        if (dateLte != null) queryParams['first_air_date.lte'] = dateLte;
      } else {
        queryParams['primary_release_date.gte'] = dateGte;
        if (dateLte != null) queryParams['primary_release_date.lte'] = dateLte;
      }
    }

    final response = await _dio.get(
      '/$endpoint/discover',
      queryParameters: queryParams,
    );

    final List results = response.data['results'] ?? [];
    final List<Media> mediaList = results.map<Media>((e) {
      // Map API response to Media object with correct type
      final media = Media.fromJson(e);
      // Ensure media type is set correctly based on the endpoint we queried
      MediaType mediaType;
      if (type == 'anime') mediaType = MediaType.anime;
      else if (type == 'tv') mediaType = MediaType.tv;
      else mediaType = MediaType.movie;
      
      return media.copyWith(mediaType: mediaType);
    }).toList();

    return {
      'results': mediaList,
      'total_pages': response.data['total_pages'] ?? 1,
      'total_results': response.data['total_results'] ?? 0,
    };
  }
}

class _CacheEntry {
  final dynamic data;
  final DateTime timestamp;

  _CacheEntry({required this.data, required this.timestamp});
}
