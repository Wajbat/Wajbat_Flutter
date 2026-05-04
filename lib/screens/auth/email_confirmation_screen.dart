import 'package:flutter/material.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/config/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../core/constants/app_routes.dart';

class EmailConfirmationScreen extends StatelessWidget {
  final String email;

  const EmailConfirmationScreen({super.key, required this.email});

  Future<void> _resendEmail(BuildContext context) async {
    try {
      await SupabaseConfig.client.auth.resend(
        type: OtpType.signup,
        email: email,
      );
      if (context.mounted) {
        SnackbarHelper.showSuccess(context, 'Confirmation email resent! Please check your inbox.');
      }
    } catch (e) {
      if (context.mounted) {
        SnackbarHelper.showError(context, e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Check Your Email'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.mark_email_read_outlined,
                  size: 80,
                  color: theme.primaryColor,
                ),
              ),
              const SizedBox(height: 40),
              Text(
                'Verify your email',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: theme.textTheme.bodyLarge?.copyWith(color: Colors.black54),
                  children: [
                    const TextSpan(text: 'We sent a confirmation link to \n'),
                    TextSpan(
                      text: email,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.primaryColor,
                      ),
                    ),
                    const TextSpan(text: '.\nPlease click it to activate your account.'),
                  ],
                ),
              ),
              const SizedBox(height: 48),
              CustomButton(
                text: 'Resend Email',
                onPressed: () => _resendEmail(context),
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    AppRoutes.login,
                    (route) => false,
                  );
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.arrow_back, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Back to Login',
                      style: TextStyle(
                        color: theme.primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
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
}
