import 'dart:async';

import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../core/services/volume_service.dart';
import '../../../../core/utils/debug_logger.dart';

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

  /// The YouTube controller drops method calls until the webview is ready, so
  /// any level chosen before that has to be replayed once it is.
  bool _volumePending = false;

  /// Same problem, for playback: a play/seek issued before the webview is
  /// ready is dropped on the floor.
  bool _remoteSyncPending = false;

  /// When the last broadcast landed, so we can extrapolate from it.
  DateTime? _lastStateAt;

  /// Listener-side reconcile tick. The host only broadcasts every couple of
  /// seconds, and a listener that stalls between broadcasts has to notice on
  /// its own rather than waiting for the next one.
  Timer? _reconcileTimer;

  /// How far out of step a listener may drift before being seeked. Tight
  /// enough that nobody notices, loose enough not to fight normal jitter.
  static const double _driftToleranceSec = 1.0;

  /// How often the host re-anchors everyone. Was 10s, which let listeners
  /// wander for most of that window; a tiny socket message every 2s costs
  /// nothing next to the video itself.
  static const Duration _heartbeatInterval = Duration(seconds: 2);

  @override
  void initState() {
    super.initState();
    VolumeService.instance.videoVolume.addListener(_applyVideoVolume);
    if (widget.youtubeId != null) _initPlayer(widget.youtubeId!);
    _lastStateAt = DateTime.now();
    if (!widget.isHost) _startReconcileTimer();
  }

  void _startReconcileTimer() {
    _reconcileTimer?.cancel();
    _reconcileTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _applyRemoteState(),
    );
  }

  void _applyVideoVolume() {
    try {
      final yt = _yt;
      if (yt == null) return;

      final level = VolumeService.instance.videoVolume.value;
      if (!yt.value.isReady) {
        // Not a failure — _onPlayerReady replays it the moment we can.
        _volumePending = true;
        DebugLogger.log('video volume $level deferred (player not ready)',
            tag: 'VOL');
        return;
      }

      _volumePending = false;
      // mute()/unMute() on top of setVolume(): setVolume(0) leaves the player
      // technically unmuted, and the mute flag is the only thing the iframe
      // honours everywhere, so 0 means actually silent.
      if (level == 0) {
        yt.mute();
      } else {
        yt.unMute();
        yt.setVolume(level);
      }
      DebugLogger.log('video volume → $level', tag: 'VOL');
    } catch (e) {
      DebugLogger.error('video volume apply failed', error: e);
    }
  }

  /// Tear the controller down and forget it. Safe to call when there is none.
  void _disposePlayer() {
    _yt?.removeListener(_onPlayerStateChange);
    _yt?.removeListener(_onPlayerReady);
    _yt?.dispose();
    _yt = null;
    _volumePending = false;
  }

  /// Attached for every user (the sync listener below is host-only) purely to
  /// catch the moment the player becomes ready.
  void _onPlayerReady() {
    final yt = _yt;
    if (yt == null || !yt.value.isReady) return;
    if (_volumePending) _applyVideoVolume();
    // Whatever the room was doing while we were still loading gets applied
    // the instant we can act on it.
    if (_remoteSyncPending) _applyRemoteState();
  }

  @override
  void didUpdateWidget(RoomVideoPlayer old) {
    super.didUpdateWidget(old);

    final id = widget.youtubeId;

    if (id == null) {
      if (widget.youtubeId != old.youtubeId) {
        _disposePlayer();
        if (mounted) setState(() {});
      }
      return;
    }

    // Host handover. `hideControls` is baked into the controller when it is
    // constructed and the sync listener is only attached for a host, so a
    // promoted listener would otherwise keep a read-only player forever: no
    // pause, no seek, and none of their actions reaching the room. Rebuild at
    // the current position so the swap is invisible.
    if (widget.isHost != old.isHost) {
      final resumeAt =
          _yt?.value.position.inSeconds.toDouble() ?? widget.timestampSec;
      final wasPlaying = _yt?.value.isPlaying ?? widget.isPlaying;
      _disposePlayer();
      _showSuggestions = false;
      _initPlayer(id, startAt: resumeAt, autoPlay: wasPlaying); // rebuilds
      return;
    }

    if (widget.youtubeId != old.youtubeId) {
      if (_yt == null) {
        _initPlayer(id);
      } else {
        _yt!.load(id);
        // A fresh video can come up at the iframe's own default level.
        _applyVideoVolume();
      }
      _showSuggestions = false;
      return;
    }

    if (_yt == null) return;

    if (!widget.isHost) {
      // A fresh broadcast: restart the clock we extrapolate the host's
      // position from.
      if (widget.timestampSec != old.timestampSec ||
          widget.isPlaying != old.isPlaying) {
        _lastStateAt = DateTime.now();
      }
      _applyRemoteState();
    } else {
      final playerIsPlaying = _yt?.value.isPlaying ?? false;
      if (widget.isPlaying != old.isPlaying && widget.isPlaying != playerIsPlaying) {
        widget.isPlaying ? _yt?.play() : _yt?.pause();
      }
    }
  }

  /// Where the host should be *right now*.
  ///
  /// A broadcast is a snapshot that goes stale the moment it lands, so we keep
  /// advancing it by real elapsed time. Reconciling against the raw broadcast
  /// value would drag listeners backwards every time we checked.
  double get _expectedPosition {
    final at = _lastStateAt;
    if (!widget.isPlaying || at == null) return widget.timestampSec;
    final elapsed = DateTime.now().difference(at).inMilliseconds / 1000.0;
    return widget.timestampSec + elapsed;
  }

  /// Force the player to match the room.
  ///
  /// Compares against what the player is ACTUALLY doing rather than against
  /// the previous widget. That difference is the whole bug behind "it never
  /// started for them": if a listener stalled on a buffer, the host keeps
  /// broadcasting isPlaying: true, nothing ever *changes*, and the old
  /// change-detecting code therefore never told the player to resume.
  void _applyRemoteState() {
    final yt = _yt;
    if (yt == null || widget.isHost) return;

    // Commands are silently dropped before the webview is ready. Replay once
    // it is, instead of losing the play that was meant to start the party.
    if (!yt.value.isReady) {
      _remoteSyncPending = true;
      return;
    }
    _remoteSyncPending = false;

    final target = _expectedPosition;
    final actual = yt.value.position.inMilliseconds / 1000.0;

    if ((target - actual).abs() > _driftToleranceSec) {
      yt.seekTo(Duration(milliseconds: (target * 1000).round()));
      // seekTo() auto-plays in this package, so a paused room needs it undone.
      if (!widget.isPlaying) yt.pause();
      return;
    }

    if (widget.isPlaying && !yt.value.isPlaying) {
      yt.play();
    } else if (!widget.isPlaying && yt.value.isPlaying) {
      yt.pause();
    }
  }

  /// [startAt]/[autoPlay] override the room state — used on host handover to
  /// resume exactly where the old controller was rather than jumping back to
  /// the last broadcast timestamp.
  void _initPlayer(String id, {double? startAt, bool? autoPlay}) {
    _yt = YoutubePlayerController(
      initialVideoId: id,
      flags: YoutubePlayerFlags(
        autoPlay: autoPlay ?? widget.isPlaying,
        startAt: (startAt ?? widget.timestampSec).toInt(),
        mute: false,
        useHybridComposition: true,
        hideControls: !widget.isHost, // Only host can see controls
      ),
    );

    _volumePending = true;
    _yt!.addListener(_onPlayerReady);

    if (widget.isHost) {
      // Reset the throttle bookkeeping: a new host has broadcast nothing yet,
      // so their first play/pause/seek must go out immediately.
      _lastSyncTimestamp = startAt ?? widget.timestampSec;
      _lastSyncIsPlaying = autoPlay ?? widget.isPlaying;
      _lastSyncRealTime = null;
      _yt!.addListener(_onPlayerStateChange);
    }

    if (mounted) setState(() {});
  }

  void _onPlayerStateChange() {
    if (_yt == null || !widget.isHost) return;

    final state = _yt!.value;
    final isPlaying = state.isPlaying;
    // Milliseconds, not whole seconds. Truncating to inSeconds baked a
    // half-second of error into every broadcast before it even left the phone.
    final position = state.position.inMilliseconds / 1000.0;

    // Sync if:
    // 1. Playing state changed (INSTANT)
    // 2. The position jumped — a seek (INSTANT)
    // 3. Otherwise a heartbeat, so listeners can re-anchor their extrapolation
    bool shouldSync = false;
    final now = DateTime.now();

    final sinceLastSync = _lastSyncRealTime == null
        ? const Duration(days: 1)
        : now.difference(_lastSyncRealTime!);

    // How far the position moved beyond what plain playback explains. Real
    // playback advances ~1s per 1s elapsed, so anything well beyond that is a
    // seek and must go out immediately.
    final expected = sinceLastSync.inMilliseconds / 1000.0;
    final unexplained = (position - _lastSyncTimestamp - expected).abs();

    if (isPlaying != _lastSyncIsPlaying) {
      shouldSync = true;
    } else if (unexplained > 1.0) {
      shouldSync = true; // seek
    } else if (sinceLastSync >= _heartbeatInterval) {
      shouldSync = true; // keep everyone anchored
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
    VolumeService.instance.videoVolume.removeListener(_applyVideoVolume);
    _reconcileTimer?.cancel();
    _disposePlayer();
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
