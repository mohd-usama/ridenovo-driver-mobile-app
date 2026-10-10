import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import 'auth_provider.dart';
import 'phone_login_screen.dart';
import '../home/screens/main_navigation_screen.dart';
import '../kyc/kyc_details_screen.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));

    _scaleAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _controller.forward();

    _initSplashFlow();
  }

  Future<void> _initSplashFlow() async {
    final startTime = DateTime.now();

    // Wait until SharedPreferences session loading completes in AuthNotifier
    while (mounted) {
      final authState = ref.read(authProvider);
      if (authState.isSessionLoaded) {
        break;
      }
      await Future.delayed(const Duration(milliseconds: 100));
    }

    if (!mounted) return;

    // Ensure at least 2 seconds elapsed for splash branding animation
    final elapsed = DateTime.now().difference(startTime);
    const minDuration = Duration(seconds: 2);
    if (elapsed < minDuration) {
      await Future.delayed(minDuration - elapsed);
    }

    if (!mounted) return;

    final authState = ref.read(authProvider);
    Widget nextScreen = const PhoneLoginScreen();

    if (authState.status == AuthStatus.authenticated &&
        authState.authToken != null &&
        authState.authToken!.isNotEmpty) {
      final bool isNewUser = authState.user?.isNewUser ?? false;
      nextScreen = isNewUser ? const KycDetailsScreen() : const MainNavigationScreen();
    }

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => nextScreen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.secondary, Color(0xFF0A2550), Color(0xFF030D1F)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              // Decorative background glow circles
              Positioned(
                top: -100,
                right: -100,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.primary.withValues(alpha: 0.15)),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                    child: Container(color: Colors.transparent),
                  ),
                ),
              ),
              Positioned(
                bottom: -80,
                left: -80,
                child: Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.secondary.withValues(alpha: 0.15)),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
                    child: Container(color: Colors.transparent),
                  ),
                ),
              ),
              Center(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Logo Container with Glow & Gradient
                        Container(
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.primary, AppColors.primaryDark],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(32),
                            boxShadow: [
                              BoxShadow(color: AppColors.primary.withValues(alpha: 0.45), blurRadius: 30, offset: const Offset(0, 10)),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.asset('assets/images/app-logo.png', width: 80, height: 80, fit: BoxFit.contain),
                          ),
                        ),
                        const SizedBox(height: 28),
                        const Text(
                          'Ridonova',
                          style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: 1.0),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.4), width: 1),
                          ),
                          child: const Text(
                            'CAPTAIN PARTNER',
                            style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2.0),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Bottom loader / branding indicator
              Positioned(
                bottom: 50,
                left: 0,
                right: 0,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    children: [
                      SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary.withValues(alpha: 0.8)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Secure Captain Portal',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12, letterSpacing: 0.5),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
