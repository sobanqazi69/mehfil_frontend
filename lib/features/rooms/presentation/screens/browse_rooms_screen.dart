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
          color: AppColors.cyan,
          backgroundColor: AppColors.cardBg,
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
                  size: 16, color: AppColors.grey),
              const SizedBox(width: 6),
              Text(
                'Public rooms',
                style: AppTextStyles.labelMedium
                    .copyWith(color: AppColors.grey),
              ),
              const Spacer(),
              Text(
                '${rooms.length}',
                style: AppTextStyles.labelSmall
                    .copyWith(color: AppColors.greyLight),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.cyan.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.headphones_outlined,
              size: 40,
              color: AppColors.cyan.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 16),
          Text('No rooms yet', style: AppTextStyles.bodyLarge),
          const SizedBox(height: 6),
          Text('Be the first to start a watch party!',
              style: AppTextStyles.bodySmall),
        ],
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
