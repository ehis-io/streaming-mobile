import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

class AdService {
  static const String _lastAdShowKey = 'last_ad_show';
  static const int _initialDelayMs = 300000; // 5 minutes
  static const int _frequencyCapMs = 1800000; // 30 minutes
  static const String _zoneId = '4ttawwdyfo';

  final SharedPreferences _prefs;
  Timer? _adTimer;

  AdService(this._prefs);

  void initialize() {
    // Delay ad initialization by 5 minutes
    _adTimer = Timer(Duration(milliseconds: _initialDelayMs), () {
      _showAds();
    });
  }

  void _showAds() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final lastShow = _prefs.getInt(_lastAdShowKey) ?? 0;

    // Check frequency cap
    if (now - lastShow < _frequencyCapMs) {
      print('Ad frequency cap active. Skipping ads.');
      return;
    }

    // In a real implementation, you would initialize the ad SDK here
    // For AdCash, this would typically involve loading a WebView or using their SDK
    print('Initializing ads with zone: $_zoneId');
    
    _prefs.setInt(_lastAdShowKey, now);
  }

  void dispose() {
    _adTimer?.cancel();
  }
}
