import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

// State 類別：這就像是 C++ 中的類別實例 (Instance)，它持有頁面的狀態資料。
// 當 Widget 被銷毀時，State 也會隨之銷毀 (類似解構子)。
class _HomePageState extends State<HomePage> {
  // 1. 成員變數 (Member Variable)
  // 這就像 C++ 類別中的 private 成員變數 (例如: int m_balance = 0;)
  // 用來儲存當前的共同存款金額。
  int _balance = 0;

  // 2. 更新狀態的方法
  // 這類似 C++ 的 setter 或成員函式，用來修改資料。
  void _deposit() {
    // setState 告訴 Flutter 框架：「狀態改變了，請重新繪製 UI！」
    // 這就像在 C++ GUI 框架 (如 Qt) 中呼叫 update() 或 repaint()。
    // 如果只寫 _balance += 100; 而沒有 setState，資料會變，但畫面不會更新。
    setState(() {
      _balance += 100;
    });
  }

  void _spend() {
    setState(() {
      _balance -= 100;
    });
  }

  @override
  Widget build(BuildContext context) {
    // build 方法就像是繪製函式 (Render function)。
    // 每次呼叫 setState 時，Flutter 都會重新執行這個 build 方法，
    // 根據最新的 _balance 產生新的 Widget 樹 (Widget Tree)。
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('情侶共同記帳 App'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              '目前共同存款',
              style: TextStyle(fontSize: 24, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            // 顯示金額的文字
            Text(
              '\$$_balance',
              style: TextStyle(
                fontSize: 60,
                fontWeight: FontWeight.bold,
                // 使用主要顏色 (粉紅色)
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 50),
            // 操作按鈕區域
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 存入按鈕 (綠色)
                FilledButton.icon(
                  onPressed: _deposit,
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('存入 \$100'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green, // 覆蓋主題色，指定為綠色
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                ),
                const SizedBox(width: 30), // 按鈕之間的間距
                // 花費按鈕 (紅色)
                FilledButton.icon(
                  onPressed: _spend,
                  icon: const Icon(Icons.remove_circle_outline),
                  label: const Text('花費 \$100'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.redAccent, // 覆蓋主題色，指定為紅色
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    textStyle: const TextStyle(fontSize: 18),
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
