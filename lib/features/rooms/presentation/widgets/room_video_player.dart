import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_text_styles.dart';

class RoomVideoPlayer extends StatefulWidget {
  final String? youtubeId;
  final bool isPlaying;
  final double timestampSec;
  final bool isHost;
  final bool showInput;
  final void Function(String youtubeId) onLoad;
  final void Function(double timestamp, bool isPlaying) onSync;

  const RoomVideoPlayer({
    super.key,
    this.youtubeId,
    this.isPlaying = false,
    this.timestampSec = 0,
    this.isHost = false,
    this.showInput = false,
    required this.onLoad,
    required this.onSync,
  });

  @override
  State<RoomVideoPlayer> createState() => _RoomVideoPlayerState();
}

class _RoomVideoPlayerState extends State<RoomVideoPlayer> {
  YoutubePlayerController? _yt;
  final _urlCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.youtubeId != null) _initPlayer(widget.youtubeId!);
  }

  @override
  void didUpdateWidget(RoomVideoPlayer old) {
    super.didUpdateWidget(old);
    if (widget.youtubeId != old.youtubeId) {
      _yt?.dispose();
      _yt = null;
      if (widget.youtubeId != null) {
        _initPlayer(widget.youtubeId!);
      } else {
        if (mounted) setState(() {});
      }
    } else if (_yt != null && widget.isPlaying != old.isPlaying) {
      widget.isPlaying ? _yt!.play() : _yt!.pause();
    }
  }

  void _initPlayer(String id) {
    _yt = YoutubePlayerController(
      initialVideoId: id,
      flags: YoutubePlayerFlags(
        autoPlay: widget.isPlaying,
        startAt: widget.timestampSec.toInt(),
        mute: false,
        useHybridComposition: true,
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _yt?.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  void _submitUrl() {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) return;
    final id = YoutubePlayer.convertUrlToId(url) ?? url;
    widget.onLoad(id);
    _urlCtrl.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: Column(
        children: [
          if (_yt != null)
            YoutubePlayer(
              controller: _yt!,
              showVideoProgressIndicator: true,
              progressIndicatorColor: AppColors.cyan,
              progressColors: const ProgressBarColors(
                playedColor: AppColors.cyan,
                handleColor: AppColors.purple,
                bufferedColor: Color(0xFF2D2060),
                backgroundColor: Color(0xFF1A1040),
              ),
              onEnded: (_) {
                if (widget.isHost) widget.onSync(0, false);
              },
            )
          else if (!widget.showInput)
            _EmptyVideoState(isHost: widget.isHost),

          // URL input shown when host taps video button
          if (widget.showInput)
            _VideoUrlInput(
              ctrl: _urlCtrl,
              onSubmit: _submitUrl,
            ),
        ],
      ),
    );
  }
}

class _EmptyVideoState extends StatelessWidget {
  final bool isHost;
  const _EmptyVideoState({required this.isHost});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.cardBg,
            AppColors.darkBg.withValues(alpha: 0.8),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.play_circle_outline_rounded,
                color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('No video playing',
                  style: AppTextStyles.bodyMedium),
              const SizedBox(height: 2),
              Text(
                isHost ? 'Tap the video icon above to load one' : 'Waiting for host to load a video',
                style: AppTextStyles.labelSmall
                    .copyWith(color: AppColors.grey.withValues(alpha: 0.7)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VideoUrlInput extends StatelessWidget {
  final TextEditingController ctrl;
  final VoidCallback onSubmit;

  const _VideoUrlInput({required this.ctrl, required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: AppColors.cardBg,
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.darkBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.fieldBorder),
              ),
              child: TextField(
                controller: ctrl,
                autofocus: true,
                style: AppTextStyles.bodySmall,
                decoration: InputDecoration(
                  hintText: 'Paste YouTube URL...',
                  hintStyle: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.grey.withValues(alpha: 0.5)),
                  prefixIcon: const Icon(Icons.link_rounded,
                      color: AppColors.grey, size: 18),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 12),
                ),
                onSubmitted: (_) => onSubmit(),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onSubmit,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                gradient: AppColors.primaryGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_arrow_rounded,
                  color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
