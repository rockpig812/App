import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'providers/session_provider.dart';
import 'providers/transaction_provider.dart';
import 'repositories/room_repository.dart';
import 'models/room_model.dart';
import 'screens/transactions/add_transaction_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/goals_screen.dart';
import 'screens/room_settings_screen.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _showRoomPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _RoomPickerSheet(),
    );
  }

  void _showCalendarPicker(BuildContext context) {
    final txProvider = context.read<TransactionProvider>();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('選擇查看日期', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  TableCalendar(
                    firstDay: DateTime.utc(2020, 1, 1),
                    lastDay: DateTime.utc(2030, 12, 31),
                    focusedDay: txProvider.filterDate ?? DateTime.now(),
                    currentDay: DateTime.now(),
                    calendarFormat: CalendarFormat.month,
                    selectedDayPredicate: (day) => isSameDay(txProvider.filterDate, day),
                    onDaySelected: (selectedDay, focusedDay) {
                      txProvider.setFilterDate(selectedDay);
                      Navigator.pop(context);
                    },
                    headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
                    calendarStyle: CalendarStyle(
                      selectedDecoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, shape: BoxShape.circle),
                      todayDecoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withOpacity(0.3), shape: BoxShape.circle),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      txProvider.setFilterDate(null);
                      Navigator.pop(context);
                    },
                    child: const Text('顯示全部'),
                  ),
                ],
              ),
            );
          }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final session = context.watch<SessionProvider>();
    final txProvider = context.watch<TransactionProvider>();
    final roomId = session.profile?.lastActiveRoomId ?? '';

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            onPressed: () => _showCalendarPicker(context),
            icon: Icon(
              txProvider.filterDate == null ? Icons.calendar_today_outlined : Icons.event_available,
              color: txProvider.filterDate == null ? colorScheme.onSurface : colorScheme.primary,
            ),
          ),
          const SizedBox(width: 8),
        ],
        title: StreamBuilder<RoomModel?>(
          stream: roomId.isEmpty ? const Stream.empty() : context.read<RoomRepository>().watchRoom(roomId),
          builder: (context, snapshot) {
            final roomName = snapshot.data?.name ?? "載入中...";
            return InkWell(
              onTap: () => _showRoomPicker(context),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      roomName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.keyboard_arrow_down_rounded, 
                      color: colorScheme.primary,
                      size: 20,
                    ),
                  ],
                ),
              ),
            );
          }
        ),
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() => _currentIndex = index);
        },
        children: [
          const DashboardScreen(),
          GoalsScreen(roomId: roomId, showAppBar: false),
          const RoomSettingsView(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
          _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 400),
            curve: Curves.fastOutSlowIn,
          );
        },
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.primaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.space_dashboard_outlined),
            selectedIcon: Icon(Icons.space_dashboard),
            label: '首頁',
          ),
          NavigationDestination(
            icon: Icon(Icons.star_outline_rounded),
            selectedIcon: Icon(Icons.star_rounded),
            label: '願望清單',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_outlined),
            selectedIcon: Icon(Icons.tune),
            label: '空間設定',
          ),
        ],
      ),
      floatingActionButton: (_currentIndex == 0 || _currentIndex == 1)
          ? Container(
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [colorScheme.primary, colorScheme.secondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.primary.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: FloatingActionButton.extended(
                onPressed: () {
                  if (_currentIndex == 0) {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AddTransactionScreen()),
                    );
                  } else {
                    showDialog(
                      context: context,
                      builder: (context) => AddGoalDialog(roomId: roomId),
                    );
                  }
                },
                label: Text(
                  _currentIndex == 0 ? '記一筆' : '許願',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                icon: const Icon(Icons.add_rounded, color: Colors.white),
                backgroundColor: Colors.transparent,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
            )
          : null,
    );
  }
}

class _RoomPickerSheet extends StatelessWidget {
  const _RoomPickerSheet();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final session = context.watch<SessionProvider>();
    final roomRepo = context.read<RoomRepository>();
    final joinedRoomIds = session.profile?.joinedRoomIds ?? [];
    final activeRoomId = session.profile?.lastActiveRoomId;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.only(top: 12, bottom: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                const Text(
                  '切換空間',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                IconButton.filledTonal(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: joinedRoomIds.length,
              itemBuilder: (context, index) {
                final rId = joinedRoomIds[index];
                return FutureBuilder<RoomModel?>(
                  future: roomRepo.getRoom(rId),
                  builder: (context, snap) {
                    final room = snap.data;
                    if (room == null) return const SizedBox.shrink();
                    return _buildRoomItem(
                      context,
                      name: room.name,
                      roomId: rId,
                      icon: room.type == RoomType.personal ? Icons.person_rounded : Icons.people_rounded,
                      isSelected: rId == activeRoomId,
                      color: room.type == RoomType.personal ? Colors.blue : Colors.pink,
                    );
                  },
                );
              },
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Divider(height: 1),
          ),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 24),
            leading: Icon(Icons.add_circle_outline_rounded, color: colorScheme.primary),
            title: const Text('建立新空間', style: TextStyle(fontWeight: FontWeight.w600)),
            onTap: () {
              Navigator.pop(context);
              _showCreateRoomDialog(context);
            },
          ),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 24),
            leading: Icon(Icons.qr_code_scanner_rounded, color: colorScheme.primary),
            title: const Text('加入代碼', style: TextStyle(fontWeight: FontWeight.w600)),
            onTap: () {
              Navigator.pop(context);
              _showJoinRoomDialog(context);
            },
          ),
        ],
      ),
    );
  }

  void _showCreateRoomDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('建立新空間'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: '空間名稱'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                final session = context.read<SessionProvider>();
                await context.read<RoomRepository>().createRoom(
                  creatorId: session.firebaseUser!.uid,
                  name: name,
                  type: RoomType.group,
                );
                Navigator.pop(context);
              }
            },
            child: const Text('建立'),
          ),
        ],
      ),
    );
  }

  void _showJoinRoomDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('加入空間'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: '請輸入 6 位數邀請碼'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              final code = controller.text.trim();
              if (code.isNotEmpty) {
                final session = context.read<SessionProvider>();
                final roomId = await context.read<RoomRepository>().joinRoom(
                  inviteCode: code,
                  userId: session.firebaseUser!.uid,
                );
                if (roomId != null) {
                  await session.switchRoom(roomId);
                }
                Navigator.pop(context);
              }
            },
            child: const Text('加入'),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomItem(
    BuildContext context, {
    required String name,
    required String roomId,
    required IconData icon,
    required bool isSelected,
    required Color color,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? colorScheme.primaryContainer.withOpacity(0.3) : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(
          name,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? colorScheme.onPrimaryContainer : colorScheme.onSurface,
          ),
        ),
        trailing: isSelected 
          ? Icon(Icons.check_circle_rounded, color: colorScheme.primary)
          : null,
        onTap: () {
          context.read<SessionProvider>().switchRoom(roomId);
          Navigator.pop(context);
        },
      ),
    );
  }
}
