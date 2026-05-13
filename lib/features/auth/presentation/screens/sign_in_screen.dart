import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../cubits/auth_cubit.dart';
import '../cubits/auth_state.dart';

class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is AuthError) {
          AppSnackbar.error(context, state.message);
        }
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: AppColors.bgGradient),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  _Logo(),
                  const SizedBox(height: 16),
                  Text('Mehfil', style: AppTextStyles.heading1),
                  const SizedBox(height: 8),
                  Text(
                    'Audio rooms · YouTube together · Open mic',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const Spacer(flex: 3),
                  _GoogleSignInButton(),
                  const SizedBox(height: 24),
                  Text(
                    'By signing in, you agree to our Terms of Service',
                    style: AppTextStyles.labelSmall,
                    textAlign: TextAlign.center,
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
              color: AppColors.purple.withOpacity(0.5),
              blurRadius: 30,
              spreadRadius: 4),
        ],
      ),
      child: const Icon(Icons.headphones_rounded,
          color: AppColors.white, size: 44),
    );
  }
}

class _GoogleSignInButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        final isLoading = state is AuthLoading;
        return GestureDetector(
          onTap: isLoading
              ? null
              : () => context.read<AuthCubit>().signInWithGoogle(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.fieldBorder, width: 1.5),
              boxShadow: [
                BoxShadow(
                    color: AppColors.cyan.withOpacity(0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 4)),
              ],
            ),
            child: isLoading
                ? const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor:
                            AlwaysStoppedAnimation(AppColors.cyan),
                      ),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _GoogleIcon(),
                      const SizedBox(width: 12),
                      Text('Continue with Google',
                          style: AppTextStyles.button
                              .copyWith(color: AppColors.white)),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

class _GoogleIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: const BoxDecoration(
          shape: BoxShape.circle, color: Colors.white),
      padding: const EdgeInsets.all(3),
      child: Image.network(
        'https://www.google.com/favicon.ico',
        errorBuilder: (_, __, ___) => const Icon(
          Icons.g_mobiledata_rounded,
          color: AppColors.darkBg,
          size: 20,
        ),
      ),
    );
  }
}
