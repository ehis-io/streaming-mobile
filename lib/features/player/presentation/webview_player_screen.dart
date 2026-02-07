import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../models/stream_info.dart';


class WebViewPlayerScreen extends StatefulWidget {
  final StreamInfo stream;
  final Function(String) onStreamExtracted;
  final VoidCallback onNextServer;
  final VoidCallback? onNextEpisode;
  final VoidCallback? onPrevEpisode;

  const WebViewPlayerScreen({
    super.key,
    required this.stream,
    required this.onStreamExtracted,
    required this.onNextServer,
    this.onNextEpisode,
    this.onPrevEpisode,
  });

  @override
  State<WebViewPlayerScreen> createState() => _WebViewPlayerScreenState();
}

class _WebViewPlayerScreenState extends State<WebViewPlayerScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF000000))
      ..addJavaScriptChannel(
        'StreamSniffer',
        onMessageReceived: (JavaScriptMessage message) {
          final url = message.message;
          if (url.startsWith('http') && (url.contains('.mp4') || url.contains('.m3u8'))) {
            debugPrint('Sniffer found stream: $url');
            widget.onStreamExtracted(url);
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            // Update loading bar.
          },
          onPageStarted: (String url) {},
          onPageFinished: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
              
              // Inject Sniffer Script
              _controller.runJavaScript('''
                (function() {
                  console.log("Sniffer Active");
                  
                  function checkUrl(url) {
                    if (url && (url.includes(".m3u8") || url.includes(".mp4"))) {
                      StreamSniffer.postMessage(url);
                    }
                  }

                  // Intercept XHR
                  var originalOpen = XMLHttpRequest.prototype.open;
                  XMLHttpRequest.prototype.open = function(method, url) {
                    checkUrl(url);
                    return originalOpen.apply(this, arguments);
                  };
                  
                  // Intercept Fetch
                  var originalFetch = window.fetch;
                  window.fetch = function(input, init) {
                    var url = (typeof input === "string") ? input : input.url;
                    checkUrl(url);
                    return originalFetch.apply(this, arguments);
                  };

                  // Scan DOM for video tags
                  setInterval(function() {
                    var videos = document.getElementsByTagName("video");
                    for (var i = 0; i < videos.length; i++) {
                      checkUrl(videos[i].src);
                      checkUrl(videos[i].currentSrc);
                    }
                    
                    // Scan iframes
                    var iframes = document.getElementsByTagName("iframe");
                    for (var i = 0; i < iframes.length; i++) {
                       checkUrl(iframes[i].src);
                    }
                  }, 1000);
                  
                  // Hide Ads via CSS
                  var style = document.createElement('style');
                  style.innerHTML = `
                    div[id*="ad"], div[class*="ad-"], div[class*="popup"], 
                    .jw-display-icon-container { display: none !important; }
                  `;
                  document.head.appendChild(style);
                })();
              ''');
            }
          },
          onWebResourceError: (WebResourceError error) {
             debugPrint('WebView error: ${error.description}');
          },
          onNavigationRequest: (NavigationRequest request) {
            final url = request.url.toLowerCase();
            // Basic Ad Block List
            if (url.contains('ad') || 
                url.contains('pop') || 
                url.contains('click') || 
                url.contains('tracker') || 
                url.contains('doubleclick') ||
                url.startsWith('https://shopee') ||
                url.startsWith('https://lazada')) {
               debugPrint('Blocking Ad: $url'); 
               return NavigationDecision.prevent;
            }
            
            // Allow if it matches current stream host or is main frame (with caution)
            // Ideally we only want strict navigation for the video player
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(
        Uri.parse(widget.stream.url),
        headers: widget.stream.headers ?? {},
      );
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          SafeArea(
            child: WebViewWidget(controller: _controller),
          ),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: Colors.red),
            ),

          
          // Series Navigation (Top Center)
          if (widget.onNextEpisode != null || widget.onPrevEpisode != null)
            Positioned(
              top: 20,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.onPrevEpisode != null)
                      Container(
                        margin: const EdgeInsets.only(right: 16),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.skip_previous, color: Colors.white),
                          onPressed: widget.onPrevEpisode,
                          tooltip: 'Previous Episode',
                        ),
                      ),
                    if (widget.onNextEpisode != null)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.skip_next, color: Colors.white),
                          onPressed: widget.onNextEpisode,
                          tooltip: 'Next Episode',
                         ),
                      ),
                  ],
                ),
              ),
            ),

          // Next Server Button (Top Left) - Moved from bottom right to avoid covering controls
          Positioned(
            top: 20,
            left: 20,
            child: SafeArea(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: IconButton(
                  icon: const Icon(Icons.autorenew, color: Colors.white),
                  onPressed: widget.onNextServer,
                  tooltip: 'Next Server',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
