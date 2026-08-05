/// The reaction set available in a room.
///
/// Animation comes from Google's Noto Animated Emoji, served as Lottie JSON.
/// Nothing is bundled — the assets are a few tens of KB each, fetched once and
/// then cached in memory, which beats shipping a megabyte of GIFs for emoji
/// most rooms will never use. [char] is the plain unicode fallback and is also
/// what travels over the wire, so the feature degrades to a normal emoji if the
/// CDN is unreachable.
class RoomReaction {
  /// Unicode emoji. The wire format and the offline fallback.
  final String char;

  /// Noto codepoint slug, e.g. `1f525` or `2764_fe0f`.
  final String code;

  const RoomReaction(this.char, this.code);

  String get lottieUrl =>
      'https://fonts.gstatic.com/s/e/notoemoji/latest/$code/lottie.json';
}

class RoomReactions {
  RoomReactions._();

  static const List<RoomReaction> all = [
    RoomReaction('❤️', '2764_fe0f'),
    RoomReaction('😂', '1f602'),
    RoomReaction('🔥', '1f525'),
    RoomReaction('👏', '1f44f'),
    RoomReaction('👍', '1f44d'),
    RoomReaction('🎉', '1f389'),
    RoomReaction('😍', '1f60d'),
    RoomReaction('😮', '1f62e'),
    RoomReaction('😭', '1f62d'),
    RoomReaction('🙏', '1f64f'),
    RoomReaction('💯', '1f4af'),
    RoomReaction('😎', '1f60e'),
  ];

  /// Look up the animation for a received emoji. Returns null for anything we
  /// do not recognise, so an unexpected payload renders as plain text rather
  /// than breaking the tile.
  static RoomReaction? byChar(String char) {
    for (final r in all) {
      if (r.char == char) return r;
    }
    return null;
  }

  /// True when [text] is nothing but reaction emoji — used to decide whether a
  /// chat message should render large and animated instead of as a bubble.
  static bool isReactionOnly(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;
    for (final r in all) {
      if (trimmed == r.char) return true;
    }
    return false;
  }
}
