import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/splash_screen.dart';

void main() {
  runApp(const ProviderScope(child: RidonovaDriverApp()));
}

class RidonovaDriverApp extends StatelessWidget {
  const RidonovaDriverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(title: 'Ridonova Captain', debugShowCheckedModeBanner: false, theme: AppTheme.lightTheme, home: const SplashScreen());
  }
}
