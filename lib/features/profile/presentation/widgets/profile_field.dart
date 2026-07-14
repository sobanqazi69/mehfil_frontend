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
              color: AppColors.slate,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        TextField(
          controller: controller,
          onChanged: onChanged,
          inputFormatters: inputFormatters,
          maxLength: maxLength,
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.slate),
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: AppColors.cardBg,
            hintText: hint,
            hintStyle:
                AppTextStyles.bodyMedium.copyWith(color: AppColors.greyLight),
            prefixIcon: Icon(
              icon,
              size: 20,
              color: hasError ? AppColors.error : AppColors.grey,
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
            border: _border(AppColors.fieldBorder),
            enabledBorder: _border(
              hasError ? AppColors.error.withValues(alpha: 0.6) : AppColors.fieldBorder,
            ),
            focusedBorder: _border(
              hasError ? AppColors.error : AppColors.cyan,
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
                                hasError ? AppColors.error : AppColors.greyLight,
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
