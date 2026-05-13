import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../cubits/room_list_cubit.dart';
import '../cubits/room_list_state.dart';
import '../widgets/category_chip.dart';
import '../widgets/room_card.dart';

class BrowseRoomsScreen extends StatefulWidget {
  final void Function(int roomId) onRoomTap;
  const BrowseRoomsScreen({super.key, required this.onRoomTap});

  @override
  State<BrowseRoomsScreen> createState() => _BrowseRoomsScreenState();
}

class _BrowseRoomsScreenState extends State<BrowseRoomsScreen> {
  @override
  void initState() {
    super.initState();
    context.read<RoomListCubit>().loadRooms();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<RoomListCubit, RoomListState>(
      listener: (context, state) {
        if (state is RoomListError) {
          AppSnackbar.error(context, state.message);
        }
      },
      builder: (context, state) {
        return RefreshIndicator(
          color: AppColors.cyan,
          backgroundColor: AppColors.cardBg,
          onRefresh: () => context.read<RoomListCubit>().refresh(),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 12),
                  child: CategoryChipRow(
                    selected: state is RoomListLoaded
                        ? state.selectedCategory
                        : 'All',
                    onSelect: (cat) =>
                        context.read<RoomListCubit>().changeCategory(cat),
                  ),
                ),
              ),
              if (state is RoomListLoading)
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, __) => const _RoomCardShimmer(),
                      childCount: 6,
                    ),
                  ),
                )
              else if (state is RoomListLoaded && state.rooms.isEmpty)
                SliverFillRemaining(child: _EmptyState())
              else if (state is RoomListLoaded)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: RoomCard(
                          room: state.rooms[i],
                          onTap: () =>
                              widget.onRoomTap(state.rooms[i].id),
                        ),
                      ),
                      childCount: state.rooms.length,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.headphones_outlined,
              size: 64, color: AppColors.grey.withOpacity(0.4)),
          const SizedBox(height: 16),
          Text('No rooms yet', style: AppTextStyles.bodyLarge),
          const SizedBox(height: 6),
          Text('Be the first to create one!',
              style: AppTextStyles.bodySmall),
        ],
      ),
    );
  }
}

class _RoomCardShimmer extends StatelessWidget {
  const _RoomCardShimmer();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Shimmer.fromColors(
        baseColor: AppColors.cardBg,
        highlightColor: AppColors.cardBg2,
        child: Container(
          height: 100,
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}
