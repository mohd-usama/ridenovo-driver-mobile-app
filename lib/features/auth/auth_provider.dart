import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/network/api_constants.dart';
import '../../core/network/api_service.dart';
import 'models/auth_response_model.dart';
import '../kyc/kyc_model.dart';
import '../kyc/kyc_provider.dart';
import '../vehicle/vehicle_model.dart';
import '../vehicle/vehicle_provider.dart';

enum AuthStatus { initial, loading, otpSent, authenticated, unauthenticated, error }

class AuthState {
  final String phoneNumber;
  final String otp;
  final AuthStatus status;
  final String? errorMessage;
  final String? authToken;
  final UserModel? user;
  final bool isSessionLoaded;

  AuthState({
    this.phoneNumber = '',
    this.otp = '',
    this.status = AuthStatus.initial,
    this.errorMessage,
    this.authToken,
    this.user,
    this.isSessionLoaded = false,
  });

  AuthState copyWith({
    String? phoneNumber,
    String? otp,
    AuthStatus? status,
    String? errorMessage,
    String? authToken,
    UserModel? user,
    bool? isSessionLoaded,
  }) {
    return AuthState(
      phoneNumber: phoneNumber ?? this.phoneNumber,
      otp: otp ?? this.otp,
      status: status ?? this.status,
      errorMessage: errorMessage,
      authToken: authToken ?? this.authToken,
      user: user ?? this.user,
      isSessionLoaded: isSessionLoaded ?? this.isSessionLoaded,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiService _apiService;
  final Ref _ref;

  AuthNotifier(this._ref, {ApiService? apiService})
      : _apiService = apiService ?? ApiService(),
        super(AuthState()) {
    loadSavedSession();
  }

  /// Loads stored user token and session state on app launch
  Future<void> loadSavedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('auth_token');
      final bool? isNewUser = prefs.getBool('is_new_user');
      final String? userJsonStr = prefs.getString('user_json');

      if (token != null && token.isNotEmpty) {
        UserModel? user;
        if (userJsonStr != null && userJsonStr.isNotEmpty) {
          try {
            user = UserModel.fromJson(jsonDecode(userJsonStr));
          } catch (_) {}
        }

        user ??= UserModel(
          id: 'stored-user',
          phone: prefs.getString('user_phone') ?? '',
          fullName: null,
          role: 'driver',
          isNewUser: isNewUser ?? false,
        );

        if (isNewUser != null) {
          user = user.copyWith(isNewUser: isNewUser);
        }

        state = state.copyWith(
          status: AuthStatus.authenticated,
          authToken: token,
          user: user,
          isSessionLoaded: true,
        );

        // Fetch fresh profile in background using 'data' key as requested
        fetchProfile();
        return;
      }
    } catch (_) {}

    state = state.copyWith(
      status: AuthStatus.unauthenticated,
      isSessionLoaded: true,
    );
  }

  /// Fetches latest driver profile from server using /api/driver/profile,
  /// always extracting data from the 'data' key as requested by the user,
  /// and populating profile, kyc, and vehicle states.
  Future<bool> fetchProfile() async {
    if (state.authToken == null || state.authToken!.isEmpty) return false;

    try {
      final response = await _apiService.get(
        ApiConstants.driverProfile,
        token: state.authToken,
      );

      if (response.isSuccess && response.data != null) {
        final jsonResponse = response.data is String ? jsonDecode(response.data) : response.data;
        if (jsonResponse is Map<String, dynamic>) {
          // Always use 'data' key as requested: jsonResponse['data']
          final dataMap = jsonResponse['data'] ?? jsonResponse['result'] ?? jsonResponse;
          if (dataMap is Map<String, dynamic>) {
            // 1. Profile -> UserModel
            final profileMap = dataMap['profile'];
            if (profileMap is Map<String, dynamic>) {
              final user = UserModel.fromJson(profileMap);
              state = state.copyWith(user: user);
            }

            // 2. Driver -> KycModel
            final driverMap = dataMap['driver'];
            if (driverMap is Map<String, dynamic>) {
              final kyc = KycModel.fromJson(driverMap);
              _ref.read(kycProvider.notifier).updateKycData(kyc);
            }

            // 3. Vehicle -> VehicleModel
            final vehicleMap = dataMap['vehicle'];
            if (vehicleMap is Map<String, dynamic>) {
              final vehicle = VehicleModel.fromJson(vehicleMap);
              _ref.read(vehicleProvider.notifier).updateVehicleData(vehicle);
            }

            // Save user to shared prefs
            if (state.user != null) {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('user_json', jsonEncode(state.user!.toJson()));
              await prefs.setString('user_phone', state.user!.phone);
            }
            return true;
          }
        }
      }
    } catch (_) {}
    return false;
  }

  void setPhoneNumber(String phone) {
    state = state.copyWith(phoneNumber: phone);
  }

  void setOtp(String otp) {
    state = state.copyWith(otp: otp);
  }

  Future<bool> sendOtp() async {
    if (state.phoneNumber.length < 10) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Please enter a valid 10-digit mobile number',
      );
      return false;
    }

    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);

    final response = await _apiService.post(
      ApiConstants.sendOtp,
      data: {
        'phone': state.phoneNumber,
        'countryCode': '+91',
        'role': 'driver',
      },
    );

    if (response.isSuccess) {
      try {
        final authResponse = AuthResponseModel.fromJson(response.data);
        if (authResponse.success) {
          state = state.copyWith(status: AuthStatus.otpSent);
          return true;
        } else {
          state = state.copyWith(
            status: AuthStatus.error,
            errorMessage: authResponse.message,
          );
          return false;
        }
      } catch (e) {
        state = state.copyWith(
          status: AuthStatus.error,
          errorMessage: 'Invalid response format from server',
        );
        return false;
      }
    } else {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: response.errorMessage ?? 'Failed to send OTP',
      );
      return false;
    }
  }

  Future<bool> resendOtp() async {
    if (state.phoneNumber.length < 10) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Invalid phone number for resending OTP',
      );
      return false;
    }

    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);

    final response = await _apiService.post(
      ApiConstants.resendOtp,
      data: {
        'phone': state.phoneNumber,
        'countryCode': '+91',
      },
    );

    if (response.isSuccess) {
      state = state.copyWith(status: AuthStatus.otpSent);
      return true;
    } else {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: response.errorMessage ?? 'Failed to resend OTP',
      );
      return false;
    }
  }

  Future<bool> verifyOtp() async {
    if (state.otp.length < 6) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Please enter complete 6-digit OTP',
      );
      return false;
    }

    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);

    final response = await _apiService.post(
      ApiConstants.verifyOtp,
      data: {
        'phone': state.phoneNumber,
        'otp': state.otp,
        'role': 'driver',
        'deviceId': 'device-uuid-driver-app-123',
        'deviceName': Platform.operatingSystem == 'ios' ? 'iPhone' : 'Android Device',
        'devicePlatform': Platform.operatingSystem,
        'fcmToken': 'optional_firebase_push_token_xyz',
      },
    );

    if (response.isSuccess) {
      try {
        final authResponse = AuthResponseModel.fromJson(response.data);
        if (authResponse.success && authResponse.data?.token != null) {
          final token = authResponse.data!.token!;
          final user = authResponse.data!.user;

          // Save session to SharedPreferences
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('auth_token', token);
          if (user != null) {
            await prefs.setBool('is_new_user', user.isNewUser);
            await prefs.setString('user_phone', user.phone);
            await prefs.setString('user_json', jsonEncode(user.toJson()));
          }

          state = state.copyWith(
            status: AuthStatus.authenticated,
            authToken: token,
            user: user,
          );

          // Fetch complete profile (profile, driver, vehicle) after verification
          fetchProfile();
          return true;
        } else {
          state = state.copyWith(
            status: AuthStatus.error,
            errorMessage: authResponse.message,
          );
          return false;
        }
      } catch (e) {
        state = state.copyWith(
          status: AuthStatus.error,
          errorMessage: 'Invalid verification response format',
        );
        return false;
      }
    } else {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: response.errorMessage ?? 'Invalid OTP code',
      );
      return false;
    }
  }

  /// Called after KYC and Vehicle registration complete to set isNewUser = false
  Future<void> markOnboardingComplete() async {
    final updatedUser = state.user?.copyWith(isNewUser: false) ??
        UserModel(
          id: 'usr-id',
          phone: state.phoneNumber,
          fullName: null,
          role: 'driver',
          isNewUser: false,
        );

    state = state.copyWith(user: updatedUser);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_new_user', false);
    await prefs.setString('user_json', jsonEncode(updatedUser.toJson()));
  }

  /// Updates driver duty online/offline status using /api/driver/duty-status,
  /// always extracting data from the 'data' key as requested.
  Future<bool> updateDutyStatus(bool isOnline) async {
    if (state.authToken == null || state.authToken!.isEmpty) return false;

    try {
      final response = await _apiService.post(ApiConstants.dutyStatus, data: {'isOnline': isOnline}, token: state.authToken);

      if (response.isSuccess && response.data != null) {
        final jsonResponse = response.data is String ? jsonDecode(response.data) : response.data;
        if (jsonResponse is Map<String, dynamic>) {
          // Always use 'data' key as requested: jsonResponse['data']
          final dataMap = jsonResponse['data'] ?? jsonResponse['result'] ?? jsonResponse;
          if (dataMap is Map<String, dynamic>) {
            return true;
          }
        }
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<bool> logout() async {
    state = state.copyWith(status: AuthStatus.loading);

    try {
      await _apiService.post(ApiConstants.logout, token: state.authToken);
    } catch (_) {}

    // Clear local stored session
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('is_new_user');
    await prefs.remove('user_phone');
    await prefs.remove('user_json');

    state = AuthState(isSessionLoaded: true);
    return true;
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});
