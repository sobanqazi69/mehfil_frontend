import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../auth/presentation/cubits/auth_cubit.dart';
import '../../../auth/presentation/cubits/auth_state.dart';
import '../../../rooms/presentation/screens/browse_rooms_screen.dart';

class HomeScreen extends StatelessWidget {
  final void Function(int roomId) onRoomTap;
  const HomeScreen({super.key, required this.onRoomTap});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBg,
      appBar: const _AppBar(),
      body: BrowseRoomsScreen(onRoomTap: onRoomTap),
      floatingActionButton: _CreateRoomFab(),
    );
  }
}

class _AppBar extends StatelessWidget implements PreferredSizeWidget {
  const _AppBar();

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.lightBg,
      elevation: 0,
      titleSpacing: 20,
      title: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: Colors.black,
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(4),
            child: Image.asset(
              'assets/images/logo_transparent.png',
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 10),
          Text('Mehfil', style: AppTextStyles.heading3),
        ],
      ),
      actions: [
        BlocBuilder<AuthCubit, AuthState>(
          builder: (context, state) {
            final avatar = state is AuthAuthenticated
                ? state.user.avatar
                : null;
            return GestureDetector(
              onTap: () => _showProfileMenu(context),
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: _AvatarWidget(avatarUrl: avatar),
              ),
            );
          },
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: AppColors.divider),
      ),
    );
  }

  void _showProfileMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ProfileSheet(
        onSignOut: () => context.read<AuthCubit>().signOut(),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 1);
}

class _AvatarWidget extends StatelessWidget {
  final String? avatarUrl;
  const _AvatarWidget({this.avatarUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.primaryGradient,
        border: Border.all(color: AppColors.fieldBorder),
      ),
      child: ClipOval(
        child: avatarUrl != null
            ? CachedNetworkImage(
                imageUrl: avatarUrl!,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => const Icon(
                  Icons.person_rounded,
                  color: AppColors.white,
                  size: 20,
                ),
              )
            : const Icon(Icons.person_rounded,
                color: AppColors.white, size: 20),
      ),
    );
  }
}

class _CreateRoomFab extends StatelessWidget {
  const _CreateRoomFab();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/youtube-picker'),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.purple.withValues(alpha: 0.45),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
      ),
    );
  }
}

class _ProfileSheet extends StatelessWidget {
  final VoidCallback onSignOut;
  const _ProfileSheet({required this.onSignOut});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        final user = state is AuthAuthenticated ? state.user : null;
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.fieldBorder,
                    borderRadius: BorderRadius.circular(2),
                  )),
              const SizedBox(height: 24),
              if (user != null) ...[
                Text(user.name, style: AppTextStyles.heading3),
                const SizedBox(height: 4),
                Text(user.email, style: AppTextStyles.bodySmall),
                const SizedBox(height: 24),
                const Divider(color: AppColors.divider),
                const SizedBox(height: 16),
              ],
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.logout_rounded,
                    color: AppColors.error),
                title: Text('Sign Out',
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.error)),
                onTap: () {
                  Navigator.pop(context);
                  onSignOut();
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
