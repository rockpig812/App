import 'package:flutter/material.dart';
import 'home_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Couple Accounting',
      theme: ThemeData(
        // 設定 Material 3 風格
        useMaterial3: true,
        // 設定主色調為粉紅色 (Pink)
        // 這會自動產生一整套相容的配色方案 (Color Scheme)
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.pink),
      ),
      // 指定首頁為 home_page.dart 中定義的 Widget
      home: const HomePage(),
    );
  }
}
