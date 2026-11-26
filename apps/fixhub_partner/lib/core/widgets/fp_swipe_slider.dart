import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/theme/app_colors.dart';
import '../config/theme/app_radius.dart';
import '../config/theme/app_spacing.dart';

/// HelpTab Premium Swipe Slider Component
///
/// Designed per Soft Neutral Material 3 guidelines.
/// Replaces accidental tap buttons with an intentional, tactile swipe action.
/// Features:
/// - Dedicated thumb bay ensuring text is NEVER obscured at rest.
/// - Progressive dynamic track fill following thumb drag.
/// - Smooth text fade-out and animated chevron guide.
/// - Multi-stage haptic feedback on drag thresholds and completion.
/// - Spring-back animation on cancelled swipe.
class FpSwipeSlider extends StatefulWidget {
  final VoidCallback onComplete;
  final String label;
  final bool isEnabled;
  final double height;

  const FpSwipeSlider({
    super.key,
    required this.onComplete,
    this.label = 'Slide to Complete Job',
    this.isEnabled = true,
    this.height = AppSpacing.buttonHeight,
  });

  @override
  State<FpSwipeSlider> createState() => _FpSwipeSliderState();
}

class _FpSwipeSliderState extends State<FpSwipeSlider>
    with SingleTickerProviderStateMixin {
  double _dragPosition = 0.0;
  bool _completed = false;
  late AnimationController _resetController;
  late Animation<double> _resetAnimation;
  int _lastHapticMilestone = 0;

  @override
  void initState() {
    super.initState();
    _resetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    )..addListener(() {
        setState(() {
          _dragPosition = _resetAnimation.value;
        });
      });
  }

  @override
  void dispose() {
    _resetController.dispose();
    super.dispose();
  }

  void _triggerHapticMilestone(double progress) {
    int milestone = (progress * 4).floor(); // 0, 1, 2, 3
    if (milestone > _lastHapticMilestone && milestone > 0) {
      _lastHapticMilestone = milestone;
      HapticFeedback.selectionClick();
    } else if (milestone < _lastHapticMilestone) {
      _lastHapticMilestone = milestone;
    }
  }

  void _resetSlider() {
    _resetAnimation = Tween<double>(
      begin: _dragPosition,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _resetController,
      curve: Curves.easeOutCubic,
    ));
    _lastHapticMilestone = 0;
    _resetController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final thumbSize = widget.height - 8;
        final maxDrag = (totalWidth - thumbSize - 8).clamp(0.0, double.infinity);
        final progress = maxDrag > 0 ? (_dragPosition / maxDrag).clamp(0.0, 1.0) : 0.0;

        return Container(
          height: widget.height,
          decoration: BoxDecoration(
            color: widget.isEnabled ? AppColors.surface : AppColors.surface.withValues(alpha: 0.5),
            borderRadius: AppRadius.button,
            border: Border.all(
              color: AppColors.border,
              width: 1.0,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              // 1. Progressive Track Fill
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: _dragPosition + (thumbSize / 2) + 4,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(
                      alpha: 0.06 + (0.12 * progress),
                    ),
                    borderRadius: AppRadius.button,
                  ),
                ),
              ),

              // 2. Clear Non-Overlapping Center-Right Label
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: thumbSize + AppSpacing.md,
                    right: AppSpacing.md,
                  ),
                  child: Opacity(
                    opacity: (1.0 - (progress * 1.6)).clamp(0.0, 1.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            widget.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: widget.isEnabled
                                  ? AppColors.textPrimary.withValues(alpha: 0.85)
                                  : AppColors.textDisabled,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.keyboard_double_arrow_right_rounded,
                          size: 18,
                          color: widget.isEnabled
                              ? AppColors.textPrimary.withValues(alpha: 0.4 + (0.4 * (1 - progress)))
                              : AppColors.textDisabled,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 3. Tactile Draggable Thumb
              Positioned(
                left: 4 + _dragPosition,
                child: GestureDetector(
                  onHorizontalDragUpdate: widget.isEnabled && !_completed
                      ? (details) {
                          if (_resetController.isAnimating) _resetController.stop();
                          setState(() {
                            _dragPosition = (_dragPosition + details.delta.dx).clamp(0.0, maxDrag);
                          });
                          _triggerHapticMilestone(progress);
                        }
                      : null,
                  onHorizontalDragEnd: widget.isEnabled && !_completed
                      ? (details) {
                          if (_dragPosition >= maxDrag * 0.72) {
                            // Completed swipe!
                            setState(() {
                              _dragPosition = maxDrag;
                              _completed = true;
                            });
                            HapticFeedback.heavyImpact();
                            widget.onComplete();

                            // Reset after brief completion tick
                            Future.delayed(const Duration(milliseconds: 650), () {
                              if (mounted) {
                                setState(() {
                                  _completed = false;
                                });
                                _resetSlider();
                              }
                            });
                          } else {
                            // Cancelled swipe - spring back
                            HapticFeedback.lightImpact();
                            _resetSlider();
                          }
                        }
                      : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: thumbSize + (progress * 4), // subtle expansion on pull
                    height: thumbSize,
                    decoration: BoxDecoration(
                      color: widget.isEnabled
                          ? (_completed ? AppColors.success : AppColors.primary)
                          : AppColors.primary.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.16 + (0.08 * progress)),
                          blurRadius: 6 + (4 * progress),
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          _completed
                              ? Icons.check_rounded
                              : (progress > 0.6
                                  ? Icons.keyboard_double_arrow_right_rounded
                                  : Icons.arrow_forward_rounded),
                          key: ValueKey<bool>(_completed),
                          color: AppColors.textOnPrimary,
                          size: 20,
                        ),
                      ),
                    ),
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
