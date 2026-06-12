import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'services/firestore_service.dart';
import 'providers/session_provider.dart';
import 'providers/joint_pot_provider.dart';
import 'repositories/joint_pot_repository.dart';
import 'repositories/room_repository.dart';
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
        ProxyProvider<FirestoreService, JointPotRepository>(
          update: (_, service, __) => JointPotRepository(service),
        ),
        ProxyProvider<FirestoreService, RoomRepository>(
          update: (_, service, __) => RoomRepository(),
        ),
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

    if (session.error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text('Login Error: ${session.error}', textAlign: TextAlign.center),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => session.signOut(),
                  child: const Text('Back to Login'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (!session.isLoggedIn) {
      return const LoginScreen();
    }

    // 登入成功，但 joinedRoomIds 是空的 -> 進入配對流程
    if (!session.isJoinedRoom) {
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
    final roomId = session.profile?.lastActiveRoomId ?? '';

    // 若沒有 roomId，理論上 _RootRouter 會擋住，但這裡多做一層保護
    if (roomId.isEmpty) {
      return const Center(child: Text('Error: No Room ID'));
    }

    final pages = [
      const DashboardScreen(),
      ChangeNotifierProvider(
        key: ValueKey('room_$roomId'),
        create: (context) => JointPotProvider(
          repository: context.read<JointPotRepository>(),
          roomId: roomId,
        ),
        child: const JointPotScreen(),
      ),
      GoalsScreen(roomId: roomId),
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
