import 'package:flutter/material.dart';

enum CategoryType {
  household,
  food,
  bills,
  transport,
  health,
  entertainment,
  pets,
  other,
}

class TransactionCategory {
  final String id;
  final String label;
  final IconData icon;
  final Color color;

  const TransactionCategory({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
  });

  static const List<TransactionCategory> presets = [
    TransactionCategory(
      id: 'breakfast',
      label: '早餐',
      icon: Icons.bakery_dining_rounded,
      color: Colors.orangeAccent,
    ),
    TransactionCategory(
      id: 'lunch',
      label: '午餐',
      icon: Icons.lunch_dining_rounded,
      color: Colors.orange,
    ),
    TransactionCategory(
      id: 'dinner',
      label: '晚餐',
      icon: Icons.dinner_dining_rounded,
      color: Colors.deepOrange,
    ),
    TransactionCategory(
      id: 'food',
      label: '食物',
      icon: Icons.restaurant,
      color: Colors.redAccent,
    ),
    TransactionCategory(
      id: 'household',
      label: '居家',
      icon: Icons.home,
      color: Colors.blueAccent,
    ),
    TransactionCategory(
      id: 'bills',
      label: 'Bills',
      icon: Icons.receipt_long,
      color: Colors.blue,
    ),
    TransactionCategory(
      id: 'transport',
      label: 'Transport',
      icon: Icons.directions_car,
      color: Colors.green,
    ),
    TransactionCategory(
      id: 'health',
      label: 'Health',
      icon: Icons.local_hospital,
      color: Colors.teal,
    ),
    TransactionCategory(
      id: 'entertainment',
      label: 'Fun',
      icon: Icons.movie,
      color: Colors.purple,
    ),
    TransactionCategory(
      id: 'pets',
      label: 'Pets',
      icon: Icons.pets,
      color: Colors.brown,
    ),
    TransactionCategory(
      id: 'other',
      label: 'Other',
      icon: Icons.category,
      color: Colors.grey,
    ),
  ];

  static TransactionCategory getById(String id) {
    return presets.firstWhere(
      (c) => c.id == id,
      orElse: () => presets.last, // 'other'
    );
  }
}
