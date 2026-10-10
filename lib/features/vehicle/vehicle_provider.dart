import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_constants.dart';
import '../../core/network/api_service.dart';
import 'vehicle_model.dart';

enum VehicleStatus { initial, loading, registered, error }

class VehicleState {
  final VehicleModel vehicleData;
  final VehicleStatus status;
  final String? errorMessage;

  VehicleState({
    required this.vehicleData,
    this.status = VehicleStatus.initial,
    this.errorMessage,
  });

  VehicleState copyWith({
    VehicleModel? vehicleData,
    VehicleStatus? status,
    String? errorMessage,
  }) {
    return VehicleState(
      vehicleData: vehicleData ?? this.vehicleData,
      status: status ?? this.status,
      errorMessage: errorMessage,
    );
  }
}

class VehicleNotifier extends StateNotifier<VehicleState> {
  final ApiService _apiService;

  VehicleNotifier({ApiService? apiService})
      : _apiService = apiService ?? ApiService(),
        super(VehicleState(vehicleData: VehicleModel()));

  void updateVehicleData(VehicleModel newData) {
    state = state.copyWith(vehicleData: newData);
  }

  Future<bool> registerVehicle({String? token}) async {
    final v = state.vehicleData;

    if (v.registrationNumber.isEmpty) {
      state = state.copyWith(
        status: VehicleStatus.error,
        errorMessage: 'Please enter Vehicle Registration Number',
      );
      return false;
    }

    if (v.make.isEmpty || v.model.isEmpty) {
      state = state.copyWith(
        status: VehicleStatus.error,
        errorMessage: 'Please enter Vehicle Make and Model',
      );
      return false;
    }

    state = state.copyWith(status: VehicleStatus.loading, errorMessage: null);

    // POST /api/driver/vehicle using ApiService with direct raw JSON Map (No request model used)
    final response = await _apiService.post(
      ApiConstants.driverVehicle,
      data: {
        "vehicleTypeId": v.vehicleTypeId,
        "registrationNumber": v.registrationNumber,
        "make": v.make,
        "model": v.model,
        "year": v.year,
        "color": v.color,
        "fuelType": v.fuelType,
        "rcDocUrl": v.rcDocUrl,
        "insuranceDocUrl": v.insuranceDocUrl,
        "insuranceExpiry": v.insuranceExpiry,
        "vehiclePhotoUrl": v.vehiclePhotoUrl,
      },
      token: token,
    );

    if (response.isSuccess) {
      state = state.copyWith(status: VehicleStatus.registered);
      return true;
    } else {
      state = state.copyWith(
        status: VehicleStatus.error,
        errorMessage: response.errorMessage ?? 'Failed to register vehicle',
      );
      return false;
    }
  }
}

final vehicleProvider =
    StateNotifierProvider<VehicleNotifier, VehicleState>((ref) {
  return VehicleNotifier();
});
