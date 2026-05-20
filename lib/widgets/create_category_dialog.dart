import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Dialog for creating a new category.
///
/// Returns a `({String name, String? color})` record on confirm,
/// or `null` on cancel.
class CreateCategoryDialog extends StatefulWidget {
  const CreateCategoryDialog({
    super.key,
    required this.colors,
  });

  final WeatherThemeColors colors;

  @override
  State<CreateCategoryDialog> createState() =>
      _CreateCategoryDialogState();
}

class _CreateCategoryDialogState
    extends State<CreateCategoryDialog> {
  final _nameController = TextEditingController();
  String? _selectedColor;

  static const _presetColors = [
    '#E55934', // Running
    '#43A047', // Hiking
    '#1E88E5', // Cycling
    '#8E24AA', // Photography
    '#F4B942', // Beach
    '#039BE5', // Skiing
    '#8D6E63', // Camping
    '#FB8C00', // Picnic
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;

    return Dialog(
      backgroundColor: colors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          OutAboutRadius.lg,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(OutAboutSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'New Category',
              style:
                  OutAboutTypography.headingMedium(colors),
            ),
            const SizedBox(height: OutAboutSpacing.md),
            TextField(
              controller: _nameController,
              autofocus: true,
              style: OutAboutTypography.bodyMedium(colors),
              decoration: InputDecoration(
                labelText: 'Category name',
                labelStyle:
                    OutAboutTypography.bodySmall(colors),
                filled: true,
                fillColor: colors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    OutAboutRadius.buttons,
                  ),
                  borderSide:
                      BorderSide(color: colors.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    OutAboutRadius.buttons,
                  ),
                  borderSide:
                      BorderSide(color: colors.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    OutAboutRadius.buttons,
                  ),
                  borderSide: BorderSide(
                    color: colors.primary,
                    width: 2,
                  ),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: OutAboutSpacing.md),
            Text(
              'Color',
              style: OutAboutTypography.labelMedium(colors),
            ),
            const SizedBox(height: OutAboutSpacing.sm),
            _ColorPicker(
              presetColors: _presetColors,
              selectedColor: _selectedColor,
              themeColors: colors,
              onSelect: (color) =>
                  setState(() => _selectedColor = color),
            ),
            const SizedBox(height: OutAboutSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () =>
                      Navigator.of(context).pop(null),
                  child: Text(
                    'Cancel',
                    style: OutAboutTypography.labelLarge(
                      colors,
                    ).copyWith(color: colors.textSecondary),
                  ),
                ),
                const SizedBox(width: OutAboutSpacing.sm),
                ElevatedButton(
                  onPressed: _nameController.text
                          .trim()
                          .isEmpty
                      ? null
                      : () {
                          Navigator.of(context).pop((
                            name: _nameController.text
                                .trim(),
                            color: _selectedColor,
                          ));
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    disabledBackgroundColor:
                        colors.primary.withValues(
                      alpha: 0.3,
                    ),
                  ),
                  child: Text(
                    'Create',
                    style: OutAboutTypography.labelLarge(
                      colors,
                    ).copyWith(
                      color: _nameController.text
                              .trim()
                              .isEmpty
                          ? colors.textSecondary
                          : colors.cardBackground,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Color picker row
// ---------------------------------------------------------------------------

class _ColorPicker extends StatelessWidget {
  const _ColorPicker({
    required this.presetColors,
    required this.selectedColor,
    required this.themeColors,
    required this.onSelect,
  });

  final List<String> presetColors;
  final String? selectedColor;
  final WeatherThemeColors themeColors;
  final ValueChanged<String?> onSelect;

  Color _parseHex(String hex) {
    final cleaned = hex.replaceFirst('#', '');
    final value = int.parse(cleaned, radix: 16);
    return Color(0xFF000000 | value);
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: OutAboutSpacing.sm,
      runSpacing: OutAboutSpacing.sm,
      children: [
        // "No color" option
        _ColorCircle(
          color: null,
          isSelected: selectedColor == null,
          themeColors: themeColors,
          onTap: () => onSelect(null),
        ),
        // Preset colors
        for (final hex in presetColors)
          _ColorCircle(
            color: _parseHex(hex),
            isSelected: selectedColor == hex,
            themeColors: themeColors,
            onTap: () => onSelect(hex),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Individual color circle
// ---------------------------------------------------------------------------

class _ColorCircle extends StatelessWidget {
  const _ColorCircle({
    required this.color,
    required this.isSelected,
    required this.themeColors,
    required this.onTap,
  });

  final Color? color;
  final bool isSelected;
  final WeatherThemeColors themeColors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 48,
        height: 48,
        child: Center(
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color ?? themeColors.surface,
              border: color == null
                  ? Border.all(
                      color: themeColors.divider,
                    )
                  : null,
            ),
            foregroundDecoration: isSelected
                ? BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: themeColors.primary,
                      width: 2.5,
                    ),
                  )
                : null,
            child: color == null
                ? Icon(
                    Icons.block,
                    size: 14,
                    color: themeColors.textSecondary,
                  )
                : null,
          ),
        ),
      ),
    );
  }
}
