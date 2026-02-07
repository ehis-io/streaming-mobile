
import 'dart:isolate';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/download_service.dart';

class DownloadsScreen extends ConsumerStatefulWidget {
  const DownloadsScreen({super.key});

  @override
  ConsumerState<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends ConsumerState<DownloadsScreen> {
  List<DownloadTask> _tasks = [];
  late ReceivePort _port;

  @override
  void initState() {
    super.initState();
    _bindBackgroundIsolate();
    FlutterDownloader.registerCallback(DownloadService.downloadCallback);
    _loadTasks();
  }

  @override
  void dispose() {
    _unbindBackgroundIsolate();
    super.dispose();
  }

  void _bindBackgroundIsolate() {
    _port = ReceivePort();
    final bool isSuccess = IsolateNameServer.registerPortWithName(
      _port.sendPort,
      'downloader_send_port',
    );
    if (!isSuccess) {
      _unbindBackgroundIsolate();
      _bindBackgroundIsolate();
      return;
    }
    _port.listen((dynamic data) {
      final String id = data[0];
      final DownloadTaskStatus status = DownloadTaskStatus.fromInt(data[1]);
      final int progress = data[2];
      
      // Update UI efficiently
      final taskIndex = _tasks.indexWhere((task) => task.taskId == id);
      if (taskIndex != -1) {
        setState(() {
          // We can't modify the DownloadTask object directly as it has final fields,
          // so we re-fetch tasks or update local state if we had a view model.
          // For simplicity, reloading tasks or forcing rebuild.
          // Better approach: fetch tasks again or update a local mutable List wrapper.
        });
        // Optimisation: Just reloading logic for simpler implementation for now.
        _loadTasks(); 
      }
    });
  }

  void _unbindBackgroundIsolate() {
    IsolateNameServer.removePortNameMapping('downloader_send_port');
  }

  Future<void> _loadTasks() async {
    final tasks = await FlutterDownloader.loadTasks();
    if (mounted) {
      setState(() {
        _tasks = tasks ?? [];
      });
    }
  }

  // Action handlers
  Future<void> _pauseDownload(String taskId) async {
    await FlutterDownloader.pause(taskId: taskId);
    _loadTasks();
  }

  Future<void> _resumeDownload(String taskId) async {
    await FlutterDownloader.resume(taskId: taskId);
    _loadTasks();
  }

  Future<void> _retryDownload(String taskId) async {
    await FlutterDownloader.retry(taskId: taskId);
    _loadTasks();
  }
  
  Future<void> _openDownload(String taskId) async {
    await FlutterDownloader.open(taskId: taskId);
  }

  Future<void> _deleteDownload(String taskId) async {
    await FlutterDownloader.remove(taskId: taskId, shouldDeleteContent: true);
    _loadTasks();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Downloads', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _tasks.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.download_done, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No downloads yet', style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : ListView.builder(
              itemCount: _tasks.length,
              itemBuilder: (context, index) {
                final task = _tasks[index];
                return _buildTaskItem(task);
              },
            ),
    );
  }

  Widget _buildTaskItem(DownloadTask task) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey[900],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    task.filename ?? 'Unknown File',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _buildActionButtons(task),
              ],
            ),
            const SizedBox(height: 8),
            if (task.status == DownloadTaskStatus.running || task.status == DownloadTaskStatus.paused)
              LinearProgressIndicator(
                value: task.progress / 100,
                backgroundColor: Colors.grey[800],
                valueColor: AlwaysStoppedAnimation(
                  task.status == DownloadTaskStatus.paused ? Colors.amber : Colors.red,
                ),
              ),
            const SizedBox(height: 4),
             Row(
               mainAxisAlignment: MainAxisAlignment.spaceBetween,
               children: [
                 Text(
                   _getStatusString(task.status),
                   style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                 ),
                 Text(
                   '${task.progress}%',
                   style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                 ),
               ],
             ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(DownloadTask task) {
    if (task.status == DownloadTaskStatus.undefined) {
      return const SizedBox.shrink();
    }
    
    if (task.status == DownloadTaskStatus.running) {
       return IconButton(
         icon: const Icon(Icons.pause, color: Colors.amber),
         onPressed: () => _pauseDownload(task.taskId),
       );
    } 
    
    if (task.status == DownloadTaskStatus.paused) {
      return IconButton(
        icon: const Icon(Icons.play_arrow, color: Colors.green),
        onPressed: () => _resumeDownload(task.taskId),
      );
    }
    
    if (task.status == DownloadTaskStatus.complete) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
           IconButton(
            icon: const Icon(Icons.play_circle_outline, color: Colors.red),
            onPressed: () => _openDownload(task.taskId),
           ),
           IconButton(
             icon: const Icon(Icons.delete, color: Colors.grey),
             onPressed: () => _deleteDownload(task.taskId),
           ),
        ],
      );
    }
    
    if (task.status == DownloadTaskStatus.failed || task.status == DownloadTaskStatus.canceled) {
       return Row(
         mainAxisSize: MainAxisSize.min,
         children: [
           IconButton(
             icon: const Icon(Icons.refresh, color: Colors.red),
             onPressed: () => _retryDownload(task.taskId),
           ),
            IconButton(
             icon: const Icon(Icons.delete, color: Colors.grey),
             onPressed: () => _deleteDownload(task.taskId),
           ),
         ],
       );
    }

    return const SizedBox.shrink();
  }

  String _getStatusString(DownloadTaskStatus status) {
    switch (status) {
      case DownloadTaskStatus.running: return 'Downloading...';
      case DownloadTaskStatus.paused: return 'Paused';
      case DownloadTaskStatus.complete: return 'Completed';
      case DownloadTaskStatus.failed: return 'Failed';
      case DownloadTaskStatus.canceled: return 'Canceled';
      default: return 'Pending';
    }
  }
}
