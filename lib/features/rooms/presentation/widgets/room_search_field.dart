import 'package:flutter/material.dart';
import '../../../../config/theme/app_text_styles.dart';

class RoomSearchField extends StatefulWidget {
  final ValueChanged<String> onChanged;

  const RoomSearchField({super.key, required this.onChanged});

  @override
  State<RoomSearchField> createState() => _RoomSearchFieldState();
}

class _RoomSearchFieldState extends State<RoomSearchField> {
  final _controller = TextEditingController();
  bool _hasText = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    final has = value.isNotEmpty;
    if (has != _hasText) setState(() => _hasText = has);
    widget.onChanged(value);
  }

  void _clear() {
    _controller.clear();
    _onChanged('');
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF130E26), // Force dark background
          border: _border(const Color(0x33F59E0B)),
          enabledBorder: _border(const Color(0x33F59E0B)),
          focusedBorder: _border(const Color(0xFFFBBF24), width: 1.5),
          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          prefixIconColor: const Color(0xFFF59E0B),
          suffixIconColor: const Color(0xFFF59E0B),
        ),
      ),
      child: TextField(
        controller: _controller,
        onChanged: _onChanged,
        textInputAction: TextInputAction.search,
        style: AppTextStyles.bodySmall.copyWith(color: const Color(0xFFFBBF24)),
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Search rooms or hosts',
          hintStyle: AppTextStyles.bodySmall.copyWith(
            color: const Color(0xFFFBBF24).withValues(alpha: 0.45),
          ),
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          suffixIcon: _hasText
              ? IconButton(
                  onPressed: _clear,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  tooltip: 'Clear search',
                )
              : null,
        ),
      ),
    );
  }

  OutlineInputBorder _border(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: color, width: width),
      );
}
