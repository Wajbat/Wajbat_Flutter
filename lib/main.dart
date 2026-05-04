import 'dart:async';
import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
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
import 'providers/notification_provider.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/email_confirmation_screen.dart';
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
import 'screens/auth/reset_password_screen.dart';
import 'core/utils/navigator_key.dart';
import 'core/utils/snackbar_helper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
    
    // Listen for auth state changes to catch password recovery deep link
    SupabaseConfig.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      if (event == AuthChangeEvent.passwordRecovery) {
        AppNavigator.navigatorKey.currentState?.pushNamed(AppRoutes.resetPassword);
      }
    });
  }

  void _initDeepLinks() {
    _appLinks = AppLinks();

    // Check initial link if app was closed
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) _handleDeepLink(uri);
    });

    // Listen for incoming links while app is running
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    });
  }

  void _handleDeepLink(Uri uri) async {
    debugPrint('Deep Link Received: $uri');
    
    // We handle any link with the wajbat scheme
    if (uri.scheme == 'wajbat') {
      try {
        // Supabase getSessionFromUrl handles both #fragment and ?query parameters
        await SupabaseConfig.client.auth.getSessionFromUrl(uri);
        
        if (mounted) {
          // If we successfully got a session, redirect to home
          AppNavigator.navigatorKey.currentState?.pushNamedAndRemoveUntil(
            AppRoutes.home,
            (route) => false,
          );
          
          final context = AppNavigator.navigatorKey.currentContext;
          if (context != null) {
            SnackbarHelper.showSuccess(context, 'Email confirmed successfully!');
          }
        }
      } catch (e) {
        debugPrint('Deep Link Error: $e');
        if (mounted) {
          final context = AppNavigator.navigatorKey.currentContext;
          if (context != null) {
            // Only show error if it's not a "no code found" which can happen on redundant triggers
            if (!e.toString().contains('no code found')) {
              SnackbarHelper.showError(context, 'Verification failed: ${e.toString()}');
            }
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

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
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      child: Consumer<LanguageProvider>(
        builder: (context, languageProvider, child) {
          return MaterialApp(
            title: 'Wajbat',
            navigatorKey: AppNavigator.navigatorKey,
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
              AppRoutes.resetPassword: (context) => const ResetPasswordScreen(),
              AppRoutes.emailConfirmation: (context) {
                final email = ModalRoute.of(context)!.settings.arguments as String;
                return EmailConfirmationScreen(email: email);
              },
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
