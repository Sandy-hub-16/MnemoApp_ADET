import 'package:firebase_auth/firebase_auth.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  // final FirebaseFirestore _db = FirebaseFirestore.instance;

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
    try{
      UserCredential userCredential = 
        await _auth.createUserWithEmailAndPassword(
      email: email, 
      password: password
      );

      await userCredential.user!.sendEmailVerification();

      User? user = userCredential.user;

      // Keep the user signed in after sending the verification email so
      // the app can periodically `reload()` the `currentUser` and detect
      // when `emailVerified` flips to true. Previously we signed out here,
      // which made `currentUser` null and prevented the verify screen
      // from auto-detecting verification.
      return user;
    } on FirebaseAuthException catch(e) {
      if(e.code == 'email-already-in-use') {
        print("Email already registered. Try logging in instead.");
        return null;
      } else {
        print("Register Error: $e");
        return null;
      }
    } catch (e) {
      print("Register Error: $e");
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
    } catch(e) {
      print("Register Error: $e");
      return null;
    }
  }

  Future<User?> login(String email, String password) async {
    try {
      UserCredential userCredential =
          await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      return userCredential.user;
    } catch(e) {
      print("Login Error: $e");
      return null;
    }
  }

  Future<User?> signInWithGoogle() async {
    try {
      GoogleAuthProvider googleProvider = GoogleAuthProvider();

      UserCredential userCredential =
        await FirebaseAuth.instance.signInWithPopup(googleProvider);

        return userCredential.user;
    } catch(e) {
      // ignore: avoid_print
      print("Google Sign-in Error : $e");
      return null;
    }
  }

  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
  }
}