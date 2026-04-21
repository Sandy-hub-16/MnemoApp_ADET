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
    try {
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);

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
        'emailVerified': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return user;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        print("Email already registered. Try logging in instead.");
        return null;
      } else {
        print("FirebaseAuth Error: ${e.code} - ${e.message}");
        return null;
      }
    } catch (e) {
      print("Unknown Error: $e");
      return null;
    }
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

      return userCredential.user;
    } catch (e) {
      // ignore: avoid_print
      print("Google Sign-in Error : $e");
      return null;
    }
  }

  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
  }
}
