import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../core/constants/app_colors.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../core/widgets/loading_indicator.dart';
import '../../models/food_post_model.dart';
import '../../models/request_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/request_provider.dart';
import '../../providers/food_post_provider.dart';
import '../../providers/user_provider.dart';
import '../../core/localization/app_localizations.dart';

class MyRequestsScreen extends StatefulWidget {
  const MyRequestsScreen({super.key});

  @override
  State<MyRequestsScreen> createState() => _MyRequestsScreenState();
}

class _MyRequestsScreenState extends State<MyRequestsScreen> with SingleTickerProviderStateMixin {
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
          .fetchMyRequests(authProvider.currentUser!.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)?.translate('my_requests_title') ?? 'My Requests'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRequests,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [
            Tab(text: AppLocalizations.of(context)?.translate('pending') ?? 'Pending'),
            Tab(text: AppLocalizations.of(context)?.translate('accepted') ?? 'Accepted'),
            Tab(text: AppLocalizations.of(context)?.translate('rejected') ?? 'Rejected'),
            Tab(text: AppLocalizations.of(context)?.translate('completed') ?? 'Completed'),
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

        final requests = provider.myRequests.where((r) {
          if (status == 'rejected') {
            return r.requestStatus == 'rejected' || r.requestStatus == 'cancelled';
          }
          return r.requestStatus == status;
        }).toList();

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
                _buildPostThumbnail(request.postId),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPostTitle(request.postId),
                      const SizedBox(height: 4),
                      _buildDonorInfo(request.donorId),
                    ],
                  ),
                ),
                _buildStatusBadge(request.requestStatus),
              ],
            ),
            if (request.message != null && request.message!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  request.message!,
                  style: const TextStyle(fontSize: 13, color: Colors.black87),
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

  Widget _buildPostThumbnail(String postId) {
    return FutureBuilder<FoodPostModel?>(
      future: Provider.of<FoodPostProvider>(context, listen: false).getPostById(postId),
      builder: (context, snapshot) {
        final post = snapshot.data;
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: post?.imageUrl != null
              ? CachedNetworkImage(
                  imageUrl: post!.imageUrl!,
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(color: Colors.grey[200]),
                )
              : Container(
                  width: 60,
                  height: 60,
                  color: Colors.grey[200],
                  child: const Icon(Icons.fastfood, color: Colors.grey),
                ),
        );
      },
    );
  }

  Widget _buildPostTitle(String postId) {
    return FutureBuilder<FoodPostModel?>(
      future: Provider.of<FoodPostProvider>(context, listen: false).getPostById(postId),
      builder: (context, snapshot) {
        final post = snapshot.data;
        return Text(
          post?.itemName ?? AppLocalizations.of(context)?.translate('loading') ?? 'Loading...',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        );
      },
    );
  }

  Widget _buildDonorInfo(String donorId) {
    return FutureBuilder<UserModel?>(
      future: Provider.of<UserProvider>(context, listen: false).getUser(donorId),
      builder: (context, snapshot) {
        final donor = snapshot.data;
        return Row(
          children: [
            CircleAvatar(
              radius: 10,
              backgroundImage: donor?.profileImageUrl != null
                  ? CachedNetworkImageProvider(donor!.profileImageUrl!)
                  : null,
              child: donor?.profileImageUrl == null ? const Icon(Icons.person, size: 12) : null,
            ),
            const SizedBox(width: 4),
            Text(
              donor?.name ?? AppLocalizations.of(context)?.translate('donor') ?? 'Donor',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
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
      case 'cancelled': color = Colors.grey; break;
      default: color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        AppLocalizations.of(context)?.translateDynamic(status).toUpperCase() ?? status.toUpperCase(),
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10),
      ),
    );
  }

  Widget _buildActionButtons(RequestModel request) {
    if (request.requestStatus == 'pending') {
      return TextButton(
        onPressed: () => _confirmCancel(request),
        child: Text(AppLocalizations.of(context)?.translate('cancel_request') ?? 'Cancel Request', style: const TextStyle(color: Colors.red)),
      );
    } else if (request.requestStatus == 'accepted') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          OutlinedButton(
            onPressed: () {
              // Navigate to Chat
            },
            child: Text(AppLocalizations.of(context)?.translate('chat') ?? 'Contact'),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => _confirmComplete(request),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: Text(AppLocalizations.of(context)?.translate('completed') ?? 'Complete', style: const TextStyle(color: Colors.white)),
          ),
        ],
      );
    } else if (request.requestStatus == 'completed') {
      return TextButton(
        onPressed: () {},
        child: Text(AppLocalizations.of(context)?.translate('leave_review') ?? 'Leave Review'),
      );
    }
    return const SizedBox.shrink();
  }

  void _confirmCancel(RequestModel request) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context)?.translate('cancel_request') ?? 'Cancel Request?'),
        content: Text(AppLocalizations.of(context)?.translate('are_you_sure_cancel_request') ?? 'Are you sure you want to cancel this food request?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppLocalizations.of(context)?.translate('no') ?? 'No')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await Provider.of<RequestProvider>(context, listen: false).cancelRequest(request.requestId);
              if (success && mounted) {
                SnackbarHelper.showSuccess(context, AppLocalizations.of(context)?.translate('request_cancelled') ?? 'Request cancelled');
              }
            },
            child: Text(AppLocalizations.of(context)?.translate('yes_cancel') ?? 'Yes, Cancel', style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _confirmComplete(RequestModel request) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context)?.translate('mark_as_completed_title') ?? 'Mark as Completed?'),
        content: Text(AppLocalizations.of(context)?.translate('mark_as_completed_desc') ?? 'Has the food been successfully picked up?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppLocalizations.of(context)?.translate('cancel') ?? 'Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final requestProvider = Provider.of<RequestProvider>(context, listen: false);
              final foodProvider = Provider.of<FoodPostProvider>(context, listen: false);
              
              final success = await requestProvider.completeRequest(request.requestId);
              if (success) {
                await foodProvider.updatePostStatus(request.postId, 'completed');
                if (mounted) SnackbarHelper.showSuccess(context, AppLocalizations.of(context)?.translate('completed') ?? 'Marked as completed!');
              }
            },
            child: Text(AppLocalizations.of(context)?.translate('yes_completed') ?? 'Yes, Completed'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String status) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            (AppLocalizations.of(context)?.translate('no_requests_found_status') ?? 'No {status} requests found').replaceAll('{status}', AppLocalizations.of(context)?.translateDynamic(status) ?? status),
            style: TextStyle(color: Colors.grey[500], fontSize: 16),
          ),
        ],
      ),
    );
  }
}
