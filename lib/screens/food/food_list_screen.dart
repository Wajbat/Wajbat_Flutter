import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../models/food_post_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/food_post_provider.dart';
import '../../core/localization/app_localizations.dart';


class FoodListScreen extends StatefulWidget {
  final bool isMyPosts;

  const FoodListScreen({super.key, this.isMyPosts = false});

  @override
  State<FoodListScreen> createState() => _FoodListScreenState();
}

class _FoodListScreenState extends State<FoodListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    final foodProvider = Provider.of<FoodPostProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    if (widget.isMyPosts) {
      if (authProvider.currentUser != null) {
        await foodProvider.fetchMyPosts(authProvider.currentUser!.id);
      }
    } else {
      await foodProvider.fetchAllFoodPosts();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isMyPosts 
            ? (AppLocalizations.of(context)?.translate('my_donations') ?? 'My Donations')
            : (AppLocalizations.of(context)?.translate('available_food_title') ?? 'Available Food')),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppColors.primary,
          indicatorColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          tabs: [
            Tab(text: AppLocalizations.of(context)?.translate('all') ?? 'All'),
            Tab(text: AppLocalizations.of(context)?.translate('available') ?? 'Available'),
            Tab(text: AppLocalizations.of(context)?.translate('expired') ?? 'Expired'),
            Tab(text: AppLocalizations.of(context)?.translate('completed') ?? 'Completed'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPostList('all'),
          _buildPostList('available'),
          _buildPostList('expired'),
          _buildPostList('completed'),
        ],
      ),
    );
  }

  Widget _buildPostList(String filter) {
    return Consumer<FoodPostProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        List<FoodPostModel> posts = widget.isMyPosts ? provider.myPosts : provider.foodPosts;
        List<FoodPostModel> filteredPosts = posts;
        
        if (filter != 'all') {
          filteredPosts = posts.where((p) => p.postStatus == filter).toList();
        }

        if (filteredPosts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(
                  (AppLocalizations.of(context)?.translate('no_posts_found_filter') ?? 'No {filter} posts found').replaceAll('{filter}', AppLocalizations.of(context)?.translateDynamic(filter) ?? filter),
                  style: const TextStyle(color: Colors.grey)
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _loadData,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredPosts.length,
            itemBuilder: (context, index) {
              final post = filteredPosts[index];
              return _buildPostCard(post);
            },
          ),
        );
      },
    );
  }

  Widget _buildPostCard(FoodPostModel post) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, AppRoutes.foodDetail, arguments: post),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 120,
                child: post.imageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: post.imageUrl!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(color: Colors.grey[200]),
                      )
                    : Container(color: Colors.grey[200], child: const Icon(Icons.fastfood, color: Colors.grey)),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              post.itemName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          _buildStatusBadge(post),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('${AppLocalizations.of(context)?.translate('quantity_label') ?? 'Quantity: '}${post.quantity}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                      const SizedBox(height: 4),
                      Text(
                        '${AppLocalizations.of(context)?.translate('expires_label') ?? 'Expires: '}${DateFormat('MMM dd, yyyy').format(post.expirationDate)}',
                        style: const TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: () => Navigator.pushNamed(context, AppRoutes.editPost, arguments: post),
                            icon: const Icon(Icons.edit, size: 16),
                            label: Text(AppLocalizations.of(context)?.translate('edit') ?? 'Edit', style: const TextStyle(fontSize: 12)),
                          ),
                          TextButton.icon(
                            onPressed: () => _confirmDelete(context, post),
                            icon: const Icon(Icons.delete, size: 16, color: Colors.red),
                            label: Text(AppLocalizations.of(context)?.translate('delete') ?? 'Delete', style: const TextStyle(fontSize: 12, color: Colors.red)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(FoodPostModel post) {
    String status = post.postStatus;
    if (post.isExpired && status == 'available') {
      status = 'expired';
    }

    Color color;
    switch (status) {
      case 'available': color = Colors.green; break;
      case 'expired': color = Colors.red; break;
      case 'completed': color = Colors.blue; break;
      case 'reserved': color = Colors.orange; break;
      default: color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        AppLocalizations.of(context)?.translateDynamic(status).toUpperCase() ?? status.toUpperCase(),
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  void _confirmDelete(BuildContext context, FoodPostModel post) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context)?.translate('delete_post_title') ?? 'Delete Post?'),
        content: Text(AppLocalizations.of(context)?.translate('delete_post_confirm') ?? 'Are you sure you want to remove this donation?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppLocalizations.of(context)?.translate('cancel') ?? 'Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await Provider.of<FoodPostProvider>(context, listen: false).deletePost(post.postId);
            },
            child: Text(AppLocalizations.of(context)?.translate('delete') ?? 'Delete', style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
