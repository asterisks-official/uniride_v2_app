import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/motion.dart';

/// Back chevron and a segmented progress bar.
///
/// The segments matter more than they look: an application that asks for a
/// vehicle, four documents and a face scan is long enough that people abandon
/// it, and seeing three of four segments filled is the cheapest reason to
/// finish.
class RiderStepHeader extends StatelessWidget {
  const RiderStepHeader({
    super.key,
    required this.step,
    required this.total,
    required this.onBack,
  });

  /// 1-based. Zero hides the progress bar entirely (the intro screen).
  final int step;
  final int total;

  /// Null renders no back button at all, for a rider who has to finish the
  /// application before the rest of the app opens up. A disabled-looking arrow
  /// would just invite tapping.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(onBack == null ? 20 : 8, 6, 20, 8),
      // Fixed height so the chrome does not collapse when there is no back
      // button and no progress bar to give the row a size.
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            if (onBack != null)
              IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_ios_new, size: 19),
                color: AppColors.textPrimary,
              ),
            if (step > 0) ...[
              Expanded(
                child: Row(
                  children: [
                    for (var i = 1; i <= total; i++) ...[
                      Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeOut,
                          height: 4,
                          decoration: BoxDecoration(
                            color: i <= step
                                ? AppColors.primary
                                : AppColors.segmentTrack,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      if (i != total) const SizedBox(width: 5),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Text(
                '$step of $total',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ] else
              const Spacer(),
          ],
        ),
      ),
    );
  }
}

/// Large title and standfirst at the top of a step.
class RiderPageTitle extends StatelessWidget {
  const RiderPageTitle({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.8,
            height: 1.12,
            color: AppColors.textPrimary,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 9),
          Text(
            subtitle!,
            style: const TextStyle(
              fontSize: 15,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

/// A titled group of rows on one white card, hairlines between them.
class RiderSection extends StatelessWidget {
  const RiderSection({
    super.key,
    this.title,
    this.footnote,
    this.action,
    required this.children,
    this.padded = true,
  });

  final String? title;
  final String? footnote;

  /// Trailing control on the title row — an "Edit" jump back, usually.
  final Widget? action;
  final List<Widget> children;

  /// False when the children draw their own padding (upload tiles, grids).
  final bool padded;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null || action != null)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 9),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title ?? '',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.1,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                ?action,
              ],
            ),
          ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (padded)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
                    child: children[i],
                  )
                else
                  children[i],
                if (i != children.length - 1)
                  const Padding(
                    padding: EdgeInsets.only(left: 16),
                    child: Divider(
                      height: 1,
                      thickness: 1,
                      color: AppColors.border,
                    ),
                  ),
              ],
            ],
          ),
        ),
        if (footnote != null) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              footnote!,
              style: const TextStyle(
                fontSize: 12,
                height: 1.4,
                color: AppColors.muted,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// One borderless field on a grouped card — label on the left, value on the
/// right, the way iOS lays out forms.
class RiderFieldRow extends StatelessWidget {
  const RiderFieldRow({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.words,
    this.maxLength,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final int? maxLength;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 96,
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
        Expanded(
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            textCapitalization: textCapitalization,
            maxLength: maxLength,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: hint,
              filled: false,
              isDense: true,
              counterText: '',
              contentPadding: EdgeInsets.zero,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              hintStyle: const TextStyle(color: AppColors.muted, fontSize: 15),
              errorStyle: const TextStyle(fontSize: 11.5, height: 1.3),
            ),
            validator:
                validator ??
                (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
        ),
      ],
    );
  }
}

/// Selectable vehicle-type tile.
class VehicleTypeTile extends StatelessWidget {
  const VehicleTypeTile({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// False for vehicle types the platform does not carry yet. Shown rather
  /// than hidden so the single available option does not look like a bug.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final active = selected && enabled;
    final foreground = !enabled
        ? AppColors.muted
        : active
        ? AppColors.primary
        : AppColors.textSecondary;

    return PressableScale(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: active
              ? AppColors.primaryWash
              : enabled
              ? AppColors.surface
              : AppColors.segmentTrack.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: active ? AppColors.primary : AppColors.border,
            width: active ? 1.5 : 1,
          ),
        ),
        // Scales down rather than overflowing if the user runs a large system
        // text size — the grid row has a fixed height.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 24, color: foreground),
              const SizedBox(height: 6),
              // The label has to survive a large text scale on a narrow phone,
              // which is exactly where the tile used to overflow.
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: foreground,
                ),
              ),
              if (!enabled) ...[
                const SizedBox(height: 3),
                Text(
                  'Soon',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    color: AppColors.muted.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A document slot: thumbnail once picked, prompt until then.
class DocumentUploadTile extends StatelessWidget {
  const DocumentUploadTile({
    super.key,
    required this.label,
    required this.description,
    required this.icon,
    required this.file,
    required this.onTap,
    this.onFile = false,
  });

  final String label;
  final String description;
  final IconData icon;
  final XFile? file;
  final VoidCallback onTap;

  /// A copy is already stored on the server from an earlier submission. Shown
  /// as satisfied without a thumbnail — the stored file is behind a CDN URL,
  /// and the applicant only needs to know the slot is filled.
  final bool onFile;

  @override
  Widget build(BuildContext context) {
    final picked = file != null;
    final satisfied = picked || onFile;
    return PressableScale(
      scale: 0.985,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          children: [
            SizedBox(
              height: 52,
              width: 52,
              child: picked
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(file!.path),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            _placeholder(Icons.description_outlined),
                      ),
                    )
                  : _placeholder(satisfied ? Icons.description_outlined : icon),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    picked
                        ? 'Added — tap to change'
                        : onFile
                        ? 'Already sent — tap to replace'
                        : description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: satisfied
                          ? AppColors.success
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              satisfied ? Icons.check_circle : Icons.add_circle_outline,
              size: 22,
              color: satisfied ? AppColors.success : AppColors.muted,
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.segmentTrack,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 23, color: AppColors.muted),
    );
  }
}

/// Icon, title and body — used for "what you'll need" and the face-check
/// explainer.
class RiderBulletRow extends StatelessWidget {
  const RiderBulletRow({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.tint,
  });

  final IconData icon;
  final String title;
  final String body;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final color = tint ?? AppColors.primary;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 38,
          width: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, size: 19, color: color),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                body,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Label on the left, value on the right — the review step's building block.
class RiderReviewRow extends StatelessWidget {
  const RiderReviewRow({
    super.key,
    required this.label,
    required this.value,
    this.done,
  });

  final String label;
  final String value;

  /// When set, renders a tick or a warning instead of plain text.
  final bool? done;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14.5,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        if (done != null) ...[
          Icon(
            done! ? Icons.check_circle : Icons.error_outline,
            size: 17,
            color: done! ? AppColors.success : AppColors.warning,
          ),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: done == false ? AppColors.warning : AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

/// iOS action sheet asking where a document should come from.
Future<ImageSource?> askImageSource(
  BuildContext context, {
  required String title,
  bool canRemove = false,
  VoidCallback? onRemove,
}) {
  return showCupertinoModalPopup<ImageSource>(
    context: context,
    builder: (sheetContext) => CupertinoActionSheet(
      title: Text(title),
      actions: [
        CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheetContext, ImageSource.camera),
          child: const Text('Take a photo'),
        ),
        CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheetContext, ImageSource.gallery),
          child: const Text('Choose from library'),
        ),
        if (canRemove)
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(sheetContext);
              onRemove?.call();
            },
            child: const Text('Remove'),
          ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.pop(sheetContext),
        child: const Text('Cancel'),
      ),
    ),
  );
}
