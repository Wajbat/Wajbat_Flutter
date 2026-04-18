import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../providers/auth_provider.dart';
import '../../providers/food_post_provider.dart';
import '../../providers/request_provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../models/food_post_model.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/widgets/notification_dialog.dart';

class DonorHomeScreen extends StatefulWidget {
  const DonorHomeScreen({super.key});

  @override
  State<DonorHomeScreen> createState() => _DonorHomeScreenState();
}

class _DonorHomeScreenState extends State<DonorHomeScreen> {
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final foodProvider = Provider.of<FoodPostProvider>(context, listen: false);
    final requestProvider = Provider.of<RequestProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    if (authProvider.currentUser != null) {
      await Future.wait([
        foodProvider.fetchMyPosts(authProvider.currentUser!.id),
        requestProvider.fetchIncomingRequests(authProvider.currentUser!.id),
      ]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final foodProvider = Provider.of<FoodPostProvider>(context);
    final requestProvider = Provider.of<RequestProvider>(context);
    final user = authProvider.currentUser;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 120,
              floating: false,
              pinned: true,
              backgroundColor: AppColors.primary,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsetsDirectional.only(start: 20, bottom: 16),
                title: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${AppLocalizations.of(context)?.translate('hello') ?? 'Hello'}, ${user?.name ?? AppLocalizations.of(context)?.translate('donor') ?? 'Donor'}',
                      style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      AppLocalizations.of(context)?.translate('ready_to_make_difference') ?? 'Ready to make a difference?',
                      style: const TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.notifications_none, color: Colors.white),
                  onPressed: () => NotificationDialog.show(context),
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stats Row
                    _buildStatsGrid(foodProvider, requestProvider, user?.donationPoints ?? 0),
                    const SizedBox(height: 24),
                    
                    // Recent Posts Section
                    _buildSectionHeader(AppLocalizations.of(context)?.translate('recent_posts') ?? 'Recent Posts', () {
                       // Navigate to Manage Posts
                    }),
                    const SizedBox(height: 12),
                    _buildRecentPosts(foodProvider),
                    
                    const SizedBox(height: 24),
                    
                    // Pending Requests Section
                    _buildSectionHeader(AppLocalizations.of(context)?.translate('pending_requests') ?? 'Pending Requests', () {
                       // Navigate to All Requests
                    }),
                    const SizedBox(height: 12),
                    _buildPendingRequests(requestProvider),
                    
                    const SizedBox(height: 24),
                    
                    // Create New Post Call to Action
                    _buildCreatePostCard(),
                    
                    const SizedBox(height: 80), // Padding for FAB
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid(FoodPostProvider food, RequestProvider requests, int points) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 2.5,
      children: [
        _buildStatCard(AppLocalizations.of(context)?.translate('total_donations') ?? 'Total Donations', food.myPosts.length.toString(), Icons.volunteer_activism, Colors.blue),
        _buildStatCard(AppLocalizations.of(context)?.translate('active_posts') ?? 'Active Posts', food.myPosts.where((p) => p.postStatus == 'available').length.toString(), Icons.restaurant, Colors.green),
        _buildStatCard(AppLocalizations.of(context)?.translate('impact_points') ?? 'Impact Points', points.toString(), Icons.stars, Colors.orange),
        _buildStatCard(AppLocalizations.of(context)?.translate('pending_requests') ?? 'Pending Req', requests.incomingRequests.where((r) => r.requestStatus == 'pending').length.toString(), Icons.pending_actions, Colors.red),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Card(
      elevation: 0,
      color: color.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16)),
                  Text(label, style: const TextStyle(fontSize: 10, color: Colors.black54), overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, VoidCallback onSeeAll) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        TextButton(onPressed: onSeeAll, child: Text(AppLocalizations.of(context)?.translate('view_all') ?? 'View All')),
      ],
    );
  }

  Widget _buildRecentPosts(FoodPostProvider provider) {
    if (provider.isLoading) return _buildShimmerList();
    if (provider.myPosts.isEmpty) return _buildEmptyState(AppLocalizations.of(context)?.translate('no_posts_yet') ?? 'No posts yet', AppLocalizations.of(context)?.translate('start_sharing_surplus') ?? 'Start sharing surplus food.');

    final recent = provider.myPosts.take(5).toList();
    return SizedBox(
      height: 180,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: recent.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final post = recent[index];
          return Card(
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: SizedBox(
              width: 150,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: post.imageUrl != null
                        ? CachedNetworkImage(
                            imageUrl: post.imageUrl!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            placeholder: (_, __) => _buildShimmer(),
                          )
                        : Container(color: Colors.grey[200], child: const Icon(Icons.fastfood, color: Colors.grey)),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(post.itemName, style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: (post.isExpired && post.postStatus == 'available' ? Colors.red : _getStatusColor(post.postStatus)).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                (post.isExpired && post.postStatus == 'available' 
                                    ? AppLocalizations.of(context)?.translate('expired') ?? 'EXPIRED' 
                                    : AppLocalizations.of(context)?.translateDynamic(post.postStatus) ?? post.postStatus).toUpperCase(),
                                style: TextStyle(
                                  fontSize: 8, 
                                  color: post.isExpired && post.postStatus == 'available' ? Colors.red : _getStatusColor(post.postStatus), 
                                  fontWeight: FontWeight.bold
                                ),
                              ),
                            ),
                            Text(
                              '${AppLocalizations.of(context)?.translate('exp') ?? 'Exp: '}${_formatDate(post.expirationDate)}',
                              style: const TextStyle(fontSize: 8, color: Colors.black54),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPendingRequests(RequestProvider provider) {
    if (provider.isLoading) return _buildShimmerList(vertical: true);
    final pending = provider.incomingRequests.where((r) => r.requestStatus == 'pending').take(3).toList();
    
    if (pending.isEmpty) return _buildEmptyState(AppLocalizations.of(context)?.translate('no_pending_requests') ?? 'No pending requests', AppLocalizations.of(context)?.translate('requests_appear_here') ?? 'Requests will appear here.');

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: pending.length,
      itemBuilder: (context, index) {
        final req = pending[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey[200]!)),
          child: ListTile(
            leading: CircleAvatar(backgroundColor: AppColors.secondary.withOpacity(0.2), child: const Icon(Icons.person, color: AppColors.secondary)),
            title: Text('${AppLocalizations.of(context)?.translate('request_for') ?? 'Request for '} ${req.postId.substring(0, 8)}...', style: const TextStyle(fontWeight: FontWeight.bold)), // In real app, fetch post title
            subtitle: Text('${AppLocalizations.of(context)?.translate('status') ?? 'Status: '}${AppLocalizations.of(context)?.translateDynamic(req.requestStatus) ?? req.requestStatus}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
        );
      },
    );
  }

  Widget _buildCreatePostCard() {
    return InkWell(
      onTap: () => Navigator.pushNamed(context, AppRoutes.createPost),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)]),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppLocalizations.of(context)?.translate('share_surplus_food') ?? 'Share Surplus Food', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(AppLocalizations.of(context)?.translate('quickly_post_items') ?? 'Quickly post items to help others.', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
              child: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'available': return Colors.green;
      case 'reserved': return Colors.orange;
      case 'completed': return Colors.blue;
      case 'expired': return Colors.red;
      default: return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}';
  }

  Widget _buildShimmerList({bool vertical = false}) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: vertical 
        ? Column(children: List.generate(3, (i) => Container(height: 70, margin: const EdgeInsets.only(bottom: 8), color: Colors.white)))
        : Row(children: List.generate(3, (i) => Container(width: 150, height: 180, margin: const EdgeInsets.only(right: 12), color: Colors.white))),
    );
  }

  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(color: Colors.white),
    );
  }

  Widget _buildEmptyState(String title, String sub) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Icon(Icons.inbox_outlined, size: 40, color: Colors.grey[400]),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
          Text(sub, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }
}
