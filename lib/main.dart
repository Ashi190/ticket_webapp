import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:ticket_ui_test/DashboardScreen.dart';
import 'AuthProvider.dart';
import 'HomeScreen.dart';
import 'SignUpScreen.dart';
import 'LoginScreen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: "AIzaSyA4KXgcaTo15NnyUQVpEPam2v4BiVJsTTY",
        authDomain: "ticket-5ced3.firebaseapp.com",
        projectId: "ticket-5ced3",
        storageBucket: "ticket-5ced3.appspot.com",
        messagingSenderId: "103611207453",
        appId: "1:103611207453:web:920dabe72d60be13115bf4",
        measurementId: "G-J7JY6M970S",
      ),
    );
  } else {
    await Firebase.initializeApp();
  }
 // final authProvider = AuthProvider();
 // await authProvider.checkLoginStatus();

  runApp(
    ChangeNotifierProvider(
      create: (context) => AuthhProvider(),
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
   final authProvider = Provider.of<AuthhProvider>(context);
    return MaterialApp(
      title: 'Ticket App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
     initialRoute: authProvider.isAuthenticated ? '/home' : '/login',
      routes: <String, WidgetBuilder>{
        '/': (context) => StreamBuilder(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return CircularProgressIndicator(); // Or any loading indicator
            } else if (snapshot.hasData) {
              // User is authenticated
              return HomeScreen();
            } else {
              // User is not authenticated
              return LoginScreen();
            }
          },
        ),
        '/login': (context) => LoginScreen(),
        '/signup': (context) => SignUpScreen(),
        '/home': (context) => HomeScreen(),
      },
    );
  }
}
// New screen to handle permission checks
/*class PermissionCheckScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Permission Test')),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            await _checkPermission();
            // Navigate to the appropriate screen based on authentication status
            final authProvider = Provider.of<AuthhProvider>(context, listen: false);
            if (authProvider.isAuthenticated) {
              Navigator.of(context).pushReplacementNamed('/home');
            } else {
              Navigator.of(context).pushReplacementNamed('/login');
            }
          },
          child: Text('Check Storage Permission'),
        ),
      ),
    );
  }

  Future<void> _checkPermission() async {
    var status = await Permission.storage.request();
    if (status.isGranted) {
      print('Storage permission granted');
    } else {
      print('Storage permission denied');
    }
  }
}*/
