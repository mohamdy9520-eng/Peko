import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  static String get openRouterApiKey =>
      dotenv.env['OPENROUTER_API_KEY'] ?? '';

  static String get groqkey =>
      dotenv.env['GROQ_API_KEY'] ?? '';

  static Future<void> load() async {
    await dotenv.load(fileName: ".env");
  }
}