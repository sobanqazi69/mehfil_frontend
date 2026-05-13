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
        if (state is RoomError) {
          AppSnackbar.error(context, state.message);
        }
        if (state is RoomLoaded && state.messages.isNotEmpty) {
          _scrollToBottom();
        }
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

        if (state is RoomLoaded) {
          final isHost = state.room.hostId == currentUserId;
          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (_, __) => _leave(),
            child: Scaffold(
              backgroundColor: AppColors.darkBg,
              appBar: _RoomAppBar(
                room: state.room,
                onLeave: _leave,
                onMuteAll: isHost
                    ? () => context.read<RoomCubit>().muteAll()
                    : null,
              ),
              body: Column(
                children: [
                  RoomVideoPlayer(
                    youtubeId: state.room.youtubeId,
                    isPlaying: state.room.isPlaying,
                    timestampSec: state.room.timestampSec,
                    isHost: isHost,
                    onLoad: (id) =>
                        context.read<RoomCubit>().loadVideo(id),
                    onSync: (ts, playing) =>
                        context.read<RoomCubit>().syncVideo(ts, playing),
                  ),
                  _ParticipantsRow(
                    members: state.members,
                    hostId: state.room.hostId,
                    mutedMap: state.mutedMap,
                  ),
                  const Divider(color: AppColors.divider, height: 1),
                  Expanded(
                    child: state.messages.isEmpty
                        ? const _EmptyChat()
                        : ListView.builder(
                            controller: _scrollCtrl,
                            padding:
                                const EdgeInsets.symmetric(vertical: 8),
                            itemCount: state.messages.length,
                            itemBuilder: (_, i) {
                              final msg = state.messages[i];
                              return ChatBubble(
                                message: msg,
                                isMe: msg.userId == currentUserId,
                              );
                            },
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
        }

        return const SizedBox.shrink();
      },
    );
  }
}

// ── AppBar ────────────────────────────────────────────────────────────────

class _RoomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final RoomModel room;
  final VoidCallback onLeave;
  final VoidCallback? onMuteAll;

  const _RoomAppBar({
    required this.room,
    required this.onLeave,
    this.onMuteAll,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.darkBg,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_rounded,
            color: AppColors.white, size: 20),
        onPressed: onLeave,
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            room.name,
            style: AppTextStyles.heading3,
            overflow: TextOverflow.ellipsis,
          ),
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AppColors.cyan,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '${room.memberCount} listening',
                style:
                    AppTextStyles.labelSmall.copyWith(color: AppColors.cyan),
              ),
            ],
          ),
        ],
      ),
      actions: [
        if (onMuteAll != null)
          IconButton(
            icon: const Icon(Icons.volume_off_rounded,
                color: AppColors.grey, size: 22),
            onPressed: onMuteAll,
            tooltip: 'Mute all',
          ),
        const SizedBox(width: 4),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: AppColors.divider),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 1);
}

// ── Participants ──────────────────────────────────────────────────────────

class _ParticipantsRow extends StatelessWidget {
  final List<RoomMemberModel> members;
  final int hostId;
  final Map<int, bool> mutedMap;

  const _ParticipantsRow({
    required this.members,
    required this.hostId,
    required this.mutedMap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 90,
      color: AppColors.cardBg,
      child: members.isEmpty
          ? Center(
              child: Text(
                'No participants yet',
                style: AppTextStyles.bodySmall,
              ),
            )
          : ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
              itemCount: members.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) {
                final m = members[i];
                return ParticipantTile(
                  member: m,
                  isMuted: mutedMap[m.userId] ?? true,
                  isHost: m.userId == hostId,
                );
              },
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
      padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + bottom),
      decoration: const BoxDecoration(
        color: AppColors.cardBg,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          MicFab(isMuted: isMicMuted, onToggle: onMicToggle),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: ctrl,
              style: AppTextStyles.bodySmall,
              decoration: const InputDecoration(
                hintText: 'Say something...',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
              ),
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onSend,
            child: Container(
              padding: const EdgeInsets.all(10),
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

// ── Empty / Loading / Error states ───────────────────────────────────────

class _EmptyChat extends StatelessWidget {
  const _EmptyChat();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chat_bubble_outline_rounded,
              size: 48, color: AppColors.grey.withOpacity(0.3)),
          const SizedBox(height: 12),
          Text('No messages yet', style: AppTextStyles.bodyMedium),
          const SizedBox(height: 4),
          Text('Be the first to say something!',
              style: AppTextStyles.bodySmall),
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
      body: const Center(
        child: CircularProgressIndicator(color: AppColors.cyan),
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
              const Icon(Icons.error_outline_rounded,
                  color: AppColors.error, size: 48),
              const SizedBox(height: 12),
              Text(message,
                  style: AppTextStyles.bodyMedium,
                  textAlign: TextAlign.center),
              const SizedBox(height: 20),
              TextButton(
                onPressed: onBack,
                child: Text(
                  'Go Back',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.cyan),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
