import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_text_styles.dart';

class RoomVideoPlayer extends StatefulWidget {
  final String? youtubeId;
  final bool isPlaying;
  final double timestampSec;
  final bool isHost;
  final void Function(String youtubeId) onLoad;
  final void Function(double timestamp, bool isPlaying) onSync;

  const RoomVideoPlayer({
    super.key,
    this.youtubeId,
    this.isPlaying = false,
    this.timestampSec = 0,
    this.isHost = false,
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
    if (widget.youtubeId != old.youtubeId && widget.youtubeId != null) {
      _yt?.dispose();
      _initPlayer(widget.youtubeId!);
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
    return Column(
      children: [
        if (_yt != null)
          YoutubePlayer(
            controller: _yt!,
            showVideoProgressIndicator: true,
            progressIndicatorColor: AppColors.cyan,
            onEnded: (_) {
              if (widget.isHost) widget.onSync(0, false);
            },
          )
        else
          _EmptyVideoSlot(showInput: false),
        if (widget.isHost)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _urlCtrl,
                    style: AppTextStyles.bodySmall,
                    decoration: const InputDecoration(
                      hintText: 'Paste YouTube URL...',
                      prefixIcon: Icon(Icons.link_rounded,
                          color: AppColors.grey, size: 18),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                    onSubmitted: (_) => _submitUrl(),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _submitUrl,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.send_rounded,
                        color: Colors.white, size: 16),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _EmptyVideoSlot extends StatelessWidget {
  final bool showInput;
  const _EmptyVideoSlot({required this.showInput});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: showInput ? 160 : 120,
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.play_circle_outline_rounded,
                size: 40, color: AppColors.grey.withOpacity(0.4)),
            const SizedBox(height: 8),
            Text(
              showInput ? 'Paste a YouTube URL above' : 'No video loaded',
              style: AppTextStyles.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
