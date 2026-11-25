import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/config/theme/app_radius.dart';
import '../../../../core/config/theme/app_spacing.dart';
import '../../../../core/widgets/fixhub_app_bar.dart';
import '../../../../core/widgets/fixhub_button.dart';
import '../../../../core/widgets/fixhub_card.dart';
import '../../../../core/widgets/fixhub_snackbar.dart';
import '../../../../core/widgets/fixhub_text_field.dart';
import '../../data/services/booking_media_upload_service.dart';
import '../providers/booking_provider.dart';

/// Maximum allowable media files: 5 photos and 1 video (SRS §2.4)
const _kMaxPhotos = 5;
const _kMaxVideos = 1;
const _kMaxPhotoBytes = 2 * 1024 * 1024; // 2MB
const _kMaxVideoBytes = 30 * 1024 * 1024; // 30MB

class AddIssueDetailsScreen extends ConsumerStatefulWidget {
  const AddIssueDetailsScreen({
    super.key,
    required this.bookingId,
    this.initialDescription,
  });

  final String bookingId;
  final String? initialDescription;

  @override
  ConsumerState<AddIssueDetailsScreen> createState() =>
      _AddIssueDetailsScreenState();
}

class _AddIssueDetailsScreenState
    extends ConsumerState<AddIssueDetailsScreen> {
  final _picker = ImagePicker();
  late final TextEditingController _descriptionController;

  final List<XFile> _selectedPhotos = [];
  XFile? _selectedVideo;

  final Set<String> _selectedChips = {};

  bool _isSaving = false;
  int _uploadingIndex = -1;
  double _uploadProgress = 0.0;
  String? _uploadStatusText;

  static const List<String> _quickChips = [
    'Water leakage',
    'Not turning on',
    'Strange noise',
    'Low cooling / weak airflow',
    'Sparking / burning smell',
    'Wiring / switch issue',
  ];

  @override
  void initState() {
    super.initState();
    _descriptionController =
        TextEditingController(text: widget.initialDescription ?? '');
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  void _toggleChip(String chip) {
    setState(() {
      if (_selectedChips.contains(chip)) {
        _selectedChips.remove(chip);
      } else {
        _selectedChips.add(chip);
      }

      // Update text field with active chips if desired
      final current = _descriptionController.text.trim();
      final hasChips = _selectedChips.isNotEmpty;
      final chipsText = _selectedChips.join(', ');

      if (current.isEmpty && hasChips) {
        _descriptionController.text = 'Issue: $chipsText';
      }
    });
  }

  Future<void> _pickPhoto(ImageSource source) async {
    if (_selectedPhotos.length >= _kMaxPhotos) {
      FixHubSnackbar.error(context, 'Maximum $_kMaxPhotos photos allowed');
      return;
    }

    try {
      final file = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1920,
      );
      if (file != null && mounted) {
        final length = await file.length();
        if (length > _kMaxPhotoBytes) {
          if (mounted) {
            FixHubSnackbar.error(context, 'Photo must be smaller than 2MB');
          }
          return;
        }
        setState(() => _selectedPhotos.add(file));
      }
    } catch (e) {
      if (mounted) {
        FixHubSnackbar.error(context, 'Failed to pick photo');
      }
    }
  }

  Future<void> _pickVideo(ImageSource source) async {
    if (_selectedVideo != null) {
      FixHubSnackbar.error(context, 'Maximum 1 video allowed');
      return;
    }

    try {
      final file = await _picker.pickVideo(
        source: source,
        maxDuration: const Duration(seconds: 60),
      );
      if (file != null && mounted) {
        final length = await file.length();
        if (length > _kMaxVideoBytes) {
          if (mounted) {
            FixHubSnackbar.error(context, 'Video must be smaller than 30MB');
          }
          return;
        }
        setState(() => _selectedVideo = file);
      }
    } catch (e) {
      if (mounted) {
        FixHubSnackbar.error(context, 'Failed to pick video');
      }
    }
  }

  void _showMediaSourceSheet({required bool isVideo}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.bottomSheet)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPadding,
              vertical: AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  isVideo ? 'Add Video of Issue' : 'Add Photo of Issue',
                  style: Theme.of(ctx).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  isVideo
                      ? 'Record up to 60 seconds of the problem'
                      : 'Take a clear picture of the affected appliance or area',
                  style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
                const SizedBox(height: AppSpacing.lg),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: AppRadius.smallRadius,
                    ),
                    child: const Icon(Icons.camera_alt_outlined, color: AppColors.textPrimary),
                  ),
                  title: Text(isVideo ? 'Record Video' : 'Take Photo'),
                  onTap: () {
                    Navigator.pop(ctx);
                    if (isVideo) {
                      _pickVideo(ImageSource.camera);
                    } else {
                      _pickPhoto(ImageSource.camera);
                    }
                  },
                ),
                const Divider(height: AppSpacing.sm),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: AppRadius.smallRadius,
                    ),
                    child: const Icon(Icons.photo_library_outlined, color: AppColors.textPrimary),
                  ),
                  title: const Text('Choose from Gallery'),
                  onTap: () {
                    Navigator.pop(ctx);
                    if (isVideo) {
                      _pickVideo(ImageSource.gallery);
                    } else {
                      _pickPhoto(ImageSource.gallery);
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _contentType(XFile file) {
    final ext = p.extension(file.name).toLowerCase().replaceAll('.', '');
    return switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'mp4' => 'video/mp4',
      'mov' => 'video/quicktime',
      'webm' => 'video/webm',
      _ => 'image/jpeg',
    };
  }

  Future<void> _saveAndSubmit() async {
    final description = _descriptionController.text.trim();
    final allFiles = <XFile>[..._selectedPhotos];
    if (_selectedVideo != null) {
      allFiles.add(_selectedVideo!);
    }

    if (description.isEmpty && allFiles.isEmpty) {
      FixHubSnackbar.error(context, 'Please add a description or attach at least one photo/video');
      return;
    }

    setState(() {
      _isSaving = true;
      _uploadingIndex = 0;
      _uploadProgress = 0.0;
      _uploadStatusText = 'Preparing uploads...';
    });

    try {
      final uploadService = ref.read(bookingMediaUploadServiceProvider);

      // 1. Upload media files sequentially
      for (int i = 0; i < allFiles.length; i++) {
        final xfile = allFiles[i];
        final isVid = _selectedVideo != null && xfile == _selectedVideo;

        if (mounted) {
          setState(() {
            _uploadingIndex = i + 1;
            _uploadStatusText = isVid
                ? 'Uploading video (${i + 1}/${allFiles.length})...'
                : 'Uploading photo (${i + 1}/${allFiles.length})...';
            _uploadProgress = 0.0;
          });
        }

        await uploadService.uploadFile(
          bookingId: widget.bookingId,
          file: File(xfile.path),
          contentType: _contentType(xfile),
          phase: 'BEFORE_SERVICE',
          onProgress: (sent, total) {
            if (mounted && total > 0) {
              setState(() => _uploadProgress = sent / total);
            }
          },
        );
      }

      // 2. Update booking description
      if (description.isNotEmpty) {
        if (mounted) {
          setState(() {
            _uploadStatusText = 'Saving issue notes...';
          });
        }
        final repo = ref.read(bookingRepositoryProvider);
        await repo.updateIssueDetails(widget.bookingId, description: description);
      }

      // Invalidate detail cache so UI refreshes
      ref.invalidate(bookingDetailProvider(widget.bookingId));

      if (mounted) {
        FixHubSnackbar.success(context, 'Issue details updated successfully');
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _uploadingIndex = -1;
          _uploadStatusText = null;
        });
        final msg = e.toString().replaceAll(RegExp(r'^(Exception:\s*|DioException:\s*)'), '');
        FixHubSnackbar.error(context, msg.isNotEmpty ? msg : 'Failed to save issue details');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const FixHubAppBar(title: 'Issue Details'),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              children: [
                // Header Note Card
                FixHubCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.xs),
                            decoration: BoxDecoration(
                              color: AppColors.info.withValues(alpha: 0.12),
                              borderRadius: AppRadius.smallRadius,
                            ),
                            child: const Icon(Icons.info_outline_rounded,
                                size: 20, color: AppColors.info),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              'Help your technician prepare',
                              style: textTheme.titleMedium,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Adding photos, a video, or details helps ensure the technician arrives with the right replacement parts and tools.',
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Quick chips
                Text('Common Issues', style: textTheme.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: _quickChips.map((chip) {
                    final isSelected = _selectedChips.contains(chip);
                    return FilterChip(
                      selected: isSelected,
                      label: Text(chip),
                      labelStyle: textTheme.bodyMedium?.copyWith(
                        color: isSelected ? AppColors.elevatedSurface : AppColors.textPrimary,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                      selectedColor: AppColors.buttonPrimary,
                      backgroundColor: AppColors.surface,
                      checkmarkColor: AppColors.elevatedSurface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.small),
                        side: BorderSide(
                          color: isSelected ? AppColors.buttonPrimary : AppColors.border,
                        ),
                      ),
                      onSelected: (_) => _toggleChip(chip),
                    );
                  }).toList(),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Description input
                Text('Describe the Problem', style: textTheme.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                FixHubTextField(
                  controller: _descriptionController,
                  hint: 'Explain what happens, when it started, or brand/model...',
                  maxLines: 4,
                  maxLength: 1000,
                  keyboardType: TextInputType.multiline,
                ),
                const SizedBox(height: AppSpacing.lg),

                // Media Attachments
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Photos & Video', style: textTheme.titleMedium),
                    Text(
                      '${_selectedPhotos.length}/$_kMaxPhotos photos' +
                          (_selectedVideo != null ? ', 1 video' : ''),
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),

                // Action buttons for picking
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          side: const BorderSide(color: AppColors.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.small),
                          ),
                          backgroundColor: AppColors.elevatedSurface,
                        ),
                        icon: const Icon(Icons.add_a_photo_outlined,
                            size: 18, color: AppColors.textPrimary),
                        label: Text(
                          'Add Photo',
                          style: textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onPressed: _isSaving
                            ? null
                            : () => _showMediaSourceSheet(isVideo: false),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          side: const BorderSide(color: AppColors.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.small),
                          ),
                          backgroundColor: AppColors.elevatedSurface,
                        ),
                        icon: const Icon(Icons.videocam_outlined,
                            size: 20, color: AppColors.textPrimary),
                        label: Text(
                          'Add Video',
                          style: textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onPressed: _isSaving
                            ? null
                            : () => _showMediaSourceSheet(isVideo: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                // Media thumbnails preview grid
                if (_selectedPhotos.isNotEmpty || _selectedVideo != null) ...[
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      ..._selectedPhotos.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final file = entry.value;
                        return _MediaThumbnail(
                          file: file,
                          isVideo: false,
                          onRemove: _isSaving
                              ? null
                              : () => setState(() => _selectedPhotos.removeAt(idx)),
                        );
                      }),
                      if (_selectedVideo != null)
                        _MediaThumbnail(
                          file: _selectedVideo!,
                          isVideo: true,
                          onRemove: _isSaving
                              ? null
                              : () => setState(() => _selectedVideo = null),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                // Upload progress indicator
                if (_isSaving && _uploadStatusText != null) ...[
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.elevatedSurface,
                      borderRadius: AppRadius.cardRadius,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _uploadStatusText!,
                              style: textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (_uploadProgress > 0)
                              Text(
                                '${(_uploadProgress * 100).toInt()}%',
                                style: textTheme.bodySmall?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: _uploadProgress > 0 ? _uploadProgress : null,
                            backgroundColor: AppColors.surface,
                            valueColor: const AlwaysStoppedAnimation(AppColors.buttonPrimary),
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Bottom Action Bar
          Container(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            decoration: BoxDecoration(
              color: AppColors.elevatedSurface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FixHubButton(
                    label: _isSaving ? 'Uploading...' : 'Save Issue Details',
                    isLoading: _isSaving,
                    onPressed: _isSaving ? null : _saveAndSubmit,
                  ),
                  if (!_isSaving) ...[
                    const SizedBox(height: AppSpacing.xs),
                    TextButton(
                      onPressed: () => context.pop(),
                      child: Text(
                        'Skip for now',
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MediaThumbnail extends StatelessWidget {
  const _MediaThumbnail({
    required this.file,
    required this.isVideo,
    this.onRemove,
  });

  final XFile file;
  final bool isVideo;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.small),
            border: Border.all(color: AppColors.border),
            image: !isVideo
                ? DecorationImage(
                    image: FileImage(File(file.path)),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: isVideo
              ? const Center(
                  child: Icon(
                    Icons.play_circle_fill_rounded,
                    size: 36,
                    color: AppColors.buttonPrimary,
                  ),
                )
              : null,
        ),
        if (isVideo)
          Positioned(
            bottom: 4,
            left: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'VIDEO',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        if (onRemove != null)
          Positioned(
            top: 2,
            right: 2,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: AppColors.textPrimary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  size: 14,
                  color: AppColors.elevatedSurface,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

