import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../core/utils/debug_logger.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../auth/presentation/cubits/auth_cubit.dart';
import '../../../auth/presentation/cubits/auth_state.dart';
import 'profile_avatar_editor.dart';
import 'profile_field.dart';

/// Right-side drawer holding the whole profile: photo, name, handle, bio, and
/// sign out. Everything is edited in place — there is no separate screen.
class ProfileDrawer extends StatefulWidget {
  const ProfileDrawer({super.key});

  @override
  State<ProfileDrawer> createState() => _ProfileDrawerState();
}

class _ProfileDrawerState extends State<ProfileDrawer> {
  final _nameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();

  String _initialName = '';
  String _initialUsername = '';
  String _initialBio = '';

  String? _nameError;
  String? _usernameError;

  bool _checkingUsername = false;
  bool _usernameOk = false;
  bool _saving = false;
  bool _uploading = false;

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _seedFromUser();
  }

  void _seedFromUser() {
    final state = context.read<AuthCubit>().state;
    if (state is! AuthAuthenticated) return;
    _initialName = state.user.name;
    _initialUsername = state.user.username ?? '';
    _initialBio = state.user.bio ?? '';
    _nameCtrl.text = _initialName;
    _usernameCtrl.text = _initialUsername;
    _bioCtrl.text = _initialBio;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  bool get _dirty =>
      _nameCtrl.text.trim() != _initialName ||
      _usernameCtrl.text.trim() != _initialUsername ||
      _bioCtrl.text.trim() != _initialBio;

  bool get _canSave =>
      _dirty &&
      !_saving &&
      _nameError == null &&
      _usernameError == null &&
      !_checkingUsername;

  // ── Validation ───────────────────────────────────────────────────────────

  void _onNameChanged(String value) {
    final v = value.trim();
    setState(() {
      _nameError = v.isEmpty ? 'Your name cannot be empty' : null;
    });
  }

  /// Debounced: hit the server once typing settles, not on every keystroke.
  void _onUsernameChanged(String value) {
    final v = value.trim().toLowerCase();
    _debounce?.cancel();

    setState(() {
      _usernameOk = false;
      _checkingUsername = false;
      if (v.isEmpty || v == _initialUsername) {
        _usernameError = null;
        return;
      }
      _usernameError = RegExp(r'^[a-z0-9_]{3,30}$').hasMatch(v)
          ? null
          : '3-30 characters. Letters, numbers and _ only.';
    });

    if (v.isEmpty || v == _initialUsername || _usernameError != null) return;

    setState(() => _checkingUsername = true);
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      try {
        final reason = await context.read<AuthCubit>().usernameTakenReason(v);
        if (!mounted) return;
        setState(() {
          _checkingUsername = false;
          _usernameError = reason;
          _usernameOk = reason == null;
        });
      } catch (e) {
        DebugLogger.error('username check failed', error: e);
        if (mounted) setState(() => _checkingUsername = false);
      }
    });
  }

  // ── Actions ──────────────────────────────────────────────────────────────

  Future<void> _pickAvatar() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 720,
        maxHeight: 720,
        imageQuality: 85,
      );
      if (picked == null || !mounted) return;

      setState(() => _uploading = true);
      await context.read<AuthCubit>().uploadAvatar(picked.path);
      if (!mounted) return;
      AppSnackbar.success(context, 'Photo updated');
    } catch (e) {
      DebugLogger.error('pickAvatar failed', error: e);
      if (mounted) AppSnackbar.error(context, e.toString());
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    if (!_canSave) return;
    FocusScope.of(context).unfocus();

    final name = _nameCtrl.text.trim();
    final username = _usernameCtrl.text.trim().toLowerCase();
    final bio = _bioCtrl.text.trim();

    try {
      setState(() => _saving = true);
      await context.read<AuthCubit>().updateProfile(
            name: name != _initialName ? name : null,
            username: username != _initialUsername ? username : null,
            bio: bio != _initialBio ? bio : null,
          );
      if (!mounted) return;

      setState(() {
        _initialName = name;
        _initialUsername = username;
        _initialBio = bio;
        _usernameOk = false;
      });
      AppSnackbar.success(context, 'Profile saved');
    } catch (e) {
      DebugLogger.error('save profile failed', error: e);
      if (!mounted) return;
      // The server has the last word on uniqueness — pin it to the field.
      final msg = e.toString();
      if (msg.toLowerCase().contains('username')) {
        setState(() => _usernameError = msg);
      } else {
        AppSnackbar.error(context, msg);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You will need to sign in again to join rooms.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Sign out',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    Navigator.pop(context); // close the drawer
    context.read<AuthCubit>().signOut();
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.lightBg,
      child: SafeArea(
        child: BlocBuilder<AuthCubit, AuthState>(
          builder: (context, state) {
            final user = state is AuthAuthenticated ? state.user : null;

            return Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    children: [
                      Center(
                        child: ProfileAvatarEditor(
                          avatarUrl: user?.avatar,
                          name: user?.name ?? '',
                          uploading: _uploading,
                          onTap: _uploading ? null : _pickAvatar,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Center(
                        child: Text(
                          user?.email ?? '',
                          style: AppTextStyles.labelSmall
                              .copyWith(color: AppColors.greyLight),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 28),

                      ProfileField(
                        label: 'Name',
                        hint: 'How you appear in rooms',
                        controller: _nameCtrl,
                        icon: Icons.person_outline_rounded,
                        errorText: _nameError,
                        maxLength: 100,
                        onChanged: _onNameChanged,
                      ),
                      const SizedBox(height: 16),

                      ProfileField(
                        label: 'Username',
                        hint: 'yourhandle',
                        controller: _usernameCtrl,
                        icon: Icons.alternate_email_rounded,
                        errorText: _usernameError,
                        helperText: 'Your unique handle.',
                        maxLength: 30,
                        // Enforce the format at the keyboard so an invalid
                        // handle is hard to even type.
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[a-zA-Z0-9_]')),
                          _LowerCaseFormatter(),
                        ],
                        suffix: _UsernameStatus(
                          checking: _checkingUsername,
                          ok: _usernameOk,
                        ),
                        onChanged: _onUsernameChanged,
                      ),
                      const SizedBox(height: 16),

                      ProfileField(
                        label: 'Bio',
                        hint: 'Say something about yourself',
                        controller: _bioCtrl,
                        icon: Icons.edit_note_rounded,
                        helperText: 'Up to 160 characters.',
                        maxLength: 160,
                        maxLines: 3,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 8),

                      _SaveButton(
                        enabled: _canSave,
                        saving: _saving,
                        onSave: _save,
                      ),
                    ],
                  ),
                ),

                const Divider(color: AppColors.divider, height: 1),
                _SignOutRow(onTap: _confirmSignOut),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Handles are lowercase everywhere, so normalise as they type rather than
/// silently rewriting on save.
class _LowerCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) =>
      newValue.copyWith(text: newValue.text.toLowerCase());
}

class _UsernameStatus extends StatelessWidget {
  final bool checking;
  final bool ok;

  const _UsernameStatus({required this.checking, required this.ok});

  @override
  Widget build(BuildContext context) {
    if (checking) {
      return const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.grey,
        ),
      );
    }
    if (ok) {
      return const Icon(Icons.check_circle_rounded,
          color: AppColors.success, size: 20);
    }
    return const SizedBox.shrink();
  }
}

class _SaveButton extends StatelessWidget {
  final bool enabled;
  final bool saving;
  final VoidCallback onSave;

  const _SaveButton({
    required this.enabled,
    required this.saving,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      // Stays legible when disabled rather than vanishing.
      opacity: enabled || saving ? 1 : 0.4,
      child: GestureDetector(
        onTap: enabled ? onSave : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 48,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(14),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: AppColors.purple.withValues(alpha: 0.3),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    'Save changes',
                    style: AppTextStyles.button.copyWith(color: Colors.white),
                  ),
          ),
        ),
      ),
    );
  }
}

class _SignOutRow extends StatelessWidget {
  final VoidCallback onTap;
  const _SignOutRow({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          child: Row(
            children: [
              const Icon(Icons.logout_rounded,
                  color: AppColors.error, size: 20),
              const SizedBox(width: 14),
              Text(
                'Sign out',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
