import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ClickaduAdManager with WidgetsBindingObserver {
  // Replace with your actual Clickadu SmartLink
  static const String _smartLinkUrl = 'https://thubordas.com/4/8664150';
  
  final VoidCallback onAdComplete;
  bool _isAdShowing = false;

  ClickaduAdManager({required this.onAdComplete}) {
    WidgetsBinding.instance.addObserver(this);
  }

  Future<void> showAd() async {
    final Uri url = Uri.parse(_smartLinkUrl);
    
    if (await canLaunchUrl(url)) {
      _isAdShowing = true;
      await launchUrl(
        url,
        mode: LaunchMode.inAppBrowserView, // Opens in a modal-like browser
      );
      // Fallback: If launch returns immediately or fails silently,
      // we rely on didChangeAppLifecycleState to detect return.
    } else {
      debugPrint('Could not launch Clickadu Ad URL');
      _completeAd();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When app resumes (user closed the browser), complete the ad
    if (state == AppLifecycleState.resumed && _isAdShowing) {
      debugPrint('App resumed from Ad. Starting content.');
      _completeAd();
    }
  }

  void _completeAd() {
    if (!_isAdShowing) return;
    _isAdShowing = false;
    onAdComplete();
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }
}
