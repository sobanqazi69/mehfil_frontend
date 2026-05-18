import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_text_styles.dart';

class RoomVideoPlayer extends StatefulWidget {
  final String? youtubeId;
  final String? nextYoutubeId;
  final bool isPlaying;
  final double timestampSec;
  final bool isHost;
  final void Function(String youtubeId) onLoad;
  final void Function(String youtubeId) onQueue;
  final void Function(double timestamp, bool isPlaying) onSync;

  const RoomVideoPlayer({
    super.key,
    this.youtubeId,
    this.nextYoutubeId,
    this.isPlaying = false,
    this.timestampSec = 0,
    this.isHost = false,
    required this.onLoad,
    required this.onQueue,
    required this.onSync,
  });

  @override
  State<RoomVideoPlayer> createState() => _RoomVideoPlayerState();
}

class _RoomVideoPlayerState extends State<RoomVideoPlayer> {
  YoutubePlayerController? _yt;
  final _urlCtrl = TextEditingController();

  // Local state to track host playback to avoid excessive sync events
  double _lastSyncTimestamp = 0;
  bool _lastSyncIsPlaying = false;
  DateTime? _lastSyncRealTime;
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    if (widget.youtubeId != null) _initPlayer(widget.youtubeId!);
  }

  @override
  void didUpdateWidget(RoomVideoPlayer old) {
    super.didUpdateWidget(old);

    if (widget.youtubeId != old.youtubeId) {
      if (widget.youtubeId == null) {
        _yt?.removeListener(_onPlayerStateChange);
        _yt?.dispose();
        _yt = null;
        if (mounted) setState(() {});
      } else {
        if (_yt == null) {
          _initPlayer(widget.youtubeId!);
        } else {
          _yt!.load(widget.youtubeId!);
        }
        _showSuggestions = false;
      }
      return;
    }

    if (_yt == null) return;

    // Listeners synchronization
    if (!widget.isHost) {
      // Sync play/pause
      if (widget.isPlaying != old.isPlaying) {
        if (widget.isPlaying) {
          _yt?.play();
        } else {
          _yt?.pause();
        }
      }

      // Sync position if it drifts by more than 3 seconds (Rave-style threshold)
      final currentPos = _yt?.value.position.inSeconds.toDouble() ?? 0;
      if ((widget.timestampSec - currentPos).abs() > 3) {
        _yt?.seekTo(Duration(seconds: widget.timestampSec.toInt()));
      }
    } else {
      final playerIsPlaying = _yt?.value.isPlaying ?? false;
      if (widget.isPlaying != old.isPlaying && widget.isPlaying != playerIsPlaying) {
        widget.isPlaying ? _yt?.play() : _yt?.pause();
      }
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
        hideControls: !widget.isHost, // Only host can see controls
      ),
    );

    if (widget.isHost) {
      _yt!.addListener(_onPlayerStateChange);
    }

    if (mounted) setState(() {});
  }

  void _onPlayerStateChange() {
    if (_yt == null || !widget.isHost) return;

    final state = _yt!.value;
    final isPlaying = state.isPlaying;
    final position = state.position.inSeconds.toDouble();

    // Prevent excessive sync events. Sync if:
    // 1. Playing state changed (INSTANT)
    // 2. Position changed significantly (e.g. a seek) (INSTANT)
    // 3. Periodic sync to keep everyone aligned (THROTTLED to 10s)
    bool shouldSync = false;
    final now = DateTime.now();

    if (isPlaying != _lastSyncIsPlaying) {
      shouldSync = true;
    } else if ((position - _lastSyncTimestamp).abs() > 2) {
      // If the difference is > 2s, it's likely a SEEK (Instant sync)
      // or we haven't synced in a while.
      
      // Throttle periodic syncs to every 10 seconds to save resources
      final timeSinceLastSync = _lastSyncRealTime != null 
          ? now.difference(_lastSyncRealTime!).inSeconds 
          : 999;

      if (timeSinceLastSync >= 10 || (position - _lastSyncTimestamp).abs() > 5) {
        shouldSync = true;
      }
    }

    if (shouldSync) {
      _lastSyncTimestamp = position;
      _lastSyncIsPlaying = isPlaying;
      _lastSyncRealTime = now;
      widget.onSync(position, isPlaying);
    }
  }

  @override
  void dispose() {
    _yt?.removeListener(_onPlayerStateChange);
    _yt?.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: Column(
        children: [
          if (_yt != null && !_showSuggestions)
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
                if (widget.isHost) {
                  if (widget.nextYoutubeId != null) {
                    // Auto-play pinned video
                    widget.onLoad(widget.nextYoutubeId!);
                  } else {
                    widget.onSync(0, false);
                    if (mounted) setState(() => _showSuggestions = true);
                  }
                }
              },
            )
          else
            _EmptyVideoState(
              isHost: widget.isHost,
              onLoad: (id) {
                widget.onLoad(id);
                setState(() => _showSuggestions = false);
              },
            ),
        ],
      ),
    );
  }
}

class _EmptyVideoState extends StatelessWidget {
  final bool isHost;
  final Function(String) onLoad;
  const _EmptyVideoState({required this.isHost, required this.onLoad});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.white, AppColors.lightBg],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
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
                    Text('No video playing', style: AppTextStyles.bodyMedium),
                    const SizedBox(height: 2),
                    Text(
                      isHost
                          ? 'Pick a suggestion or search above'
                          : 'Waiting for host to load a video',
                      style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.grey.withValues(alpha: 0.7)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (isHost) ...[
            const Divider(height: 1, color: AppColors.divider),
            _SuggestionsList(onSelect: onLoad),
          ],
        ],
      ),
    );
  }
}

class _SuggestionsList extends StatelessWidget {
  final Function(String) onSelect;
  const _SuggestionsList({required this.onSelect});

  static const List<Map<String, String>> _mockSuggestions = [
    {
      'id': 't0Q2otsqC4I',
      'title': 'Tom & Jerry Classic',
      'thumb': 'https://img.youtube.com/vi/t0Q2otsqC4I/0.jpg'
    },
    {
      'id': 'dQw4w9WgXcQ',
      'title': 'Never Gonna Give You Up',
      'thumb': 'https://img.youtube.com/vi/dQw4w9WgXcQ/0.jpg'
    },
    {
      'id': '9bZkp7q19f0',
      'title': 'PSY - GANGNAM STYLE',
      'thumb': 'https://img.youtube.com/vi/9bZkp7q19f0/0.jpg'
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Text(
            'SUGGESTED FOR YOU',
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.grey,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
        ),
        SizedBox(
          height: 140,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _mockSuggestions.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final item = _mockSuggestions[index];
              return GestureDetector(
                onTap: () => onSelect(item['id']!),
                child: Container(
                  width: 160,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.fieldBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(11)),
                        child: Image.network(
                          item['thumb']!,
                          height: 90,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          item['title']!,
                          style: AppTextStyles.labelSmall.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
