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
    return MaterialApp(title: 'Ridonova Captain Driver', debugShowCheckedModeBanner: false, theme: AppTheme.lightTheme, home: const SplashScreen());
  }
}

//  Ridonova@2026Driver
// #	Status Name (API / DB)	Driver Side Action / Meaning	Customer Mobile App UI
// 1	searching (ya pending)	Customer ne ride request ki hai. Nearby drivers ko popup request ja rahi hai.	Radar animation / "Looking for nearby drivers..."
// 2	accepted	Driver ne ride accept kar li hai aur pickup ki taraf nikal gaya hai.	Captain details (Name, Car, Rating) + 4-digit START OTP PIN display hota hai.
// 3	arrived (ya driver_arrived)	Driver pickup location par pahunch gaya hai aur usne "I HAVE ARRIVED" dabaya.	"Driver arrived at pickup location. Share OTP with driver."
// 4	in_progress (ya started)	Driver ne customer se 4-digit OTP le kar Verify & Start kar diya.	Live tracking start: "Heading to destination • Trip Active" (Aapke screenshot wali screen)
// 5	completed	Driver dropoff par pahunch kar "COMPLETE RIDE" dabata hai.	Screen update hokar "Trip Completed! 🎉" popup/receipt modal khulta hai aur rating aati hai.
// 6	cancelled	Rider ya Driver kisi wajah se ride cancel karta hai.	"Ride Cancelled" notification aati hai aur home map par reset ho jata hai.