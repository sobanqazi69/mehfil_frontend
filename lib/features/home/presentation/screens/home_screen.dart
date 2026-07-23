import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../core/utils/debug_logger.dart';
import '../../../../core/utils/map_utils.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../auth/presentation/cubits/auth_cubit.dart';
import '../../../auth/presentation/cubits/auth_state.dart';
import '../../../rooms/presentation/cubits/room_list_cubit.dart';
import '../../../profile/presentation/widgets/profile_drawer.dart';
import '../../../rooms/presentation/screens/browse_rooms_screen.dart';
import '../../../rooms/presentation/screens/youtube_picker_screen.dart';

class HomeScreen extends StatelessWidget {
  final void Function(int roomId) onRoomTap;
  const HomeScreen({super.key, required this.onRoomTap});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.roomBgTop,
      extendBodyBehindAppBar: true, // Let background flow behind AppBar
      appBar: const _AppBar(),
      endDrawer: const ProfileDrawer(),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.roomBgTop,
          image: DecorationImage(
            image: const AssetImage('assets/images/mehfil_background.jpg'),
            fit: BoxFit.cover,
            alignment: Alignment.center,
            colorFilter: ColorFilter.mode(
              AppColors.roomBgTop.withValues(alpha: 0.50), // 90% dark overlay
              BlendMode.srcOver,
            ),
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: BrowseRoomsScreen(onRoomTap: onRoomTap),
        ),
      ),
      floatingActionButton: const _CreateRoomFab(),
    );
  }
}

class _AppBar extends StatelessWidget implements PreferredSizeWidget {
  const _AppBar();

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0, // Keep transparent on scroll
      titleSpacing: 20,
      title: Row(
        children: [
          // Premium Gold Headphones logo badge
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFBBF24), Color(0xFFD97706)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD97706).withValues(alpha: 0.35),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            padding: const EdgeInsets.all(6),
            child: Image.asset(
              'assets/images/logo_transparent.png',
              fit: BoxFit.contain,
              color: Colors.black, // Dark headphones silhouette on gold
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Mehfil',
            style: AppTextStyles.heading3.copyWith(
              color: const Color(0xFFF59E0B),
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
      actions: [
        BlocBuilder<AuthCubit, AuthState>(
          builder: (context, state) {
            final avatar =
                state is AuthAuthenticated ? state.user.avatar : null;
            return GestureDetector(
              onTap: () => Scaffold.of(context).openEndDrawer(),
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: _AvatarWidget(avatarUrl: avatar),
              ),
            );
          },
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
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
        gradient: const LinearGradient(
          colors: [Color(0xFFFBBF24), Color(0xFFD97706)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFBBF24).withValues(alpha: 0.25),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipOval(
        child: avatarUrl != null
            ? CachedNetworkImage(
                imageUrl: avatarUrl!,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => const Icon(
                  Icons.person_rounded,
                  color: Colors.black,
                  size: 20,
                ),
              )
            : const Icon(Icons.person_rounded, color: Colors.black, size: 20),
      ),
    );
  }
}

class _CreateRoomFab extends StatelessWidget {
  const _CreateRoomFab();

  Future<void> _createRoom(BuildContext context) async {
    try {
      final result = await Navigator.push<Map>(
        context,
        MaterialPageRoute(builder: (_) => const YoutubePickerScreen()),
      );
      if (result == null || !context.mounted) return;

      final data = MapUtils.asMap(result);
      final youtubeId = MapUtils.handleNullableStringKey(data, 'id');
      if (youtubeId == null || youtubeId.isEmpty) return;
      final name =
          MapUtils.handleNullableStringKey(data, 'title') ?? 'Watch Party';

      AppLoader.show(context);
      final room = await context
          .read<RoomListCubit>()
          .createRoom(name: name, youtubeId: youtubeId);
      if (!context.mounted) return;
      AppLoader.hide();

      context.push('/room/${room.id}');
    } catch (e) {
      DebugLogger.error('createRoom from home failed', error: e);
      if (context.mounted) {
        AppLoader.hide();
        AppSnackbar.error(context, e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _createRoom(context),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFBBF24), Color(0xFFD97706)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00FFB2).withValues(alpha: 0.45),
              blurRadius: 16,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(Icons.add_rounded, color: Colors.black, size: 28),
      ),
    );
  }
}
