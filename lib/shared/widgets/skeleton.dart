import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Shimmer-like animated placeholder for loading states.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  final double width;
  final double height;
  final double borderRadius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _anim = Tween(begin: 0.3, end: 0.9).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    _ctrl.repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, _) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          color: AppColors.border.withValues(alpha: _anim.value),
        ),
      ),
    );
  }
}

/// A skeleton that mimics a RideCard for loading states on the feed.
class RideCardSkeleton extends StatelessWidget {
  const RideCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Rider row
          Row(
            children: [
              const SkeletonBox(width: 40, height: 40, borderRadius: 20),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 110, height: 13),
                    SizedBox(height: 5),
                    SkeletonBox(width: 75, height: 11),
                  ],
                ),
              ),
              const SkeletonBox(width: 36, height: 13),
            ],
          ),
          const SizedBox(height: 16),
          // Route
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    SkeletonBox(width: double.infinity, height: 12),
                    SizedBox(height: 16),
                    SkeletonBox(width: 180, height: 12),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 12),
          // Info chips
          Row(
            children: const [
              SkeletonBox(width: 90, height: 26, borderRadius: 8),
              SizedBox(width: 8),
              SkeletonBox(width: 60, height: 26, borderRadius: 8),
              SizedBox(width: 8),
              SkeletonBox(width: 68, height: 26, borderRadius: 8),
            ],
          ),
        ],
      ),
    );
  }
}

/// A skeleton that mimics the ride detail screen layout.
class RideDetailSkeleton extends StatelessWidget {
  const RideDetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Rider card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const SkeletonBox(width: 56, height: 56, borderRadius: 28),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(width: 130, height: 16),
                      SizedBox(height: 8),
                      SkeletonBox(width: 90, height: 12),
                    ],
                  ),
                ),
                const SkeletonBox(width: 40, height: 40, borderRadius: 20),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Section: Route
          const SkeletonBox(width: 50, height: 12),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: double.infinity, height: 14),
                SizedBox(height: 12),
                SkeletonBox(width: 200, height: 14),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Section: Details
          const SkeletonBox(width: 60, height: 12),
          const SizedBox(height: 10),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SkeletonBox(width: 140, height: 34, borderRadius: 20),
              SkeletonBox(width: 80, height: 34, borderRadius: 20),
              SkeletonBox(width: 90, height: 34, borderRadius: 20),
            ],
          ),
          const SizedBox(height: 28),

          // CTA button
          const SkeletonBox(width: double.infinity, height: 48, borderRadius: 12),
        ],
      ),
    );
  }
}

/// A skeleton that mimics a join request card.
class RequestCardSkeleton extends StatelessWidget {
  const RequestCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              SkeletonBox(width: 44, height: 44, borderRadius: 22),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 110, height: 14),
                    SizedBox(height: 6),
                    SkeletonBox(width: 80, height: 12),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: const [
              Expanded(child: SkeletonBox(width: double.infinity, height: 40, borderRadius: 8)),
              SizedBox(width: 12),
              Expanded(child: SkeletonBox(width: double.infinity, height: 40, borderRadius: 8)),
            ],
          ),
        ],
      ),
    );
  }
}

/// A skeleton that mimics the rider verification / profile form screens.
class FormScreenSkeleton extends StatelessWidget {
  const FormScreenSkeleton({super.key, this.fieldCount = 5});

  final int fieldCount;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        for (int i = 0; i < fieldCount; i++) ...[
          const SkeletonBox(width: double.infinity, height: 56, borderRadius: 10),
          const SizedBox(height: 16),
        ],
        const SizedBox(height: 8),
        const SkeletonBox(width: double.infinity, height: 56, borderRadius: 10),
        const SizedBox(height: 12),
        const SkeletonBox(width: double.infinity, height: 56, borderRadius: 10),
        const SizedBox(height: 28),
        const SkeletonBox(width: double.infinity, height: 50, borderRadius: 12),
      ],
    );
  }
}
