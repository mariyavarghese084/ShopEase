import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';
import '../models/category_model.dart';

/// Interactive luxury chip for selecting a product category.
class CategoryItem extends StatefulWidget {
  final CategoryModel category;
  final bool isSelected;
  final VoidCallback onTap;

  const CategoryItem({
    super.key,
    required this.category,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<CategoryItem> createState() => _CategoryItemState();
}

class _CategoryItemState extends State<CategoryItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isSelected = widget.isSelected;
    final category = widget.category;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(AppRadius.full),
          splashColor: AppColors.luxuryWine.withAlpha(25),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            transform: Matrix4.translationValues(0, _isHovered ? -1.5 : 0, 0),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm + 2,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.luxuryWine
                  : (_isHovered
                      ? AppColors.luxuryWine.withAlpha(14)
                      : AppColors.cardBackground),
              borderRadius: BorderRadius.circular(AppRadius.full),
              border: Border.all(
                color: isSelected
                    ? AppColors.champagneGold
                    : (_isHovered
                        ? AppColors.luxuryWine.withAlpha(120)
                        : AppColors.divider),
                width: isSelected ? 1.4 : 1.0,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppColors.luxuryWine.withAlpha(50),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: AppColors.mainText.withAlpha(_isHovered ? 12 : 6),
                        blurRadius: _isHovered ? 6 : 4,
                        offset: Offset(0, _isHovered ? 2 : 1),
                      ),
                    ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  category.icon,
                  size: 18,
                  color: isSelected ? AppColors.white : AppColors.secondaryText,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  category.name,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? AppColors.white : AppColors.mainText,
                    letterSpacing: 0.1,
                  ),
                ),
                if (category.itemCount != null && isSelected) ...[
                  const SizedBox(width: AppSpacing.xs),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.champagneGold.withAlpha(70),
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: Text(
                      '${category.itemCount}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
