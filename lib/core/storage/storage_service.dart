import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/media.dart';

class StorageService {
  static const String _watchHistoryKey = 'watch_history';
  static const String _watchlistKey = 'watchlist';

  final SharedPreferences _prefs;

  StorageService(this._prefs);

  // Watch History Methods
  Future<void> addToHistory(Media media) async {
    final history = await getHistory();
    
    // Remove if already exists to update position
    history.removeWhere((item) => item.id == media.id && item.mediaType == media.mediaType);
    
    // Add to beginning
    history.insert(0, media);
    
    // Keep only last 50 items
    if (history.length > 50) {
      history.removeRange(50, history.length);
    }
    
    await _saveHistory(history);
  }

  Future<List<Media>> getHistory() async {
    final jsonString = _prefs.getString(_watchHistoryKey);
    if (jsonString == null) return [];
    
    try {
      final List<dynamic> jsonList = json.decode(jsonString);
      return jsonList.map((json) => Media.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> _saveHistory(List<Media> history) async {
    final jsonString = json.encode(history.map((m) => m.toJson()).toList());
    await _prefs.setString(_watchHistoryKey, jsonString);
  }

  // Watchlist Methods
  Future<void> addToWatchlist(Media media) async {
    final watchlist = await getWatchlist();
    
    // Don't add duplicates
    if (watchlist.any((item) => item.id == media.id && item.mediaType == media.mediaType)) {
      return;
    }
    
    watchlist.insert(0, media);
    await _saveWatchlist(watchlist);
  }

  Future<void> removeFromWatchlist(Media media) async {
    final watchlist = await getWatchlist();
    watchlist.removeWhere((item) => item.id == media.id && item.mediaType == media.mediaType);
    await _saveWatchlist(watchlist);
  }

  Future<List<Media>> getWatchlist() async {
    final jsonString = _prefs.getString(_watchlistKey);
    if (jsonString == null) return [];
    
    try {
      final List<dynamic> jsonList = json.decode(jsonString);
      return jsonList.map((json) => Media.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<bool> isInWatchlist(Media media) async {
    final watchlist = await getWatchlist();
    return watchlist.any((item) => item.id == media.id && item.mediaType == media.mediaType);
  }

  Future<void> _saveWatchlist(List<Media> watchlist) async {
    final jsonString = json.encode(watchlist.map((m) => m.toJson()).toList());
    await _prefs.setString(_watchlistKey, jsonString);
  }

  // Search History Methods
  static const String _searchHistoryKey = 'search_history';

  Future<List<String>> getSearchHistory() async {
    return _prefs.getStringList(_searchHistoryKey) ?? [];
  }

  Future<void> addSearchHistory(String query) async {
    final history = await getSearchHistory();
    
    // Remove if already exists to move to top
    history.remove(query);
    
    // Add to beginning
    history.insert(0, query);
    
    // Keep only last 20 items
    if (history.length > 20) {
      history.removeRange(20, history.length);
    }
    
    await _prefs.setStringList(_searchHistoryKey, history);
  }

  Future<void> removeSearchHistory(String query) async {
    final history = await getSearchHistory();
    history.remove(query);
    await _prefs.setStringList(_searchHistoryKey, history);
  }

  Future<void> clearSearchHistory() async {
    await _prefs.remove(_searchHistoryKey);
  }
}
