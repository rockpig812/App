import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/session_provider.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final coupleId = session.profile?.currentCoupleId ?? '(null)';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard (Placeholder)'),
        actions: [
          IconButton(
            onPressed: () => context.read<SessionProvider>().signOut(),
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Logged in as: ${session.firebaseUser?.email ?? session.firebaseUser?.uid ?? ''}',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text('current_couple_id: $coupleId'),
              const SizedBox(height: 24),
              const Text(
                'Phase 2 will implement the real Dashboard:\n'
                '- Net balance card\n'
                '- Transaction list\n',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

