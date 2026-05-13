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
  bool _showVideoInput = false;

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
    if (mounted) context.pop();
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

        final isHost = state.room.hostId == currentUserId;

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (_, __) => _leave(),
          child: Scaffold(
            backgroundColor: AppColors.darkBg,
            body: Column(
              children: [
                _RoomHeader(
                  room: state.room,
                  onLeave: _leave,
                  isHost: isHost,
                  onMuteAll: isHost
                      ? () => context.read<RoomCubit>().muteAll()
                      : null,
                  onToggleVideo: isHost
                      ? () => setState(() => _showVideoInput = !_showVideoInput)
                      : null,
                  showVideoInput: _showVideoInput,
                ),
                RoomVideoPlayer(
                  youtubeId: state.room.youtubeId,
                  isPlaying: state.room.isPlaying,
                  timestampSec: state.room.timestampSec,
                  isHost: isHost,
                  showInput: isHost && _showVideoInput,
                  onLoad: (id) {
                    context.read<RoomCubit>().loadVideo(id);
                    setState(() => _showVideoInput = false);
                  },
                  onSync: (ts, playing) =>
                      context.read<RoomCubit>().syncVideo(ts, playing),
                ),
                _ParticipantsSection(
                  members: state.members,
                  hostId: state.room.hostId,
                  mutedMap: state.mutedMap,
                ),
                Expanded(
                  child: state.messages.isEmpty
                      ? const _EmptyChat()
                      : ListView.builder(
                          controller: _scrollCtrl,
                          padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
                          itemCount: state.messages.length,
                          itemBuilder: (_, i) => ChatBubble(
                            message: state.messages[i],
                            isMe: state.messages[i].userId == currentUserId,
                          ),
                        ),
                ),
                _ChatBar(
                  ctrl: _chatCtrl,
                  isMicMuted: state.isMicMuted,
                  onSend: _sendMessage,
                  onMicToggle: () =>
                      context.read<RoomCubit>().toggleMic(currentUserId),
                ),
              ],
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
  final VoidCallback? onMuteAll;
  final VoidCallback? onToggleVideo;
  final bool showVideoInput;

  const _RoomHeader({
    required this.room,
    required this.onLeave,
    required this.isHost,
    this.onMuteAll,
    this.onToggleVideo,
    this.showVideoInput = false,
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.fromLTRB(4, top + 4, 4, 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A0E3F), Color(0xFF110D2B)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: const Border(
          bottom: BorderSide(color: AppColors.divider, width: 1),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded,
                color: AppColors.white, size: 20),
            onPressed: onLeave,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                          style: AppTextStyles.labelSmall
                              .copyWith(color: AppColors.purpleLight, fontSize: 10),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (isHost && onToggleVideo != null)
            _HeaderAction(
              icon: showVideoInput
                  ? Icons.close_rounded
                  : Icons.ondemand_video_rounded,
              color: showVideoInput ? AppColors.error : AppColors.cyan,
              onTap: onToggleVideo!,
            ),
          if (onMuteAll != null)
            _HeaderAction(
              icon: Icons.volume_off_rounded,
              color: AppColors.grey,
              onTap: onMuteAll!,
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
                    separatorBuilder: (_, __) =>
                        const SizedBox(width: 14),
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
      padding: EdgeInsets.fromLTRB(12, 10, 12, 10 + bottom),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: const Border(
          top: BorderSide(color: AppColors.divider),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
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
                color: AppColors.darkBg,
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
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 11),
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
              child: const Icon(Icons.send_rounded,
                  color: Colors.white, size: 18),
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
              border: Border.all(
                  color: AppColors.purple.withValues(alpha: 0.2)),
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
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: AppColors.white),
          onPressed: onBack,
        ),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppColors.cyan,
                strokeWidth: 2.5),
            const SizedBox(height: 16),
            Text('Joining room...', style: AppTextStyles.bodySmall),
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
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: AppColors.white),
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
                  style: AppTextStyles.bodyMedium,
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
    );
  }
}
