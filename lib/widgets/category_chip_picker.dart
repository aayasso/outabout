import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import '../core/providers.dart';
import '../core/theme.dart';
import '../core/weather_theme_provider.dart';
import '../data/models/category.dart';
import '../features/home/home_providers.dart';
import '../services/behavioral_event_service.dart';
import 'create_category_dialog.dart';

/// Shows [CreateCategoryDialog], inserts the new category into
/// Supabase, and refreshes the chip list.
///
/// Call this from each screen's `onCreateCategory` callback to
/// centralise the side-effect logic.
Future<void> showCreateCategoryFlow(
  BuildContext context,
  WidgetRef ref,
  WeatherThemeColors colors,
) async {
  final result = await showDialog<({String name, String? color})>(
    context: context,
    builder: (_) => CreateCategoryDialog(colors: colors),
  );
  if (result == null) return;
  try {
    final userId =
        ref.read(supabaseClientProvider).auth.currentUser?.id;
    if (userId == null) return;
    await ref.read(categoryRepositoryProvider).insert(
          Category(
            userId: userId,
            name: result.name,
            color: result.color,
          ),
        );
    ref.invalidate(categoriesProvider);
    ref.read(behavioralEventServiceProvider).log(
      'category_created',
      extra: {
        'category_name': result.name,
        'has_color': result.color != null,
      },
    );
    OutAboutHaptics.onActivitySave();
  } catch (e, st) {
    log(
      'Failed to create category',
      error: e,
      stackTrace: st,
      name: 'CategoryChipPicker',
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Couldn\'t create category'),
        ),
      );
    }
  }
}

/// Horizontal scrolling chip picker for activity categories.
///
/// Reads [categoriesProvider] and renders one chip per category
/// plus a trailing "+" chip for creating new categories.
class CategoryChipPicker extends ConsumerWidget {
  const CategoryChipPicker({
    super.key,
    required this.selectedIds,
    required this.onToggle,
    required this.onCreateCategory,
  });

  final Set<String> selectedIds;
  final ValueChanged<String> onToggle;
  final VoidCallback onCreateCategory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(weatherThemeColorsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    return categoriesAsync.when(
      loading: () => _ShimmerPlaceholder(colors: colors),
      error: (e, st) => _ErrorRow(
        colors: colors,
        onRetry: () => ref.invalidate(categoriesProvider),
      ),
      data: (categories) => _ChipRow(
        categories: categories,
        selectedIds: selectedIds,
        onToggle: onToggle,
        onCreateCategory: onCreateCategory,
        colors: colors,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Chip row — data loaded
// ---------------------------------------------------------------------------

class _ChipRow extends StatelessWidget {
  const _ChipRow({
    required this.categories,
    required this.selectedIds,
    required this.onToggle,
    required this.onCreateCategory,
    required this.colors,
  });

  final List<Category> categories;
  final Set<String> selectedIds;
  final ValueChanged<String> onToggle;
  final VoidCallback onCreateCategory;
  final WeatherThemeColors colors;

  @override
  Widget build(BuildContext context) {
    // Filter out orphaned IDs that are selected but not
    // in the fetched category list.
    for (final id in selectedIds) {
      final exists =
          categories.any((c) => c.id == id);
      if (!exists) {
        log(
          'Orphaned category reference: $id',
          name: 'CategoryChipPicker',
        );
      }
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final category in categories)
            if (category.id != null)
              Padding(
                padding: const EdgeInsets.only(
                  right: OutAboutSpacing.sm,
                ),
                child: _CategoryChip(
                  category: category,
                  isSelected:
                      selectedIds.contains(category.id),
                  onTap: () {
                    OutAboutHaptics.onConditionToggle();
                    onToggle(category.id!);
                  },
                  colors: colors,
                ),
              ),
          _AddChip(
            onTap: onCreateCategory,
            colors: colors,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Individual category chip
// ---------------------------------------------------------------------------

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.category,
    required this.isSelected,
    required this.onTap,
    required this.colors,
  });

  final Category category;
  final bool isSelected;
  final VoidCallback onTap;
  final WeatherThemeColors colors;

  Color _parseDotColor() {
    final hex = category.color;
    if (hex == null || hex.isEmpty) return colors.textSecondary;
    try {
      final cleaned =
          hex.replaceFirst('#', '');
      final value = int.parse(cleaned, radix: 16);
      return Color(
        cleaned.length == 6 ? (0xFF000000 | value) : value,
      );
    } catch (_) {
      return colors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dotColor = _parseDotColor();

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 48,
        child: Center(
          child: Container(
            constraints:
                const BoxConstraints(minHeight: 32),
            padding: const EdgeInsets.symmetric(
              horizontal: OutAboutSpacing.sm,
              vertical: OutAboutSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? colors.primary
                      .withValues(alpha: 0.15)
                  : colors.surface,
              borderRadius: BorderRadius.circular(
                OutAboutRadius.full,
              ),
              border: Border.all(
                color: isSelected
                    ? colors.primary
                    : colors.divider,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: OutAboutSpacing.xs),
                Text(
                  category.name,
                  style:
                      OutAboutTypography.labelMedium(colors),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// "+" add chip
// ---------------------------------------------------------------------------

class _AddChip extends StatelessWidget {
  const _AddChip({
    required this.onTap,
    required this.colors,
  });

  final VoidCallback onTap;
  final WeatherThemeColors colors;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 48,
        child: Center(
          child: Container(
            constraints:
                const BoxConstraints(minHeight: 32),
            padding: const EdgeInsets.symmetric(
              horizontal: OutAboutSpacing.sm,
              vertical: OutAboutSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(
                OutAboutRadius.full,
              ),
            ),
            child: CustomPaint(
              painter: _DashedBorderPainter(
                color: colors.divider,
                borderRadius: OutAboutRadius.full,
              ),
              child: Icon(
                Icons.add,
                size: 16,
                color: colors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Dashed border painter for the "+" chip
// ---------------------------------------------------------------------------

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({
    required this.color,
    required this.borderRadius,
  });

  final Color color;
  final double borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(0.5),
      Radius.circular(borderRadius),
    );
    final path = Path()..addRRect(rrect);

    const dashWidth = 4.0;
    const dashSpace = 3.0;
    final dashedPath = Path();
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + dashWidth)
            .clamp(0.0, metric.length);
        dashedPath.addPath(
          metric.extractPath(distance, end),
          Offset.zero,
        );
        distance += dashWidth + dashSpace;
      }
    }

    canvas.drawPath(dashedPath, paint);
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      color != old.color ||
      borderRadius != old.borderRadius;
}

// ---------------------------------------------------------------------------
// Shimmer loading placeholder
// ---------------------------------------------------------------------------

class _ShimmerPlaceholder extends StatelessWidget {
  const _ShimmerPlaceholder({
    required this.colors,
  });

  final WeatherThemeColors colors;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Row(
        children: List.generate(4, (index) {
          return Padding(
            padding: const EdgeInsets.only(
              right: OutAboutSpacing.sm,
            ),
            child: Shimmer.fromColors(
              baseColor: colors.surface,
              highlightColor: colors.divider,
              child: Container(
                width: 80,
                height: 32,
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(
                    OutAboutRadius.full,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Error row with retry
// ---------------------------------------------------------------------------

class _ErrorRow extends StatelessWidget {
  const _ErrorRow({
    required this.colors,
    required this.onRetry,
  });

  final WeatherThemeColors colors;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'Couldn\'t load categories',
          style: OutAboutTypography.bodySmall(colors),
        ),
        const SizedBox(width: OutAboutSpacing.sm),
        GestureDetector(
          onTap: onRetry,
          child: Text(
            'Retry',
            style: OutAboutTypography.labelMedium(
              colors,
            ).copyWith(color: colors.primary),
          ),
        ),
      ],
    );
  }
}
