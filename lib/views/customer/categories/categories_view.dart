import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../controllers/home_controller.dart';
import '../../../core/constants/app_constants.dart';

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
                fontWeight: FontWeight.bold,
                color: AppColors.mainText,
              ),
            ),
          ),
          body: categories.isEmpty
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primaryOrange),
                )
              : Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
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

                      return Material(
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        elevation: isSelected ? 4 : 1,
                        shadowColor: isSelected
                            ? AppColors.primaryOrange.withAlpha(60)
                            : AppColors.divider,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          onTap: () {
                            controller.selectCategory(category.id);
                            controller.setBottomNavIndex(0); // Return to home tab
                            onCategorySelected?.call();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Showing ${category.name} collection'),
                                backgroundColor: AppColors.primaryOrange,
                                behavior: SnackBarBehavior.floating,
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primaryOrange
                                    : AppColors.divider,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(AppSpacing.md),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.primaryOrange
                                        : AppColors.primaryOrange.withAlpha(20),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    category.icon,
                                    size: 32,
                                    color: isSelected
                                        ? AppColors.white
                                        : AppColors.primaryOrange,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                Text(
                                  category.name,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.w600,
                                    color: isSelected
                                        ? AppColors.primaryOrange
                                        : AppColors.mainText,
                                  ),
                                ),
                                if (category.itemCount != null)
                                  Text(
                                    '${category.itemCount} items',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.secondaryText,
                                    ),
                                  ),
                              ],
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
