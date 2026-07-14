class MapUtils {
  MapUtils._();

  static String? handleNullableStringKey(Map<String, dynamic>? json, String key) {
    try {
      final value = json?[key];
      if (value == null) return null;
      return value.toString();
    } catch (_) {
      return null;
    }
  }

  static int? handleNullableIntKey(Map<String, dynamic>? json, String key) {
    try {
      final value = json?[key];
      if (value == null) return null;
      if (value is int) return value;
      if (value is double) return value.toInt();
      return int.tryParse(value.toString());
    } catch (_) {
      return null;
    }
  }

  static bool? handleNullableBoolKey(Map<String, dynamic>? json, String key) {
    try {
      final value = json?[key];
      if (value == null) return null;
      if (value is bool) return value;
      return value.toString().toLowerCase() == 'true';
    } catch (_) {
      return null;
    }
  }

  static double? handleNullableDoubleKey(Map<String, dynamic>? json, String key) {
    try {
      final value = json?[key];
      if (value == null) return null;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      return double.tryParse(value.toString());
    } catch (_) {
      return null;
    }
  }

  static List<T>? handleNullableListKey<T>(
    Map<String, dynamic>? json,
    String key,
    T Function(dynamic) fromItem,
  ) {
    try {
      final value = json?[key];
      if (value == null || value is! List) return null;
      return value.map((e) => fromItem(e)).toList();
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic>? handleNullableMapKey(
      Map<String, dynamic>? json, String key) {
    try {
      final value = json?[key];
      if (value == null || value is! Map) return null;
      return Map<String, dynamic>.from(value);
    } catch (_) {
      return null;
    }
  }

  /// Coerces any raw value (API body, socket payload) into a map.
  ///
  /// Never throws. A hard `value as Map<String, dynamic>` blows up when the
  /// server returns null, a String (an HTML error page), or a Map with
  /// non-String keys — use this instead.
  static Map<String, dynamic> asMap(dynamic value) {
    try {
      if (value is Map) return Map<String, dynamic>.from(value);
      return const {};
    } catch (_) {
      return const {};
    }
  }

  /// Coerces a raw value into a list of maps, dropping any entry that isn't a
  /// usable map. One malformed element can no longer take down the whole list.
  static List<Map<String, dynamic>> asMapList(dynamic value) {
    try {
      if (value is! List) return const [];
      return value
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return const [];
    }
  }
}
