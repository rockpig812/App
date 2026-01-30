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
      id: 'household',
      label: 'Household',
      icon: Icons.home,
      color: Colors.orange,
    ),
    TransactionCategory(
      id: 'food',
      label: 'Food',
      icon: Icons.restaurant,
      color: Colors.redAccent,
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
