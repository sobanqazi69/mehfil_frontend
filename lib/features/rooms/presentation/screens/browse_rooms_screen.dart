import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../data/models/room_model.dart';
import '../cubits/room_list_cubit.dart';
import '../cubits/room_list_state.dart';
import '../widgets/room_list_tile.dart';
import '../widgets/room_search_field.dart';

class BrowseRoomsScreen extends StatefulWidget {
  final void Function(int roomId) onRoomTap;
  const BrowseRoomsScreen({super.key, required this.onRoomTap});

  @override
  State<BrowseRoomsScreen> createState() => _BrowseRoomsScreenState();
}

class _BrowseRoomsScreenState extends State<BrowseRoomsScreen>
    with WidgetsBindingObserver {
  Timer? _refreshTimer;
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    context.read<RoomListCubit>().loadRooms();
    _startRefreshTimer();
  }

  void _startRefreshTimer() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) context.read<RoomListCubit>().refresh(silent: true);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<RoomListCubit>().refresh(silent: true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    super.dispose();
  }

  List<RoomModel> _filter(List<RoomModel> rooms) {
    if (_query.isEmpty) return rooms;
    final q = _query.toLowerCase();
    return rooms
        .where((r) =>
            r.name.toLowerCase().contains(q) ||
            (r.host?.name.toLowerCase().contains(q) ?? false))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<RoomListCubit, RoomListState>(
      listener: (context, state) {
        if (state is RoomListError) AppSnackbar.error(context, state.message);
      },
      builder: (context, state) {
        return RefreshIndicator(
          color: const Color(0xFFFBBF24),
          backgroundColor: const Color(0xFF130E26),
          onRefresh: () => context.read<RoomListCubit>().refresh(),
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                sliver: SliverToBoxAdapter(
                  child: RoomSearchField(
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
              ),
              if (state is RoomListLoading)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, __) => const _RoomTileShimmer(),
                      childCount: 7,
                    ),
                  ),
                )
              else if (state is RoomListLoaded)
                ..._loadedSlivers(state.rooms),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _loadedSlivers(List<RoomModel> allRooms) {
    final rooms = _filter(allRooms);

    if (rooms.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _query.isEmpty
              ? const _EmptyState()
              : _NoResultsState(query: _query),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        sliver: SliverToBoxAdapter(
          child: Row(
            children: [
              const Icon(Icons.public_rounded,
                  size: 16, color: Color(0x99F59E0B)),
              const SizedBox(width: 6),
              Text(
                'Public rooms',
                style: AppTextStyles.labelMedium
                    .copyWith(color: const Color(0xFFF59E0B).withValues(alpha: 0.7)),
              ),
              const Spacer(),
              Text(
                '${rooms.length}',
                style: AppTextStyles.labelSmall
                    .copyWith(color: const Color(0xFFF59E0B).withValues(alpha: 0.5)),
              ),
            ],
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (_, i) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: RoomListTile(
                room: rooms[i],
                onTap: () => widget.onRoomTap(rooms[i].id),
              ),
            ),
            childCount: rooms.length,
          ),
        ),
      ),
    ];
  }
}

// ── States ────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Intricate gold mandala with neon headphones
            Container(
              width: 230,
              height: 230,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00FFB2).withValues(alpha: 0.12),
                    blurRadius: 40,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Image.asset(
                'assets/images/mehfil_mandala_headphones.png',
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'No rooms yet',
              style: TextStyle(
                color: Color(0xFFF59E0B), // Gold color
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Be the first to start a watch party!',
              style: TextStyle(
                color: Color(0xFF00FFB2), // Neon green/cyan
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _NoResultsState extends StatelessWidget {
  final String query;
  const _NoResultsState({required this.query});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.cardBg2,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.search_off_rounded,
                  size: 36, color: AppColors.greyLight),
            ),
            const SizedBox(height: 16),
            Text('No rooms match "$query"',
                style: AppTextStyles.bodyLarge,
                textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text('Try a different name or host.',
                style: AppTextStyles.bodySmall,
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _RoomTileShimmer extends StatelessWidget {
  const _RoomTileShimmer();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Shimmer.fromColors(
        baseColor: AppColors.cardBg2,
        highlightColor: AppColors.white,
        child: Container(
          height: 90,
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }
}
