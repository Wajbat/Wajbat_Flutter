import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../models/request_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/request_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/language_provider.dart';
import '../../core/widgets/loading_indicator.dart';
import '../../core/localization/app_localizations.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final requestProvider = Provider.of<RequestProvider>(context, listen: false);

    if (authProvider.currentUser != null) {
      // Fetch both incoming and outgoing requests to build the full chat list
      await Future.wait([
        requestProvider.fetchMyRequests(authProvider.currentUser!.id),
        requestProvider.fetchIncomingRequests(authProvider.currentUser!.id),
      ]);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final requestProvider = Provider.of<RequestProvider>(context);
    final currentUser = authProvider.currentUser;

    if (currentUser == null) return Center(child: Text(AppLocalizations.of(context)?.translate('please_login_messages') ?? 'Please login to view messages'));

    // Combine requests where user is either donor or recipient
    // Determine the "other" user ID for each request
    // Filter by search query if needed

    final allRequests = [
      ...requestProvider.myRequests,
      ...requestProvider.incomingRequests,
    ];

    // Remove duplicates if any (though usually separate lists) and sort by latest
    final uniqueRequests = <String, RequestModel>{};
    for (var req in allRequests) {
      uniqueRequests[req.requestId] = req;
    }
    
    final sortedRequests = uniqueRequests.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    // We need to fetch/display details of the "other" user
    // This might require FutureBuilders in the list items or a bulk fetch strategy.
    // For now, individual FutureBuilders in tiles are easiest.

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)?.translate('messages') ?? 'Messages'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // Expand search bar or just focus it if visible
              // For now, simpler implementation with a persistent search bar in body
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadConversations,
        child: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context)?.translate('search_conversations') ?? 'Search conversations...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
              ),
            ),

            // List
            Expanded(
              child: sortedRequests.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          Text(AppLocalizations.of(context)?.translate('no_messages_yet') ?? 'No messages yet', style: const TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: sortedRequests.length,
                      separatorBuilder: (ctx, i) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final request = sortedRequests[index];
                        final isMeDonor = request.donorId == currentUser.id;
                        final otherUserId = isMeDonor ? request.recipientId : request.donorId;

                        return _ChatTile(
                          request: request,
                          otherUserId: otherUserId,
                          searchQuery: _searchQuery,
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

class _ChatTile extends StatelessWidget {
  final RequestModel request;
  final String otherUserId;
  final String searchQuery;

  const _ChatTile({
    required this.request,
    required this.otherUserId,
    required this.searchQuery,
  });

  @override
  Widget build(BuildContext context) {
    // Optimization: If we had a UserCache, we'd use it here.
    // Using FutureBuilder for each tile for simplicity.
    
    return FutureBuilder<UserModel?>(
      future: Provider.of<UserProvider>(context, listen: false).getUser(otherUserId),
      builder: (context, snapshot) {
        if (!snapshot.hasData && snapshot.connectionState != ConnectionState.done) {
          // Loading state for tile
          return ListTile(
            leading: const CircleAvatar(backgroundColor: Colors.grey),
            title: Container(height: 10, width: 100, color: Colors.grey),
          );
        }

        final otherUser = snapshot.data;
        if (otherUser == null) return const SizedBox.shrink();

        // Search Filter
        if (searchQuery.isNotEmpty && !otherUser.name.toLowerCase().contains(searchQuery)) {
          return const SizedBox.shrink();
        }

        return ListTile(
          onTap: () {
            Navigator.pushNamed(
              context, 
              AppRoutes.chat, 
              arguments: {
                'request': request,
                'otherUser': otherUser,
              }
            );
          },
          leading: CircleAvatar(
            radius: 28,
            backgroundImage: otherUser.profileImageUrl != null
                ? CachedNetworkImageProvider(otherUser.profileImageUrl!)
                : null,
            child: otherUser.profileImageUrl == null
                ? Text(otherUser.name[0].toUpperCase())
                : null,
          ),
          title: Text(
            otherUser.name,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Row(
            children: [
              Expanded(
                child: Text(
                  request.message ?? 'No messages yet', // Or fetch last message
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.grey[600],
                    // fontWeight: isUnread ? FontWeight.bold : FontWeight.normal // Add logic for unread
                  ),
                ),
              ),
            ],
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                timeago.format(request.updatedAt, locale: Provider.of<LanguageProvider>(context, listen: false).currentLanguage == 'ar' ? 'ar_short' : 'en_short'),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              // Unread Badge (Optional implementation)
              /*
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Text('1', style: TextStyle(color: Colors.white, fontSize: 10)),
              ),
              */
            ],
          ),
        );
      },
    );
  }
}
