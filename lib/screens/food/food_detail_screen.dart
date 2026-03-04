import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart'; // Removed due to missing API Key
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/widgets/loading_indicator.dart';
import '../../models/food_post_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/food_post_provider.dart';
import '../../providers/request_provider.dart';
import '../../providers/user_provider.dart';
import '../../models/request_model.dart';

class FoodDetailScreen extends StatefulWidget {
  const FoodDetailScreen({super.key});

  @override
  State<FoodDetailScreen> createState() => _FoodDetailScreenState();
}

class _FoodDetailScreenState extends State<FoodDetailScreen> {
  bool _isRequesting = false;

  Future<void> _handleRequest(FoodPostModel post) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final requestProvider = Provider.of<RequestProvider>(context, listen: false);

    if (authProvider.currentUser == null) return;

    // Check for allergies
    final proceed = await _checkAllergiesBeforeRequest(post);
    if (!proceed) return;

    final message = await _showRequestDialog();
    if (message == null) return;

    setState(() => _isRequesting = true);
    try {
      final success = await requestProvider.createRequest(
        postId: post.postId,
        recipientId: authProvider.currentUser!.id,
        donorId: post.donorId,
        message: message,
      );

      if (success && mounted) {
        SnackbarHelper.showSuccess(context, 'Request sent successfully!');
      }
    } catch (e) {
      if (mounted) SnackbarHelper.showError(context, 'Failed to send request: $e');
    } finally {
      if (mounted) setState(() => _isRequesting = false);
    }
  }

  Future<String?> _showRequestDialog() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Request Food'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Add a message for the donor (optional)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Send Request', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  late Future<void> _donorFuture;

  @override
  void initState() {
    super.initState();
    // Defer the provider access to next frame or use listen: false if immediate
    WidgetsBinding.instance.addPostFrameCallback((_) {
       final post = ModalRoute.of(context)!.settings.arguments as FoodPostModel;
       final authProvider = Provider.of<AuthProvider>(context, listen: false);
       if (mounted) {
         setState(() {
            _donorFuture = Provider.of<UserProvider>(context, listen: false).fetchUserById(post.donorId);
         });
         
         // Also fetch my requests to check if we already requested this
         if (authProvider.currentUser != null) {
           Provider.of<RequestProvider>(context, listen: false).fetchMyRequests(authProvider.currentUser!.id);
         }
       }
    }); 
  }

  @override
  Widget build(BuildContext context) {
    final post = ModalRoute.of(context)!.settings.arguments as FoodPostModel;
    final authProvider = Provider.of<AuthProvider>(context);
    final userProvider = Provider.of<UserProvider>(context);
    final isDonor = authProvider.currentUser?.id == post.donorId;
    
    final remainingTime = post.expirationDate.difference(DateTime.now());
    final isExpired = remainingTime.isNegative;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Hero(
                tag: 'food_${post.postId}',
                child: post.imageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: post.imageUrl!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(color: Colors.grey[200]),
                      )
                    : Container(color: Colors.grey[200], child: const Icon(Icons.fastfood, size: 100, color: Colors.grey)),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          post.itemName,
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isExpired ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isExpired ? 'Expired' : 'Available',
                          style: TextStyle(
                            color: isExpired ? Colors.red : Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Donor Info Card
                  if (userProvider.isLoading)
                      const Center(child: LoadingIndicator())
                  else
                      Card(
                        elevation: 0,
                        color: Colors.grey[100],
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundImage: userProvider.targetUser?.profileImageUrl != null
                                ? CachedNetworkImageProvider(userProvider.targetUser!.profileImageUrl!)
                                : null,
                            child: userProvider.targetUser?.profileImageUrl == null ? const Icon(Icons.person) : null,
                          ),
                          title: Text(userProvider.targetUser?.name ?? 'Donor Name', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(userProvider.targetUser?.organizationName ?? 'Individual Donor'),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.star, color: Colors.orange, size: 20),
                              Text('${userProvider.targetUser?.donationPoints ?? 0}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            ],
                          ),
                        ),
                      ),

                  const SizedBox(height: 24),
                  
                  // Details Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildDetailItem(Icons.shopping_basket_outlined, 'Quantity', post.quantity),
                      _buildDetailItem(
                        Icons.timer_outlined, 
                        'Expires', 
                        isExpired ? 'Expired' : timeago.format(post.expirationDate, allowFromNow: true),
                        color: isExpired ? Colors.red : Colors.black,
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Allergy Warning Banner
                  if (authProvider.currentUser?.isRecipient == true && 
                      authProvider.currentUser!.getAllergenIngredients(post.ingredients).isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        border: Border.all(color: Colors.red, width: 2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: Colors.red),
                              const SizedBox(width: 8),
                              const Text(
                                'Allergy Warning',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Contains: ${authProvider.currentUser!.getAllergenIngredients(post.ingredients).join(", ")}',
                            style: TextStyle(
                              color: Colors.red[900],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  
                  // Ingredients
                  Row(
                    children: [
                     const Icon(Icons.restaurant_menu, size: 20, color: Colors.grey),
                     const SizedBox(width: 8),
                     const Text('Ingredients', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: post.ingredients.map((ing) {
                      final isAllergen = authProvider.currentUser != null && 
                                       authProvider.currentUser!.isRecipient &&
                                       authProvider.currentUser!.hasAllergy(ing);
                                       
                      return Chip(
                        avatar: isAllergen ? const Icon(Icons.warning, size: 16, color: Colors.red) : null,
                        label: Text(
                          ing,
                          style: TextStyle(
                            color: isAllergen ? Colors.red[900] : Colors.green[900],
                            fontWeight: isAllergen ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        backgroundColor: isAllergen ? Colors.red[50] : Colors.green[50],
                        side: BorderSide(
                          color: isAllergen ? Colors.red : Colors.green[200]!,
                          width: isAllergen ? 2 : 1,
                        ),
                      );
                    }).toList(),
                  ),
                  
                  // Legend
                  if (authProvider.currentUser?.isRecipient == true && 
                      authProvider.currentUser!.getAllergenIngredients(post.ingredients).isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
                        const SizedBox(width: 4),
                        Text('Contains Allergen', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                        const SizedBox(width: 12),
                        Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                        const SizedBox(width: 4),
                        Text('Safe Ingredient', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                      ],
                    ),
                  ],

                  const SizedBox(height: 24),
                  
                  // Location
                  const Text('Location', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(post.location, style: const TextStyle(color: Colors.black54)),
                  const SizedBox(height: 12),
                  if (post.latitude != null && post.longitude != null)
                    Container(
                      height: 150,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.map, size: 40, color: Colors.grey[400]),
                            const SizedBox(height: 8),
                            Text(
                              'Map preview unavailable',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            // Optional: Add a button to open in external maps
                            TextButton.icon(
                              onPressed: () async {
                                final uri = Uri.parse(
                                    'https://www.google.com/maps/search/?api=1&query=${post.latitude},${post.longitude}');
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(uri,
                                      mode: LaunchMode.externalApplication);
                                } else {
                                  if (context.mounted) {
                                    SnackbarHelper.showError(
                                        context, 'Could not open maps');
                                  }
                                }
                              }, 
                              icon: const Icon(Icons.open_in_new, size: 16),
                              label: const Text('Open in Maps'),
                            )
                          ],
                        ),
                      ),
                    ),
                  
                  const SizedBox(height: 100), // Space for bottom buttons
                ],
              ),
            ),
          ),
        ],
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
        ),
        child: isDonor
            ? Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pushNamed(context, AppRoutes.editPost, arguments: post),
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _confirmDelete(context, post),
                      icon: const Icon(Icons.delete),
                      label: const Text('Delete'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                    ),
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(
                    child: _isRequesting
                        ? const LoadingIndicator()
                        : CustomButton(
                            text: 'Request This Food',
                            onPressed: isExpired ? null : () => _handleRequest(post),
                            color: (authProvider.currentUser?.isRecipient == true && 
                                            authProvider.currentUser!.getAllergenIngredients(post.ingredients).isNotEmpty)
                                            ? Colors.red 
                                            : AppColors.primary,
                          ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.chat_bubble_outline, color: AppColors.secondary),
                      onPressed: () {
                        // Find if there is an existing request for this post
                        final requestProvider = Provider.of<RequestProvider>(context, listen: false);
                        final existingRequest = requestProvider.myRequests.cast<RequestModel?>().firstWhere(
                              (r) => r?.postId == post.postId,
                              orElse: () => null,
                            );

                        if (existingRequest != null && userProvider.targetUser != null) {
                          Navigator.pushNamed(
                            context,
                            AppRoutes.chat,
                            arguments: {
                              'request': existingRequest,
                              'otherUser': userProvider.targetUser!,
                            },
                          );
                        } else {
                          if (existingRequest == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please request the food first to start a chat/negotiation.')),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Donor details not loaded yet.')),
                            );
                          }
                        }
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Future<bool> _checkAllergiesBeforeRequest(FoodPostModel post) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.currentUser == null || !authProvider.currentUser!.isRecipient) return true;

    final allergens = authProvider.currentUser!.getAllergenIngredients(post.ingredients);
    if (allergens.isEmpty) return true;

    // Show warning dialog
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning, color: Colors.red),
            const SizedBox(width: 8),
            const Text('Allergy Warning', style: TextStyle(color: Colors.red)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('This food contains ingredients you are allergic to:'),
            const SizedBox(height: 8),
            Text(
              allergens.join(", "),
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
            ),
            const SizedBox(height: 16),
            const Text('Are you sure you want to proceed nicely? consuming this could be dangerous.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Request Anyway (I understand the risk)', style: TextStyle(color: Colors.white, fontSize: 12)),
          ),
        ],
      ),
    );

    return confirmed ?? false;
  }

  Widget _buildDetailItem(IconData icon, String label, String value, {Color color = Colors.black}) {
    return Expanded(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54), overflow: TextOverflow.ellipsis),
                Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, FoodPostModel post) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Post?'),
        content: const Text('Are you sure you want to remove this food contribution? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await Provider.of<FoodPostProvider>(context, listen: false).deletePost(post.postId);
              if (success && mounted) {
                Navigator.pop(context);
                SnackbarHelper.showSuccess(context, 'Post deleted');
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
