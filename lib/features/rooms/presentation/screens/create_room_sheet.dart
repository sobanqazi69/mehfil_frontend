import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/gradient_button.dart';
import '../cubits/room_list_cubit.dart';
import '../widgets/category_chip.dart';

class CreateRoomSheet extends StatefulWidget {
  final void Function(int roomId) onRoomCreated;
  const CreateRoomSheet({super.key, required this.onRoomCreated});

  @override
  State<CreateRoomSheet> createState() => _CreateRoomSheetState();
}

class _CreateRoomSheetState extends State<CreateRoomSheet> {
  final _nameCtrl = TextEditingController();
  String? _category;
  bool _isPublic = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      AppSnackbar.error(context, 'Please enter a room name');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final room = await context.read<RoomListCubit>().createRoom(
            name: name,
            isPublic: _isPublic,
            category: _category,
          );
      if (mounted) {
        Navigator.pop(context);
        widget.onRoomCreated(room.id);
      }
    } catch (e) {
      if (mounted) AppSnackbar.error(context, e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding:
          EdgeInsets.fromLTRB(24, 20, 24, 24 + bottom),
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
          const SizedBox(height: 20),
          Text('Create Room', style: AppTextStyles.heading3),
          const SizedBox(height: 20),
          TextField(
            controller: _nameCtrl,
            style: AppTextStyles.bodyMedium,
            decoration: const InputDecoration(
              hintText: 'Room name (e.g. PSL Final Watch Party)',
              prefixIcon: Icon(Icons.meeting_room_outlined,
                  color: AppColors.grey, size: 20),
            ),
          ),
          const SizedBox(height: 16),
          Text('Category', style: AppTextStyles.labelMedium),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: kCategories.skip(1).map((cat) {
              final sel = _category == cat;
              return GestureDetector(
                onTap: () =>
                    setState(() => _category = sel ? null : cat),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    gradient:
                        sel ? AppColors.primaryGradient : null,
                    color: sel ? null : AppColors.darkBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: sel
                          ? Colors.transparent
                          : AppColors.fieldBorder,
                    ),
                  ),
                  child: Text(cat,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: sel
                            ? AppColors.white
                            : AppColors.grey,
                      )),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text('Public room', style: AppTextStyles.bodyMedium),
              const Spacer(),
              Switch(
                value: _isPublic,
                onChanged: (v) => setState(() => _isPublic = v),
                activeColor: AppColors.cyan,
                inactiveTrackColor: AppColors.fieldBorder,
              ),
            ],
          ),
          const SizedBox(height: 20),
          GradientButton(
            label: 'Create Room',
            isLoading: _isLoading,
            onTap: _create,
            icon: const Icon(Icons.add_rounded,
                color: AppColors.white, size: 18),
          ),
        ],
      ),
    );
  }
}
