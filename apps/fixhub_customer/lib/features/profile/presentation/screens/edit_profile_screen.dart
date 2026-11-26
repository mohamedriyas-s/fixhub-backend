import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/config/theme/app_spacing.dart';
import '../../../../core/widgets/fixhub_app_bar.dart';
import '../../../../core/widgets/fixhub_button.dart';
import '../../../../core/widgets/fixhub_network_image.dart';
import '../../../../core/widgets/fixhub_snackbar.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/services/profile_upload_service.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;

  File? _pickedImage;
  bool _isUploading = false;
  bool _isSaving = false;
  double _uploadProgress = 0;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    _nameController = TextEditingController(text: user?.name ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // ── Avatar picking ─────────────────────────────────────────────────

  Future<void> _showImageSourceSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Update Profile Photo',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 20),
              _SourceTile(
                icon: Icons.photo_library_rounded,
                label: 'Choose from Gallery',
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              const SizedBox(height: 12),
              _SourceTile(
                icon: Icons.camera_alt_rounded,
                label: 'Take a Photo',
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1024,
    );
    if (xfile != null && mounted) {
      setState(() => _pickedImage = File(xfile.path));
    }
  }

  // ── Save (upload + profile update) ────────────────────────────────

  Future<void> _saveProfile() async {
    if (_formKey.currentState?.validate() != true) return;

    final service = ref.read(profileUploadServiceProvider);

    setState(() => _isSaving = true);
    try {
      // Upload avatar first (if a new one was picked)
      if (_pickedImage != null) {
        setState(() {
          _isUploading = true;
          _uploadProgress = 0;
        });

        // Animate progress while uploading (S3 doesn't stream progress easily
        // with read(), so we fake a smooth bar then complete when done)
        final progressTimer = _startFakeProgress();
        try {
          await service.uploadProfileImage(_pickedImage!);
          progressTimer.cancel();
          setState(() => _uploadProgress = 1.0);
        } finally {
          setState(() => _isUploading = false);
        }
      }

      // Update name/email
      await service.updateProfile(
        name: _nameController.text,
        email: _emailController.text,
        phone: _phoneController.text,
      );

      // Refresh profile in AuthProvider so the UI syncs everywhere
      await ref.read(authProvider.notifier).refreshProfile();

      if (mounted) {
        FixHubSnackbar.success(context, 'Profile updated successfully!');
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        FixHubSnackbar.error(context, 'Failed to save profile. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  _FakeTimer _startFakeProgress() {
    return _FakeTimer(() {
      if (mounted && _uploadProgress < 0.9) {
        setState(() => _uploadProgress += 0.05);
      }
    });
  }

  // ── UI ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final existingAvatarUrl = user?.profile?.profilePictureUrl;
    final displayName = user?.displayName ?? 'Customer';
    final firstLetter = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'C';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const FixHubAppBar(title: 'Edit Profile'),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          children: [
            // ── Avatar ───────────────────────────────────────────────
            Center(
              child: GestureDetector(
                onTap: _showImageSourceSheet,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 104,
                      height: 104,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.surface,
                        border: Border.all(color: AppColors.border, width: 0.5),
                      ),
                      child: ClipOval(
                        child: _buildAvatarContent(
                          pickedImage: _pickedImage,
                          avatarUrl: existingAvatarUrl,
                          firstLetter: firstLetter,
                          isUploading: _isUploading,
                          uploadProgress: _uploadProgress,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: AppColors.buttonPrimary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          color: AppColors.buttonPrimaryText,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.xs),
            Center(
              child: Text(
                'Tap to change photo',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // ── Full Name ─────────────────────────────────────────────
            _FieldLabel(text: 'Full Name'),
            const SizedBox(height: AppSpacing.xs),
            TextFormField(
              controller: _nameController,
              textInputAction: TextInputAction.next,
              decoration: _inputDecoration(hint: 'Enter your full name'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Please enter your name' : null,
            ),

            const SizedBox(height: AppSpacing.md),

            // ── Email ─────────────────────────────────────────────────
            _FieldLabel(text: 'Email Address'),
            const SizedBox(height: AppSpacing.xs),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              decoration: _inputDecoration(hint: 'Enter your email (optional)'),
            ),

            const SizedBox(height: AppSpacing.md),

            _FieldLabel(text: 'Booking Contact Number'),
            const SizedBox(height: AppSpacing.xs),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: _inputDecoration(hint: '+91 98765 43210'),
            ),

            const SizedBox(height: AppSpacing.xxl),

            // ── Save Button ───────────────────────────────────────────
            FixHubButton(
              label: _isSaving ? 'Saving…' : 'Save Changes',
              onPressed: (_isSaving || _isUploading) ? null : _saveProfile,
            ),

            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({required String hint}) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.buttonPrimary, width: 1.5),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _buildAvatarContent({
    required File? pickedImage,
    required String? avatarUrl,
    required String firstLetter,
    required bool isUploading,
    required double uploadProgress,
  }) {
    if (isUploading) {
      return Stack(
        alignment: Alignment.center,
        children: [
          if (pickedImage != null)
            Image.file(pickedImage, fit: BoxFit.cover, width: 104, height: 104),
          Container(color: Colors.black38),
          CircularProgressIndicator(
            value: uploadProgress > 0 ? uploadProgress : null,
            color: AppColors.surface,
            strokeWidth: 2.5,
          ),
        ],
      );
    }

    if (pickedImage != null) {
      return Image.file(pickedImage, fit: BoxFit.cover, width: 104, height: 104);
    }

    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return FixHubNetworkImage(
        avatarUrl,
        fit: BoxFit.cover,
        width: 104,
        height: 104,
        errorBuilder: (_, __, ___) => _InitialAvatar(firstLetter: firstLetter),
      );
    }

    return _InitialAvatar(firstLetter: firstLetter);
  }
}

// ── Supporting widgets ────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
    );
  }
}

class _InitialAvatar extends StatelessWidget {
  const _InitialAvatar({required this.firstLetter});
  final String firstLetter;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      alignment: Alignment.center,
      child: Text(
        firstLetter,
        style: Theme.of(context).textTheme.displaySmall?.copyWith(
              color: AppColors.textPrimary,
            ),
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: AppColors.textPrimary),
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

// Minimal timer helper that fires a callback repeatedly
class _FakeTimer {
  _FakeTimer(this._onTick) {
    _tick();
  }

  final VoidCallback _onTick;
  bool _cancelled = false;

  void _tick() {
    if (_cancelled) return;
    Future.delayed(const Duration(milliseconds: 200), () {
      _onTick();
      _tick();
    });
  }

  void cancel() => _cancelled = true;
}
