import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../core/utils/map_utils.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../auth/presentation/cubits/auth_cubit.dart';
import '../../../auth/presentation/cubits/auth_state.dart';
import '../../data/models/message_model.dart';
import '../../data/models/room_model.dart';
import '../cubits/room_cubit.dart';
import '../cubits/room_list_cubit.dart';
import '../cubits/room_state.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/listeners_drawer.dart';
import '../widgets/mic_fab.dart';
import '../widgets/room_settings_sheet.dart';
import '../widgets/room_video_player.dart';
import '../widgets/unmuted_avatars.dart';
import 'youtube_picker_screen.dart';

class RoomScreen extends StatefulWidget {
  final int roomId;
  const RoomScreen({super.key, required this.roomId});

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  final _chatCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _hasLeft = false;

  @override
  void initState() {
    super.initState();
    final cubit = context.read<RoomCubit>();
    cubit.micBlocked = (message) {
      if (mounted) AppSnackbar.error(context, message);
    };

    final authState = context.read<AuthCubit>().state;
    if (authState is AuthAuthenticated) {
      cubit.enterRoom(widget.roomId, authState.user.id);
    }
  }

  Future<void> _leave() async {
    if (_hasLeft) return;
    _hasLeft = true;
    final authState = context.read<AuthCubit>().state;
    if (authState is AuthAuthenticated) {
      await context.read<RoomCubit>().leaveRoom(authState.user.id);
    }
    if (mounted) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/');
      }
    }
  }

  bool _leaveDialogOpen = false;

  void _confirmLeave() {
    if (_hasLeft || _leaveDialogOpen) return;
    _leaveDialogOpen = true;

    // Defer to next frame — onPopInvokedWithResult fires while the navigator
    // is locked mid-pop; pushing a dialog at that moment throws an assertion.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final res = await showDialog<bool>(
        context: context,
        builder: (c) => const _LeaveConfirmDialog(),
      );
      _leaveDialogOpen = false;
      if (res == true) _leave();
    });
  }

  Future<void> _openYoutubePicker() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const YoutubePickerScreen(allowQueue: true),
      ),
    );

    if (result != null && result is Map) {
      final data = MapUtils.asMap(result);
      final id = MapUtils.handleNullableStringKey(data, 'id');
      final action = MapUtils.handleNullableStringKey(data, 'action');
      if (id == null || id.isEmpty) return;
      if (action == 'play') {
        context.read<RoomCubit>().loadVideo(id);
      } else {
        context.read<RoomCubit>().queueVideo(id);
      }
    }
  }

  /// Host removed us: leave silently (no confirm dialog), go home, refresh the
  /// list so the room we can no longer see disappears.
  void _onKicked() {
    if (_hasLeft) return;
    _hasLeft = true;

    context.read<RoomListCubit>().refresh(silent: true);
    context.go('/');
    AppSnackbar.error(context, 'You have been kicked from the room');
  }

  void _sendMessage() {
    final text = _chatCtrl.text.trim();
    if (text.isEmpty) return;
    context.read<RoomCubit>().sendMessage(text);
    _chatCtrl.clear();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _chatCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<RoomCubit, RoomState>(
      listener: (context, state) {
        if (state is RoomError) AppSnackbar.error(context, state.message);
        if (state is RoomKicked) _onKicked();
        if (state is RoomLoaded && state.messages.isNotEmpty) _scrollToBottom();
      },
      builder: (context, state) {
        final authState = context.watch<AuthCubit>().state;
        final currentUserId =
            authState is AuthAuthenticated ? authState.user.id : 0;

        if (state is RoomLoading || state is RoomInitial) {
          return _LoadingScaffold(onBack: _leave);
        }
        if (state is RoomError) {
          return _ErrorScaffold(message: state.message, onBack: _leave);
        }
        if (state is! RoomLoaded) return const SizedBox.shrink();

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, __) {
            // Fires again once _leave() pops the route. Without the didPop
            // guard that second call re-opens the dialog on a room we already
            // left.
            if (didPop || _hasLeft) return;
            _confirmLeave();
          },
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: Scaffold(
              backgroundColor: AppColors.roomBgTop,
              endDrawer: const ListenersDrawer(),
              body: Container(
                decoration: const BoxDecoration(
                  gradient: AppColors.roomGradient,
                ),
                child: Column(
                  children: [
                    // 1. Optimized Header
                    BlocSelector<RoomCubit, RoomState, _HeaderData>(
                      selector: (s) => (s is RoomLoaded)
                          ? _HeaderData(s.room, s.room.hostId == currentUserId)
                          : _HeaderData.empty(),
                      builder: (context, data) {
                        return _RoomHeader(
                          room: data.room,
                          onLeave: _confirmLeave,
                          isHost: data.isHost,
                          onOpenListeners: () =>
                              Scaffold.of(context).openEndDrawer(),
                          onOpenSettings: data.isHost
                              ? () => showRoomSettingsSheet(context)
                              : null,
                          onToggleQueue:
                              data.isHost ? _openYoutubePicker : null,
                        );
                      },
                    ),

                    // 2. Optimized Video Player
                    BlocSelector<RoomCubit, RoomState, _VideoData>(
                      selector: (s) => (s is RoomLoaded)
                          ? _VideoData(s.room, s.room.hostId == currentUserId)
                          : _VideoData.empty(),
                      builder: (context, data) {
                        return RoomVideoPlayer(
                          youtubeId: data.room.youtubeId,
                          nextYoutubeId: data.room.nextYoutubeId,
                          isPlaying: data.room.isPlaying,
                          timestampSec: data.room.timestampSec,
                          isHost: data.isHost,
                          onLoad: (id) =>
                              context.read<RoomCubit>().loadVideo(id),
                          onQueue: (id) =>
                              context.read<RoomCubit>().queueVideo(id),
                          onSync: (ts, playing) =>
                              context.read<RoomCubit>().syncVideo(ts, playing),
                        );
                      },
                    ),

                    // 3. Optimized Chat List
                    Expanded(
                      child: BlocSelector<RoomCubit, RoomState, _ChatData>(
                        selector: (s) => (s is RoomLoaded)
                            ? _ChatData(s.messages, s.room.hostId)
                            : const _ChatData([], 0),
                        builder: (context, data) {
                          final messages = data.messages;
                          if (messages.isEmpty) return const _EmptyChat();
                          return ListView.builder(
                            controller: _scrollCtrl,
                            padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
                            itemCount: messages.length,
                            itemBuilder: (_, i) => ChatBubble(
                              message: messages[i],
                              isMe: messages[i].userId == currentUserId,
                              isHost: messages[i].userId == data.hostId,
                              // Hide avatar/name on a run from the same sender.
                              showSender: i == 0 ||
                                  messages[i - 1].userId != messages[i].userId,
                            ),
                          );
                        },
                      ),
                    ),

                    // 5. Optimized Chat Bar
                    BlocSelector<RoomCubit, RoomState, _MicData>(
                      selector: (s) => (s is RoomLoaded)
                          ? _MicData(s.isMicMuted, s.isHostMuted)
                          : const _MicData(true, false),
                      builder: (context, mic) {
                        return _ChatBar(
                          ctrl: _chatCtrl,
                          isMicMuted: mic.isMicMuted,
                          isHostMuted: mic.isHostMuted,
                          onSend: _sendMessage,
                          onMicToggle: () => context
                              .read<RoomCubit>()
                              .toggleMic(currentUserId),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Premium Header ────────────────────────────────────────────────────────

class _RoomHeader extends StatelessWidget {
  final RoomModel room;
  final VoidCallback onLeave;
  final bool isHost;
  final VoidCallback onOpenListeners;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onToggleQueue;

  const _RoomHeader({
    required this.room,
    required this.onLeave,
    required this.isHost,
    required this.onOpenListeners,
    this.onOpenSettings,
    this.onToggleQueue,
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.fromLTRB(10, top + 8, 10, 10),
      decoration: BoxDecoration(
        // Subtle top glow fading into the room gradient.
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.cyan.withValues(alpha: 0.10),
            Colors.transparent,
          ],
        ),
        border: Border(
          bottom: BorderSide(color: AppColors.roomGlassBorder),
        ),
      ),
      child: Row(
        children: [
          _HeaderAction(
            icon: Icons.close_rounded,
            color: AppColors.error,
            filled: true,
            onTap: onLeave,
          ),
          const SizedBox(width: 8),
          // Speaking / unmuted users live where the title used to be.
          const Expanded(child: UnmutedAvatars()),
          const SizedBox(width: 8),
          if (onOpenSettings != null)
            _HeaderAction(
              icon: Icons.tune_rounded,
              color: Colors.white,
              onTap: onOpenSettings!,
            ),
          if (isHost && onToggleQueue != null)
            _HeaderAction(
              icon: Icons.playlist_add_rounded,
              color: AppColors.cyan,
              onTap: onToggleQueue!,
            ),
          _HeaderAction(
            icon: Icons.people_alt_rounded,
            color: Colors.white,
            onTap: onOpenListeners,
          ),
        ],
      ),
    );
  }
}

class _HeaderAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool filled;
  final VoidCallback onTap;

  const _HeaderAction({
    required this.icon,
    required this.color,
    this.filled = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: filled ? color.withValues(alpha: 0.18) : AppColors.roomGlass,
          shape: BoxShape.circle,
          border: Border.all(
            color: filled
                ? color.withValues(alpha: 0.4)
                : AppColors.roomGlassBorder,
          ),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }
}

// ── Participants ──────────────────────────────────────────────────────────

class _ChatBar extends StatelessWidget {
  final TextEditingController ctrl;
  final bool isMicMuted;
  final bool isHostMuted;
  final VoidCallback onSend;
  final VoidCallback onMicToggle;

  const _ChatBar({
    required this.ctrl,
    required this.isMicMuted,
    required this.isHostMuted,
    required this.onSend,
    required this.onMicToggle,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(12, 10, 12, 10 + (bottom > 0 ? bottom : 10)),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.roomGlassBorder)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          MicFab(
            isMuted: isMicMuted,
            isHostMuted: isHostMuted,
            onToggle: onMicToggle,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                // Solid dark pill so white text is always legible, whatever the
                // gradient is doing behind it.
                color: const Color(0xFF241A48),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
              ),
              child: TextField(
                controller: ctrl,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                cursorColor: AppColors.cyan,
                decoration: InputDecoration(
                  hintText: 'Say something…',
                  hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 14),
                  // The global theme fills inputs solid white — opt out so the
                  // dark pill shows and the white text is legible.
                  filled: false,
                  fillColor: Colors.transparent,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onSend,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.purple.withValues(alpha: 0.5),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child:
                  const Icon(Icons.send_rounded, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty / Loading / Error ───────────────────────────────────────────────

class _EmptyChat extends StatelessWidget {
  const _EmptyChat();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.purple.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border:
                  Border.all(color: AppColors.purple.withValues(alpha: 0.2)),
            ),
            child: Icon(
              Icons.chat_bubble_outline_rounded,
              size: 30,
              color: AppColors.purple.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 14),
          Text('No messages yet',
              style: AppTextStyles.bodyMedium.copyWith(color: Colors.white)),
          const SizedBox(height: 4),
          Text('Start the conversation!',
              style: AppTextStyles.bodySmall
                  .copyWith(color: Colors.white.withValues(alpha: 0.5))),
        ],
      ),
    );
  }
}

class _LoadingScaffold extends StatelessWidget {
  final VoidCallback onBack;
  const _LoadingScaffold({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.roomBgTop,
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.roomGradient),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                  color: AppColors.cyan, strokeWidth: 2.5),
              const SizedBox(height: 16),
              Text('Joining room…',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: Colors.white.withValues(alpha: 0.7))),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Leave Confirmation Dialog ─────────────────────────────────────────────

class _LeaveConfirmDialog extends StatelessWidget {
  const _LeaveConfirmDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.fieldBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 40,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border:
                    Border.all(color: AppColors.error.withValues(alpha: 0.3)),
              ),
              child: const Icon(
                Icons.logout_rounded,
                color: AppColors.error,
                size: 30,
              ),
            ),
            const SizedBox(height: 20),
            Text('Leave Room?', style: AppTextStyles.heading3),
            const SizedBox(height: 8),
            Text(
              "You'll leave this watch party.\nOthers can still continue without you.",
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.grey,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.lightBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.fieldBorder),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Stay',
                        style: AppTextStyles.button
                            .copyWith(color: AppColors.white),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFE53935), Color(0xFFC62828)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.error.withValues(alpha: 0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Leave',
                        style:
                            AppTextStyles.button.copyWith(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorScaffold extends StatelessWidget {
  final String message;
  final VoidCallback onBack;
  const _ErrorScaffold({required this.message, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.roomBgTop,
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.roomGradient),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.error_outline_rounded,
                      color: AppColors.error, size: 36),
                ),
                const SizedBox(height: 16),
                Text(message,
                    style:
                        AppTextStyles.bodyMedium.copyWith(color: Colors.white),
                    textAlign: TextAlign.center),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: onBack,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Text('Go Back',
                        style: AppTextStyles.button
                            .copyWith(color: AppColors.white)),
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

// ── Data Helpers for Optimized Rebuilds ──────────────────────────────────────

class _MicData {
  final bool isMicMuted;
  final bool isHostMuted;

  const _MicData(this.isMicMuted, this.isHostMuted);

  @override
  bool operator ==(Object other) =>
      other is _MicData &&
      other.isMicMuted == isMicMuted &&
      other.isHostMuted == isHostMuted;

  @override
  int get hashCode => isMicMuted.hashCode ^ isHostMuted.hashCode;
}

class _ChatData {
  final List<MessageModel> messages;
  final int hostId;

  const _ChatData(this.messages, this.hostId);

  @override
  bool operator ==(Object other) =>
      other is _ChatData &&
      other.hostId == hostId &&
      other.messages.length == messages.length &&
      (messages.isEmpty || other.messages.last.id == messages.last.id);

  @override
  int get hashCode => messages.length.hashCode ^ hostId.hashCode;
}

class _HeaderData {
  final RoomModel room;
  final bool isHost;
  _HeaderData(this.room, this.isHost);
  static _HeaderData empty() => _HeaderData(
      RoomModel(id: 0, name: '', hostId: 0, creatorId: 0, youtubeId: ''),
      false);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _HeaderData &&
          room.name == other.room.name &&
          room.memberCount == other.room.memberCount &&
          isHost == other.isHost;

  @override
  int get hashCode =>
      room.name.hashCode ^ room.memberCount.hashCode ^ isHost.hashCode;
}

class _VideoData {
  final RoomModel room;
  final bool isHost;
  _VideoData(this.room, this.isHost);
  static _VideoData empty() => _VideoData(
      RoomModel(id: 0, name: '', hostId: 0, creatorId: 0, youtubeId: ''),
      false);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _VideoData &&
          room.youtubeId == other.room.youtubeId &&
          room.isPlaying == other.room.isPlaying &&
          room.timestampSec == other.room.timestampSec &&
          isHost == other.isHost;

  @override
  int get hashCode =>
      room.youtubeId.hashCode ^
      room.isPlaying.hashCode ^
      room.timestampSec.hashCode ^
      isHost.hashCode;
}
