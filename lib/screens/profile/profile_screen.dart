import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants/app_routes.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/language_provider.dart';
import '../../providers/food_post_provider.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../core/localization/app_localizations.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  
  Future<void> _handleRefresh() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;
    
    // Refresh user's posts if donor
    if (user != null && user.isDonor) {
      await Provider.of<FoodPostProvider>(context, listen: false).fetchMyPosts(user.id);
    }
    
    // Refresh user profile data from Supabase/Auth
    await authProvider.refreshUser();
    
    if (mounted) {
      SnackbarHelper.showSuccess(context, AppLocalizations.of(context)?.translate('profile_refreshed') ?? 'Profile refreshed');
    }
  }

  @override
  void initState() {
    super.initState();
    // Fetch user's posts to calculate stats
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
      if (user != null && user.isDonor) {
        Provider.of<FoodPostProvider>(context, listen: false).fetchMyPosts(user.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;

    if (user == null) {
      return const Center(child: Text('User not found'));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)?.translate('my_profile') ?? 'My Profile'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _handleRefresh,
            tooltip: 'Refresh Profile',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              // Header Section
              Container(
                width: double.infinity, // Extend width to full screen
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 40), // Reduced top padding for AppBar
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.white,
                    backgroundImage: user.profileImageUrl != null
                        ? CachedNetworkImageProvider(user.profileImageUrl!)
                        : null,
                    child: user.profileImageUrl == null
                        ? Text(
                            user.name[0].toUpperCase(),
                            style: const TextStyle(fontSize: 40, color: AppColors.primary),
                          )
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    user.email,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    alignment: WrapAlignment.center,
                    children: user.roles
                        .map((role) => Chip(
                              label: Text(
                                AppLocalizations.of(context)?.translateDynamic(role).toUpperCase() ?? role.toUpperCase(),
                                style: const TextStyle(fontSize: 10, color: AppColors.primary),
                              ),
                              backgroundColor: Colors.white,
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                              side: BorderSide.none,
                            ))
                        .toList(),
                  ),
                  if (user.isDonor) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            '${user.donationPoints} ${AppLocalizations.of(context)?.translate('points') ?? 'Points'}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Role Switcher
                  if (user.canSwitchRoles)
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(
                              user.isDonor ? Icons.volunteer_activism : Icons.restaurant,
                              color: AppColors.primary,
                              size: 32,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(AppLocalizations.of(context)?.translate('currently') ?? 'Currently:', style: const TextStyle(color: Colors.grey)),
                                  Text(
                                    AppLocalizations.of(context)?.translateDynamic(user.active_role).toUpperCase() ?? user.active_role.toUpperCase(),
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: user.isDonor,
                              activeColor: AppColors.primary,
                              onChanged: (value) async {
                                final newRole = value ? 'donor' : 'recipient';
                                final success = await authProvider.switchRole(newRole);
                                if (success && context.mounted) {
                                  SnackbarHelper.showSuccess(context, '${AppLocalizations.of(context)!.translate('switch_role')} ${AppLocalizations.of(context)!.translateDynamic(newRole).toUpperCase()}');
                                  Navigator.pushReplacementNamed(
                                    context,
                                    newRole == 'donor' ? AppRoutes.donorHome : AppRoutes.recipientHome,
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  
                  // Allergies Section (For Recipients)
                  if (user.isRecipient && user.allergies.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red[50], // Red-tinted background
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.red[100]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: Colors.red),
                              const SizedBox(width: 8),
                              const SizedBox(width: 8),
                              Text(
                                AppLocalizations.of(context)!.translate('my_allergies'),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red[900],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: user.allergies.map((allergy) => Chip(
                              label: Text(allergy),
                              labelStyle: TextStyle(color: Colors.red[900], fontSize: 12),
                              backgroundColor: Colors.white,
                              side: BorderSide(color: Colors.red[200]!),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                            )).toList(),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Stats Section (for donors)
                  if (user.isDonor)
                    Consumer<FoodPostProvider>(
                      builder: (context, foodProvider, _) {
                        final activePosts = foodProvider.myPosts
                            .where((p) => p.postStatus == 'available')
                            .length;
                        
                        return Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => Navigator.pushNamed(context, AppRoutes.leaderboard),
                                child: _buildStatCard(AppLocalizations.of(context)!.translate('total_donations'), '${user.donationPoints}', Icons.volunteer_activism), 
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: _buildStatCard(AppLocalizations.of(context)!.translate('active_posts'), '$activePosts', Icons.inventory_2)),
                            const SizedBox(width: 12),
                            Expanded(child: _buildStatCard(AppLocalizations.of(context)!.translate('impact_score'), AppLocalizations.of(context)!.translate('impact_high'), Icons.favorite)),
                          ],
                        );
                      },
                    ),
                    
                  if (user.isDonor) const SizedBox(height: 24),

                  // Settings List
                  _buildSettingsTile(
                    icon: Icons.person_outline,
                    title: AppLocalizations.of(context)!.translate('edit_profile'),
                    onTap: () => Navigator.pushNamed(context, AppRoutes.editProfile),
                  ),
                  _buildSettingsTile(
                    icon: Icons.language,
                    title: AppLocalizations.of(context)!.translate('language'),
                    trailing: Text(Provider.of<LanguageProvider>(context).currentLanguage == 'en' ? 'English' : 'العربية', style: TextStyle(color: Colors.grey)), 
                    onTap: () => _showLanguageDialog(context),
                  ),
                  _buildSettingsTile(
                    icon: Icons.notifications_outlined,
                    title: AppLocalizations.of(context)!.translate('notifications'),
                    trailing: Switch(
                      value: true, 
                      onChanged: (val) {},
                      activeColor: AppColors.primary,
                    ),
                  ),
                  const Divider(),
                  _buildSettingsTile(
                    icon: Icons.help_outline,
                    title: AppLocalizations.of(context)!.translate('help_center'),
                    onTap: () => Navigator.pushNamed(context, AppRoutes.chatbot),
                  ),
                   _buildSettingsTile(
                    icon: Icons.policy_outlined,
                    title: AppLocalizations.of(context)!.translate('privacy_policy'),
                    onTap: () {},
                  ),
                   _buildSettingsTile(
                    icon: Icons.description_outlined,
                    title: AppLocalizations.of(context)!.translate('terms_conditions'),
                    onTap: () {},
                  ),
                  _buildSettingsTile(
                    icon: Icons.headset_mic_outlined,
                    title: AppLocalizations.of(context)!.translate('contact_support'),
                    onTap: () => Navigator.pushNamed(context, AppRoutes.supportTicket),
                  ),
                  const Divider(),
                  _buildSettingsTile(
                    icon: Icons.logout,
                    title: AppLocalizations.of(context)!.translate('logout'),
                    textColor: Colors.red,
                    iconColor: Colors.red,
                    onTap: () => _showLogoutDialog(context, authProvider),
                  ),
                  _buildSettingsTile(
                    icon: Icons.delete_forever,
                    title: AppLocalizations.of(context)!.translate('delete_account'),
                    textColor: Colors.red,
                    iconColor: Colors.red,
                    onTap: () => _showDeleteAccountDialog(context, authProvider, user.id),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Container(
        width: 100, // Fixed width or flexible
        // Actually, better to keep it flexible but let parent handle Expanded
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    VoidCallback? onTap,
    Widget? trailing,
    Color? textColor,
    Color? iconColor,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (iconColor ?? AppColors.primary).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: iconColor ?? AppColors.primary, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: textColor ?? Colors.black87,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: trailing ?? const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      onTap: onTap,
    );
  }

  void _showLanguageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.translate('select_language')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('English'),
              onTap: () {
                Provider.of<LanguageProvider>(context, listen: false).changeLanguage('en');
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('العربية'),
              onTap: () {
                Provider.of<LanguageProvider>(context, listen: false).changeLanguage('ar');
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, AuthProvider authProvider) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.translate('logout')),
        content: Text(AppLocalizations.of(context)!.translate('logout') + '?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(AppLocalizations.of(context)!.translate('cancel')),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext); // Close dialog using its context
              await authProvider.signOut();
              // Check if the SCREEN's context is still mounted
              if (context.mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
              }
            },
            child: Text(AppLocalizations.of(context)!.translate('logout'), style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context, AuthProvider authProvider, String userId) {
    final passwordController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.translate('delete_account'), style: TextStyle(color: Colors.red)),

        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)?.translate('delete_account_confirm_msg') ?? 'This action is irreversible. All your data will be permanently removed.',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            Text(AppLocalizations.of(context)?.translate('enter_password_confirm') ?? 'Please enter your password to confirm:'),
            const SizedBox(height: 8),
            // In a real app, we should verify password. 
            // For now, assume re-authentication or just a confirmation.
             TextField(
              controller: passwordController,
              obscureText: true,
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context)!.translate('password'),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(AppLocalizations.of(context)!.translate('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              // TODO: Verify password with backend
              if (passwordController.text.isEmpty) {
                SnackbarHelper.showError(context, AppLocalizations.of(context)?.translate('password_required') ?? 'Password is required');
                return;
              }
              
              Navigator.pop(dialogContext); // Close dialog
              
              final userProvider = Provider.of<UserProvider>(context, listen: false);
              try {
                await userProvider.deleteAccount(userId);
                if (context.mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
                  SnackbarHelper.showSuccess(context, AppLocalizations.of(context)?.translate('account_deleted_success') ?? 'Account deleted successfully');
                }
              } catch (e) {
                if (context.mounted) {
                  SnackbarHelper.showError(context, '${AppLocalizations.of(context)?.translate('account_delete_failed') ?? 'Failed to delete account: '}$e');
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
