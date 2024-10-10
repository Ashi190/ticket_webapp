import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthhProvider with ChangeNotifier {
  bool _isLoggedIn = false;
  String? _email;
  String? _userName;
  String? _userRole;
  String? _Currentuser;
  String? _userId;
  String? get userId => _userId;

  String? get userName => _userName;
  String? get userRole => _userRole;
  String? get userEmail => _email;
  String? get Currentuser => _Currentuser;
  bool get isAuthenticated => _isLoggedIn;
  // Method to send OTP (in this case, a password reset link)
  Future<void> sendOtpToEmail(String email) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      print("Password reset email sent to $email");
    } on FirebaseAuthException catch (e) {
      print("Failed to send password reset email: $e");
      throw e; // You can handle error here or show message to the user
    }
  }

  Future<void> login(String email,String password,BuildContext context) async {
    _isLoggedIn = true;
    // _email = email;
    try {
      UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      print("User credentials $userCredential");
      if(userCredential !=null){

        Navigator.pushNamed(context, "/home");
      }
      // Navigate to dashboard on successful login
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

    await _saveLoginStatus();
    print('User logged in: $_isLoggedIn');
    notifyListeners();
  }

  Future<void> logout() async {
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
