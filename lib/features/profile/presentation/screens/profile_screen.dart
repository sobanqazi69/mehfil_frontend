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
import '../widgets/profile_avatar_editor.dart';
import '../widgets/profile_field.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();

  String _initialName = '';
  String _initialUsername = '';

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
    final state = context.read<AuthCubit>().state;
    if (state is AuthAuthenticated) {
      _initialName = state.user.name;
      _initialUsername = state.user.username ?? '';
      _nameCtrl.text = _initialName;
      _usernameCtrl.text = _initialUsername;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    super.dispose();
  }

  bool get _dirty =>
      _nameCtrl.text.trim() != _initialName ||
      _usernameCtrl.text.trim() != _initialUsername;

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
      _nameError = v.isEmpty
          ? 'Your name cannot be empty'
          : (v.length > 100 ? 'Keep it under 100 characters' : null);
    });
  }

  /// Debounced so we hit the server once the user stops typing, not per key.
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

    try {
      setState(() => _saving = true);
      await context.read<AuthCubit>().updateProfile(
            name: name != _initialName ? name : null,
            username: username != _initialUsername ? username : null,
          );
      if (!mounted) return;

      setState(() {
        _initialName = name;
        _initialUsername = username;
        _usernameOk = false;
      });
      AppSnackbar.success(context, 'Profile saved');
    } catch (e) {
      DebugLogger.error('save profile failed', error: e);
      if (!mounted) return;
      // Server is the final word on uniqueness — surface it on the field.
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

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        final user = state is AuthAuthenticated ? state.user : null;

        return Scaffold(
          backgroundColor: AppColors.lightBg,
          appBar: AppBar(
            backgroundColor: AppColors.lightBg,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded,
                  color: AppColors.slate),
              onPressed: () => Navigator.pop(context),
              tooltip: 'Back',
            ),
            title: Text('Edit profile', style: AppTextStyles.heading3),
          ),
          body: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
              children: [
                Center(
                  child: ProfileAvatarEditor(
                    avatarUrl: user?.avatar,
                    name: user?.name ?? '',
                    uploading: _uploading,
                    onTap: _uploading ? null : _pickAvatar,
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    user?.email ?? '',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.grey),
                  ),
                ),
                const SizedBox(height: 32),

                ProfileField(
                  label: 'Display name',
                  hint: 'How you appear in rooms',
                  controller: _nameCtrl,
                  icon: Icons.person_outline_rounded,
                  errorText: _nameError,
                  maxLength: 100,
                  onChanged: _onNameChanged,
                ),
                const SizedBox(height: 20),

                ProfileField(
                  label: 'Username',
                  hint: 'yourhandle',
                  controller: _usernameCtrl,
                  icon: Icons.alternate_email_rounded,
                  prefixText: '@',
                  errorText: _usernameError,
                  helperText: 'Your unique handle. Others can find you by it.',
                  maxLength: 30,
                  // Enforce the format at the keyboard, so an invalid handle is
                  // hard to even type.
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_]')),
                    LowerCaseFormatter(),
                  ],
                  suffix: _UsernameStatus(
                    checking: _checkingUsername,
                    ok: _usernameOk,
                  ),
                  onChanged: _onUsernameChanged,
                ),
              ],
            ),
          ),
          bottomNavigationBar: _SaveBar(
            enabled: _canSave,
            saving: _saving,
            onSave: _save,
          ),
        );
      },
    );
  }
}

/// Handles are lowercase everywhere; do it as they type rather than silently
/// rewriting on save.
class LowerCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toLowerCase());
  }
}

class _UsernameStatus extends StatelessWidget {
  final bool checking;
  final bool ok;

  const _UsernameStatus({required this.checking, required this.ok});

  @override
  Widget build(BuildContext context) {
    if (checking) {
      return const Padding(
        padding: EdgeInsets.all(14),
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.grey,
          ),
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

class _SaveBar extends StatelessWidget {
  final bool enabled;
  final bool saving;
  final VoidCallback onSave;

  const _SaveBar({
    required this.enabled,
    required this.saving,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: Opacity(
          // Disabled state stays legible rather than vanishing.
          opacity: enabled || saving ? 1 : 0.45,
          child: GestureDetector(
            onTap: enabled ? onSave : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 52,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: enabled
                    ? [
                        BoxShadow(
                          color: AppColors.purple.withValues(alpha: 0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Save changes',
                        style: AppTextStyles.button
                            .copyWith(color: Colors.white),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
