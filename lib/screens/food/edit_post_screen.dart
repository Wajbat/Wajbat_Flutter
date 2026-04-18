import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_datetime_picker_plus/flutter_datetime_picker_plus.dart' as picker;
import 'package:intl/intl.dart';

import '../../core/widgets/sample_image_picker.dart';
import '../../services/image_service.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../core/utils/validators.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/widgets/custom_text_field.dart';
import '../../core/widgets/loading_indicator.dart';
import '../../models/food_post_model.dart';
import '../../providers/food_post_provider.dart';
import '../../services/ai_service.dart';

class EditPostScreen extends StatefulWidget {
  const EditPostScreen({super.key});

  @override
  State<EditPostScreen> createState() => _EditPostScreenState();
}

class _EditPostScreenState extends State<EditPostScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _quantityController;
  late TextEditingController _locationController;
  final _ingredientController = TextEditingController();
  
  dynamic _newImage; // Use dynamic to support File (mobile) and CroppedFile (web)
  DateTime? _expirationDate;
  double? _latitude;
  double? _longitude;
  List<String> _ingredients = [];
  bool _isAnalyzing = false;
  bool _isLocating = false;
  bool _isPickingImage = false;
  
  FoodPostModel? _originalPost;

  final ImagePicker _picker = ImagePicker();
  final AIService _aiService = AIService();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _quantityController = TextEditingController();
    _locationController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_originalPost == null) {
      _originalPost = ModalRoute.of(context)!.settings.arguments as FoodPostModel;
      _nameController.text = _originalPost!.itemName;
      _quantityController.text = _originalPost!.quantity;
      _locationController.text = _originalPost!.location;
      _expirationDate = _originalPost!.expirationDate;
      _latitude = _originalPost!.latitude;
      _longitude = _originalPost!.longitude;
      _ingredients = List.from(_originalPost!.ingredients);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _locationController.dispose();
    _ingredientController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_isPickingImage) return;
    setState(() => _isPickingImage = true);

    try {
      final XFile? pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null && mounted) {
        await _cropImage(pickedFile.path);
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Error selecting image: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isPickingImage = false);
      }
    }
  }

  Future<void> _pickSampleImage() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SampleImagePicker(
        onSelected: (assetPath) async {
          if (_isPickingImage) return;
          setState(() => _isPickingImage = true);
          try {
            final String path = await ImageService.getSampleImagePath(assetPath);
            if (mounted) {
              await _cropImage(path);
            }
          } catch (e) {
            if (mounted) {
              SnackbarHelper.showError(context, 'Error loading sample image: $e');
            }
          } finally {
            if (mounted) {
              setState(() => _isPickingImage = false);
            }
          }
        },
      ),
    );
  }

  Future<void> _cropImage(String sourcePath) async {
    try {
      // Small delay to ensure the OS has finished with any previous picker/bottom sheet activity
      await Future.delayed(const Duration(milliseconds: 300));
      
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: sourcePath,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Image',
            toolbarColor: AppColors.primary,
            statusBarColor: AppColors.primary,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
            aspectRatioPresets: [
              CropAspectRatioPreset.square,
              CropAspectRatioPreset.ratio3x2,
              CropAspectRatioPreset.original,
              CropAspectRatioPreset.ratio4x3,
              CropAspectRatioPreset.ratio16x9
            ],
          ),
          IOSUiSettings(
            title: 'Crop Image',
            aspectRatioLockEnabled: false,
            resetAspectRatioEnabled: true,
            aspectRatioPresets: [
              CropAspectRatioPreset.square,
              CropAspectRatioPreset.ratio3x2,
              CropAspectRatioPreset.original,
              CropAspectRatioPreset.ratio4x3,
              CropAspectRatioPreset.ratio16x9
            ],
          ),
          WebUiSettings(
            context: context,
            presentStyle: WebPresentStyle.page,
          ),
        ],
      );

      if (croppedFile != null && mounted) {
        setState(() {
          if (kIsWeb) {
            _newImage = croppedFile;
          } else {
            _newImage = File(croppedFile.path);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Error cropping image: $e');
      }
    }
  }

  void _showImageSourceOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Select Image Source',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppColors.primary),
              title: const Text('Camera'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppColors.primary),
              title: const Text('Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.collections, color: AppColors.primary),
              title: const Text('Sample Photos'),
              onTap: () {
                Navigator.pop(context);
                _pickSampleImage();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _analyzeIngredients() async {
    if (_newImage == null && _originalPost?.imageUrl == null) {
      SnackbarHelper.showError(context, 'No image available for analysis');
      return;
    }

    setState(() => _isAnalyzing = true);
    
    try {
      // In a real app, if it's the old image, we might need to download it or send the URL to Gemini
      // For this implementation, we assume analysis works on the File. 
      // If user hasn't picked a new file, we can't easily re-analyze with AIService (which takes File).
      if (_newImage == null) {
        SnackbarHelper.showError(context, 'Please pick a new image to re-analyze');
        return;
      }

      final detected = await _aiService.detectIngredientsFromImage(_newImage!);
      setState(() {
        _ingredients.addAll(detected.where((e) => !_ingredients.contains(e)));
      });
      if (mounted) {
        SnackbarHelper.showSuccess(context, 'AI detected ${detected.length} ingredients!');
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'AI Analysis failed: $e');
      }
    } finally {
      setState(() => _isAnalyzing = false);
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLocating = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        Position position = await Geolocator.getCurrentPosition();
        _latitude = position.latitude;
        _longitude = position.longitude;

        List<Placemark> placemarks = await placemarkFromCoordinates(_latitude!, _longitude!);
        if (placemarks.isNotEmpty) {
          Placemark place = placemarks[0];
          setState(() {
            _locationController.text = '${place.name}, ${place.subLocality}, ${place.locality}';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Failed to get location: $e');
      }
    } finally {
      setState(() => _isLocating = false);
    }
  }

  void _addIngredient() {
    final text = _ingredientController.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        if (!_ingredients.contains(text)) {
          _ingredients.add(text);
        }
        _ingredientController.clear();
      });
    }
  }

  void _removeIngredient(String ingredient) {
    setState(() {
      _ingredients.remove(ingredient);
    });
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_ingredients.isEmpty) {
      SnackbarHelper.showError(context, 'Please add at least one ingredient');
      return;
    }

    final foodProvider = Provider.of<FoodPostProvider>(context, listen: false);

    final updatedPost = _originalPost!.copyWith(
      itemName: _nameController.text.trim(),
      quantity: _quantityController.text.trim(),
      expirationDate: _expirationDate!,
      location: _locationController.text.trim(),
      latitude: _latitude,
      longitude: _longitude,
      ingredients: _ingredients,
      updatedAt: DateTime.now(),
    );

    final success = await foodProvider.updatePost(updatedPost, _newImage);

    if (success && mounted) {
      SnackbarHelper.showSuccess(context, 'Food post updated successfully!');
      if (kIsWeb && !Navigator.canPop(context)) {
        Navigator.pushReplacementNamed(context, AppRoutes.home);
      } else {
        Navigator.pop(context);
      }
    } else if (mounted) {
      SnackbarHelper.showError(context, foodProvider.errorMessage ?? 'Failed to update post');
    }
  }

  @override
  Widget build(BuildContext context) {
    final foodProvider = Provider.of<FoodPostProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Post')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image Section
              GestureDetector(
                onTap: _showImageSourceOptions,
                child: Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!, style: BorderStyle.solid),
                    image: _newImage != null
                        ? (kIsWeb 
                            ? DecorationImage(image: NetworkImage(_newImage.path), fit: BoxFit.cover)
                            : DecorationImage(image: FileImage(_newImage as File), fit: BoxFit.cover))
                        : (_originalPost?.imageUrl != null
                            ? DecorationImage(image: NetworkImage(_originalPost!.imageUrl!), fit: BoxFit.cover)
                            : null),
                  ),
                  child: (_newImage == null && _originalPost?.imageUrl == null)
                      ? const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo_outlined, size: 40, color: Colors.grey),
                            SizedBox(height: 8),
                            Text('Click to add photo', style: TextStyle(color: Colors.grey)),
                          ],
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                   Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _showImageSourceOptions,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Camera'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _showImageSourceOptions,
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Gallery'),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // AI Analysis Button (Only for new images for now)
              if (_newImage != null)
                _isAnalyzing
                    ? const LoadingIndicator()
                    : CustomButton(
                        text: 'Re-analyze Ingredients with AI',
                        onPressed: _analyzeIngredients,
                        color: AppColors.secondary,
                      ),
              
              const SizedBox(height: 24),
              
              // Form Fields
              CustomTextField(
                controller: _nameController,
                label: 'Item Name',
                hint: 'e.g. Mixed Fruit Basket',
                validator: (v) => Validators.validateRequired(v, 'Item Name'),
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _quantityController,
                label: 'Quantity',
                hint: 'e.g. 5kg or 3 boxes',
                validator: (v) => Validators.validateRequired(v, 'Quantity'),
              ),
              const SizedBox(height: 16),
              
              // Date Picker
              InkWell(
                onTap: () {
                  picker.DatePicker.showDateTimePicker(
                    context,
                    showTitleActions: true,
                    minTime: DateTime.now().isBefore(_expirationDate!) ? DateTime.now() : _expirationDate,
                    onConfirm: (date) {
                      setState(() => _expirationDate = date);
                    },
                    currentTime: _expirationDate ?? DateTime.now(),
                    locale: picker.LocaleType.en,
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[400]!),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 20, color: Colors.grey),
                      const SizedBox(width: 12),
                      Text(
                        _expirationDate == null
                            ? 'Select Expiration Date'
                            : DateFormat('MMM dd, yyyy - hh:mm a').format(_expirationDate!),
                        style: TextStyle(
                          color: _expirationDate == null ? Colors.grey[600] : Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Location
              CustomTextField(
                controller: _locationController,
                label: 'Location',
                hint: 'Enter address manually',
                suffixIcon: IconButton(
                  icon: _isLocating ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.my_location),
                  onPressed: _getCurrentLocation,
                ),
                validator: (v) => Validators.validateRequired(v, 'Location'),
              ),
              
              const SizedBox(height: 24),
              
              // Ingredients Chips
              const Text('Ingredients', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _ingredients.map((ing) => Chip(
                  label: Text(ing),
                  onDeleted: () => _removeIngredient(ing),
                  deleteIcon: const Icon(Icons.close, size: 16),
                )).toList(),
              ),
              
              const SizedBox(height: 12),
              
              // Add manual ingredient
              Row(
                children: [
                  Expanded(
                    child: CustomTextField(
                      controller: _ingredientController,
                      label: 'Ingredient',
                      hint: 'Add ingredient manually',
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: AppColors.primary, size: 32),
                    onPressed: _addIngredient,
                  ),
                ],
              ),
              
              const SizedBox(height: 40),
              
              // Submit
              foodProvider.isLoading
                  ? const LoadingIndicator()
                  : CustomButton(
                      text: 'Update Post',
                      onPressed: _handleSubmit,
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
