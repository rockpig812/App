import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';

Future<void> main() async {
  // Firebase 初始化：在使用任何 Firebase 服務前一定要先做這步
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Couple Accounting – Firebase Test',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.pink),
      ),
      home: const FirebaseTestPage(),
    );
  }
}

/// 測試頁面：負責
/// 1. 匿名登入並顯示 UID
/// 2. 送出一筆記帳紀錄到 Firestore
/// 3. 即時監聽 expenses 集合
class FirebaseTestPage extends StatefulWidget {
  const FirebaseTestPage({super.key});

  @override
  State<FirebaseTestPage> createState() => _FirebaseTestPageState();
}

class _FirebaseTestPageState extends State<FirebaseTestPage> {
  // 這裡的成員變數就像 C++ 類別裡的 private 成員：
  // std::string m_uid; double m_amount; std::string m_title;
  String? _uid;
  bool _isSigningIn = true;
  String? _signInError;

  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _signInAnonymouslyIfNeeded();
  }

  /// 自動匿名登入。
  /// 對 C++ 來說，可以想成是建構子裡啟動的一個非同步初始化流程，
  /// 成功後會更新成員變數，並觸發重繪 (setState)。
  Future<void> _signInAnonymouslyIfNeeded() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      User? user;

      if (currentUser == null) {
        final credential = await FirebaseAuth.instance.signInAnonymously();
        user = credential.user;
      } else {
        user = currentUser;
      }

      setState(() {
        _uid = user?.uid;
        _isSigningIn = false;
        _signInError = null;
      });
    } catch (e) {
      setState(() {
        _signInError = e.toString();
        _isSigningIn = false;
      });
    }
  }

  /// 新增一筆開銷到 Firestore。
  /// 這類似 C++ 中呼叫某個 Service 物件的成員函式去「寫入資料庫」。
  Future<void> _addExpense() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final rawAmount = _amountController.text.trim();
    final title = _titleController.text.trim();
    if (rawAmount.isEmpty || title.isEmpty) return;

    final amount = double.tryParse(rawAmount);
    if (amount == null) return;

    await FirebaseFirestore.instance.collection('expenses').add({
      'amount': amount,
      'title': title,
      'creatorId': uid,
      'timestamp': FieldValue.serverTimestamp(),
    });

    // 清空輸入框
    _amountController.clear();
    _titleController.clear();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Firebase 匿名登入＆記帳測試'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. 顯示登入狀態與 UID
            if (_isSigningIn)
              const Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text('正在進行匿名登入中...'),
                ],
              )
            else if (_signInError != null)
              Text(
                '登入失敗：$_signInError',
                style: const TextStyle(color: Colors.red),
              )
            else
              Text(
                '我的 UID：$_uid',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),

            // 2. 記帳表單
            const Text(
              '情侶記帳測試表單',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: '金額',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '項目名稱',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _uid == null ? null : _addExpense,
                icon: const Icon(Icons.add),
                label: const Text('新增這筆開銷'),
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),

            const Text(
              '即時記帳清單（expenses 集合）',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            // 3. 即時清單：使用 StreamBuilder 監聽 Firestore
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('expenses')
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text('讀取資料時發生錯誤：${snapshot.error}'),
                    );
                  }

                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return const Center(
                      child: Text('目前還沒有任何記帳紀錄。'),
                    );
                  }

                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data();
                      final amount = (data['amount'] ?? 0).toString();
                      final title = data['title'] ?? '';
                      final creatorId = data['creatorId'] ?? '';

                      return ListTile(
                        leading: const Icon(Icons.receipt_long),
                        title: Text(title),
                        subtitle: Text('金額：$amount\n建立者 UID：$creatorId'),
                        isThreeLine: true,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
