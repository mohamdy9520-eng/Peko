import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key});

  Future<void> _selectLanguage(
      BuildContext context,
      Locale locale,
      ) async {
    await context.setLocale(locale);

    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool(
      'language_selected',
      true,
    );

    await prefs.setString(
      'language',
      locale.languageCode,
    );

    if (context.mounted) {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Choose Language',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 30),

              ElevatedButton(
                onPressed: () => _selectLanguage(
                  context,
                  const Locale('en'),
                ),
                child: const Text('English'),
              ),

              const SizedBox(height: 16),

              ElevatedButton(
                onPressed: () => _selectLanguage(
                  context,
                  const Locale('ar'),
                ),
                child: const Text('العربية'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}