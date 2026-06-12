import 'package:flutter/material.dart';
import '../models/category_model.dart';

class CategoryGrid extends StatelessWidget {
  final String selectedCategoryId;
  final Function(String categoryId) onCategorySelected;

  const CategoryGrid({
    super.key,
    required this.selectedCategoryId,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      mainAxisSpacing: 12,
      crossAxisSpacing: 8,
      childAspectRatio: 0.9,
      children: TransactionCategory.presets.map((cat) {
        final isSelected = cat.id == selectedCategoryId;
        final colorScheme = Theme.of(context).colorScheme;

        return GestureDetector(
          onTap: () {
            onCategorySelected(cat.id);
          },
          behavior: HitTestBehavior.opaque,
          child: AnimatedScale(
            duration: const Duration(milliseconds: 200),
            scale: isSelected ? 1.15 : 1.0,
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: isSelected ? cat.color : colorScheme.surfaceContainerHighest.withOpacity(0.5),
                    shape: BoxShape.circle,
                    boxShadow: isSelected ? [
                      BoxShadow(
                        color: cat.color.withOpacity(0.5),
                        blurRadius: 15,
                        spreadRadius: 2,
                        offset: const Offset(0, 4),
                      )
                    ] : [],
                    border: isSelected ? Border.all(color: Colors.white, width: 2.5) : null,
                  ),
                  child: Icon(
                    cat.icon,
                    color: isSelected ? Colors.white : cat.color.withOpacity(0.8),
                    size: 28,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  cat.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? cat.color : colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
