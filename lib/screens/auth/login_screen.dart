import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_routes.dart';
import '../../core/utils/validators.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/widgets/custom_text_field.dart';
import '../../core/widgets/loading_indicator.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/language_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      final success = await authProvider.signIn(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (success && mounted) {
        final user = authProvider.currentUser;
        if (user != null) {
          _processPostLogin(user);
        }
      } else if (mounted) {
        SnackbarHelper.showError(
          context, 
          authProvider.errorMessage ?? 'Login failed'
        );
      }
    } catch (e) {
      if (mounted) SnackbarHelper.showError(context, e.toString());
    }
  }

  void _processPostLogin(UserModel user) async {
    // If user has both roles (or more?), ask.
    // Assuming 'roles' list in user model contains available roles.
    if (user.roles.contains('donor') && user.roles.contains('recipient')) {
      await _showRoleSelectionDialog(user);
    } else {
      // Single role, navigate usually
      _navigateHome(user.active_role);
    }
  }

  Future<void> _showRoleSelectionDialog(UserModel user) async {
    final role = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('How would you like to continue?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.volunteer_activism, color: Colors.green),
              title: const Text('I want to Donate'),
              onTap: () => Navigator.pop(ctx, 'donor'),
            ),
            ListTile(
              leading: const Icon(Icons.food_bank, color: Colors.orange),
              title: const Text('I need Food'),
              onTap: () => Navigator.pop(ctx, 'recipient'),
            ),
          ],
        ),
      ),
    );

    if (role != null && mounted) {
      // If selected role is different from active, switch it
      if (user.active_role != role) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final success = await authProvider.switchRole(role);
        if(!success && mounted) {
             SnackbarHelper.showError(context, "Failed to switch role");
             return;
        }
      }
      _navigateHome(role);
    }
  }

  void _navigateHome(String role) {
    if (role == 'donor') {
      Navigator.of(context).pushReplacementNamed(AppRoutes.donorHome);
    } else {
      Navigator.of(context).pushReplacementNamed(AppRoutes.recipientHome);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final langProvider = Provider.of<LanguageProvider>(context);

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: Text(langProvider.currentLanguage == 'en' ? 'AR' : 'EN', 
              style: const TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () {
              final newLang = langProvider.currentLanguage == 'en' ? 'ar' : 'en';
              langProvider.changeLanguage(newLang);
            },
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo
                Icon(
                  Icons.fastfood,
                  size: 80,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 24),
                
                // Welcome Title
                Text(
                  'Welcome Back',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 32),
                
                // Email
                CustomTextField(
                  controller: _emailController,
                  label: 'Email',
                  hint: 'Enter your email',
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: Icons.email_outlined,
                  validator: Validators.validateEmail,
                ),
                const SizedBox(height: 16),
                
                // Password
                CustomTextField(
                  controller: _passwordController,
                  label: 'Password',
                  hint: 'Enter your password',
                  obscureText: !_isPasswordVisible,
                  prefixIcon: Icons.lock_outlined,
                  validator: Validators.validatePassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _isPasswordVisible = !_isPasswordVisible;
                      });
                    },
                  ),
                ),
                
                // Forgot Password
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, AppRoutes.forgotPassword);
                    },
                    child: const Text('Forgot Password?'),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Login Button
                authProvider.isLoading
                    ? const LoadingIndicator()
                    : CustomButton(
                        text: 'Login',
                        onPressed: _handleLogin,
                      ),
                
                const SizedBox(height: 24),
                
                // Sign Up Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Don't have an account?"),
                    TextButton(
                      onPressed: () {
                        Navigator.pushNamed(context, AppRoutes.register);
                      },
                      child: const Text('Sign Up'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
