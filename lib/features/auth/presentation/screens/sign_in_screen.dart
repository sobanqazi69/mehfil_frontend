import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../cubits/auth_cubit.dart';
import '../widgets/email_sign_in_sheet.dart';
import '../cubits/auth_state.dart';

class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is AuthError) AppSnackbar.error(context, state.message);
      },
      child: Scaffold(
        backgroundColor: AppColors.lightBg,
        body: Stack(
          children: [
            const _MeshBackground(),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: [
                    const Spacer(flex: 2),
                    const _LogoSection(),
                    const Spacer(flex: 3),
                    const _GoogleSignInButton(),
                    const SizedBox(height: 8),
                    const _EmailSignInLink(),
                    const SizedBox(height: 24),
                    Text(
                      'By signing in you agree to our Terms of Service',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.grey.withValues(alpha: 0.8),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const Spacer(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Glowing orb mesh background ───────────────────────────────────────────

class _MeshBackground extends StatelessWidget {
  const _MeshBackground();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return SizedBox.expand(
      child: Stack(
        children: [
          // Blue orb — top left
          Positioned(
            top: -size.height * 0.15,
            left: -size.width * 0.25,
            child: _Orb(
              size: size.width * 0.9,
              color: AppColors.cyan.withValues(alpha: 0.08),
            ),
          ),
          // Indigo orb — bottom right
          Positioned(
            bottom: -size.height * 0.12,
            right: -size.width * 0.3,
            child: _Orb(
              size: size.width * 1.0,
              color: AppColors.purple.withValues(alpha: 0.06),
            ),
          ),
        ],
      ),
    );
  }
}

class _Orb extends StatelessWidget {
  final double size;
  final Color color;
  const _Orb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color,
            blurRadius: 100,
            spreadRadius: 20,
          ),
        ],
      ),
    );
  }
}

// ── Logo + branding ───────────────────────────────────────────────────────

class _LogoSection extends StatelessWidget {
  const _LogoSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.cyan.withValues(alpha: 0.06),
              ),
            ),
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: Colors.black,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.cyan.withValues(alpha: 0.3),
                    blurRadius: 30,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(12),
              child: Image.asset(
                'assets/images/logo_transparent.png',
                fit: BoxFit.contain,
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        Text('Mehfil', style: AppTextStyles.heading1.copyWith(fontSize: 40)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.fieldBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            'Watch Party  ·  Music  ·  Friends',
            style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.grey,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }
}

/// Secondary, low-emphasis path. Google stays the one primary CTA.
class _EmailSignInLink extends StatelessWidget {
  const _EmailSignInLink();

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => showEmailSignInSheet(context),
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 44),
        foregroundColor: AppColors.grey,
      ),
      child: Text(
        'Sign in with email',
        style: AppTextStyles.bodySmall.copyWith(
          color: AppColors.grey,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ── Google sign-in button ─────────────────────────────────────────────────

class _GoogleSignInButton extends StatelessWidget {
  const _GoogleSignInButton();

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
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.fieldBorder,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: isLoading
                ? const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation(AppColors.cyan),
                      ),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _GoogleIcon(),
                      const SizedBox(width: 16),
                      Text(
                        'Continue with Google',
                        style: AppTextStyles.button.copyWith(
                          color: AppColors.slate,
                          fontSize: 17,
                        ),
                      ),
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
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.white,
        border: Border.all(color: AppColors.fieldBorder.withValues(alpha: 0.5)),
      ),
      padding: const EdgeInsets.all(6),
      child: Image.network(
        'https://www.google.com/favicon.ico',
        errorBuilder: (_, __, ___) => const Icon(
          Icons.g_mobiledata_rounded,
          color: Color(0xFF4285F4),
          size: 22,
        ),
      ),
    );
  }
}
