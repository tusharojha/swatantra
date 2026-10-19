import 'package:flutter/material.dart';
import '../theme.dart';

class Skeleton extends StatefulWidget {
  final double height;
  final double? width;
  final double radius;
  const Skeleton({super.key, this.height = 14, this.width, this.radius = Swa.radiusSm});

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.45, end: 1.0).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
      child: Container(
        height: widget.height,
        width: widget.width ?? double.infinity,
        decoration: BoxDecoration(
          color: Swa.wash,
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

class FeedSkeleton extends StatelessWidget {
  const FeedSkeleton({super.key});
  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Skeleton(height: 12, width: 88),
        SizedBox(height: 16),
        Skeleton(height: 200, radius: Swa.radiusMd),
        SizedBox(height: 16),
        Skeleton(height: 28),
        SizedBox(height: 8),
        Skeleton(height: 28, width: 260),
        SizedBox(height: 16),
        Skeleton(height: 14, width: 180),
        SizedBox(height: 32),
        Skeleton(height: 88, radius: Swa.radiusMd),
        SizedBox(height: 12),
        Skeleton(height: 88, radius: Swa.radiusMd),
      ],
    );
  }
}

class ArticleSkeleton extends StatelessWidget {
  const ArticleSkeleton({super.key});
  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Skeleton(height: 12, width: 72),
        SizedBox(height: 16),
        Skeleton(height: 32),
        SizedBox(height: 8),
        Skeleton(height: 32, width: 220),
        SizedBox(height: 20),
        Skeleton(height: 220, radius: Swa.radiusMd),
        SizedBox(height: 20),
        Skeleton(height: 14),
        SizedBox(height: 8),
        Skeleton(height: 14),
        SizedBox(height: 8),
        Skeleton(height: 14, width: 200),
      ],
    );
  }
}

class EmptyState extends StatelessWidget {
  final String title;
  final String dek;
  final IconData? icon;
  final Widget? action;
  const EmptyState({super.key, required this.title, required this.dek, this.icon, this.action});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Swa.wash,
                borderRadius: BorderRadius.circular(Swa.radiusLg),
                border: Border.all(color: Swa.line),
              ),
              child: Icon(icon, size: 28, color: Swa.magenta),
            ),
            const SizedBox(height: 20),
          ],
          Text(title, style: Swa.playfair(size: 24)),
          const SizedBox(height: 8),
          Text(dek, style: Swa.serif(size: 16, color: Swa.muted, height: 1.45)),
          if (action != null) ...[
            const SizedBox(height: 20),
            action!,
          ],
        ],
      ),
    );
  }
}

class ErrorNote extends StatelessWidget {
  final String text;
  const ErrorNote(this.text, {super.key});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(text, style: Swa.serif(size: 14, color: Swa.muted, height: 1.45)),
    );
  }
}
