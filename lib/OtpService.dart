import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OtpService {
  // Cloud Function to send OTP
  final HttpsCallable sendOtpCallable = FirebaseFunctions.instance.httpsCallable('sendOtpToEmail');

  // Call the Cloud Function to send OTP
  Future<void> sendOtp(String email) async {
    try {
      final result = await sendOtpCallable.call({'email': email});
      print('OTP sent: ${result.data['otp']}'); // Only for debugging
    } catch (e) {
      print('Failed to send OTP: $e');
    }
  }

  // Method to reset password (can be triggered after OTP verification)
  Future<void> resetPassword(String email, String newPassword) async {
    User? user = FirebaseAuth.instance.currentUser;

    try {
      await user?.updatePassword(newPassword);
      print('Password reset successful');
    } catch (e) {
      print('Password reset failed: $e');
    }
  }
}
