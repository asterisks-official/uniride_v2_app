import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/exceptions/app_exception.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_snack.dart';
import '../../domain/models/saved_place.dart';
import '../providers/saved_places_notifier.dart';

/// Names a point that has already been chosen, and keeps it.
///
/// Offered right after a pin is dropped rather than as a separate errand,
/// because that is the only moment when saving costs one tap and the user
/// already knows what the place is. Skipping is a first-class outcome — a
/// one-off trip should not have to become a saved place.
class SavePlaceSheet extends ConsumerStatefulWidget {
  const SavePlaceSheet({super.key, required this.point, this.existing});

  final PickedPlace point;

  /// Set when renaming rather than creating.
  final SavedPlace? existing;

  /// Resolves to the saved place, or null if it was skipped or failed.
  static Future<PickedPlace?> show(
    BuildContext context, {
    required PickedPlace point,
    SavedPlace? existing,
  }) {
    return showModalBottomSheet<PickedPlace>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SavePlaceSheet(point: point, existing: existing),
    );
  }

  @override
  ConsumerState<SavePlaceSheet> createState() => _SavePlaceSheetState();
}

class _SavePlaceSheetState extends ConsumerState<SavePlaceSheet> {
  late final TextEditingController _label = TextEditingController(
    text: widget.existing?.label ?? '',
  );
  bool _saving = false;

  /// The two places nearly everyone needs, as one tap each.
  static const _suggestions = ['Home', 'Campus', 'Work'];

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  bool get _valid => _label.text.trim().isNotEmpty;

  Future<void> _save() async {
    if (!_valid || _saving) return;
    setState(() => _saving = true);

    final notifier = ref.read(savedPlacesProvider.notifier);
    final label = _label.text.trim();

    try {
      final saved = widget.existing == null
          ? await notifier.add(
              label: label,
              lat: widget.point.lat,
              lng: widget.point.lng,
              areaLabel: widget.point.areaLabel,
            )
          : await _rename(notifier, label);

      if (mounted) Navigator.of(context).pop(PickedPlace.fromSaved(saved));
    } on AppException catch (e) {
      // The cap is the likely failure and it has a real message. Close with
      // nothing saved — the caller falls back to the unsaved point, so the
      // ride can still be posted.
      if (mounted) {
        showAppSnack(context, e.message, isError: true);
        setState(() => _saving = false);
      }
    }
  }

  Future<SavedPlace> _rename(
    SavedPlacesNotifier notifier,
    String label,
  ) async {
    await notifier.rename(widget.existing!, label: label);
    return SavedPlace(
      id: widget.existing!.id,
      label: label,
      lat: widget.existing!.lat,
      lng: widget.existing!.lng,
      areaLabel: widget.existing!.areaLabel,
      lastUsedAt: widget.existing!.lastUsedAt,
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;

    return Padding(
      // Lifts clear of the keyboard, which is otherwise guaranteed to cover
      // the save button on a small phone.
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.muted.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                editing ? 'Rename this place' : 'Save this place?',
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(
                    Icons.place_outlined,
                    size: 15,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      widget.point.areaLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _label,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                maxLength: 40,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _save(),
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  labelText: 'Call it something',
                  hintText: 'Home',
                  counterText: '',
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  for (final s in _suggestions)
                    _SuggestionChip(
                      label: s,
                      selected: _label.text.trim() == s,
                      onTap: () => setState(() {
                        _label.text = s;
                        _label.selection = TextSelection.collapsed(
                          offset: s.length,
                        );
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              AppButton(
                label: editing ? 'Save changes' : 'Save place',
                loading: _saving,
                onPressed: _valid ? _save : null,
              ),
              if (!editing) ...[
                const SizedBox(height: 8),
                AppButton(
                  label: 'Just use it once',
                  variant: AppButtonVariant.outline,
                  onPressed: _saving
                      ? null
                      : () => Navigator.of(context).pop(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.segmentTrack,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.onPrimary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
