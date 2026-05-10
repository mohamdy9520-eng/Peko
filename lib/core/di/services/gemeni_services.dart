import 'dart:convert';
import 'package:http/http.dart' as http;

class GeminiService {

  static const String apiKey = "YOUR_API_KEY";

  static Future<String> generatePlan(String prompt) async {

    final response = await http.post(
      Uri.parse(
        "https://generativelanguage.googleapis.com/v1/models/gemini-2.0-flash:generateContent?key=$apiKey",
      ),

      headers: {
        "Content-Type": "application/json",
      },

      body: jsonEncode({
        "contents": [
          {
            "parts": [
              {
                "text": prompt,
              }
            ]
          }
        ]
      }),
    );

    final data = jsonDecode(response.body);

    return data["candidates"][0]["content"]["parts"][0]["text"];
  }
}