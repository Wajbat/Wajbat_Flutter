import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/constants/app_colors.dart';
import '../../models/reward_model.dart';
import '../../models/user_model.dart'; // Need for User details if RewardModel only has userId
import '../../services/database_service.dart';
import '../../providers/auth_provider.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final DatabaseService _dbService = DatabaseService();
  List<RewardModel> _leaderboard = [];
  bool _isLoading = true;
  UserModel? _currentUser;
  
  // We need to fetch User details for each Reward entry since RewardModel usually just has userId
  // Or assuming RewardModel was joined with User data. 
  // Looking at previous valid code, RewardModel likely needs join or we fetch users separately.
  // Let's assume for now we might need to fetch user profiles or RewardModel has user data.
  // Checking RewardModel definition previously... it has `userId`.
  // I will fetch full user profiles for the leaderboard.
  Map<String, UserModel> _userProfiles = {};

  @override
  void initState() {
    super.initState();
    _currentUser = Provider.of<AuthProvider>(context, listen: false).currentUser;
    _loadLeaderboard();
  }

  Future<void> _loadLeaderboard() async {
    setState(() => _isLoading = true);
    try {
      final rewards = await _dbService.getLeaderboard(limit: 50);
      
      // Fetch user details for these rewards
      // In a real app, we'd use a join query or a bulk fetch. 
      // verified database_service.dart: getLeaderboard just selects from 'rewards'.
      // We need to fetch users. doing loop for now (not efficient but functional for MVP).
      
      for (var reward in rewards) {
        if (!_userProfiles.containsKey(reward.userId)) {
          final user = await _dbService.getUserById(reward.userId);
          if (user != null) {
            _userProfiles[reward.userId] = user;
          }
        }
      }

      setState(() {
        _leaderboard = rewards;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load leaderboard: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_leaderboard.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Top Donors')),
        body: const Center(child: Text('No donors yet. Be the first!')),
      );
    }

    // Sort just in case DB didn't
    _leaderboard.sort((a, b) => b.points.compareTo(a.points));

    final top3 = _leaderboard.take(3).toList();
    final rest = _leaderboard.skip(3).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Top Donors'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Badges'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      ListTile(leading: Text('🥉'), title: Text('Bronze (0-49)')),
                      ListTile(leading: Text('🥈'), title: Text('Silver (50-149)')),
                      ListTile(leading: Text('🥇'), title: Text('Gold (150-299)')),
                      ListTile(leading: Text('💎'), title: Text('Platinum (300+)')),
                    ],
                  ),
                  actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
                ),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadLeaderboard,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _buildPodium(top3),
            ),
            if (_currentUser != null) 
              SliverToBoxAdapter(
                child: _buildMyRank(),
              ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final reward = rest[index];
                  final rank = index + 4;
                  return _buildLeaderboardTile(reward, rank);
                },
                childCount: rest.length,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPodium(List<RewardModel> top3) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (top3.length > 1) _buildPodiumPlace(top3[1], 2),
          if (top3.isNotEmpty) _buildPodiumPlace(top3[0], 1),
          if (top3.length > 2) _buildPodiumPlace(top3[2], 3),
        ],
      ),
    );
  }

  Widget _buildPodiumPlace(RewardModel reward, int rank) {
    final user = _userProfiles[reward.userId];
    final isFirst = rank == 1;
    final size = isFirst ? 100.0 : 80.0;
    
    return Column(
      children: [
        if (isFirst) const Text('👑', style: TextStyle(fontSize: 32)),
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isFirst ? Colors.amber : (rank == 2 ? Colors.grey : Colors.brown),
                  width: 4,
                ),
              ),
              child: CircleAvatar(
                radius: size / 2,
                backgroundImage: user?.profileImageUrl != null
                    ? CachedNetworkImageProvider(user!.profileImageUrl!)
                    : null,
                child: user?.profileImageUrl == null
                    ? Text(user?.name[0].toUpperCase() ?? '?', style: TextStyle(fontSize: size / 3))
                    : null,
              ),
            ),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.black87,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$rank',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          user?.name ?? 'Unknown',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: isFirst ? 18 : 16,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          '${reward.points} pts',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
            fontSize: isFirst ? 16 : 14,
          ),
        ),
      ],
    );
  }

  Widget _buildMyRank() {
    // Find my rank
    int myIndex = _leaderboard.indexWhere((r) => r.userId == _currentUser?.id);
    if (myIndex == -1) return const SizedBox.shrink();

    final myReward = _leaderboard[myIndex];
    final rank = myIndex + 1;
    final user = _userProfiles[myReward.userId] ?? _currentUser!;

    // Calculate progress to next badge
    int nextBadgePoints = 50;
    String nextBadge = 'Silver';
    if (myReward.points >= 300) {
      nextBadgePoints = 300; // Max
      nextBadge = 'Max';
    } else if (myReward.points >= 150) {
      nextBadgePoints = 300;
      nextBadge = 'Platinum';
    } else if (myReward.points >= 50) {
      nextBadgePoints = 150;
      nextBadge = 'Gold';
    }

    double progress = nextBadge == 'Max' ? 1.0 : myReward.points / nextBadgePoints;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.secondary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.secondary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundImage: user.profileImageUrl != null
                ? CachedNetworkImageProvider(user.profileImageUrl!)
                : null,
            child: user.profileImageUrl == null
                ? Text(user.name[0].toUpperCase())
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('You are ranked #$rank', style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('${myReward.points} pts', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.grey[300],
                  color: AppColors.secondary,
                ),
                const SizedBox(height: 4),
                Text(
                  nextBadge == 'Max' ? 'Max Level Reached!' : '${nextBadgePoints - myReward.points} pts to $nextBadge',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardTile(RewardModel reward, int rank) {
    final user = _userProfiles[reward.userId];
    
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.grey[200],
        child: Text('#$rank', style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.bold)),
      ),
      title: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundImage: user?.profileImageUrl != null
                ? CachedNetworkImageProvider(user!.profileImageUrl!)
                : null,
            child: user?.profileImageUrl == null
                ? Text(user?.name[0].toUpperCase() ?? '?', style: const TextStyle(fontSize: 12))
                : null,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(user?.name ?? 'Unknown', overflow: TextOverflow.ellipsis)),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${reward.points}', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 4),
          _buildBadgeIcon(reward.points),
        ],
      ),
    );
  }

  Widget _buildBadgeIcon(int points) {
    String icon = '🥉';
    if (points >= 300) icon = '💎';
    else if (points >= 150) icon = '🥇';
    else if (points >= 50) icon = '🥈';
    
    return Text(icon);
  }
}
