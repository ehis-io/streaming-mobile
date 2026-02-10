import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../models/stream_info.dart';


class WebViewPlayerScreen extends StatefulWidget {
  final StreamInfo stream;
  final VoidCallback onNextServer;
  final VoidCallback? onNextEpisode;
  final VoidCallback? onPrevEpisode;

  const WebViewPlayerScreen({
    super.key,
    required this.stream,
    required this.onNextServer,
    this.onNextEpisode,
    this.onPrevEpisode,
  });

  @override
  State<WebViewPlayerScreen> createState() => _WebViewPlayerScreenState();
}

class _WebViewPlayerScreenState extends State<WebViewPlayerScreen> {
  WebViewController? _controller;
  // Keep loading true until we either find a stream or timeout
  bool _isLoading = true;
  String _statusMessage = 'Initializing sniffer...';
  Timer? _fallbackTimer;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // Set a fallback timer to show the WebView if sniffing takes too long
    _fallbackTimer = Timer(const Duration(seconds: 60), () {
      if (mounted && _isLoading) {
        debugPrint('Sniffing timed out (60s). Revealing WebView for manual interaction.');
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Automatic playback failed. Please play manually.')),
        );
      }
    });

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF000000))
      ..setOnConsoleMessage((message) {
        debugPrint('WebView Console [${message.level}]: ${message.message}');
      })
      ..addJavaScriptChannel(
        'StreamSniffer',
        onMessageReceived: (JavaScriptMessage message) async {
          final msg = message.message;
          if (msg.startsWith('STATUS:')) {
            if (mounted) {
              setState(() {
                _statusMessage = msg.substring(7);
              });
            }
            return;
          }

          final url = msg;
          if (url.startsWith('http') && (url.contains('.mp4') || url.contains('.m3u8'))) {
            debugPrint('Sniffer found stream: $url');
            if (mounted) {
              setState(() {
                _statusMessage = 'Stream found! Readying player...';
              });
            }
            _fallbackTimer?.cancel();
            
            if (mounted) {
              // Resource Release Barrier: explicitly clean up BEFORE popping
              try {
                _controller?.loadRequest(Uri.parse('about:blank'));
              } catch (_) {}
              
              Navigator.pop(context, url);
            }
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            // Update loading bar.
          },
          onPageStarted: (String url) {
             if (mounted && _controller != null) {
                _injectSniffer();
             }
          },
          onPageFinished: (String url) {
             if (mounted && _controller != null) {
                _injectSniffer();
             }
          },
          onWebResourceError: (WebResourceError error) {
             debugPrint('WebView error: ${error.description}');
          },
          onNavigationRequest: (NavigationRequest request) {
            final url = request.url.toLowerCase();
            // PERMISSIVE FOR PLAYER DOMAINS
            if (url.contains('.m3u8') || url.contains('.mp4') || 
                url.contains('vidsrc') || url.contains('vidlink') || 
                url.contains('player') || url.contains('src')) {
              return NavigationDecision.navigate;
            }

            // Block known aggressive ad domains
            if (url.contains('ad-') || 
                url.contains('ads.') ||
                url.contains('pop') ||
                url.contains('click') ||
                url.contains('doubleclick') ||
                url.contains('google-analytics') ||
                url.contains('facebook') ||
                url.contains('twitter') ||
                url.contains('yandex') ||
                url.contains('prapal') ||
                url.contains('propush') ||
                url.contains('onclick') ||
                url.contains('hilltop') ||
                url.contains('creative')) {
              debugPrint('Blocked ad/tracker navigation: $url');
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..setUserAgent("Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36")
      ..loadRequest(
        Uri.parse(widget.stream.url),
        headers: widget.stream.headers ?? {},
      );

      // Clear cookies and cache periodically to save memory
      WebViewCookieManager().clearCookies();
      controller.clearCache();

      _controller = controller;
  }

  void _injectSniffer() {
    if (_controller == null) return;
    
    _controller!.runJavaScript(r'''
      (function() {
        function sendStatus(msg) {
          try { window.StreamSniffer.postMessage("STATUS:" + msg); } catch(e) {}
        }
        
        try {
          if (!window._snifferLoaded) {
            window.StreamSniffer.postMessage("LOADED:" + window.location.href);
            window._snifferLoaded = true;
          }
          
          if (window._snifferActive) return;
          window._snifferActive = true;
          
          console.log = function() {};
          console.warn = function() {};
          sendStatus("Sniffer Active");

          function checkUrl(url) {
            if (!url) return;
            var u = "";
            try {
              u = (typeof url === "string") ? url : (url.url || url.toString());
            } catch(e) { return; }
            
            if (u.indexOf(".m3u8") !== -1 || u.indexOf(".mp4") !== -1) {
              var clean = u.replace(/\\/g, "/").replace(/["']/g, "");
              if (clean.indexOf("http") === 0 || clean.indexOf("https") === 0) {
                sendStatus("Source Found: " + (clean.indexOf(".m3u8") !== -1 ? "HLS" : "MP4"));
                window.StreamSniffer.postMessage(clean);
              }
            }
          }

          // Interceptors
          var oOpen = XMLHttpRequest.prototype.open;
          XMLHttpRequest.prototype.open = function(method, url) {
            checkUrl(url);
            return oOpen.apply(this, arguments);
          };
          
          var oFetch = window.fetch;
          window.fetch = function(input, init) {
            var url = (typeof input === "string") ? input : (input ? input.url : "");
            checkUrl(url);
            return oFetch.apply(this, arguments);
          };

          // Burner
          var cCount = 0;
          var mClicks = 10;
          function burn() {
            if (cCount >= mClicks) return;
            sendStatus("Auto-play Step " + (cCount + 1));
            var sel = [".jw-display-icon-display", ".vjs-big-play-button", ".play-button", ".bigPlay", "video", ".jw-video", "#player_play", ".play-icon"];
            var hit = false;
            for (var i = 0; i < sel.length; i++) {
              var b = document.querySelector(sel[i]);
              if (b && (b.offsetWidth > 0 || b.offsetHeight > 0)) {
                b.click();
                hit = true;
                break;
              }
            }
            if (!hit) {
              var c = document.elementFromPoint(window.innerWidth/2, window.innerHeight/2);
              if (c && c.tagName !== "BODY") c.click();
            }
            cCount++;
            setTimeout(burn, 1200);
          }
          setTimeout(burn, 1500);

          // Observer
          var obs = new MutationObserver(function(muts) {
            for (var i = 0; i < muts.length; i++) {
              var added = muts[i].addedNodes;
              for (var j = 0; j < added.length; j++) {
                var n = added[j];
                if (n.nodeType === 1) {
                  if (n.tagName === "VIDEO" || n.tagName === "IFRAME") checkUrl(n.src);
                  var id = n.id || "";
                  var cls = n.className || "";
                  if (typeof cls !== "string") cls = "";
                  if (/ad|pop|overlay/i.test(id + cls)) n.remove();
                }
              }
            }
          });
          obs.observe(document.documentElement, { childList: true, subtree: true });

          // Periodic Scanner
          setInterval(function() {
            var scs = document.getElementsByTagName("script");
            for (var i = 0; i < scs.length; i++) {
              var content = scs[i].innerText || "";
              var match = content.match(/https?[:\/\\]+[^"']+\.m3u8[^"']*/g);
              if (match) {
                for (var j = 0; j < match.length; j++) checkUrl(match[j]);
              }
            }
            
            var ifrs = document.getElementsByTagName("iframe");
            for (var k = 0; k < ifrs.length; k++) {
              var f = ifrs[k];
              if (f.offsetWidth > 200 && f.src && f.src.indexOf("http") === 0 && window.location.href.indexOf(f.src) === -1) {
                 if (f.src.indexOf("vidsrc") !== -1 || f.src.indexOf("vidlink") !== -1 || f.src.indexOf("player") !== -1) {
                   sendStatus("Promoting Player Frame...");
                   window.location.href = f.src;
                 }
              }
            }
          }, 2000);

        } catch(e) {
          sendStatus("Sniffer Error: " + e.message);
        }
      })();
    ''');
  }

  @override
  void dispose() {
    _fallbackTimer?.cancel();
    // Load a blank page to stop any active scripts/rendering immediately
    try {
      _controller?.loadRequest(Uri.parse('about:blank'));
    } catch (_) {}
    
    _controller = null; // Explicitly nullify to help GC

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
          // Move WebView off-screen during loading to save buffers
          Positioned(
            left: _isLoading ? -2000 : 0,
            right: _isLoading ? 2000 : 0,
            top: 0,
            bottom: 0,
            child: _controller != null 
                ? WebViewWidget(controller: _controller!)
                : const Center(child: CircularProgressIndicator()),
          ),
          if (_isLoading)
            Container(
              color: Colors.black, 
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      _statusMessage,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
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

          // Close Button (Top Right)
          Positioned(
            top: 20,
            right: 20,
            child: SafeArea(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Close',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
