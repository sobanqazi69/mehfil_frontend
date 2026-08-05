import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../../../core/constants/room_reactions.dart';

/// An emoji rendered as a Noto Lottie animation, falling back to the plain
/// unicode glyph.
///
/// The fallback matters more than it looks: the animation is fetched over the
/// network, so on a cold or offline start the glyph is what the user sees.
/// Never leave a hole where a reaction should be.
class AnimatedEmoji extends StatelessWidget {
  final String char;
  final double size;

  /// Play once and stop (a reaction) rather than loop forever (a picker tile).
  final bool repeat;

  const AnimatedEmoji({
    super.key,
    required this.char,
    this.size = 32,
    this.repeat = true,
  });

  @override
  Widget build(BuildContext context) {
    final reaction = RoomReactions.byChar(char);
    if (reaction == null) return _glyph();

    return SizedBox(
      width: size,
      height: size,
      child: Lottie.network(
        reaction.lottieUrl,
        width: size,
        height: size,
        repeat: repeat,
        fit: BoxFit.contain,
        // Both states show the real emoji, so a slow or failed fetch is
        // invisible rather than a blank box or an error icon.
        frameBuilder: (context, child, composition) =>
            composition == null ? _glyph() : child,
        errorBuilder: (_, __, ___) => _glyph(),
      ),
    );
  }

  Widget _glyph() => SizedBox(
        width: size,
        height: size,
        child: Center(
          child: Text(
            char,
            style: TextStyle(fontSize: size * 0.82),
          ),
        ),
      );
}
