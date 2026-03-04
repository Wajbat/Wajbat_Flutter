import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/widgets/loading_indicator.dart';
import '../../models/food_post_model.dart';
import '../../models/request_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/request_provider.dart';
import '../../providers/food_post_provider.dart';
import '../../providers/user_provider.dart';

class IncomingRequestsScreen extends StatefulWidget {
  const IncomingRequestsScreen({super.key});

  @override
  State<IncomingRequestsScreen> createState() => _IncomingRequestsScreenState();
}

class _IncomingRequestsScreenState extends State<IncomingRequestsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.currentUser != null) {
      await Provider.of<RequestProvider>(context, listen: false)
          .fetchIncomingRequests(authProvider.currentUser!.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Incoming Requests'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRequests,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Accepted'),
            Tab(text: 'Rejected'),
            Tab(text: 'Completed'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRequestList('pending'),
          _buildRequestList('accepted'),
          _buildRequestList('rejected'),
          _buildRequestList('completed'),
        ],
      ),
    );
  }

  Widget _buildRequestList(String status) {
    return Consumer<RequestProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) return const LoadingIndicator();

        final requests = provider.incomingRequests.where((r) => r.requestStatus == status).toList();

        if (requests.isEmpty) {
          return _buildEmptyState(status);
        }

        return RefreshIndicator(
          onRefresh: _loadRequests,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            itemBuilder: (context, index) => _buildRequestCard(requests[index]),
          ),
        );
      },
    );
  }

  Widget _buildRequestCard(RequestModel request) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildRecipientAvatar(request.recipientId),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildRecipientName(request.recipientId),
                      const SizedBox(height: 4),
                      _buildPostContext(request.postId),
                    ],
                  ),
                ),
                _buildStatusBadge(request.requestStatus),
              ],
            ),
            if (request.message != null && request.message!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Message:', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      request.message!,
                      style: const TextStyle(fontSize: 13, color: Colors.black87),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  timeago.format(request.createdAt),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                _buildActionButtons(request),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecipientAvatar(String recipientId) {
    return FutureBuilder<UserModel?>(
      future: Provider.of<UserProvider>(context, listen: false).getUser(recipientId),
      builder: (context, snapshot) {
        final recipient = snapshot.data;
        return CircleAvatar(
          radius: 25,
          backgroundImage: recipient?.profileImageUrl != null
              ? CachedNetworkImageProvider(recipient!.profileImageUrl!)
              : null,
          child: recipient?.profileImageUrl == null ? const Icon(Icons.person) : null,
        );
      },
    );
  }

  Widget _buildRecipientName(String recipientId) {
    return FutureBuilder<UserModel?>(
      future: Provider.of<UserProvider>(context, listen: false).getUser(recipientId),
      builder: (context, snapshot) {
        return Text(
          snapshot.data?.name ?? 'Loading...',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        );
      },
    );
  }

  Widget _buildPostContext(String postId) {
    return FutureBuilder<FoodPostModel?>(
      future: Provider.of<FoodPostProvider>(context, listen: false).getPostById(postId),
      builder: (context, snapshot) {
        final post = snapshot.data;
        return Text(
          'For: ${post?.itemName ?? '...'}',
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        );
      },
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status) {
      case 'pending': color = Colors.orange; break;
      case 'accepted': color = Colors.green; break;
      case 'rejected': color = Colors.red; break;
      case 'completed': color = Colors.blue; break;
      default: color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10),
      ),
    );
  }

  Widget _buildActionButtons(RequestModel request) {
    if (request.requestStatus == 'pending') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            onPressed: () => _handleStatusChange(request, 'rejected'),
            child: const Text('Reject', style: TextStyle(color: Colors.red)),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => _handleAccept(request),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Accept', style: TextStyle(color: Colors.white)),
          ),
        ],
      );
    } else if (request.requestStatus == 'accepted') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: () {
              // Navigate to Chat
            },
            icon: Icon(Icons.chat_bubble_outline, color: AppColors.secondary),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => _handleStatusChange(request, 'completed'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Mark Completed', style: TextStyle(color: Colors.white)),
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  Future<void> _handleAccept(RequestModel request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Accept Request?'),
        content: const Text('This will reserve the food for this recipient.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Accept')),
        ],
      ),
    );

    if (confirmed == true) {
      final requestProvider = Provider.of<RequestProvider>(context, listen: false);
      final foodProvider = Provider.of<FoodPostProvider>(context, listen: false);

      final success = await requestProvider.acceptRequest(request.requestId);
      if (success && mounted) {
        await foodProvider.updatePostStatus(request.postId, 'reserved');
        if (mounted) SnackbarHelper.showSuccess(context, 'Request accepted & food reserved!');
      }
    }
  }

  Future<void> _handleStatusChange(RequestModel request, String status) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${status[0].toUpperCase()}${status.substring(1)} Request?'),
        content: Text('Are you sure you want to mark this request as $status?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm')),
        ],
      ),
    );

    if (confirmed == true) {
      final requestProvider = Provider.of<RequestProvider>(context, listen: false);
      bool success = false;

      if (status == 'rejected') {
        success = await requestProvider.rejectRequest(request.requestId);
      } else if (status == 'completed') {
        success = await requestProvider.completeRequest(request.requestId);
        if (success && mounted) {
          final foodProvider = Provider.of<FoodPostProvider>(context, listen: false);
          await foodProvider.updatePostStatus(request.postId, 'completed');
          
          // Refresh user data to update points
          final authProvider = Provider.of<AuthProvider>(context, listen: false);
          await authProvider.refreshUser();

          if (mounted) {
            SnackbarHelper.showSuccess(context, 'Success! +10 Impact Points earned! 🌟');
          }
        }
      }

      if (success && mounted && status != 'completed') {
        SnackbarHelper.showSuccess(context, 'Request updated to $status');
      }
    }
  }

  Widget _buildEmptyState(String status) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No $status incoming requests',
            style: TextStyle(color: Colors.grey[500], fontSize: 16),
          ),
        ],
      ),
    );
  }
}
