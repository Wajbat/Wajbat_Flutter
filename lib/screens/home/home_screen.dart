import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/food_post_provider.dart';
import '../../providers/request_provider.dart';
import '../../providers/notification_provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import 'donor_home_screen.dart';
import 'recipient_home_screen.dart';
import '../food/food_list_screen.dart';
import '../requests/my_requests_screen.dart';
import '../requests/incoming_requests_screen.dart';
import '../profile/profile_screen.dart';
import '../chat/chat_list_screen.dart';
import '../../core/localization/app_localizations.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const RoleSpecificHome(),
    const BrowseOrMyPosts(),
    const RequestsScreenSwitcher(),
    const ChatListScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.currentUser != null) {
        Provider.of<NotificationProvider>(context, listen: false)
            .initializeRealtime(authProvider.currentUser!.id);
      }
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final notificationProvider = Provider.of<NotificationProvider>(context);
    final isDonor = authProvider.currentUser?.isDonor ?? true;

    return Scaffold(
      appBar: AppBar(
        title: Text(
            AppLocalizations.of(context)?.translate('app_name') ?? 'Wajbat'),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () {
                  notificationProvider.clearUnread();
                  // Optionally navigate to a notifications screen
                },
              ),
              if (notificationProvider.unreadCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '${notificationProvider.unreadCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Colors.grey,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home_outlined),
            activeIcon: const Icon(Icons.home),
            label: AppLocalizations.of(context)?.translate('home') ?? 'Home',
          ),
          BottomNavigationBarItem(
            icon:
                Icon(isDonor ? Icons.list_alt_outlined : Icons.search_outlined),
            activeIcon: Icon(isDonor ? Icons.list_alt : Icons.search),
            label: isDonor
                ? (AppLocalizations.of(context)?.translate('my_posts') ??
                    'My Posts')
                : (AppLocalizations.of(context)?.translate('browse') ??
                    'Browse'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.inbox_outlined),
            activeIcon: const Icon(Icons.inbox),
            label: AppLocalizations.of(context)?.translate('requests') ??
                'Requests',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.chat_bubble_outline),
            activeIcon: const Icon(Icons.chat_bubble),
            label: AppLocalizations.of(context)?.translate('chat') ?? 'Chat',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person_outline),
            activeIcon: const Icon(Icons.person),
            label:
                AppLocalizations.of(context)?.translate('profile') ?? 'Profile',
          ),
        ],
      ),
      floatingActionButton: isDonor && _selectedIndex == 0
          ? FloatingActionButton(
              onPressed: () =>
                  Navigator.pushNamed(context, AppRoutes.createPost),
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }
}

class RoleSpecificHome extends StatelessWidget {
  const RoleSpecificHome({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    return authProvider.currentUser?.isDonor ?? true
        ? const DonorHomeScreen()
        : const RecipientHomeScreen();
  }
}

class BrowseOrMyPosts extends StatelessWidget {
  const BrowseOrMyPosts({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    return authProvider.currentUser?.isDonor ?? true
        ? const FoodListScreen(isMyPosts: true)
        : const RecipientHomeScreen(); // For recipient, browse is home or similar.
    // Technically RecipientHomeScreen is duplicate here if Home is also RecipientHomeScreen.
    // Assuming FoodListScreen can be used for "Browse" too if configured.
    // But for now, keeping as logic dictated.
  }
}

class RequestsScreenSwitcher extends StatelessWidget {
  const RequestsScreenSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    return authProvider.currentUser?.isDonor ?? true
        ? const IncomingRequestsScreen()
        : const MyRequestsScreen();
  }
}
