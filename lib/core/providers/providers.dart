import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../storage/storage_service.dart';
import '../ads/ad_service.dart';

// Storage Service Provider
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences must be initialized in main()');
});

final storageServiceProvider = Provider<StorageService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return StorageService(prefs);
});

// Ad Service Provider
final adServiceProvider = Provider<AdService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return AdService(prefs);
});

// Watch History Provider
final watchHistoryProvider = FutureProvider((ref) async {
  final storage = ref.watch(storageServiceProvider);
  return storage.getHistory();
});

// Watchlist Provider
final watchlistProvider = FutureProvider((ref) async {
  final storage = ref.watch(storageServiceProvider);
  return storage.getWatchlist();
});
