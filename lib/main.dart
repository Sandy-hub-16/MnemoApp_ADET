import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'landing_page/landing_screen.dart';
import 'landing_page/app_theme.dart';
import 'auth/login_screen.dart';
import 'auth/register/register_step1_screen.dart';
import 'auth/register/register_step2_screen.dart';
import 'auth/register/register_step3_screen.dart';
import 'auth/register/verify_email_screen.dart';
import 'profile/profile_screen.dart';           
import 'profile/account_settings_screen.dart';  

import 'package:firebase_core/firebase_core.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: "assets/.env");

  await Firebase.initializeApp(
    options: FirebaseOptions(
      apiKey: dotenv.env['FIREBASE_API_KEY']!,
      authDomain: dotenv.env['FIREBASE_AUTH_DOMAIN']!,
      projectId: dotenv.env['FIREBASE_PROJECT_ID']!,
      storageBucket: dotenv.env['FIREBASE_STORAGE_BUCKET']!,
      messagingSenderId: dotenv.env['FIREBASE_MESSAGING_SENDER_ID']!,
      appId: dotenv.env['FIREBASE_APP_ID']!,
    ),
  );
  runApp(const MnemoApp());
}

class MnemoApp extends StatelessWidget {
  const MnemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MnemoApp',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const AuthGate(),
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      if (!user.emailVerified) {
        return const VerifyEmailScreen(); // redirect here
      } else {
        return const LandingScreen(); // or your Home screen
      }
    }

    return const LandingScreen(); // not logged in
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ROUTES — single source of truth. Add a new screen → add a case here.
// ─────────────────────────────────────────────────────────────────────────────

abstract final class AppRoutes {
  static const String landing = '/';
  static const String signIn = '/sign-in';
  static const String signUp1 = '/sign-up/step-1';
  static const String signUp2 = '/sign-up/step-2';
  static const String signUp3 = '/sign-up/step-3';
  static const String verifyEmail = '/verify-email';
  static const String profile = '/profile';
  static const String accountSettings = '/account-settings';
}

// ─────────────────────────────────────────────────────────────────────────────
// ROUTER — custom slide transition keeps the feel native & snappy.
// ─────────────────────────────────────────────────────────────────────────────

abstract final class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final Widget page = switch (settings.name) {
      AppRoutes.landing => const LandingScreen(),
      AppRoutes.signIn => const SignInScreen(),
      AppRoutes.signUp1 => const SignUpStep1Screen(),
      AppRoutes.signUp2 => const SignUpStep2Screen(),
      AppRoutes.signUp3 => const SignUpStep3Screen(),
      AppRoutes.verifyEmail => const VerifyEmailScreen(),
      AppRoutes.profile => const ProfileScreen(),
      AppRoutes.accountSettings => const AccountSettingsScreen(),
      _ => const LandingScreen(),
    };

    return PageRouteBuilder(
      settings: settings,
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, animation, __, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          ),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 280),
    );
  }
}