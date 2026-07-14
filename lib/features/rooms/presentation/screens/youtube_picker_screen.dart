import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../../core/utils/debug_logger.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_text_styles.dart';

class YoutubePickerScreen extends StatefulWidget {
  /// Only a room that already exists can queue a video up next. When the picker
  /// is opened from home to start a new room, there is nothing to queue onto,
  /// so PIN NEXT is hidden.
  final bool allowQueue;

  const YoutubePickerScreen({super.key, this.allowQueue = false});

  @override
  State<YoutubePickerScreen> createState() => _YoutubePickerScreenState();
}

class _YoutubePickerScreenState extends State<YoutubePickerScreen> {
  late final WebViewController _ctrl;
  String? _currentVideoId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _ctrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _loading = true),
          onPageFinished: (_) => setState(() => _loading = false),
          onUrlChange: (change) {
            final url = change.url;
            if (url != null) {
              _extractVideoId(url);
            }
          },
        ),
      )
      ..loadRequest(Uri.parse('https://m.youtube.com'));
  }

  /// The webview title is "<video title> - YouTube"; strip the suffix so the
  /// room gets a usable name.
  Future<String> _videoTitle() async {
    try {
      final raw = await _ctrl.getTitle();
      final cleaned = (raw ?? '')
          .replaceAll(RegExp(r'\s*-\s*YouTube\s*$'), '')
          .trim();
      return cleaned.isEmpty ? 'Watch Party' : cleaned;
    } catch (e) {
      DebugLogger.error('getTitle failed', error: e);
      return 'Watch Party';
    }
  }

  Future<void> _pick(String action) async {
    final title = await _videoTitle();
    if (!mounted) return;
    Navigator.pop(context, {
      'id': _currentVideoId,
      'action': action,
      'title': title,
    });
  }

  void _extractVideoId(String url) {
    String? id;
    if (url.contains('v=')) {
      id = url.split('v=')[1].split('&')[0];
    } else if (url.contains('shorts/')) {
      id = url.split('shorts/')[1].split('?')[0];
    }

    if (id != _currentVideoId) {
      setState(() => _currentVideoId = id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('YouTube Search', style: AppTextStyles.heading3),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(right: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _ctrl),
          if (_currentVideoId != null)
            Positioned(
              bottom: 30,
              left: 20,
              right: 20,
              child: Container(
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.purple.withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _pick('play'),
                          borderRadius: widget.allowQueue
                              ? const BorderRadius.horizontal(
                                  left: Radius.circular(30))
                              : BorderRadius.circular(30),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: const Center(
                              child: Text(
                                'PLAY NOW',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (widget.allowQueue) ...[
                      Container(width: 1, height: 30, color: Colors.white24),
                      Expanded(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _pick('pin'),
                            borderRadius: const BorderRadius.horizontal(
                                right: Radius.circular(30)),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: const Center(
                                child: Text(
                                  'PIN NEXT',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
