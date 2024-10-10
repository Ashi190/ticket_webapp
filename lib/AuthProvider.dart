
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthhProvider with ChangeNotifier {
  bool _isLoggedIn = false;
  String? _email;

  String? get email => _email;
  bool get isAuthenticated => _isLoggedIn;

  Future<void> login(String email, String password, BuildContext context) async {
    try {
      UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // If login is successful, save the email and login status
      _isLoggedIn = true;
      _email = email;
      await _saveLoginStatus();

      // Navigate to home screen on successful login
      Navigator.pushNamed(context, "/home");
    } on FirebaseAuthException catch (e) {
      String message;
      if (e.code == 'user-not-found') {
        message = 'No user found for that email.';
      } else if (e.code == 'wrong-password') {
        message = 'Wrong password provided.';
      } else {
        message = 'Email not verified. Please register.';
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }

    notifyListeners();
  }

  Future<void> logout() async {
    await FirebaseAuth.instance.signOut();
    _isLoggedIn = false;
    _email = null;
    await _clearLoginStatus();
    notifyListeners();
  }

  Future<void> _saveLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', _isLoggedIn);
    if (_email != null) {
      await prefs.setString('email', _email!);
    }
  }

  Future<void> _clearLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('isLoggedIn');
    await prefs.remove('email');
  }

  Future<void> checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    _isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    _email = prefs.getString('email');
    notifyListeners();
  }
}