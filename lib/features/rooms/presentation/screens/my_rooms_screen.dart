import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../cubits/room_list_cubit.dart';
import '../cubits/room_list_state.dart';
import '../widgets/room_card.dart';

class MyRoomsScreen extends StatefulWidget {
  final void Function(int roomId) onRoomTap;
  const MyRoomsScreen({super.key, required this.onRoomTap});

  @override
  State<MyRoomsScreen> createState() => _MyRoomsScreenState();
}

class _MyRoomsScreenState extends State<MyRoomsScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    context.read<RoomListCubit>().loadMyRooms();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return BlocConsumer<RoomListCubit, RoomListState>(
      listener: (context, state) {
        if (state is RoomListError) {
          AppSnackbar.error(context, state.message);
        }
      },
      builder: (context, state) {
        if (state is RoomListLoading) {
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: 4,
            itemBuilder: (_, __) => Padding(
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
            ),
          );
        }

        if (state is RoomListLoaded && state.rooms.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.meeting_room_outlined,
                    size: 64,
                    color: AppColors.grey.withOpacity(0.4)),
                const SizedBox(height: 16),
                Text("You haven't created any rooms",
                    style: AppTextStyles.bodyLarge),
                const SizedBox(height: 6),
                Text('Tap + to create your first room',
                    style: AppTextStyles.bodySmall),
              ],
            ),
          );
        }

        if (state is RoomListLoaded) {
          return RefreshIndicator(
            color: AppColors.cyan,
            backgroundColor: AppColors.cardBg,
            onRefresh: () => context.read<RoomListCubit>().loadMyRooms(),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: state.rooms.length,
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: RoomCard(
                  room: state.rooms[i],
                  onTap: () => widget.onRoomTap(state.rooms[i].id),
                ),
              ),
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }
}
