import 'package:flutter/material.dart';
import '../models/category_model.dart';

class CategorySelector extends StatelessWidget {
  final String selectedCategoryId;
  final ValueChanged<String> onCategorySelected;

  const CategorySelector({
    Key? key,
    required this.selectedCategoryId,
    required this.onCategorySelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: TransactionCategory.presets.length,
        separatorBuilder: (ctx, i) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = TransactionCategory.presets[index];
          final isSelected = cat.id == selectedCategoryId;
          
          return ChoiceChip(
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  cat.icon,
                  size: 18,
                  color: isSelected ? Colors.white : cat.color,
                ),
                const SizedBox(width: 4),
                Text(cat.label),
              ],
            ),
            selected: isSelected,
            onSelected: (val) {
              if (val) {
                onCategorySelected(cat.id);
              }
            },
            selectedColor: cat.color,
            labelStyle: TextStyle(
              color: isSelected ? Colors.white : Colors.black,
            ),
            backgroundColor: Colors.white,
          );
        },
      ),
    );
  }
}
