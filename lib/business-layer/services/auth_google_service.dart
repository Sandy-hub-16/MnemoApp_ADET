import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'account_deletion_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final AccountDeletionService _deletionService = AccountDeletionService();

  Future<void> sendVerificationEmail() async {
    final user = FirebaseAuth.instance.currentUser;
    await user?.sendEmailVerification();
  }

  // Thrown when an email is still inside its 7-day post-deletion cooldown.
  // Callers should catch this specifically and show e.message to the user.
  Future<User?> registerWithDetails({
    required String email,
    required String password,
    required String fullName,
    required String username,
    required int age,
    required String country,
    required String educationLevel,
  }) async {
    // ── Cooldown check ────────────────────────────────────────────────────
    // NOTE: this is a client-side convenience check against the
    // `deletedAccounts` Firestore ledger. It gives a fast, friendly error
    // message, but it is NOT a hard security boundary — see the warning
    // at the top of account_deletion_service.dart. For airtight enforcement,
    // pair this with an Auth Blocking Function (beforeCreate trigger).
    final cooldownMessage = await _deletionService.checkEmailCooldown(email);
    if (cooldownMessage != null) {
      throw AccountDeletionException(cooldownMessage, code: 'email-cooldown');
    }

    UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email, password: password);

    final user = userCredential.user;

    if (user == null) return null;

    await user.sendEmailVerification();

    // Create Firestore Profile
    await _db.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'email': email,
      'fullName': fullName,
      'username': username,
      'age': age,
      'country': country,
      'provider': 'email',
      'emailVerified': false,
      'createdAt': FieldValue.serverTimestamp(),
      'educationLevel': educationLevel,
      'reminderEnabled': false,
      'reminderHourUTC': 1, // (default 9AM PH = UTC+8 → 1 UTC)
    });

    return user;
  }

  Future<User?> register(String email, String password) async {
    try {
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      return userCredential.user;
    } catch (e) {
      print("Register Error: $e");
      return null;
    }
  }

  // ── login ────────────────────────────────────────────────────────────────
  // Throws FirebaseAuthException on failure so callers can inspect the
  // error code and show a precise message (wrong-password, user-not-found,
  // invalid-email, too-many-requests, etc.).
  Future<User?> login(String email, String password) async {
    final UserCredential credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return credential.user;
  }

  Future<User?> signInWithGoogle() async {
    try {
      GoogleAuthProvider googleProvider = GoogleAuthProvider();

      // Force Google's account chooser to show every time instead of
      // silently reusing whatever Google session is still active in the
      // browser. Without this, signing out of Firebase only clears our
      // own session — the browser's Google login cookie is untouched —
      // so the next signInWithPopup() call auto-picks the previous
      // account instead of letting the user choose/switch accounts.
      googleProvider.setCustomParameters({'prompt': 'select_account'});

      UserCredential userCredential =
          await FirebaseAuth.instance.signInWithPopup(googleProvider);

      final user = userCredential.user;

      if (user == null) return null;

      // 🔍 Check if user already exists in Firestore
      final userDoc = await _db.collection('users').doc(user.uid).get();

      if (!userDoc.exists) {
        // ── Cooldown check (new Google users only) ─────────────────────────
        // Google's popup already created the Auth user by this point, so if
        // the email is in cooldown we have to roll that back: delete the
        // freshly-created Auth user and sign out, then surface the error.
        // Same caveat as the email path — this is a UX check, not a hard
        // security boundary. Pair with an Auth Blocking Function for that.
        final cooldownMessage =
            await _deletionService.checkEmailCooldown(user.email ?? '');
        if (cooldownMessage != null) {
          await user.delete();
          throw AccountDeletionException(cooldownMessage,
              code: 'email-cooldown');
        }

        // 🆕 First time login → create document
        await _db.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'email': user.email,
          'fullName': user.displayName ?? "",
          'username': user.email?.split('@')[0] ?? "",
          'age': null,
          'country': "",
          'photoUrl': user.photoURL,
          'provider': 'google',
          'emailVerified': true, // Google emails are already verified
          'createdAt': FieldValue.serverTimestamp(),
          'educationLevel': 'general',
          'reminderEnabled': false,
          'reminderHourUTC': 1,
        });
      } else {
        // update existing user (if needed)
        await _db.collection('users').doc(user.uid).update({
          'lastLogin': FieldValue.serverTimestamp(),
        });
      }

      return user;
    } on AccountDeletionException {
      rethrow;
    } catch (e) {
      print("Google Sign-in Error : $e");
      return null;
    }
  }

  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
  }
}
