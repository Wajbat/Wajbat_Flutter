import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/food_post_provider.dart';
import '../../providers/request_provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import 'donor_home_screen.dart';
import 'recipient_home_screen.dart';
import '../food/food_list_screen.dart';
import '../requests/my_requests_screen.dart';
import '../requests/incoming_requests_screen.dart';
import '../profile/profile_screen.dart';

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
    const ChatListScreenPlaceholder(), // Placeholder for now
    const ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final isDonor = authProvider.currentUser?.isDonor ?? true;

    return Scaffold(
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
          const BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(isDonor ? Icons.list_alt_outlined : Icons.search_outlined),
            activeIcon: Icon(isDonor ? Icons.list_alt : Icons.search),
            label: isDonor ? 'My Posts' : 'Browse',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.inbox_outlined),
            activeIcon: Icon(Icons.inbox),
            label: 'Requests',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            activeIcon: Icon(Icons.chat_bubble),
            label: 'Chat',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
      floatingActionButton: isDonor && _selectedIndex == 0
          ? FloatingActionButton(
              onPressed: () => Navigator.pushNamed(context, AppRoutes.createPost),
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
        ? const FoodListScreen()
        : const RecipientHomeScreen(); // For recipient, browse is home or similar
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

// Temporary Placeholders
class RequestsScreenPlaceholder extends StatelessWidget {
  const RequestsScreenPlaceholder({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('Requests Screen')));
}

class ChatListScreenPlaceholder extends StatelessWidget {
  const ChatListScreenPlaceholder({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('Chat Screen')));
}


