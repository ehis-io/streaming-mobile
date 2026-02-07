import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../../models/media.dart';
import '../../../models/stream_info.dart';
import '../../../core/network/api_client.dart';
import '../../../core/ads/clickadu_ad_manager.dart';
import '../../../core/services/download_service.dart';
import 'webview_player_screen.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  final List<StreamInfo> streams;
  final int initialIndex;
  
  // New fields for Series Navigation
  final Media? media;
  final int? season;
  final int? episode;

  const PlayerScreen({
    super.key,
    required this.streams,
    this.initialIndex = 0,
    this.media,
    this.season,
    this.episode,
  });

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  
  // State for playlist management
  int _currentIndex = 0;
  List<StreamInfo> _currentStreams = [];
  StreamInfo? _extractedStream; // Stores the resolved direct link from a sniffer
  bool _isError = false;
  String _errorMessage = '';
  bool _isSwitching = false;

  // Series State
  int? _currentSeason;
  int? _currentEpisode;
  bool _isLoadingEpisode = false;

  // Ad State
  bool _showAd = true;
  ClickaduAdManager? _adManager;

  StreamInfo get currentStream => _extractedStream ?? _currentStreams[_currentIndex];

  bool get isSeries => widget.media?.mediaType == MediaType.tv || (widget.season != null && widget.episode != null);

  @override
  void initState() {
    super.initState();
    // Keep screen on
    WakelockPlus.enable();
    
    _currentIndex = widget.initialIndex;
    _currentStreams = widget.streams;
    _currentSeason = widget.season;
    _currentEpisode = widget.episode;

    _initializePreRollAd();
  }

  void _initializePreRollAd() {
    _showAd = false; // Disable ads for now
    
    // Skip ad manager initialization and start content directly
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) initializePlayer();
    });
  }

  void _startContentPlayback() {
    if (!mounted) return;
    setState(() {
      _showAd = false;
      _adManager?.dispose();
      _adManager = null;
    });

    if (_currentIndex < _currentStreams.length) {
      // Small delay to ensure clean UI transition
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) initializePlayer();
      });
    }
  }

  Future<void> _disposeControllers() async {
    if (_chewieController != null) {
      _chewieController!.dispose();
      _chewieController = null;
    }
    if (_videoPlayerController != null) {
      await _videoPlayerController!.dispose();
      _videoPlayerController = null;
    }
    // Give the OS time to reclaim the graphics buffer
    await Future.delayed(const Duration(milliseconds: 500));
  }

  Future<void> initializePlayer() async {
    if (_isSwitching) return;
    
    // key fix: Dispose previous controllers to free up graphics buffers
    await _disposeControllers();
    
    try {
      setState(() {
        _isError = false;
        _errorMessage = '';
        _isSwitching = true;
      });

      debugPrint('Initializing player for stream index: $_currentIndex, url: ${currentStream.url}');

      if (currentStream.isEmbed) {
        setState(() {
          _isSwitching = false;
        });
        return;
      }

      final controller = VideoPlayerController.networkUrl(
        Uri.parse(currentStream.url),
        httpHeaders: currentStream.headers ?? {},
      );

      _videoPlayerController = controller;
      await controller.initialize();

      _chewieController = ChewieController(
        videoPlayerController: controller,
        autoPlay: true,
        looping: false,
        aspectRatio: controller.value.aspectRatio,
        deviceOrientationsAfterFullScreen: [
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ],
        fullScreenByDefault: true,
        allowFullScreen: true,
        allowPlaybackSpeedChanging: true,
        playbackSpeeds: [0.5, 0.75, 1.0, 1.25, 1.5, 2.0],
        materialProgressColors: ChewieProgressColors(
          playedColor: Colors.red,
          handleColor: Colors.red,
          backgroundColor: Colors.grey.withOpacity(0.5),
          bufferedColor: Colors.white.withOpacity(0.5),
        ),
        placeholder: const Center(child: CircularProgressIndicator()),
        errorBuilder: (context, errorMessage) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _tryNextStream('Playback error: $errorMessage');
          });
          return const Center(child: CircularProgressIndicator(color: Colors.red));
        },
        overlay: _buildNavigationOverlay(), // Add navigation overlay to native player
      );
      
      setState(() {
        _isSwitching = false;
      });
    } catch (e) {
      debugPrint('Error initializing player: $e');
      _tryNextStream(e.toString());
    }
  }

  Future<void> _loadEpisode(int season, int episode) async {
    if (widget.media == null || _isLoadingEpisode) return;

    setState(() {
      _isLoadingEpisode = true;
      _isSwitching = true;
      _extractedStream = null;
    });

    // Cleanup current player
    await _disposeControllers();

    try {
      debugPrint('Fetching streams for S${season}E${episode}...');
      final client = ref.read(apiClientProvider);
      final newStreams = await client.getStreams(
        widget.media!.id.toString(),
        mediaType: 'tv',
        season: season,
        episode: episode,
      );

      if (newStreams.isEmpty) {
        throw Exception('No streams found for S${season}E${episode}');
      }

      if (!mounted) return;

      setState(() {
        _currentSeason = season;
        _currentEpisode = episode;
        _currentStreams = newStreams;
        _currentIndex = 0; // Reset to first stream of new episode
        _isLoadingEpisode = false;
        // _isSwitching will be handled by initializePlayer
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Playing Season $season, Episode $episode')),
      );

      initializePlayer();

    } catch (e) {
      debugPrint('Failed to load episode: $e');
      if (mounted) {
        setState(() {
          _isLoadingEpisode = false;
          _isSwitching = false; // Reset switching state
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load Episode $episode: $e')),
        );
        // We could revert counters here if we wanted, but we haven't updated them in UI yet unless successful
      }
    }
  }

  void _onNextEpisode() {
    if (_currentSeason != null && _currentEpisode != null) {
      _loadEpisode(_currentSeason!, _currentEpisode! + 1);
    }
  }

  void _onPrevEpisode() {
    if (_currentSeason != null && _currentEpisode != null && _currentEpisode! > 1) {
      _loadEpisode(_currentSeason!, _currentEpisode! - 1);
    }
  }

  Future<void> _downloadCurrentVideo() async {
    final stream = currentStream;
    if (stream.isEmbed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot download embedded streams')),
      );
      return;
    }
    
    // Construct filename
    String filename = widget.media?.displayTitle ?? 'video';
    if (isSeries && _currentSeason != null && _currentEpisode != null) {
      filename += '_S${_currentSeason}E${_currentEpisode}';
    }
    // Sanitize filename
    filename = filename.replaceAll(RegExp(r'[^\w\s\.-]'), '').replaceAll(' ', '_');
    if (!filename.endsWith('.mp4') && !filename.endsWith('.m3u8')) {
        filename += stream.isM3U8 == true ? '.m3u8' : '.mp4';
    }
    
    final downloadService = ref.read(downloadServiceProvider);
    final taskId = await downloadService.downloadFile(
      url: stream.url,
      fileName: filename,
    );
    
    if (mounted) {
      if (taskId != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Download started')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('Download failed or permission denied')),
        );
      }
    }
  }

  // Overlay for Native Player
  Widget _buildNavigationOverlay() {
    if (!isSeries) return const SizedBox.shrink();

    return SafeArea(
      child: Stack(
        children: [
          // Top Center Controls
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                   if (_currentEpisode != null && _currentEpisode! > 1)
                    IconButton(
                      icon: const Icon(Icons.skip_previous, color: Colors.white, size: 32),
                      onPressed: _onPrevEpisode,
                      tooltip: 'Previous Episode',
                    ),
                  const SizedBox(width: 32),
                  if (_currentEpisode != null)
                     IconButton(
                      icon: const Icon(Icons.skip_next, color: Colors.white, size: 32),
                      onPressed: _onNextEpisode,
                      tooltip: 'Next Episode',
                    ),
                    const SizedBox(width: 32),
                    IconButton(
                      icon: const Icon(Icons.download, color: Colors.white, size: 32),
                      onPressed: _downloadCurrentVideo,
                      tooltip: 'Download',
                    ),
                ],
              ),
            ),
          ),
          if (_isLoadingEpisode)
            const Center(
              child: CircularProgressIndicator(color: Colors.red),
            ),
        ],
      ),
    );
  }

  void _tryNextStream(String reason) {
    debugPrint('Stream failed ($reason). Trying next...');
    
    if (_extractedStream != null) {
      _extractedStream = null;
    }
    
    if (_currentIndex < _currentStreams.length - 1) {
      setState(() {
        _currentIndex++;
        _extractedStream = null;
        _isError = false;
        _isSwitching = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Stream failed. Trying server ${_currentIndex + 1}...'),
          duration: const Duration(seconds: 2),
        ),
      );
      
      initializePlayer();
    } else {
      setState(() {
        _isError = true;
        _errorMessage = 'No working streams found.';
        _isSwitching = false;
      });
    }
  }
  
  void _onStreamExtracted(String url) {
    debugPrint('Extracted new URL: $url');
    setState(() {
      _extractedStream = StreamInfo(
        provider: 'Extracted',
        quality: 'Auto',
        url: url,
        isM3U8: url.contains('.m3u8'),
      );
    });
    initializePlayer();
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _adManager?.dispose(); // Dispose Ad Manager
    _disposeControllers();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // While Ad is active (browser open), show black screen with loader
    if (_showAd) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.red),
              SizedBox(height: 16),
              Text('Loading Content...', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      );
    }

    if (currentStream.isEmbed) {
      return WebViewPlayerScreen(
        stream: currentStream,
        onStreamExtracted: _onStreamExtracted,
        onNextServer: () => _tryNextStream('Manual skip'),
        onNextEpisode: isSeries ? _onNextEpisode : null,
        onPrevEpisode: (isSeries && _currentEpisode != null && _currentEpisode! > 1) ? _onPrevEpisode : null,
      );
    }

    if (_isError) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              const Text(
                'All streams failed',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                   setState(() {
                     _currentIndex = 0;
                     _extractedStream = null;
                   });
                   initializePlayer();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
             _chewieController != null && _videoPlayerController != null && _videoPlayerController!.value.isInitialized
            ? Chewie(controller: _chewieController!)
            : Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      _isLoadingEpisode 
                        ? 'Loading Episode $_currentEpisode...' 
                        : 'Loading Stream ${_currentIndex + 1}...', 
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
             // Overlay for Loading Episode if triggered NOT from Chewie (e.g. initial load)
             if (_isLoadingEpisode && _chewieController == null)
                Container(
                  color: Colors.black.withOpacity(0.7),
                  child: const Center(child: CircularProgressIndicator(color: Colors.red)),
                ),
          ],
        ),
      ),
    );
  }
}
