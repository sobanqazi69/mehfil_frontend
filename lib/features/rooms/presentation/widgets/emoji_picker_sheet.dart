import 'package:flutter/material.dart';

import '../../../../config/theme/app_text_styles.dart';
import '../../../../core/constants/room_reactions.dart';
import 'animated_emoji.dart';

const _gold = Color(0xFFFBBF24);

/// Reaction picker. Resolves to the chosen emoji, or null if dismissed.
Future<String?> showEmojiPickerSheet(
  BuildContext context, {
  required bool isSeated,
}) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    builder: (_) => _EmojiPickerSheet(isSeated: isSeated),
  );
}

class _EmojiPickerSheet extends StatelessWidget {
  final bool isSeated;
  const _EmojiPickerSheet({required this.isSeated});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF130E26),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _gold.withValues(alpha: 0.15)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                child: Row(
                  children: [
                    const Icon(Icons.emoji_emotions_rounded,
                        size: 17, color: _gold),
                    const SizedBox(width: 10),
                    Text(
                      'Reactions',
                      style: AppTextStyles.heading3
                          .copyWith(fontSize: 15, color: _gold),
                    ),
                    const Spacer(),
                    // Tell people where it will land before they tap.
                    Flexible(
                      child: Text(
                        isSeated ? 'Shows on your seat' : 'Sends to chat',
                        textAlign: TextAlign.right,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.labelSmall.copyWith(
                          fontSize: 10,
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: _gold.withValues(alpha: 0.12)),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 14, 12, 18),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: RoomReactions.all.length,
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6,
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                  ),
                  itemBuilder: (_, i) {
                    final reaction = RoomReactions.all[i];
                    return InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => Navigator.pop(context, reaction.char),
                      child: Padding(
                        padding: const EdgeInsets.all(5),
                        child: AnimatedEmoji(char: reaction.char, size: 38),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
