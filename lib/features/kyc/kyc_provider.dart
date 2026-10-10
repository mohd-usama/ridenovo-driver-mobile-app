import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_constants.dart';
import '../../core/network/api_service.dart';
import 'kyc_model.dart';

enum KycStatus { initial, loading, success, error }

class KycState {
  final KycModel kycData;
  final KycStatus status;
  final String? errorMessage;

  KycState({required this.kycData, this.status = KycStatus.initial, this.errorMessage});

  KycState copyWith({KycModel? kycData, KycStatus? status, String? errorMessage}) {
    return KycState(kycData: kycData ?? this.kycData, status: status ?? this.status, errorMessage: errorMessage);
  }
}

class KycNotifier extends StateNotifier<KycState> {
  final ApiService _apiService;

  KycNotifier({ApiService? apiService}) : _apiService = apiService ?? ApiService(), super(KycState(kycData: KycModel()));

  void updateKycData(KycModel newData) {
    state = state.copyWith(kycData: newData);
  }

  Future<bool> submitKycDetails({String? token}) async {
    final kyc = state.kycData;

    if (kyc.fullName.isEmpty) {
      state = state.copyWith(status: KycStatus.error, errorMessage: 'Please enter Full Name');
      return false;
    }

    if (kyc.email.isEmpty || !kyc.email.contains('@')) {
      state = state.copyWith(status: KycStatus.error, errorMessage: 'Please enter a valid Email address');
      return false;
    }

    if (kyc.mobileNumber.isEmpty || kyc.mobileNumber.length < 10) {
      state = state.copyWith(status: KycStatus.error, errorMessage: 'Please enter a valid Mobile Number');
      return false;
    }

    if (kyc.aadharNumber.isEmpty || kyc.aadharNumber.length < 12) {
      state = state.copyWith(status: KycStatus.error, errorMessage: 'Please enter a valid 12-digit Aadhar Number');
      return false;
    }

    if (kyc.panNumber.isEmpty || kyc.panNumber.length < 10) {
      state = state.copyWith(status: KycStatus.error, errorMessage: 'Please enter a valid 10-character PAN Number');
      return false;
    }

    if (kyc.drivingLicenseNumber.isEmpty) {
      state = state.copyWith(status: KycStatus.error, errorMessage: 'Please enter Driving License Number');
      return false;
    }

    if (kyc.bankAccountNumber.isEmpty || kyc.bankIfscCode.isEmpty) {
      state = state.copyWith(status: KycStatus.error, errorMessage: 'Please enter complete Bank Details');
      return false;
    }

    state = state.copyWith(status: KycStatus.loading, errorMessage: null);

    // Call API using ApiService with direct raw JSON Map matching POST /api/driver/kyc
    final response = await _apiService.post(ApiConstants.driverKyc, data: kyc.toJson(), token: token);

    if (response.isSuccess) {
      state = state.copyWith(status: KycStatus.success);
      return true;
    } else {
      state = state.copyWith(status: KycStatus.error, errorMessage: response.errorMessage ?? 'Failed to submit KYC details');
      return false;
    }
  }
}

final kycProvider = StateNotifierProvider<KycNotifier, KycState>((ref) {
  return KycNotifier();
});
