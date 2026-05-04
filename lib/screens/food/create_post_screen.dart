import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_datetime_picker_plus/flutter_datetime_picker_plus.dart'
    as picker;
import 'package:intl/intl.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart' show rootBundle;


import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../core/utils/validators.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/widgets/custom_text_field.dart';
import '../../core/widgets/loading_indicator.dart';
import '../../providers/auth_provider.dart';
import '../../providers/food_post_provider.dart';
import '../../services/ai_service.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController();
  final _locationController = TextEditingController();
  final _ingredientController = TextEditingController();

  dynamic _image; // Use dynamic to support File (mobile) and CroppedFile (web)
  DateTime? _expirationDate;
  double? _latitude;
  double? _longitude;
  List<String> _ingredients = [];
  bool _isAnalyzing = false;
  bool _isLocating = false;
  bool _isPickingImage = false;

  final ImagePicker _picker = ImagePicker();
  final AIService _aiService = AIService();
  final MapController _mapController = MapController();
  LatLng _currentLatLng = const LatLng(
      25.2048, 55.2708); // Default to Dubai since app name is Arabic
  String _address = '';

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

  Future<void> _pickSampleImage(String assetPath) async {
    if (_isPickingImage) return;
    setState(() => _isPickingImage = true);

    try {
      // Load asset
      final byteData = await rootBundle.load(assetPath);

      // Create temp file
      final tempDir = await getTemporaryDirectory();
      final tempFile =
          File('${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.png');

      // Write to file
      await tempFile.writeAsBytes(byteData.buffer.asUint8List(
          byteData.offsetInBytes, byteData.lengthInBytes));

      // Proceed to crop
      await _cropImage(tempFile.path);
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Failed to load sample image: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isPickingImage = false);
      }
    }
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
            _image = croppedFile;
          } else {
            _image = File(croppedFile.path);
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
              leading:
                  const Icon(Icons.photo_library, color: AppColors.primary),
              title: const Text('Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            const Divider(),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text(
                'Or Choose Sample Photo (For Testing)',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey),
              ),
            ),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: 4,
                itemBuilder: (context, index) {
                  final assetPath = 'assets/images/food${index + 1}.png';
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      _pickSampleImage(assetPath);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 12),
                      width: 80,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        image: DecorationImage(
                          image: AssetImage(assetPath),
                          fit: BoxFit.cover,
                        ),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _analyzeIngredients() async {
    if (_image == null) {
      SnackbarHelper.showError(context, 'Please select an image first');
      return;
    }

    setState(() => _isAnalyzing = true);

    try {
      final detected = await _aiService.detectIngredientsFromImage(_image!);
      setState(() {
        _ingredients.addAll(detected.where((e) => !_ingredients.contains(e)));
      });
      if (mounted) {
        SnackbarHelper.showSuccess(
            context, 'AI detected ${detected.length} ingredients!');
      }
    } catch (e) {
      if (mounted) {
        final message = e.toString().replaceFirst('Exception: ', '');
        SnackbarHelper.showError(context, message);
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

      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        Position position = await Geolocator.getCurrentPosition();
        setState(() {
          _latitude = position.latitude;
          _longitude = position.longitude;
          _currentLatLng = LatLng(_latitude!, _longitude!);
        });

        _mapController.move(_currentLatLng, 15.0);

        List<Placemark> placemarks =
            await placemarkFromCoordinates(_latitude!, _longitude!);
        if (placemarks.isNotEmpty) {
          Placemark place = placemarks[0];
          setState(() {
            _address = '${place.name}, ${place.subLocality}, ${place.locality}';
            _locationController.text = _address;
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
    if (_image == null) {
      SnackbarHelper.showError(context, 'Please select an image');
      return;
    }
    if (_ingredients.isEmpty) {
      SnackbarHelper.showError(context, 'Please add at least one ingredient');
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final foodProvider = Provider.of<FoodPostProvider>(context, listen: false);

    final success = await foodProvider.createPost(
      itemName: _nameController.text.trim(),
      quantity: _quantityController.text.trim(),
      expirationDate: _expirationDate!,
      location: _locationController.text.trim(),
      latitude: _latitude,
      longitude: _longitude,
      image: _image!,
      ingredients: _ingredients,
      donorId: authProvider.currentUser!.id,
    );

    if (success && mounted) {
      SnackbarHelper.showSuccess(context, 'Food post created successfully!');
      if (kIsWeb && !Navigator.canPop(context)) {
        Navigator.pushReplacementNamed(context, AppRoutes.home);
      } else {
        Navigator.pop(context);
      }
    } else if (mounted) {
      SnackbarHelper.showError(
          context, foodProvider.errorMessage ?? 'Failed to create post');
    }
  }

  Future<void> _updateAddress(LatLng point) async {
    try {
      List<Placemark> placemarks =
          await placemarkFromCoordinates(point.latitude, point.longitude);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        setState(() {
          _address = '${place.name}, ${place.subLocality}, ${place.locality}';
          _locationController.text = _address;
        });
      }
    } catch (e) {
      debugPrint('Error reverse geocoding: $e');
    }
  }

  Widget _buildMap() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Pick Location',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        Container(
          height: 250,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _currentLatLng,
                initialZoom: 15.0,
                onTap: (tapPosition, point) {
                  setState(() {
                    _currentLatLng = point;
                    _latitude = point.latitude;
                    _longitude = point.longitude;
                  });
                  _updateAddress(point);
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.app',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _currentLatLng,
                      width: 80,
                      height: 80,
                      child: const Icon(Icons.location_on,
                          color: Colors.red, size: 40),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                _address.isEmpty
                    ? 'Tap map or use button to select location'
                    : _address,
                style: TextStyle(
                    color: _address.isEmpty ? Colors.grey : Colors.black87,
                    fontSize: 13),
              ),
            ),
            TextButton.icon(
              onPressed: _getCurrentLocation,
              icon: _isLocating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.my_location, size: 18),
              label: const Text('My Location'),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final foodProvider = Provider.of<FoodPostProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Post Food')),
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
                    border: Border.all(
                        color: Colors.grey[300]!, style: BorderStyle.solid),
                    image: _image != null
                        ? (kIsWeb
                            ? DecorationImage(
                                image: NetworkImage(_image.path),
                                fit: BoxFit.cover)
                            : DecorationImage(
                                image: FileImage(_image as File),
                                fit: BoxFit.cover))
                        : null,
                  ),
                  child: _image == null
                      ? const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo_outlined,
                                size: 40, color: Colors.grey),
                            SizedBox(height: 8),
                            Text('Click to add photo',
                                style: TextStyle(color: Colors.grey)),
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

              // AI Analysis Button
              _isAnalyzing
                  ? const LoadingIndicator()
                  : CustomButton(
                      text: 'Analyze Ingredients with AI',
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
                    minTime: DateTime.now(),
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
                      const Icon(Icons.calendar_today,
                          size: 20, color: Colors.grey),
                      const SizedBox(width: 12),
                      Text(
                        _expirationDate == null
                            ? 'Select Expiration Date'
                            : DateFormat('MMM dd, yyyy - hh:mm a')
                                .format(_expirationDate!),
                        style: TextStyle(
                          color: _expirationDate == null
                              ? Colors.grey[600]
                              : Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              _buildMap(),

              const SizedBox(height: 24),

              // Ingredients Chips
              const Text('Ingredients',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _ingredients
                    .map((ing) => Chip(
                          label: Text(ing),
                          onDeleted: () => _removeIngredient(ing),
                          deleteIcon: const Icon(Icons.close, size: 16),
                        ))
                    .toList(),
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
                    icon: const Icon(Icons.add_circle,
                        color: AppColors.primary, size: 32),
                    onPressed: _addIngredient,
                  ),
                ],
              ),

              const SizedBox(height: 40),

              // Submit
              foodProvider.isLoading
                  ? const LoadingIndicator()
                  : CustomButton(
                      text: 'Post Food',
                      onPressed: _handleSubmit,
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
