import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_text_styles.dart';

/// Labelled text field. The label sits above the input rather than acting as a
/// placeholder, so it stays visible once the user starts typing.
class ProfileField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final IconData icon;
  final String? prefixText;
  final String? errorText;
  final String? helperText;
  final int? maxLength;
  final int maxLines;
  final Widget? suffix;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;

  const ProfileField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    required this.icon,
    this.prefixText,
    this.errorText,
    this.helperText,
    this.maxLength,
    this.maxLines = 1,
    this.suffix,
    this.inputFormatters,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: AppTextStyles.labelMedium.copyWith(
              color: const Color(0xFFFBBF24), // Gold label
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        TextField(
          controller: controller,
          onChanged: onChanged,
          inputFormatters: inputFormatters,
          maxLength: maxLength,
          maxLines: maxLines,
          // Multi-line fields grow downward, so keep the icon at the top.
          textAlignVertical:
              maxLines > 1 ? TextAlignVertical.top : TextAlignVertical.center,
          style: AppTextStyles.bodyMedium.copyWith(color: Colors.white), // White text input
          decoration: InputDecoration(
            counterText: '',
            alignLabelWithHint: maxLines > 1,
            filled: true,
            fillColor: const Color(0xFF130E26), // Dark input background
            hintText: hint,
            hintStyle:
                AppTextStyles.bodyMedium.copyWith(color: const Color(0xFFFBBF24).withValues(alpha: 0.45)),
            prefixIcon: maxLines > 1
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 34),
                    child: Icon(
                      icon,
                      size: 20,
                      color: hasError ? AppColors.error : const Color(0xFFFBBF24),
                    ),
                  )
                : Icon(
                    icon,
                    size: 20,
                    color: hasError ? AppColors.error : const Color(0xFFFBBF24),
                  ),
            prefixText: prefixText,
            prefixStyle:
                AppTextStyles.bodyMedium.copyWith(color: AppColors.grey),
            suffixIcon: suffix == null
                ? null
                : Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: suffix,
                  ),
            suffixIconConstraints:
                const BoxConstraints(minWidth: 24, minHeight: 24),
            // 56px tall: comfortably above the 44pt touch minimum.
            contentPadding: const EdgeInsets.symmetric(vertical: 18),
            border: _border(const Color(0x33F59E0B)),
            enabledBorder: _border(
              hasError ? AppColors.error.withValues(alpha: 0.6) : const Color(0x33F59E0B),
            ),
            focusedBorder: _border(
              hasError ? AppColors.error : const Color(0xFFFBBF24),
              width: 1.6,
            ),
          ),
        ),
        // Reserve the row so the field below doesn't jump when an error appears.
        Padding(
          padding: const EdgeInsets.only(left: 4, top: 6),
          child: SizedBox(
            height: 16,
            child: (errorText ?? helperText) == null
                ? null
                : Row(
                    children: [
                      if (hasError) ...[
                        const Icon(Icons.error_outline_rounded,
                            size: 13, color: AppColors.error),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          errorText ?? helperText!,
                          style: AppTextStyles.labelSmall.copyWith(
                            color:
                                hasError ? AppColors.error : const Color(0x73FBBF24),
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  OutlineInputBorder _border(Color color, {double width = 1.2}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: color, width: width),
      );
}
