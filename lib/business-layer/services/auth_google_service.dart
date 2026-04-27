import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> sendVerificationEmail() async {
    final user = FirebaseAuth.instance.currentUser;
    await user?.sendEmailVerification();
  }

  Future<User?> registerWithDetails({
    required String email,
    required String password,
    required String fullName,
    required String username,
    required int age,
    required String country,
  }) async {
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

      UserCredential userCredential =
          await FirebaseAuth.instance.signInWithPopup(googleProvider);

      final user = userCredential.user;

      if (user == null) return null;

      // 🔍 Check if user already exists in Firestore
      final userDoc = await _db.collection('users').doc(user.uid).get();

      if (!userDoc.exists) {
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
        });
      } else {
        // update existing user (if needed)
        await _db.collection('users').doc(user.uid).update({
          'lastLogin': FieldValue.serverTimestamp(),
        });
      }

      return user;
    } catch (e) {
      print("Google Sign-in Error : $e");
      return null;
    }
  }

  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
  }
}

