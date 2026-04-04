import 'package:flutter/material.dart';
import 'landing_page/landing_screen.dart';
import 'landing_page/app_theme.dart';

void main() => runApp(const MnemoApp());

class MnemoApp extends StatelessWidget {
  const MnemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MnemoApp',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const LandingScreen(),
    );
  }
}