import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ListSkeleton extends StatelessWidget {
  final int itemCount;
  final double height;
  final EdgeInsets padding;

  const ListSkeleton({
    super.key,
    this.itemCount = 5,
    this.height = 72,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListView.separated(
      padding: padding,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, _) => Shimmer.fromColors(
        baseColor: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        highlightColor: cs.surfaceContainerHighest.withValues(alpha: 0.7),
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

class GridSkeleton extends StatelessWidget {
  final int itemCount;
  final double crossAxisExtent;
  final double aspectRatio;
  final EdgeInsets padding;

  const GridSkeleton({
    super.key,
    this.itemCount = 8,
    this.crossAxisExtent = 200,
    this.aspectRatio = 0.7,
    this.padding = const EdgeInsets.all(12),
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GridView.builder(
      padding: padding,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: crossAxisExtent,
        childAspectRatio: aspectRatio,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: itemCount,
      itemBuilder: (_, _) => Shimmer.fromColors(
        baseColor: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        highlightColor: cs.surfaceContainerHighest.withValues(alpha: 0.7),
        child: Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}
