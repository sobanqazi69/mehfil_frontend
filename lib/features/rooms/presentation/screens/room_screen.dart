import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../auth/presentation/cubits/auth_cubit.dart';
import '../../../auth/presentation/cubits/auth_state.dart';
import '../../data/models/room_member_model.dart';
import '../../data/models/room_model.dart';
import '../cubits/room_cubit.dart';
import '../cubits/room_state.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/mic_fab.dart';
import '../widgets/participant_tile.dart';
import '../widgets/room_video_player.dart';
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
    final authState = context.read<AuthCubit>().state;
    if (authState is AuthAuthenticated) {
      context.read<RoomCubit>().enterRoom(widget.roomId, authState.user.id);
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

  void _confirmLeave() {
    // Defer to next frame — onPopInvokedWithResult fires while the navigator
    // is locked mid-pop; pushing a dialog at that moment throws an assertion.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final res = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Leave Room?'),
          content: const Text('Do you want to leave this session?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Stay')),
            TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Leave')),
          ],
        ),
      );
      if (res == true) _leave();
    });
  }

  Future<void> _openYoutubePicker() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const YoutubePickerScreen()),
    );

    if (result != null && result is Map) {
      final id = result['id'] as String;
      final action = result['action'] as String;
      if (action == 'play') {
        context.read<RoomCubit>().loadVideo(id);
      } else {
        context.read<RoomCubit>().queueVideo(id);
      }
    }
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
          onPopInvokedWithResult: (_, __) => _confirmLeave(),
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: Scaffold(
              backgroundColor: AppColors.lightBg,
              drawer: _RoomDrawer(
                room: state.room,
                isHost: state.room.hostId == currentUserId,
              ),
              body: Column(
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
                        onOpenDrawer: () => Scaffold.of(context).openDrawer(),
                        onToggleQueue: data.isHost ? _openYoutubePicker : null,
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
                      onLoad: (id) => context.read<RoomCubit>().loadVideo(id),
                      onQueue: (id) => context.read<RoomCubit>().queueVideo(id),
                      onSync: (ts, playing) =>
                          context.read<RoomCubit>().syncVideo(ts, playing),
                    );
                  },
                ),

                // 3. Optimized Participants
                BlocSelector<RoomCubit, RoomState, _ParticipantsData>(
                  selector: (s) => (s is RoomLoaded)
                      ? _ParticipantsData(s.members, s.room.hostId, s.mutedMap)
                      : _ParticipantsData.empty(),
                  builder: (context, data) {
                    return _ParticipantsSection(
                      members: data.members,
                      hostId: data.hostId,
                      mutedMap: data.mutedMap,
                    );
                  },
                ),

                // 4. Optimized Chat List
                Expanded(
                  child: BlocSelector<RoomCubit, RoomState, List>(
                    selector: (s) => (s is RoomLoaded) ? s.messages : [],
                    builder: (context, messages) {
                      if (messages.isEmpty) return const _EmptyChat();
                      return ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
                        itemCount: messages.length,
                        itemBuilder: (_, i) => ChatBubble(
                          message: messages[i],
                          isMe: messages[i].userId == currentUserId,
                        ),
                      );
                    },
                  ),
                ),

                // 5. Optimized Chat Bar
                BlocSelector<RoomCubit, RoomState, bool>(
                  selector: (s) => (s is RoomLoaded) ? s.isMicMuted : true,
                  builder: (context, isMicMuted) {
                    return _ChatBar(
                      ctrl: _chatCtrl,
                      isMicMuted: isMicMuted,
                      onSend: _sendMessage,
                      onMicToggle: () =>
                          context.read<RoomCubit>().toggleMic(currentUserId),
                    );
                  },
                ),
              ],
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
  final VoidCallback onOpenDrawer;
  final VoidCallback? onToggleQueue;

  const _RoomHeader({
    required this.room,
    required this.onLeave,
    required this.isHost,
    required this.onOpenDrawer,
    this.onToggleQueue,
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.fromLTRB(4, top + 4, 4, 8),
      decoration: BoxDecoration(
        gradient: AppColors.glassGradient,
        border: const Border(
          bottom: BorderSide(color: AppColors.fieldBorder, width: 1.5),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.cyan.withValues(alpha: 0.08),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onLeave,
            child: Container(
              width: 38,
              height: 38,
              margin: const EdgeInsets.only(left: 8, right: 4),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border:
                    Border.all(color: AppColors.error.withValues(alpha: 0.35)),
              ),
              child: const Icon(
                Icons.logout_rounded,
                color: AppColors.error,
                size: 18,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  room.name,
                  style: AppTextStyles.heading3,
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  children: [
                    _LivePulse(),
                    const SizedBox(width: 6),
                    Text(
                      '${room.memberCount} listening',
                      style: AppTextStyles.labelSmall
                          .copyWith(color: AppColors.grey),
                    ),
                    if (room.category != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.purple.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: AppColors.purple.withValues(alpha: 0.5)),
                        ),
                        child: Text(
                          room.category!,
                          style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.purpleLight, fontSize: 10),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (isHost && onToggleQueue != null)
            _HeaderAction(
              icon: Icons.playlist_add_rounded,
              color: AppColors.cyan,
              onTap: onToggleQueue!,
            ),
          _HeaderAction(
            icon: Icons.menu_rounded,
            color: AppColors.grey,
            onTap: onOpenDrawer,
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class _LivePulse extends StatefulWidget {
  @override
  State<_LivePulse> createState() => _LivePulseState();
}

class _LivePulseState extends State<_LivePulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ScaleTransition(
          scale: _scale,
          child: Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: AppColors.cyan,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.cyan.withValues(alpha: 0.6),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          'LIVE',
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.cyan,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}

class _HeaderAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _HeaderAction({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }
}

// ── Participants ──────────────────────────────────────────────────────────

class _ParticipantsSection extends StatelessWidget {
  final List<RoomMemberModel> members;
  final int hostId;
  final Map<int, bool> mutedMap;

  const _ParticipantsSection({
    required this.members,
    required this.hostId,
    required this.mutedMap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: const Border(
          bottom: BorderSide(color: AppColors.divider),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Row(
              children: [
                Icon(Icons.people_alt_rounded,
                    size: 14, color: AppColors.grey.withValues(alpha: 0.7)),
                const SizedBox(width: 6),
                Text(
                  '${members.length} in room',
                  style: AppTextStyles.labelSmall
                      .copyWith(color: AppColors.grey.withValues(alpha: 0.7)),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 92,
            child: members.isEmpty
                ? Center(
                    child: Text(
                      'Waiting for others to join...',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.grey.withValues(alpha: 0.5),
                      ),
                    ),
                  )
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    itemCount: members.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 14),
                    itemBuilder: (_, i) => ParticipantTile(
                      member: members[i],
                      isMuted: mutedMap[members[i].userId] ?? true,
                      isHost: members[i].userId == hostId,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Chat Bar ──────────────────────────────────────────────────────────────

class _ChatBar extends StatelessWidget {
  final TextEditingController ctrl;
  final bool isMicMuted;
  final VoidCallback onSend;
  final VoidCallback onMicToggle;

  const _ChatBar({
    required this.ctrl,
    required this.isMicMuted,
    required this.onSend,
    required this.onMicToggle,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(12, 10, 12, 10 + (bottom > 0 ? bottom : 10)),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: const Border(
          top: BorderSide(color: AppColors.fieldBorder),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          MicFab(isMuted: isMicMuted, onToggle: onMicToggle),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.lightBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.fieldBorder),
              ),
              child: TextField(
                controller: ctrl,
                style: AppTextStyles.bodySmall,
                decoration: InputDecoration(
                  hintText: 'Say something...',
                  hintStyle: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.grey.withValues(alpha: 0.5)),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
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
              decoration: const BoxDecoration(
                gradient: AppColors.primaryGradient,
                shape: BoxShape.circle,
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
          Text('No messages yet', style: AppTextStyles.bodyMedium),
          const SizedBox(height: 4),
          Text('Start the conversation!',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.grey.withValues(alpha: 0.6))),
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
      backgroundColor: AppColors.lightBg,
      appBar: AppBar(
        backgroundColor: AppColors.lightBg,
        elevation: 0,
        leading: IconButton(
          icon:
              const Icon(Icons.arrow_back_ios_rounded, color: AppColors.white),
          onPressed: onBack,
        ),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
                color: AppColors.cyan, strokeWidth: 2.5),
            const SizedBox(height: 16),
            Text('Joining room...', style: AppTextStyles.bodySmall),
          ],
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
      backgroundColor: AppColors.lightBg,
      appBar: AppBar(
        backgroundColor: AppColors.lightBg,
        elevation: 0,
        leading: IconButton(
          icon:
              const Icon(Icons.arrow_back_ios_rounded, color: AppColors.white),
          onPressed: onBack,
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.error_outline_rounded,
                    color: AppColors.error, size: 36),
              ),
              const SizedBox(height: 16),
              Text(message,
                  style: AppTextStyles.bodyMedium, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: onBack,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
    );
  }
}

// ── Data Helpers for Optimized Rebuilds ──────────────────────────────────────

class _HeaderData {
  final RoomModel room;
  final bool isHost;
  _HeaderData(this.room, this.isHost);
  static _HeaderData empty() => _HeaderData(
      RoomModel(id: 0, name: '', hostId: 0, creatorId: 0, youtubeId: ''), false);

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
      RoomModel(id: 0, name: '', hostId: 0, creatorId: 0, youtubeId: ''), false);

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

class _ParticipantsData {
  final List<RoomMemberModel> members;
  final int hostId;
  final Map<int, bool> mutedMap;
  _ParticipantsData(this.members, this.hostId, this.mutedMap);
  static _ParticipantsData empty() => _ParticipantsData([], 0, {});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _ParticipantsData &&
          members.length == other.members.length &&
          hostId == other.hostId &&
          mutedMap.length == other.mutedMap.length;

  @override
  int get hashCode =>
      members.length.hashCode ^ hostId.hashCode ^ mutedMap.length.hashCode;
}

// ── Room Drawer ───────────────────────────────────────────────────────────

class _RoomDrawer extends StatelessWidget {
  final RoomModel room;
  final bool isHost;

  const _RoomDrawer({required this.room, required this.isHost});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.lightBg,
      child: Column(
        children: [
          _DrawerHeader(room: room),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: [
                const _DrawerSection(title: 'Room Settings'),
                _DrawerTile(
                  icon: Icons.public_rounded,
                  title: 'Privacy',
                  trailing: Switch.adaptive(
                    value: room.isPublic,
                    onChanged: isHost
                        ? (val) {
                            context.read<RoomCubit>().updateSettings(isPublic: val);
                            AppSnackbar.info(context, 'Privacy updated');
                          }
                        : null,
                    activeTrackColor: AppColors.cyan,
                  ),
                  subtitle: room.isPublic ? 'Public Room' : 'Private Room',
                ),
                _DrawerTile(
                  icon: Icons.edit_rounded,
                  title: 'Rename Room',
                  onTap: isHost ? () {} : null,
                ),
                const Divider(color: AppColors.divider, height: 32),
                const _DrawerSection(title: 'Audio'),
                _DrawerTile(
                  icon: Icons.volume_off_rounded,
                  title: 'Mute All',
                  onTap: isHost
                      ? () => context.read<RoomCubit>().muteAll()
                      : null,
                ),
                const Divider(color: AppColors.divider, height: 32),
                _DrawerTile(
                  icon: Icons.info_outline_rounded,
                  title: 'About Room',
                  onTap: () {},
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'Mehfil v1.0.0',
              style: AppTextStyles.labelSmall.copyWith(color: AppColors.grey),
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerHeader extends StatelessWidget {
  final RoomModel room;
  const _DrawerHeader({required this.room});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(24, top + 32, 24, 32),
      decoration: const BoxDecoration(
        gradient: AppColors.primaryGradient,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.meeting_room_rounded,
                color: Colors.white, size: 32),
          ),
          const SizedBox(height: 16),
          Text(
            room.name,
            style: AppTextStyles.heading2.copyWith(color: Colors.white),
          ),
          Text(
            'Room ID: #${room.id}',
            style: AppTextStyles.bodySmall
                .copyWith(color: Colors.white.withValues(alpha: 0.8)),
          ),
        ],
      ),
    );
  }
}

class _DrawerSection extends StatelessWidget {
  final String title;
  const _DrawerSection({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
      child: Text(
        title.toUpperCase(),
        style: AppTextStyles.labelSmall.copyWith(
          color: AppColors.cyan,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _DrawerTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.grey.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.grey, size: 20),
      ),
      title: Text(title, style: AppTextStyles.bodyMedium),
      subtitle: subtitle != null
          ? Text(subtitle!,
              style: AppTextStyles.labelSmall.copyWith(color: AppColors.grey))
          : null,
      trailing: trailing,
      onTap: onTap,
    );
  }
}
