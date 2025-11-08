import 'dart:async';
import 'package:flutter/material.dart';
import 'create_account_screen.dart'; // Update this import path based on where you place the file

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // 🎬 Animation setup
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 2));
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
    _controller.forward();

    // ⏱ Navigate to CreateAccountScreen after 4 seconds
    Timer(const Duration(seconds: 4), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const CreateAccountScreen()),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 🪙 App Logo
              Image.asset(
                'assets/images/logo.png',
                height: 130,
              ),
              const SizedBox(height: 20),

              // 💰 App Name
              const Text(
                'DollarZoneMining',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E6FFF),
                  letterSpacing: 1.2,
                ),
              ),

              const SizedBox(height: 10),

              // 🌀 Loading animation
              const CircularProgressIndicator(
                color: Color(0xFF1E6FFF),
                strokeWidth: 2.5,
              ),
            ],
          ),
        ),
      ),
    );
  }
}