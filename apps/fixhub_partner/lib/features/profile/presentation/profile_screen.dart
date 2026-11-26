import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/theme/app_colors.dart';
import '../../../core/config/theme/app_spacing.dart';
import '../../../core/config/theme/app_radius.dart';
import '../../../core/widgets/fp_card.dart';
import '../../../core/widgets/fp_skeleton.dart';
import '../../../core/widgets/fp_offline_banner.dart';
import '../../../core/widgets/fp_button.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../../core/error/failures.dart';
import 'profile_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  bool _isEditing = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: const Text(
          'My Profile',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          if (!_isEditing)
            TextButton(
              onPressed: () {
                final p = profileAsync.value;
                if (p != null) {
                  _nameController.text = p.name ?? '';
                  _emailController.text = p.email ?? '';
                }
                setState(() => _isEditing = true);
              },
              child: const Text('Edit'),
            )
          else
            TextButton(
              onPressed: () => setState(() => _isEditing = false),
              child: const Text('Cancel'),
            ),
        ],
      ),
      body: profileAsync.when(
        skipLoadingOnReload: profileAsync.value != null,
        skipLoadingOnRefresh: profileAsync.value != null,
        loading: () => const Center(child: FpPageLoader()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FpErrorState(
                  message: 'Could not load profile',
                  onRetry: () => ref.read(profileProvider.notifier).load(),
                ),
                const SizedBox(height: AppSpacing.lg),
                FpButton(
                  label: 'Logout',
                  variant: FpButtonVariant.secondary,
                  onPressed: () async {
                    await ref.read(authProvider.notifier).logout();
                    if (context.mounted) context.go('/login');
                  },
                ),
              ],
            ),
          ),
        ),
        data: (profile) {
          if (profile == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && !ref.read(profileProvider).isLoading) {
                ref.read(profileProvider.notifier).load();
              }
            });
            return const Center(child: FpPageLoader());
          }

          return RefreshIndicator(
            onRefresh: () => ref.read(profileProvider.notifier).load(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
            child: Column(
              children: [
                // ── Avatar ───────────────────────────────────────
                Center(
                  child: Stack(
                    children: [
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.border, width: 2),
                        ),
                        child: ClipOval(
                          child: profile.profilePictureUrl != null
                              ? Image.network(
                                  profile.profilePictureUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      _AvatarPlaceholder(
                                        name: profile.displayName,
                                      ),
                                )
                              : _AvatarPlaceholder(name: profile.displayName),
                        ),
                      ),
                      if (_isEditing)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(
                              Icons.camera_alt_outlined,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                Text(
                  profile.displayName,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                _VerificationBadge(status: profile.verificationStatus),
                const SizedBox(height: AppSpacing.xl),

                // ── Stats ─────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: _MiniStat(
                        icon: Icons.star_rounded,
                        value: profile.rating.toStringAsFixed(1),
                        label: 'Rating',
                        iconColor: const Color(0xFFD4A017),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _MiniStat(
                        icon: Icons.check_circle_outline_rounded,
                        value: profile.totalJobs.toString(),
                        label: 'Jobs Done',
                        iconColor: AppColors.success,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _MiniStat(
                        icon: Icons.location_on_outlined,
                        value: profile.serviceAreas.length.toString(),
                        label: 'Areas',
                        iconColor: AppColors.info,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.xl),

                // ── Info / Edit ───────────────────────────────────
                if (_isEditing)
                  _EditForm(
                    nameController: _nameController,
                    emailController: _emailController,
                    isSaving: _isSaving,
                    onSave: () async {
                      setState(() => _isSaving = true);
                      try {
                        final updated = await ref.read(profileProvider.notifier).updateProfile(
                          name: _nameController.text.trim().isNotEmpty
                              ? _nameController.text.trim()
                              : null,
                          email: _emailController.text.trim().isNotEmpty
                              ? _emailController.text.trim()
                              : null,
                        );
                        // Synchronize updated user info into authProvider
                        ref.read(authProvider.notifier).updateUser(
                          name: updated.name,
                          email: updated.email,
                        );
                        if (mounted) {
                          _nameController.text = updated.name ?? '';
                          _emailController.text = updated.email ?? '';
                          setState(() => _isEditing = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Profile updated successfully'),
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                e is Failure ? e.message : 'Failed to update profile',
                              ),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        }
                      } finally {
                        if (mounted) setState(() => _isSaving = false);
                      }
                    },
                  )
                else
                  _InfoSection(profile: profile),

                const SizedBox(height: AppSpacing.xl),

                // ── Specializations ──────────────────────────────
                _SpecializationsCard(profile: profile),

                const SizedBox(height: AppSpacing.md),

                // ── Service Areas ─────────────────────────────────
                _ServiceAreasCard(profile: profile),

                const SizedBox(height: AppSpacing.xl),

                // ── Account ──────────────────────────────────────
                FpCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _ActionTile(
                        icon: Icons.settings_outlined,
                        label: 'Settings',
                        onTap: () => context.push('/settings'),
                      ),
                      const Divider(
                        height: 1,
                        indent: 56,
                        color: AppColors.divider,
                      ),
                      _ActionTile(
                        icon: Icons.logout_rounded,
                        label: 'Logout',
                        color: AppColors.error,
                        onTap: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (c) => AlertDialog(
                              title: const Text('Logout'),
                              content: const Text(
                                'Are you sure you want to logout?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(c, false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(c, true),
                                  style: TextButton.styleFrom(foregroundColor: AppColors.error),
                                  child: const Text('Logout'),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true && context.mounted) {
                            await ref.read(authProvider.notifier).logout();
                            if (context.mounted) context.go('/login');
                          }
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.xxxl),
              ],
            ),
            ),
          );
        },
      ),
    );
  }
}

class _AvatarPlaceholder extends StatelessWidget {
  final String name;
  const _AvatarPlaceholder({required this.name});

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'T';
    return Container(
      color: AppColors.primaryContainer,
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}

class _VerificationBadge extends StatelessWidget {
  final String status;
  const _VerificationBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final isVerified = status == 'VERIFIED';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isVerified ? AppColors.successLight : AppColors.warningLight,
        borderRadius: AppRadius.pill,
        border: Border.all(
          color: (isVerified ? AppColors.success : AppColors.warning)
              .withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isVerified ? Icons.verified_rounded : Icons.schedule_rounded,
            size: 14,
            color: isVerified ? AppColors.success : AppColors.warning,
          ),
          const SizedBox(width: 4),
          Text(
            isVerified ? 'Verified' : status.replaceAll('_', ' '),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isVerified ? AppColors.success : AppColors.warning,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color iconColor;

  const _MiniStat({
    required this.icon,
    required this.value,
    required this.label,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return FpCard(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.md,
        horizontal: AppSpacing.sm,
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  final dynamic profile;
  const _InfoSection({required this.profile});

  @override
  Widget build(BuildContext context) {
    return FpCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Contact',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _InfoRow(
            icon: Icons.phone_outlined,
            label: 'Mobile',
            value: profile.phone ?? '-',
          ),
          const SizedBox(height: AppSpacing.sm),
          _InfoRow(
            icon: Icons.email_outlined,
            label: 'Email',
            value: profile.email ?? 'Not set',
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: AppSpacing.md),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary),
            ),
          ],
        ),
      ],
    );
  }
}

class _EditForm extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController emailController;
  final bool isSaving;
  final VoidCallback onSave;

  const _EditForm({
    required this.nameController,
    required this.emailController,
    required this.isSaving,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextFormField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Full Name',
            prefixIcon: Icon(Icons.person_outline_rounded),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        TextFormField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Email Address',
            prefixIcon: Icon(Icons.email_outlined),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        FpButton(label: 'Save Changes', isLoading: isSaving, onPressed: onSave),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textPrimary;
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: c, size: 22),
      title: Text(
        label,
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: c),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios_rounded,
        size: 14,
        color: AppColors.textDisabled,
      ),
      minLeadingWidth: 0,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.base,
        vertical: AppSpacing.xs,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Specializations card
// ─────────────────────────────────────────────────────────────────

class _SpecializationsCard extends StatelessWidget {
  final dynamic profile;
  const _SpecializationsCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    final specs = profile.specializations as List<dynamic>;

    return FpCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.build_outlined,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'My Specializations',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              GestureDetector(
                onTap: () => context.push('/edit-specializations'),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: AppRadius.pill,
                  ),
                  child: const Text(
                    'Edit',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (specs.isEmpty)
            Text(
              'No specializations added yet. Tap Edit to add.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            )
          else
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: specs.map((s) {
                final Map<String, dynamic>? specMap =
                    s is Map ? Map<String, dynamic>.from(s) : null;
                final subService = specMap?['subService'] is Map
                    ? Map<String, dynamic>.from(specMap!['subService'] as Map)
                    : null;
                final name = subService?['name'] ?? specMap?['name'] ?? s.toString();
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: AppRadius.pill,
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    name as String,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primary,
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Service Areas card
// ─────────────────────────────────────────────────────────────────

class _ServiceAreasCard extends StatelessWidget {
  final dynamic profile;
  const _ServiceAreasCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    final areas = profile.serviceAreas as List<dynamic>;

    return FpCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 18,
                color: AppColors.info,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'My Service Areas',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              GestureDetector(
                onTap: () => context.push('/edit-service-areas'),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.infoLight,
                    borderRadius: AppRadius.pill,
                  ),
                  child: const Text(
                    'Edit',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.info,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (areas.isEmpty)
            Text(
              'No service areas added yet. Tap Edit to add.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            )
          else
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: areas.map((a) {
                final Map<String, dynamic>? areaMap =
                    a is Map ? Map<String, dynamic>.from(a) : null;
                final serviceArea = areaMap?['serviceArea'] is Map
                    ? Map<String, dynamic>.from(areaMap!['serviceArea'] as Map)
                    : null;
                final name = serviceArea?['name'] ??
                    areaMap?['city'] ??
                    areaMap?['name'] ??
                    a.toString();
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.infoLight,
                    borderRadius: AppRadius.pill,
                    border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.location_on_rounded,
                        size: 12,
                        color: AppColors.info,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        name as String,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.info,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}
