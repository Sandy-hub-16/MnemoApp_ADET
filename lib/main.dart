import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'ui-layer/landing_page/landing_screen.dart';
import 'ui-layer/landing_page/app_theme.dart';
import 'ui-layer/auth/login_screen.dart';
import 'ui-layer/auth/register/register_step1_screen.dart';
import 'ui-layer/auth/register/register_step2_screen.dart';
import 'ui-layer/auth/register/register_step3_screen.dart';
import 'ui-layer/auth/register/verify_email_screen.dart';
import 'ui-layer/main_screens/deck/create_deck_screen.dart';
import 'ui-layer/main_screens/deck/edit_deck_screen.dart';
import 'ui-layer/main_screens/deck/deck_study_screen.dart';
import 'ui-layer/main_screens/main_shell.dart';
import 'ui-layer/main_screens/sub_screens/profile-personal-info_screen.dart';
import 'ui-layer/main_screens/sub_screens/settings_screen.dart';
import 'ui-layer/main_screens/deck/deck-quiz_screen.dart';
import 'ui-layer/main_screens/deck/deck-quiz_results_screen.dart';
import 'ui-layer/social/notification_screen.dart';
import 'ui-layer/social/shared_deck_detail_screen.dart';
import 'ui-layer/social/public_profile_screen.dart';
import 'ui-layer/social/social_feed_screen.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'business-layer/services/connectivity_service.dart';

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

  // Enable offline persistence for all Firestore data
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // Initialize connectivity monitoring
  ConnectivityService().initialize();

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
        return const VerifyEmailScreen();
      } else {
        return const MainShell();
      }
    }

    return const LandingScreen();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ROUTES — single source of truth. Add a new screen → add a case here.
// ─────────────────────────────────────────────────────────────────────────────

abstract final class AppRoutes {
  static const String main = '/main';
  static const String landing = '/';
  static const String signIn = '/sign-in';
  static const String signUp1 = '/sign-up/step-1';
  static const String signUp2 = '/sign-up/step-2';
  static const String signUp3 = '/sign-up/step-3';
  static const String verifyEmail = '/verify-email';
  static const String home = '/home';
  static const String profile = '/profile';
  static const String accountSettings = '/account-settings';
  static const String settings = '/settings';
  static const String decks = '/decks';
  static const String createDeck = '/create-deck';
  static const String editDeck = '/edit-deck';
  static const String study = '/study';
  static const String quiz = '/quiz';
  static const String quizResults = '/quiz-results';
  static const String progress = '/progress';
  // ── Social routes (wired fully in Task 14) ────────────────────────────────
  static const String discover = '/discover';
  static const String sharedDeckDetail = '/shared-deck-detail';
  static const String publicProfile = '/public-profile';
  static const String feed = '/feed';
  static const String notifications = '/notifications';
}

// ─────────────────────────────────────────────────────────────────────────────
// ROUTER — custom slide transition keeps the feel native & snappy.
// ─────────────────────────────────────────────────────────────────────────────

abstract final class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final Widget page = switch (settings.name) {
      AppRoutes.main => const MainShell(),
      AppRoutes.landing => const LandingScreen(),
      AppRoutes.signIn => const SignInScreen(),
      AppRoutes.signUp1 => const SignUpStep1Screen(),
      AppRoutes.signUp2 => const SignUpStep2Screen(),
      AppRoutes.signUp3 => const SignUpStep3Screen(),
      AppRoutes.verifyEmail => const VerifyEmailScreen(),
      AppRoutes.home => const MainShell(),
      AppRoutes.profile => const MainShell(initialIndex: 4),
      AppRoutes.accountSettings => const AccountSettingsScreen(),
      AppRoutes.settings => const SettingsScreen(),
      AppRoutes.decks => const MainShell(initialIndex: 1),
      AppRoutes.createDeck => const CreateDeckScreen(),
      AppRoutes.editDeck => EditDeckScreen(
          // ← NEW
          args: settings.arguments as EditDeckArgs,
        ),
      AppRoutes.study => const DeckStudyScreen(),
      AppRoutes.quiz => const QuizScreen(),
      AppRoutes.quizResults => const QuizResultsScreen(),
      AppRoutes.progress => const MainShell(initialIndex: 3),
      AppRoutes.notifications => const NotificationScreen(),
      AppRoutes.discover => const MainShell(initialIndex: 2),
      AppRoutes.sharedDeckDetail => const SharedDeckDetailScreen(),
      AppRoutes.publicProfile => const PublicProfileScreen(),
      AppRoutes.feed => const SocialFeedScreen(),
      _ => const MainShell(),
    };

    return PageRouteBuilder(
      settings: settings,
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, animation, __, child) {
        final curved =
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 220),
    );
  }
}
