import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/motion.dart';
import '../../domain/models/ride_quote.dart';

/// The fare, as the thing being chosen rather than a number in a bar.
///
/// One option today — a bike carries one pillion — but shaped as a selectable
/// card because that is what it is: the trip you are about to commit to, with
/// its price, at a glance. A second vehicle class slots in beside it without
/// the screen changing shape.
class TripFareCard extends StatelessWidget {
  const TripFareCard({
    super.key,
    required this.quote,
    required this.isOffer,
    required this.accent,
  });

  /// Null while the price is still being worked out.
  final RideQuote? quote;

  final bool isOffer;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        // Outlined rather than shadowed: it reads as *selected*, which is what
        // a one-option chooser should look like.
        border: Border.all(color: accent, width: 1.6),
      ),
      child: Row(
        children: [
          Container(
            height: 46,
            width: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.14),
            ),
            child: Icon(Icons.two_wheeler_rounded, size: 26, color: accent),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'UniRide Bike',
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  quote?.summary ?? 'Working out the fare…',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (quote?.minimumApplied ?? false) ...[
                  const SizedBox(height: 3),
                  Text(
                    'Minimum fare for a short trip',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: accent,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (quote == null)
            Container(
              height: 22,
              width: 62,
              decoration: BoxDecoration(
                color: AppColors.skeleton,
                borderRadius: BorderRadius.circular(5),
              ),
            )
          else
            SwapIn(
              value: quote!.total,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    quote!.formattedTotal,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.6,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    isOffer ? "you'll earn" : "you'll pay",
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// From and to, as a connected pair with the route drawn between them.
///
/// Compact on purpose: on a map-first screen the map has already shown the
/// journey, so these rows only have to name the ends and be tappable.
class TripEndpointRows extends StatelessWidget {
  const TripEndpointRows({
    super.key,
    required this.from,
    required this.to,
    required this.onFrom,
    required this.onTo,
    required this.onSwap,
  });

  final String? from;
  final String? to;
  final VoidCallback onFrom;
  final VoidCallback onTo;
  final VoidCallback? onSwap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.fromLTRB(14, 4, 6, 4),
      child: Row(
        children: [
          // The connector: dot, line, pin. Cheaper to read than two icons that
          // happen to sit above each other.
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 9,
                width: 9,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary,
                ),
              ),
              Container(
                height: 22,
                width: 1.5,
                margin: const EdgeInsets.symmetric(vertical: 2),
                color: AppColors.border,
              ),
              const Icon(Icons.place, size: 13, color: AppColors.dark),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              children: [
                _EndpointRow(
                  text: from,
                  placeholder: 'Pick-up point',
                  onTap: onFrom,
                ),
                const Divider(height: 1, thickness: 1, color: AppColors.border),
                _EndpointRow(
                  text: to,
                  placeholder: 'Where to?',
                  onTap: onTo,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Swap',
            onPressed: onSwap,
            icon: Icon(
              Icons.swap_vert_rounded,
              size: 21,
              color: onSwap == null ? AppColors.muted : AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _EndpointRow extends StatelessWidget {
  const _EndpointRow({
    required this.text,
    required this.placeholder,
    required this.onTap,
  });

  final String? text;
  final String placeholder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final empty = text == null || text!.isEmpty;
    return PressableScale(
      scale: 0.99,
      onTap: onTap,
      child: SizedBox(
        height: 42,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            empty ? placeholder : text!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: empty ? FontWeight.w500 : FontWeight.w600,
              color: empty ? AppColors.muted : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

/// "Now" / "Schedule", as a compact dropdown rather than a segmented control.
///
/// It sits beside a heading rather than under it because on this screen it is
/// a qualifier on the trip, not one of the trip's fields — and a full-width
/// segmented control would claim more attention than the choice deserves when
/// "now" is right most of the time.
class TripWhenButton extends StatelessWidget {
  const TripWhenButton({
    super.key,
    required this.label,
    required this.scheduled,
    required this.onTap,
  });

  final String label;
  final bool scheduled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      scale: 0.97,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              scheduled ? Icons.event_outlined : Icons.bolt_rounded,
              size: 16,
              color: AppColors.primary,
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 19,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
