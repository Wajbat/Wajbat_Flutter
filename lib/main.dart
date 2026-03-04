import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/localization/app_localizations.dart';
import 'core/config/supabase_config.dart';
import 'core/constants/app_colors.dart';
import 'core/constants/app_routes.dart';
import 'providers/auth_provider.dart';
import 'providers/food_post_provider.dart';
import 'providers/language_provider.dart';
import 'providers/message_provider.dart';
import 'providers/request_provider.dart';
import 'providers/user_provider.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/food/create_post_screen.dart';
import 'screens/food/food_detail_screen.dart';
import 'screens/food/food_list_screen.dart';
import 'screens/food/edit_post_screen.dart';
import 'screens/requests/my_requests_screen.dart';
import 'screens/requests/incoming_requests_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/profile/edit_profile_screen.dart';
import 'screens/support/support_ticket_screen.dart';
import 'screens/support/chatbot_screen.dart';
import 'screens/rewards/leaderboard_screen.dart';
import 'screens/chat/chat_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase
  try {
    await SupabaseConfig.initialize();
  } catch (e) {
    debugPrint('Initialization Error: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => FoodPostProvider()),
        ChangeNotifierProvider(create: (_) => RequestProvider()),
        ChangeNotifierProvider(create: (_) => MessageProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
      ],
      child: Consumer<LanguageProvider>(
        builder: (context, languageProvider, child) {
          return MaterialApp(
            title: 'Wajbat',
            debugShowCheckedModeBanner: false,
            // Localization
            locale: languageProvider.currentLocale,
            supportedLocales: const [
              Locale('en'),
              Locale('ar'),
            ],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              AppLocalizations.delegate,
            ],
            // Theme
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: AppColors.primary,
                primary: AppColors.primary,
                secondary: AppColors.secondary,
                surface: AppColors.lightBackground,
              ),
              useMaterial3: true,
              fontFamily: 'Roboto',
            ),
            // Routes
            initialRoute: AppRoutes.splash,
            routes: {
              AppRoutes.splash: (context) => const SplashScreen(),
              AppRoutes.login: (context) => const LoginScreen(),
              AppRoutes.register: (context) => const RegisterScreen(),
              AppRoutes.forgotPassword: (context) => const ForgotPasswordScreen(),
              AppRoutes.home: (context) => const HomeScreen(),
              // Role-based home routes also point to HomeScreen which handles internal switching
              AppRoutes.donorHome: (context) => const HomeScreen(),
              AppRoutes.recipientHome: (context) => const HomeScreen(),
              AppRoutes.myRequests: (context) => const MyRequestsScreen(),
              AppRoutes.incomingRequests: (context) => const IncomingRequestsScreen(),
              AppRoutes.foodDetail: (context) => const FoodDetailScreen(),
              AppRoutes.createPost: (context) => const CreatePostScreen(),
              AppRoutes.editPost: (context) => const EditPostScreen(),
              AppRoutes.profile: (context) => const ProfileScreen(),
              AppRoutes.editProfile: (context) => const EditProfileScreen(),
              AppRoutes.supportTicket: (context) => const SupportTicketScreen(),
              AppRoutes.chat: (context) => const ChatScreen(),
              AppRoutes.chatbot: (context) => const ChatbotScreen(),
              AppRoutes.leaderboard: (context) => const LeaderboardScreen(),
              AppRoutes.myDonations: (context) => const FoodListScreen(isMyPosts: true),
            },
          );
        },
      ),
    );
  }
}
