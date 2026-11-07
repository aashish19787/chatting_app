import 'package:flutter/material.dart';

import '../../../models/chat_model.dart';
import '../../../services/firebase_auth_service.dart';
import '../../../services/firestore_service.dart';
import '../../chats/screens/chat_list_screen.dart';
import '../../feed/screens/feed_screen.dart';
import '../../notifications/screens/notifications_screen.dart';
import 'menu_screen.dart';
import 'people_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final _firestoreService = FirestoreService();
  final _authService = FirebaseAuthService();

  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final myUid = _authService.currentUser?.uid ?? '';

    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _index = 0);
      },
      child: Scaffold(
        body: IndexedStack(
          index: _index,
          children: [
            const ChatListScreen(),
            const FeedScreen(),
            const PeopleScreen(),
            NotificationsScreen(active: _index == 3),
            const MenuScreen(),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: [
            NavigationDestination(
              label: 'Chats',
              icon: StreamBuilder<List<ChatModel>>(
                stream: _firestoreService.chatsStream(myUid),
                builder: (context, snapshot) {
                  final unreadChats = (snapshot.data ?? const <ChatModel>[])
                      .where((c) => c.unreadFor(myUid) > 0)
                      .length;
                  return Badge(
                    isLabelVisible: unreadChats > 0,
                    label: Text(unreadChats > 99 ? '99+' : '$unreadChats'),
                    child: const Icon(Icons.chat_bubble_outline_rounded),
                  );
                },
              ),
              selectedIcon: const Icon(Icons.chat_bubble_rounded),
            ),
            const NavigationDestination(
              label: 'Home',
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
            ),
            const NavigationDestination(
              label: 'People',
              icon: Icon(Icons.people_outline_rounded),
              selectedIcon: Icon(Icons.people_rounded),
            ),
            NavigationDestination(
              label: 'Alerts',
              icon: StreamBuilder<int>(
                stream: _firestoreService.unreadNotificationsCount(myUid),
                builder: (context, snapshot) {
                  final count = snapshot.data ?? 0;
                  return Badge(
                    isLabelVisible: count > 0,
                    label: Text(count > 99 ? '99+' : '$count'),
                    child: const Icon(Icons.notifications_none_rounded),
                  );
                },
              ),
              selectedIcon: const Icon(Icons.notifications_rounded),
            ),
            const NavigationDestination(
              label: 'Menu',
              icon: Icon(Icons.menu_rounded),
              selectedIcon: Icon(Icons.menu_rounded),
            ),
          ],
        ),
      ),
    );
  }
}
