import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../config/routes.dart';
import '../utils/responsive.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // User is signed in
      Navigator.pushReplacementNamed(context, AppRoutes.home);
    } else {
      // No user is signed in
      Navigator.pushReplacementNamed(context, AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo change this to assets/images/logo.png
            Image.asset(
              'assets/images/logo.png',
              width: Responsive.isDesktop(context) ? 180 : 140,
              height: Responsive.isDesktop(context) ? 180 : 140,
            ),
            const SizedBox(height: 24),
            Text(
              'ESSU',
              style: TextStyle(
                fontSize: Responsive.isDesktop(context) ? 40 : 32,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Alumni Tracker System',
              style: TextStyle(
                fontSize: Responsive.isDesktop(context) ? 24 : 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

