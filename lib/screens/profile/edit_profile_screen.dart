import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/widgets/custom_text_field.dart';
import '../../core/widgets/loading_indicator.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../core/utils/validators.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/storage_service.dart';
import '../../core/localization/app_localizations.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _organizationController;
  final _allergyController = TextEditingController();

  String? _recipientType;
  List<String> _allergies = [];

  dynamic _newImage; // Use dynamic to support File (mobile) and CroppedFile (web)
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();
  final StorageService _storageService = StorageService();

  @override
  void initState() {
    super.initState();
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser!;
    _nameController = TextEditingController(text: user.name);
    _phoneController = TextEditingController(text: user.phoneNumber);
    _organizationController = TextEditingController(text: user.organizationName);
    _recipientType = user.recipientType;
    _allergies = List.from(user.allergies);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _phoneController.dispose();
    _organizationController.dispose();
    _allergyController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null) {
        // Small delay for UI stability
        await Future.delayed(const Duration(milliseconds: 200));

        final croppedFile = await ImageCropper().cropImage(
          sourcePath: pickedFile.path,
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'Crop Image',
              toolbarColor: AppColors.primary,
              statusBarColor: AppColors.primary,
              toolbarWidgetColor: Colors.white,
              initAspectRatio: CropAspectRatioPreset.square,
              lockAspectRatio: true,
            ),
            IOSUiSettings(
              title: 'Crop Image',
              aspectRatioLockEnabled: true,
            ),
            WebUiSettings(
              context: context,
              presentStyle: WebPresentStyle.page,
            ),
          ],
        );

        if (croppedFile != null) {
          setState(() {
            if (kIsWeb) {
              _newImage = croppedFile;
            } else {
              _newImage = File(croppedFile.path);
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Error picking image: $e');
      }
    }
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
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
}

void _removeAllergy(String allergy) {
  setState(() {
    _allergies.remove(allergy);
  });
}

Future<void> _saveProfile() async {
  if (!_formKey.currentState!.validate()) return;

  setState(() => _isLoading = true);
  final userProvider = Provider.of<UserProvider>(context, listen: false);
  final authProvider = Provider.of<AuthProvider>(context, listen: false);
  final currentUser = authProvider.currentUser!;

  try {
    String? imageUrl = currentUser.profileImageUrl;

    // Upload new image if selected
    if (_newImage != null) {
      imageUrl = await _storageService.uploadProfileImage(_newImage!, currentUser.id);
    }

    final updatedUser = currentUser.copyWith(
      name: _nameController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
      organizationName: currentUser.isDonor ? _organizationController.text.trim() : null,
      recipientType: currentUser.isRecipient ? _recipientType : null,
      allergies: currentUser.isRecipient ? _allergies : null,
      profileImageUrl: imageUrl,
      updatedAt: DateTime.now(),
    );

    await userProvider.updateUserProfile(updatedUser);
    // Refresh AuthProvider user state
    await authProvider.checkAuthState();

    if (mounted) {
      SnackbarHelper.showSuccess(context, 'Profile updated successfully');
      if (kIsWeb && !Navigator.canPop(context)) {
        Navigator.pushReplacementNamed(context, AppRoutes.home);
      } else {
        Navigator.pop(context);
      }
    }
  } catch (e) {
    if (mounted) {
      SnackbarHelper.showError(context, 'Failed to update profile: $e');
    }
  } finally {
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }
}

@override
Widget build(BuildContext context) {
  final user = Provider.of<AuthProvider>(context).currentUser;
  if (user == null) return const SizedBox.shrink();

  return Scaffold(
    appBar: AppBar(
      title: Text(AppLocalizations.of(context)!.translate('edit_profile')),
      actions: [
        if (!_isLoading)
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _saveProfile,
          ),
      ],
    ),
    body: _isLoading
        ? const LoadingIndicator()
        : SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        onWillPop: () async {
          // TODO: Show discard dialog if changes made
          return true;
        },
        child: Column(
          children: [
            // Profile Image
            GestureDetector(
              onTap: _showImagePickerOptions,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundImage: _newImage != null
                        ? (kIsWeb 
                            ? NetworkImage(_newImage.path) as ImageProvider
                            : FileImage(_newImage as File))
                        : (user.profileImageUrl != null
                        ? CachedNetworkImageProvider(user.profileImageUrl!) as ImageProvider
                        : null),
                    child: (_newImage == null && user.profileImageUrl == null)
                        ? Text(
                      user.name[0].toUpperCase(),
                      style: const TextStyle(fontSize: 40),
                    )
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            CustomTextField(
              controller: _nameController,
              label: AppLocalizations.of(context)!.translate('full_name'),
              validator: (v) => Validators.validateName(v),
            ),
            const SizedBox(height: 16),
            // Email is read-only
            CustomTextField(
              controller: TextEditingController(text: user.email),
              label: AppLocalizations.of(context)!.translate('email'),
              readOnly: true,
              fillColor: Colors.grey[100],
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _phoneController,
              label: AppLocalizations.of(context)!.translate('phone_number'),
              keyboardType: TextInputType.phone,
            ),

            if (user.isDonor) ...[
              const SizedBox(height: 16),
              CustomTextField(
                controller: _organizationController,
                label: AppLocalizations.of(context)!.translate('organization_name'),
              ),
            ],

            if (user.isRecipient) ...[
              const SizedBox(height: 24),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Recipient Type',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<String>(
                      title: Text(AppLocalizations.of(context)!.translate('individual')),
                      value: 'individual',
                      groupValue: _recipientType,
                      onChanged: (val) => setState(() => _recipientType = val),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      title: Text(AppLocalizations.of(context)!.translate('charity')),
                      value: 'charity',
                      groupValue: _recipientType,
                      onChanged: (val) => setState(() => _recipientType = val),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ],


            if (user.isRecipient) ...[
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 16),

              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.red),
                  const SizedBox(width: 8),
                  Text(
                    AppLocalizations.of(context)!.translate('food_allergies'),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.red[900],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(context)!.translate('add_allergy_desc'),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),

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
                      label: AppLocalizations.of(context)!.translate('add_allergy_hint').split(':')[0], // Using hint logic if needed, or just label
                      hint: AppLocalizations.of(context)!.translate('add_allergy_hint'),
                      prefixIcon: Icons.add_alert_outlined,
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: _addAllergy,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.add, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 40),
            CustomButton(
              text: AppLocalizations.of(context)!.translate('save_changes'),
              onPressed: _saveProfile,
            ),
          ],
        ),
      ),
    ),
  );
}
}

