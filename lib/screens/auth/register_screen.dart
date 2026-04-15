import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_routes.dart';
import '../../core/utils/validators.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/widgets/custom_text_field.dart';
import '../../core/widgets/loading_indicator.dart';
import '../../providers/auth_provider.dart';
import '../../core/localization/app_localizations.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _orgNameController = TextEditingController();
  final _allergyController = TextEditingController();

  // State
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _termsAccepted = false;
  
  // Roles
  bool _isDonor = false;
  bool _isRecipient = false;
  String? _recipientType = 'individual'; // "individual" or "charity"
  final List<String> _allergies = [];

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _orgNameController.dispose();
    _allergyController.dispose();
    super.dispose();
  }

  Widget _buildPasswordStrengthIndicator() {
    final text = _passwordController.text;
    if (text.isEmpty) return const SizedBox.shrink();

    String strength = 'Weak';
    Color color = Colors.red;
    double progress = 0.3;

    final hasUpper = text.contains(RegExp(r'[A-Z]'));
    final hasNumber = text.contains(RegExp(r'[0-9]'));
    final hasMinLength = text.length >= 8;

    if (hasUpper && hasNumber && hasMinLength) {
      strength = 'Strong';
      color = Colors.green;
      progress = 1.0;
    } else if (hasMinLength && (hasUpper || hasNumber)) {
      strength = 'Medium';
      color = Colors.orange;
      progress = 0.6;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.grey[300],
          color: color,
          minHeight: 4,
        ),
        const SizedBox(height: 4),
        Text(
          'Strength: $strength',
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ],
    );

  }

  void _addAllergy() {
    final text = _allergyController.text.trim().toLowerCase();
    if (text.isEmpty) return;

    if (_allergies.contains(text)) {
      SnackbarHelper.showError(context, 'Allergy already added');
      return;
    }

    setState(() {
      _allergies.add(text);
      _allergyController.clear();
    });
    SnackbarHelper.showSuccess(context, 'Allergy added');
  }

  void _removeAllergy(String allergy) {
    setState(() {
      _allergies.remove(allergy);
    });
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Custom Validation
    if (!_isDonor && !_isRecipient) {
      SnackbarHelper.showError(context, 'Please select at least one role (Donate or Receive)');
      return;
    }
    if (!_termsAccepted) {
      SnackbarHelper.showError(context, 'You must accept the Terms and Conditions');
      return;
    }

    FocusScope.of(context).unfocus();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Prepare roles list
    List<String> roles = [];
    if (_isDonor) roles.add('donor');
    if (_isRecipient) roles.add('recipient');

    try {
      final success = await authProvider.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        name: _nameController.text.trim(),
        roles: roles,
        phoneNumber: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        organizationName: _isDonor ? _orgNameController.text.trim() : null,
        recipientType: _isRecipient ? _recipientType : null,
        allergies: _isRecipient ? _allergies : null,
      );

      if (success && mounted) {
        // Navigate based on primary role preference or just the first one
        if (_isDonor) {
          Navigator.of(context).pushReplacementNamed(AppRoutes.donorHome);
        } else {
          Navigator.of(context).pushReplacementNamed(AppRoutes.recipientHome);
        }
      } else if (mounted) {
        SnackbarHelper.showError(
          context, 
          authProvider.errorMessage ?? 'Registration failed'
        );
      }
    } catch (e) {
      if (mounted) SnackbarHelper.showError(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)?.translate('create_account_title') ?? 'Create Account')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Name
                CustomTextField(
                  controller: _nameController,
                  label: AppLocalizations.of(context)?.translate('full_name') ?? 'Full Name',
                  hint: AppLocalizations.of(context)?.translate('full_name') ?? 'Enter your name',
                  prefixIcon: Icons.person_outline,
                  validator: (val) => Validators.validateName(val),
                ),
                const SizedBox(height: 16),
                
                // Email
                CustomTextField(
                  controller: _emailController,
                  label: AppLocalizations.of(context)?.translate('email') ?? 'Email',
                  hint: AppLocalizations.of(context)?.translate('email') ?? 'Enter your email',
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: Icons.email_outlined,
                  validator: Validators.validateEmail,
                ),
                const SizedBox(height: 16),
                
                // Phone (Optional)
                CustomTextField(
                  controller: _phoneController,
                  label: AppLocalizations.of(context)?.translate('phone_number') ?? 'Phone Number (Optional)',
                  hint: AppLocalizations.of(context)?.translate('phone_number') ?? 'Enter your phone number',
                  keyboardType: TextInputType.phone,
                  prefixIcon: Icons.phone_outlined,
                ),
                const SizedBox(height: 16),
                
                // Password
                CustomTextField(
                  controller: _passwordController,
                  label: AppLocalizations.of(context)?.translate('password') ?? 'Password',
                  hint: 'Min 8 chars, 1 upper, 1 number',
                  obscureText: !_isPasswordVisible,
                  prefixIcon: Icons.lock_outlined,
                  onChanged: (val) => setState(() {}),
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
                const SizedBox(height: 8),
                _buildPasswordStrengthIndicator(),
                const SizedBox(height: 16),
                
                // Confirm Password
                CustomTextField(
                  controller: _confirmPasswordController,
                  label: 'Confirm Password',
                  hint: 'Re-enter your password',
                  obscureText: !_isConfirmPasswordVisible,
                  prefixIcon: Icons.lock_outlined,
                  validator: (val) {
                    if (val != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 24),
                
                // --- ROLE SELECTION ---
                Text(AppLocalizations.of(context)?.translate('role') ?? 'I want to:', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                
                // Donate Checkbox
                CheckboxListTile(
                  title: Text(AppLocalizations.of(context)?.translate('donor') ?? 'Donate Food'),
                  subtitle: const Text('Post surplus food for those in need'),
                  secondary: const Icon(Icons.volunteer_activism, color: Colors.green),
                  value: _isDonor,
                  onChanged: (val) => setState(() => _isDonor = val ?? false),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                
                // Organization Name (Conditional)
                if (_isDonor) ...[
                  Padding(
                    padding: const EdgeInsets.only(left: 16.0, bottom: 8.0),
                    child: CustomTextField(
                      controller: _orgNameController,
                      label: AppLocalizations.of(context)?.translate('organization_name') ?? 'Organization Name (Optional)',
                      hint: 'e.g. Restaurant Name',
                      prefixIcon: Icons.business,
                    ),
                  ),
                ],

                // Receive Checkbox
                CheckboxListTile(
                  title: Text(AppLocalizations.of(context)?.translate('recipient') ?? 'Receive Food'),
                  subtitle: const Text('Browse and request available food donations'),
                  secondary: const Icon(Icons.food_bank, color: Colors.orange),
                  value: _isRecipient,
                  onChanged: (val) => setState(() => _isRecipient = val ?? false),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                
                // Recipient Type (Conditional)
                if (_isRecipient) ...[
                  Padding(
                    padding: const EdgeInsets.only(left: 48.0),
                    child: Column(
                      children: [
                        RadioListTile<String>(
                          title: const Text('Individual'),
                          value: 'individual',
                          groupValue: _recipientType,
                          onChanged: (val) => setState(() => _recipientType = val),
                          contentPadding: EdgeInsets.zero,
                        ),
                        RadioListTile<String>(
                          title: const Text('Charity'),
                          value: 'charity',
                          groupValue: _recipientType,
                          onChanged: (val) => setState(() => _recipientType = val),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
                  ],

                  // Allergies Section (Conditional)
                  if (_isRecipient) ...[
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    
                    // Header
                    Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.red),
                        const SizedBox(width: 8),
                        Text(
                          AppLocalizations.of(context)?.translate('food_allergies') ?? 'Food Allergies (Optional)',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.red[800],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Do you have any food allergies? We\'ll warn you about posts containing these ingredients.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),

                    // Chips
                    if (_allergies.isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red[100]!),
                        ),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _allergies.map((allergy) {
                            return Chip(
                              label: Text(allergy),
                              labelStyle: TextStyle(color: Colors.red[900]),
                              backgroundColor: Colors.white,
                              deleteIcon: const Icon(Icons.close, size: 18, color: Colors.red),
                              onDeleted: () => _removeAllergy(allergy),
                              side: BorderSide(color: Colors.red[200]!),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            );
                          }).toList(),
                        ),
                      ),
                    
                    if (_allergies.isNotEmpty) const SizedBox(height: 12),

                    // Input Row
                    Row(
                      children: [
                        Expanded(
                          child: CustomTextField(
                            controller: _allergyController,
                            label: 'Add allergy',
                            hint: AppLocalizations.of(context)?.translate('add_allergy_hint') ?? 'e.g., peanuts, dairy',
                            prefixIcon: Icons.add_alert_outlined,
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: _addAllergy,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.primaryColor,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.add, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Padding(
                      padding: EdgeInsets.only(left: 4.0),
                      child: Text(
                        'Add each ingredient separately. Tap + after typing each one.',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ),
                  ],

                const SizedBox(height: 16),
                
                // Terms
                CheckboxListTile(
                  value: _termsAccepted,
                  onChanged: (val) => setState(() => _termsAccepted = val ?? false),
                  title: const Text('I agree to the Terms and Conditions'),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
                
                const SizedBox(height: 24),
                
                // Register Button
                authProvider.isLoading
                    ? const LoadingIndicator()
                    : CustomButton(
                        text: AppLocalizations.of(context)?.translate('register') ?? 'Create Account',
                        onPressed: _handleRegister,
                      ),
                      
                const SizedBox(height: 16),
                
                // Already have account
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Already have an account?'),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: Text(AppLocalizations.of(context)?.translate('login') ?? 'Login'),
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
