import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class AIService {
  late final GenerativeModel _model;
  static const String _modelName = 'gemini-3-flash-preview';

  AIService() {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('GEMINI_API_KEY is not set in .env file');
    }
    _model = GenerativeModel(
      model: _modelName,
      apiKey: apiKey.trim(),
    );
  }

  Future<List<String>> detectIngredientsFromImage(dynamic imageFile) async {
    try {
      final imageBytes = await imageFile.readAsBytes();
      final content = [
        Content.multi([
          TextPart(
              'Analyze this image. First, determine if it is a clear, identifiable image of food. If it is NOT food, or if it is too blurry or unclear to identify, return "INVALID_IMAGE". If it is a valid food image, list all visible ingredients. Return ONLY "INVALID_IMAGE" or a comma-separated list of ingredient names, nothing else. Be specific and detailed.'),
          DataPart('image/jpeg', imageBytes),
        ])
      ];

      final response = await _model.generateContent(content);
      final String? text = response.text?.trim();

      if (text == null || text.isEmpty) {
        throw Exception('AI returned empty response');
      }

      if (text.contains('INVALID_IMAGE')) {
        throw Exception('Invalid food image');
      }

      final List<String> ingredients = text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      if (ingredients.isEmpty) {
        throw Exception('Invalid food image');
      }

      return ingredients;
    } catch (e) {
      if (e.toString().contains('API_KEY')) {
        throw Exception('Invalid or missing API Key');
      }
      if (e.toString().contains('Invalid food image')) {
        throw Exception('Invalid food image');
      }
      throw Exception('Image analysis failed');
    }
  }
}
