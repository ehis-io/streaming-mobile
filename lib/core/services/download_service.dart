import 'dart:io';
import 'dart:isolate';
import 'dart:ui';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as path;
import 'hls_download_service.dart';

final downloadServiceProvider = Provider<DownloadService>((ref) {
  final hlsService = ref.watch(hlsDownloadServiceProvider);
  return DownloadService(hlsService);
});

class DownloadService {
  final HlsDownloadService _hlsService;
  final ReceivePort _port = ReceivePort();

  DownloadService(this._hlsService);

  Future<void> initialize() async {
    await FlutterDownloader.initialize(
      debug: true,
      ignoreSsl: true,
    );
    
    IsolateNameServer.registerPortWithName(_port.sendPort, 'downloader_send_port');
    
    // Register callback (must be static)
    await FlutterDownloader.registerCallback(downloadCallback);
  }

  @pragma('vm:entry-point')
  static void downloadCallback(String id, int status, int progress) {
    final SendPort? send = IsolateNameServer.lookupPortByName('downloader_send_port');
    send?.send([id, status, progress]);
  }
  
  void dispose() {
    IsolateNameServer.removePortNameMapping('downloader_send_port');
  }

  Future<bool> requestPermission() async {
    if (Platform.isIOS) return true;

    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      // On Android 13+ (SDK 33), storage permissions are granular
      if (androidInfo.version.sdkInt >= 33) {
         return true; // No general storage permission needed for saving to app-specific directories or media store
      }
      
      final status = await Permission.storage.status;
      if (status != PermissionStatus.granted) {
        final result = await Permission.storage.request();
        return result == PermissionStatus.granted;
      }
      return true;
    }
    return false;
  }

  Future<String?> getSavedDir() async {
    // Save to app-specific directory which doesn't need broad storage permission on newer Android
    // For downloads visible to user, getExternalStorageDirectory is usually fine for "Files" app access
    // or use getApplicationDocumentsDirectory
    
    if (Platform.isAndroid) {
       final dir = await getExternalStorageDirectory();
       return dir?.path;
    } else {
       final dir = await getApplicationDocumentsDirectory();
       return dir.path;
    }
  }

  Future<String?> downloadFile({
    required String url,
    required String fileName,
    String? referer,
  }) async {
    final hasPermission = await requestPermission();
    if (!hasPermission) return null;

    if (url.contains('.m3u8')) {
      return await _hlsService.startDownload(
        url: url, 
        fileName: fileName,
        referer: referer,
      );
    }

    final savedDir = await getSavedDir();
    if (savedDir == null) return null;

    final taskId = await FlutterDownloader.enqueue(
      url: url,
      savedDir: savedDir,
      fileName: fileName,
      showNotification: true,
      openFileFromNotification: true,
      saveInPublicStorage: false, 
    );
    
    return taskId;
  }
  
  Future<void> openFile(String taskId) async {
    await FlutterDownloader.open(taskId: taskId);
  }
  
  Future<void> cancel(String taskId) async {
    await FlutterDownloader.cancel(taskId: taskId);
  }
  
  Future<void> remove(String taskId) async {
    await FlutterDownloader.remove(taskId: taskId, shouldDeleteContent: true);
  }
  
  Future<List<DownloadTask>?> loadTasks() async {
    return await FlutterDownloader.loadTasks();
  }
}
