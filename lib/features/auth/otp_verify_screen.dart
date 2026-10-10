import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pinput/pinput.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/app_flushbar.dart';
import '../home/screens/main_navigation_screen.dart';
import '../kyc/kyc_details_screen.dart';
import 'auth_provider.dart';

class OtpVerifyScreen extends ConsumerStatefulWidget {
  const OtpVerifyScreen({super.key});

  @override
  ConsumerState<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends ConsumerState<OtpVerifyScreen> {
  final TextEditingController _pinController = TextEditingController();
  final FocusNode _pinFocusNode = FocusNode();

  Timer? _timer;
  int _secondsRemaining = 30;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    setState(() {
      _secondsRemaining = 30;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pinController.dispose();
    _pinFocusNode.dispose();
    super.dispose();
  }

  void _onVerify() async {
    FocusScope.of(context).unfocus();
    final otp = _pinController.text.trim();
    final authNotifier = ref.read(authProvider.notifier);
    authNotifier.setOtp(otp);

    final success = await authNotifier.verifyOtp();
    if (success && mounted) {
      final authState = ref.read(authProvider);
      final bool isNewUser = authState.user?.isNewUser ?? true;

      AppFlushbar.success(context, title: 'OTP Verified', message: 'Welcome to Ridonova!');

      final Widget nextScreen = isNewUser ? const KycDetailsScreen() : const MainNavigationScreen();

      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => nextScreen), (route) => false);
    } else if (mounted) {
      AppFlushbar.error(context, title: 'Verification Failed', message: 'Invalid OTP code. Please enter valid code.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    // Custom Pinput themes
    final defaultPinTheme = PinTheme(
      width: 48,
      height: 56,
      textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration!.copyWith(
        border: Border.all(color: AppColors.primary, width: 2),
        boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.2), blurRadius: 8)],
      ),
    );

    final submittedPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration!.copyWith(
        color: const Color(0xFFF8FAFC),
        border: Border.all(color: AppColors.primary, width: 1.5),
      ),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: AppColors.secondary,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('OTP Verification'),
          backgroundColor: AppColors.secondary,
          elevation: 0,
          leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20), onPressed: () => Navigator.pop(context)),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Icon Badge Header
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.25), width: 2),
                    ),
                    child: const Icon(Icons.phonelink_ring_rounded, color: AppColors.primary, size: 42),
                  ),
                ),

                const SizedBox(height: 24),

                const Center(
                  child: Text(
                    'Verify Your Mobile Number',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary, letterSpacing: -0.3),
                  ),
                ),

                const SizedBox(height: 8),

                // Phone number badge with edit chip
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8)],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Code sent to ', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                        Text(
                          '+91 ${authState.phoneNumber}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.12), shape: BoxShape.circle),
                            child: const Icon(Icons.edit_rounded, size: 14, color: AppColors.primary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 36),

                // Pinput 6-digit PIN Widget
                Center(
                  child: Pinput(
                    length: 6,
                    controller: _pinController,
                    focusNode: _pinFocusNode,
                    defaultPinTheme: defaultPinTheme,
                    focusedPinTheme: focusedPinTheme,
                    submittedPinTheme: submittedPinTheme,
                    showCursor: true,
                    onChanged: (value) {
                      ref.read(authProvider.notifier).setOtp(value);
                    },
                    onCompleted: (pin) {
                      _onVerify();
                    },
                  ),
                ),

                if (authState.status == AuthStatus.error && authState.errorMessage != null) ...[
                  const SizedBox(height: 14),
                  Center(
                    child: Text(
                      authState.errorMessage!,
                      style: const TextStyle(color: AppColors.error, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],

                const SizedBox(height: 32),

                // Resend Code timer or trigger
                Center(
                  child: _secondsRemaining > 0
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.timer_outlined, size: 16, color: AppColors.textSecondary),
                            const SizedBox(width: 6),
                            Text(
                              'Resend code in 00:${_secondsRemaining.toString().padLeft(2, '0')}',
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ],
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text("Didn't receive code? ", style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                            GestureDetector(
                              onTap: () async {
                                await ref.read(authProvider.notifier).resendOtp();
                                _startTimer();
                                if (context.mounted) {
                                  AppFlushbar.info(context, title: 'OTP Resent', message: 'A new verification code has been sent.');
                                }
                              },
                              child: const Text(
                                'Resend OTP',
                                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                ),

                const SizedBox(height: 48),

                // Verify Primary Button
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6))],
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: authState.status == AuthStatus.loading ? null : _onVerify,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: authState.status == AuthStatus.loading
                          ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('VERIFY & CONTINUE', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                                SizedBox(width: 8),
                                Icon(Icons.check_circle_outline_rounded, size: 20),
                              ],
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
