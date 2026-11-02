import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../controllers/home_controller.dart';
import '../../../core/constants/app_constants.dart';
import '../../../widgets/luxury_ui_components.dart';

/// Categories browsing destination displaying all fashion departments.
class CategoriesView extends StatelessWidget {
  final VoidCallback? onCategorySelected;

  const CategoriesView({super.key, this.onCategorySelected});

  @override
  Widget build(BuildContext context) {
    return Consumer<HomeController>(
      builder: (context, controller, _) {
        final categories = controller.categories;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.background,
            elevation: 0,
            title: const Text(
              'Departments & Categories',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.mainText,
                letterSpacing: -0.3,
              ),
            ),
          ),
          body: categories.isEmpty
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.luxuryWine),
                )
              : Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 260,
                      childAspectRatio: 1.15,
                      crossAxisSpacing: AppSpacing.md,
                      mainAxisSpacing: AppSpacing.md,
                    ),
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      final category = categories[index];
                      final isSelected =
                          controller.selectedCategoryId == category.id;

                      return StaggeredSlideFade(
                        index: index,
                        child: Material(
                          color: AppColors.cardBackground,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          elevation: isSelected ? 4 : 1,
                          shadowColor: isSelected
                              ? AppColors.luxuryWine.withAlpha(50)
                              : AppColors.divider,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            onTap: () {
                              controller.selectCategory(category.id);
                              controller.setBottomNavIndex(0); // Return to home tab
                              onCategorySelected?.call();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Showing ${category.name} collection',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  backgroundColor: AppColors.luxuryWine,
                                  behavior: SnackBarBehavior.floating,
                                  duration: const Duration(seconds: 1),
                                ),
                              );
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOut,
                              decoration: BoxDecoration(
                                borderRadius:
                                    BorderRadius.circular(AppRadius.lg),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.champagneGold
                                      : AppColors.divider,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              padding: const EdgeInsets.all(AppSpacing.md),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding:
                                        const EdgeInsets.all(AppSpacing.md),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppColors.luxuryWine
                                          : AppColors.luxuryWine.withAlpha(18),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      category.icon,
                                      size: 30,
                                      color: isSelected
                                          ? AppColors.white
                                          : AppColors.luxuryWine,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  Text(
                                    category.name,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: isSelected
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                      color: isSelected
                                          ? AppColors.luxuryWine
                                          : AppColors.mainText,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                  if (category.itemCount != null)
                                    Text(
                                      '${category.itemCount} items',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.secondaryText,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
        );
      },
    );
  }
}
