import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final hlsDownloadServiceProvider = Provider((ref) => HlsDownloadService());

class HlsDownloadService {
  static const _channel = MethodChannel('com.streaming.aggregator/hls_download');
  
  final List<Function(Map<String, dynamic>)> _listeners = [];

  HlsDownloadService() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onDownloadUpdate') {
        final data = Map<String, dynamic>.from(call.arguments);
        for (var listener in _listeners) {
          listener(data);
        }
      }
    });
  }

  void addListener(Function(Map<String, dynamic>) listener) {
    _listeners.add(listener);
  }

  void removeListener(Function(Map<String, dynamic>) listener) {
    _listeners.remove(listener);
  }

  Future<String?> startDownload({
    required String url,
    required String fileName,
    String? id,
    String? referer,
  }) async {
    try {
      final String? taskId = await _channel.invokeMethod('startDownload', {
        'url': url,
        'fileName': fileName,
        'id': id,
        'referer': referer,
      });
      return taskId;
    } on PlatformException catch (e) {
      print('Failed to start HLS download: ${e.message}');
      return null;
    }
  }

  Future<bool> cancelDownload(String id) async {
    try {
      final bool success = await _channel.invokeMethod('cancelDownload', {'id': id});
      return success;
    } on PlatformException catch (e) {
      print('Failed to cancel HLS download: ${e.message}');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getTasks() async {
    try {
      final List results = await _channel.invokeMethod('getTasks');
      return results.map((e) => Map<String, dynamic>.from(e)).toList();
    } on PlatformException catch (e) {
      print('Failed to get HLS tasks: ${e.message}');
      return [];
    }
  }
}
