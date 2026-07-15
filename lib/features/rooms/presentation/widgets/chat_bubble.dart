import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../data/models/message_model.dart';

class ChatBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;

  /// Sender is the room host — gets a crown on the avatar.
  final bool isHost;

  /// First message of a run from this sender. Consecutive messages hide the
  /// avatar and name so a burst reads as one block.
  final bool showSender;

  const ChatBubble({
    super.key,
    required this.message,
    this.isMe = false,
    this.isHost = false,
    this.showSender = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        isMe ? 56 : 10,
        showSender ? 6 : 2,
        isMe ? 10 : 56,
        2,
      ),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe) ...[
            _AvatarSlot(
              message: message,
              isHost: isHost,
              visible: showSender,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(child: _Bubble(
            message: message,
            isMe: isMe,
            showSender: showSender,
          )),
          if (isMe) ...[
            const SizedBox(width: 8),
            _AvatarSlot(
              message: message,
              isHost: isHost,
              visible: showSender,
            ),
          ],
        ],
      ),
    );
  }
}

// ── Bubble ────────────────────────────────────────────────────────────────

class _Bubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;
  final bool showSender;

  const _Bubble({
    required this.message,
    required this.isMe,
    required this.showSender,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.only(
      topLeft: Radius.circular(!isMe && showSender ? 4 : 16),
      topRight: Radius.circular(isMe && showSender ? 4 : 16),
      bottomLeft: const Radius.circular(16),
      bottomRight: const Radius.circular(16),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: isMe ? AppColors.primaryGradient : null,
        color: isMe ? null : AppColors.roomGlass,
        borderRadius: radius,
        border: isMe
            ? null
            : Border.all(color: AppColors.roomGlassBorder),
        boxShadow: isMe
            ? [
                BoxShadow(
                  color: AppColors.purple.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      // Name and text share one paragraph, so a short message wraps tight to
      // the name instead of stacking on its own line.
      child: RichText(
        text: TextSpan(
          children: [
            if (!isMe && showSender)
              TextSpan(
                text: '${message.name}: ',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.cyan,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
            TextSpan(
              text: message.text,
              style: AppTextStyles.bodySmall.copyWith(
                color: isMe ? AppColors.white : Colors.white,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Avatar (with crown for the host) ─────────────────────────────────────

class _AvatarSlot extends StatelessWidget {
  final MessageModel message;
  final bool isHost;
  final bool visible;

  const _AvatarSlot({
    required this.message,
    required this.isHost,
    required this.visible,
  });

  static const double _size = 30;

  @override
  Widget build(BuildContext context) {
    // Keep the space reserved on follow-up messages so the run stays aligned.
    if (!visible) return const SizedBox(width: _size);

    return SizedBox(
      width: _size,
      height: _size + (isHost ? 4 : 0),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: _size,
            height: _size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.primaryGradient,
              border: Border.all(
                color: isHost ? AppColors.gold : AppColors.fieldBorder,
                width: isHost ? 1.5 : 1,
              ),
            ),
            child: ClipOval(
              child: message.avatar != null
                  ? CachedNetworkImage(
                      imageUrl: message.avatar!,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _initial(),
                    )
                  : _initial(),
            ),
          ),
          if (isHost)
            const Positioned(
              top: -7,
              left: 5,
              child: _Crown(),
            ),
        ],
      ),
    );
  }

  Widget _initial() => Center(
        child: Text(
          message.name.isNotEmpty ? message.name[0].toUpperCase() : '?',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      );
}

class _Crown extends StatelessWidget {
  const _Crown();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AppColors.gold,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.5),
            blurRadius: 4,
          ),
        ],
      ),
      child: const Icon(
        Icons.workspace_premium_rounded,
        size: 10,
        color: Colors.white,
      ),
    );
  }
}
