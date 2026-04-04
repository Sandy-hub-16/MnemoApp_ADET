import 'package:flutter/material.dart';
import 'landing_page/landing_screen.dart';
import 'landing_page/app_theme.dart';
import 'auth/sign_in_screen.dart';
import 'auth/sign_up_step1_screen.dart';
import 'auth/sign_up_step2_screen.dart';
import 'auth/sign_up_step3_screen.dart';

void main() => runApp(const MnemoApp());

class MnemoApp extends StatelessWidget {
  const MnemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MnemoApp',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      initialRoute: AppRoutes.landing,
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
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
