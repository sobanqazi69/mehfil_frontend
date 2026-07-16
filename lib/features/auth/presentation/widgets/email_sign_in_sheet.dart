import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../cubits/auth_cubit.dart';

/// Email + password sign-in. Google is the path real users take; this exists so
/// store reviewers can always get in, since Google's challenge blocks them on
/// an unfamiliar device.
Future<void> showEmailSignInSheet(BuildContext context) {
  final cubit = context.read<AuthCubit>();
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: const _EmailSignInSheet(),
    ),
  );
}

class _EmailSignInSheet extends StatefulWidget {
  const _EmailSignInSheet();

  @override
  State<_EmailSignInSheet> createState() => _EmailSignInSheetState();
}

class _EmailSignInSheetState extends State<_EmailSignInSheet> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _submitting = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text;
    if (email.isEmpty || password.isEmpty || _submitting) return;

    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);
    await context.read<AuthCubit>().signInWithEmail(email, password);
    if (mounted) {
      setState(() => _submitting = false);
      // The router reacts to auth state; just close the sheet.
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
        decoration: const BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.fieldBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('Sign in with email', style: AppTextStyles.heading3),
            const SizedBox(height: 6),
            Text(
              'Use the credentials provided for your account.',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.grey),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              textInputAction: TextInputAction.next,
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.slate),
              decoration: InputDecoration(
                labelText: 'Email',
                prefixIcon: const Icon(Icons.mail_outline_rounded,
                    size: 20, color: AppColors.grey),
                border: _border(AppColors.fieldBorder),
                enabledBorder: _border(AppColors.fieldBorder),
                focusedBorder: _border(AppColors.cyan, width: 1.6),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _passCtrl,
              obscureText: _obscure,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.slate),
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline_rounded,
                    size: 20, color: AppColors.grey),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    size: 20,
                    color: AppColors.grey,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
                border: _border(AppColors.fieldBorder),
                enabledBorder: _border(AppColors.fieldBorder),
                focusedBorder: _border(AppColors.cyan, width: 1.6),
              ),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: _submitting ? null : _submit,
              child: Container(
                height: 54,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text('Sign in',
                          style: AppTextStyles.button
                              .copyWith(color: Colors.white)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  OutlineInputBorder _border(Color color, {double width = 1.2}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: color, width: width),
      );
}
