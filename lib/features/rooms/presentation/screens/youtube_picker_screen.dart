import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../cubits/room_list_cubit.dart';

class YoutubePickerScreen extends StatefulWidget {
  const YoutubePickerScreen({super.key});

  @override
  State<YoutubePickerScreen> createState() => _YoutubePickerScreenState();
}

class _YoutubePickerScreenState extends State<YoutubePickerScreen> {
  late final WebViewController _controller;
  String? _detectedVideoId;
  String? _videoTitle;
  bool _isCreatingRoom = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      // Mobile Chrome UA — YouTube shows mobile web, won't try to open the app
      ..setUserAgent(
          'Mozilla/5.0 (Linux; Android 12; Pixel 6) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36')
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          if (mounted) setState(() => _isLoading = true);
        },
        onPageFinished: (url) {
          if (mounted) setState(() => _isLoading = false);
          _handleUrl(url);
        },
        onUrlChange: (change) {
          if (change.url != null) _handleUrl(change.url!);
        },
        onNavigationRequest: (req) {
          // Block YouTube app deep links
          final url = req.url;
          if (url.startsWith('intent://') ||
              url.startsWith('vnd.youtube') ||
              url.startsWith('youtube://')) {
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ))
      ..loadRequest(Uri.parse('https://m.youtube.com'));
  }

  void _handleUrl(String url) {
    final id = _extractVideoId(url);
    if (id == _detectedVideoId) return;
    setState(() {
      _detectedVideoId = id;
      _videoTitle = null;
    });
    if (id != null) _fetchTitle();
  }

  String? _extractVideoId(String url) {
    try {
      final uri = Uri.parse(url);
      // Standard: /watch?v=ID
      final v = uri.queryParameters['v'];
      if (v != null && v.isNotEmpty) return v;
      // Shorts: /shorts/ID
      if (uri.pathSegments.length >= 2 &&
          uri.pathSegments[0] == 'shorts') {
        return uri.pathSegments[1];
      }
      // Short link: youtu.be/ID
      if (uri.host == 'youtu.be' && uri.pathSegments.isNotEmpty) {
        return uri.pathSegments[0];
      }
    } catch (_) {}
    return null;
  }

  Future<void> _fetchTitle() async {
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted || _detectedVideoId == null) return;
    try {
      final raw = await _controller.runJavaScriptReturningResult(
          'document.title');
      if (!mounted) return;
      final title = raw
          .toString()
          .replaceAll('"', '')
          .replaceAll(' - YouTube', '')
          .trim();
      setState(() => _videoTitle = title.isNotEmpty ? title : 'Watch Party');
    } catch (_) {
      if (mounted) setState(() => _videoTitle = 'Watch Party');
    }
  }

  Future<void> _createRoom() async {
    if (_detectedVideoId == null || _isCreatingRoom) return;
    setState(() => _isCreatingRoom = true);
    try {
      final room = await context.read<RoomListCubit>().createRoom(
            name: _videoTitle ?? 'Watch Party',
            youtubeId: _detectedVideoId!,
          );
      if (mounted) context.go('/room/${room.id}');
    } catch (e) {
      if (mounted) {
        setState(() => _isCreatingRoom = false);
        AppSnackbar.error(context, e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: Column(
        children: [
          // Custom header
          Container(
            padding: EdgeInsets.fromLTRB(4, top + 4, 16, 8),
            decoration: BoxDecoration(
              color: AppColors.darkBg,
              border: const Border(
                  bottom: BorderSide(color: AppColors.divider)),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_rounded,
                      color: AppColors.white, size: 20),
                  onPressed: () => context.pop(),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Find a Video',
                          style: AppTextStyles.heading3),
                      Text(
                        'Search, tap a video, then hit Play in Mehfil',
                        style: AppTextStyles.labelSmall
                            .copyWith(color: AppColors.grey),
                      ),
                    ],
                  ),
                ),
                if (_isLoading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: AppColors.cyan,
                      strokeWidth: 2,
                    ),
                  ),
              ],
            ),
          ),
          // WebView
          Expanded(
            child: Stack(
              children: [
                WebViewWidget(controller: _controller),
                // Play in Mehfil banner
                if (_detectedVideoId != null)
                  _PlayBanner(
                    videoTitle: _videoTitle,
                    isLoading: _isCreatingRoom,
                    onTap: _createRoom,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Play in Mehfil Banner ─────────────────────────────────────────────────

class _PlayBanner extends StatefulWidget {
  final String? videoTitle;
  final bool isLoading;
  final VoidCallback onTap;

  const _PlayBanner({
    this.videoTitle,
    required this.isLoading,
    required this.onTap,
  });

  @override
  State<_PlayBanner> createState() => _PlayBannerState();
}

class _PlayBannerState extends State<_PlayBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    )..forward();
    _slide = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: Container(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 14 + bottom),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.cardBg,
                  AppColors.darkBg.withValues(alpha: 0.95),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              border: const Border(
                  top: BorderSide(color: AppColors.divider)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Row(
              children: [
                // YouTube icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF0000).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: const Color(0xFFFF0000).withValues(alpha: 0.3)),
                  ),
                  child: const Icon(
                    Icons.play_circle_filled_rounded,
                    color: Color(0xFFFF0000),
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                // Video info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Video detected',
                        style: AppTextStyles.labelSmall
                            .copyWith(color: AppColors.cyan, fontSize: 11),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.videoTitle ?? 'Loading title...',
                        style: AppTextStyles.bodySmall
                            .copyWith(fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Play button
                GestureDetector(
                  onTap: widget.isLoading ? null : widget.onTap,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 11),
                    decoration: BoxDecoration(
                      gradient: widget.isLoading
                          ? null
                          : AppColors.primaryGradient,
                      color: widget.isLoading
                          ? AppColors.fieldBorder
                          : null,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: widget.isLoading
                          ? null
                          : [
                              BoxShadow(
                                color: AppColors.purple.withValues(alpha: 0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                    ),
                    child: widget.isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: AppColors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.headphones_rounded,
                                  color: Colors.white, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                'Play in Mehfil',
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
