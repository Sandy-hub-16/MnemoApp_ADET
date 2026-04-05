import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

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

      User? user = userCredential.user;

      if (user != null) {
  
        await _db.collection('users').doc(user.uid).set({
          'fullName': fullName,
          'username': username,
          'age': age,
          'country': country,
          'email': email,
          'createdAt': DateTime.now(),
        });
      }

      return user;
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