import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'services/firestore_service.dart';
import 'providers/session_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/pairing_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/joint_pot_screen.dart';
import 'screens/goals_screen.dart';

Future<void> main() async {
  // Firebase 初始化：在使用任何 Firebase 服務前一定要先做這步
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(
    MultiProvider(
      providers: [
        Provider(create: (_) => FirestoreService()),
        ChangeNotifierProvider(create: (_) => SessionProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Couples Finance',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.pink),
      ),
      home: const _RootRouter(),
    );
  }
}

class _RootRouter extends StatelessWidget {
  const _RootRouter();

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();

    if (session.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!session.isLoggedIn) {
      return const LoginScreen();
    }

    // 登入成功，但 users/{uid}.current_couple_id 還是 null -> 進入配對流程
    if (!session.isPaired) {
      return const PairingScreen();
    }

    return const _HomeShell();
  }
}

/// App 內部主框架：底部有 Expenses / Pot / Goals 的 BottomNavigationBar
class _HomeShell extends StatefulWidget {
  const _HomeShell();

  @override
  State<_HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<_HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final coupleId = session.profile?.currentCoupleId ?? '';

    // 若沒有 coupleId，理論上 _RootRouter 會擋住，但這裡多做一層保護
    if (coupleId.isEmpty) {
      return const Center(child: Text('Error: No Couple ID'));
    }

    final pages = [
      const DashboardScreen(),
      JointPotScreen(coupleId: coupleId),
      GoalsScreen(coupleId: coupleId),
    ];

    return Scaffold(
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: '分帳', // Expenses
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: '公基金', // Joint Pot
          ),
          NavigationDestination(
            icon: Icon(Icons.flag_outlined),
            selectedIcon: Icon(Icons.flag),
            label: '目標', // Goals
          ),
        ],
        onDestinationSelected: (i) {
          setState(() => _index = i);
        },
      ),
    );
  }
}
