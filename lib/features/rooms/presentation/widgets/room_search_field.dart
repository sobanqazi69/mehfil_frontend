import 'package:flutter/material.dart';
import '../../../../config/theme/app_colors.dart';
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
    return TextField(
      controller: _controller,
      onChanged: _onChanged,
      textInputAction: TextInputAction.search,
      style: AppTextStyles.bodySmall.copyWith(color: AppColors.slate),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: AppColors.cardBg,
        hintText: 'Search rooms or hosts',
        hintStyle:
            AppTextStyles.bodySmall.copyWith(color: AppColors.greyLight),
        prefixIcon: const Icon(Icons.search_rounded,
            color: AppColors.grey, size: 20),
        suffixIcon: _hasText
            ? IconButton(
                onPressed: _clear,
                icon: const Icon(Icons.close_rounded,
                    color: AppColors.grey, size: 18),
                tooltip: 'Clear search',
              )
            : null,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: _border(AppColors.fieldBorder),
        enabledBorder: _border(AppColors.fieldBorder),
        focusedBorder: _border(AppColors.cyan, width: 1.5),
      ),
    );
  }

  OutlineInputBorder _border(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: color, width: width),
      );
}
