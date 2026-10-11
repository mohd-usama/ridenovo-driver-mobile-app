import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/network/api_constants.dart';
import '../../core/network/api_service.dart';
import 'models/ride_request_model.dart';
import 'models/ride_route_model.dart';

enum RideStep { none, accepted, arrived, otpEntered, started, completed, cancelled }

class RideState {
  final bool isOnline;
  final int batteryLevel;
  final bool isDutyLoading;
  final bool isRideLoading;
  final List<RideRequestModel> pendingRequests;
  final RideRequestModel? activeRide;
  final RideRouteModel? activeRoute;
  final RideStep rideStep;
  final String? errorMessage;

  RideState({
    this.isOnline = false,
    this.batteryLevel = 85,
    this.isDutyLoading = false,
    this.isRideLoading = false,
    this.pendingRequests = const [],
    this.activeRide,
    this.activeRoute,
    this.rideStep = RideStep.none,
    this.errorMessage,
  });

  RideState copyWith({
    bool? isOnline,
    int? batteryLevel,
    bool? isDutyLoading,
    bool? isRideLoading,
    List<RideRequestModel>? pendingRequests,
    RideRequestModel? activeRide,
    RideRouteModel? activeRoute,
    bool clearActiveRide = false,
    bool clearActiveRoute = false,
    RideStep? rideStep,
    String? errorMessage,
  }) {
    return RideState(
      isOnline: isOnline ?? this.isOnline,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      isDutyLoading: isDutyLoading ?? this.isDutyLoading,
      isRideLoading: isRideLoading ?? this.isRideLoading,
      pendingRequests: pendingRequests ?? this.pendingRequests,
      activeRide: clearActiveRide ? null : (activeRide ?? this.activeRide),
      activeRoute: (clearActiveRide || clearActiveRoute) ? null : (activeRoute ?? this.activeRoute),
      rideStep: rideStep ?? this.rideStep,
      errorMessage: errorMessage,
    );
  }
}

class RideNotifier extends StateNotifier<RideState> {
  final ApiService _apiService;
  Timer? _pollingTimer;
  Timer? _locationTimer;
  double? currentLat;
  double? currentLng;

  RideNotifier({ApiService? apiService}) : _apiService = apiService ?? ApiService(), super(RideState()) {
    restoreDutyStatus();
  }

  @override
  void dispose() {
    _stopTimers();
    super.dispose();
  }

  void updateDriverCoordinates(double lat, double lng) {
    currentLat = lat;
    currentLng = lng;
  }

  /// Restores online duty status from SharedPreferences on app restart
  Future<void> restoreDutyStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bool isOnlineSaved = prefs.getBool('is_duty_online') ?? false;

      if (isOnlineSaved) {
        state = state.copyWith(isOnline: true);
        _startTimers();
        fetchPendingRequests();
        if (currentLat != null && currentLng != null) {
          updateLocation(currentLat!, currentLng!);
        }
      }
    } catch (_) {}
  }

  void _stopTimers() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _locationTimer?.cancel();
    _locationTimer = null;
  }

  void _startTimers() {
    _stopTimers();

    // Poll for real pending ride requests every 3 seconds while online
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (state.isOnline) {
        fetchPendingRequests();
      }
    });

    // Send live GPS location periodically every 10 seconds while online
    _locationTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (state.isOnline && currentLat != null && currentLng != null) {
        updateLocation(currentLat!, currentLng!);
      }
    });
  }

  /// 1. Go Online (POST /driver/online)
  Future<bool> goOnline({int battery = 85}) async {
    state = state.copyWith(isDutyLoading: true, errorMessage: null);

    await _apiService.post(ApiConstants.goOnline, data: {'battery': battery});

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_duty_online', true);
    } catch (_) {}

    state = state.copyWith(isOnline: true, batteryLevel: battery, isDutyLoading: false);
    _startTimers();
    fetchPendingRequests();
    if (currentLat != null && currentLng != null) {
      updateLocation(currentLat!, currentLng!);
    }
    return true;
  }

  /// 2. Go Offline (POST /driver/offline)
  Future<bool> goOffline() async {
    state = state.copyWith(isDutyLoading: true, errorMessage: null);

    await _apiService.post(ApiConstants.goOffline);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_duty_online', false);
    } catch (_) {}

    _stopTimers();
    state = state.copyWith(
      isOnline: false,
      isDutyLoading: false,
      pendingRequests: [],
      clearActiveRide: true,
      clearActiveRoute: true,
      rideStep: RideStep.none,
    );
    return true;
  }

  /// 3. Update Live Location (POST /driver/location)
  Future<bool> updateLocation(double lat, double lng) async {
    if (!state.isOnline) return false;

    final response = await _apiService.post(ApiConstants.updateLocation, data: {'lat': lat, 'lng': lng});

    // Auto refresh route polyline when driver moves with an active ride
    if (state.activeRide != null) {
      fetchRideRoute(state.activeRide!.id, lat: lat, lng: lng);
    }

    return response.isSuccess;
  }

  /// 4. Update Battery Level (POST /driver/battery)
  Future<bool> updateBattery(int battery) async {
    state = state.copyWith(batteryLevel: battery);

    final response = await _apiService.post(ApiConstants.updateBattery, data: {'battery': battery});
    return response.isSuccess;
  }

  /// 5. Get Pending Ride Requests (GET /driver/ride-requests)
  Future<void> fetchPendingRequests() async {
    if (!state.isOnline || state.activeRide != null) return;

    final response = await _apiService.get(ApiConstants.getRideRequests);

    if (response.isSuccess && response.data != null) {
      try {
        final raw = response.data is String ? jsonDecode(response.data) : response.data;
        var dataPayload = (raw is Map) ? (raw['data'] ?? raw['result'] ?? raw) : raw;

        // Extract list if wrapped in a map key (e.g., {"requests": [...]})
        if (dataPayload is Map) {
          if (dataPayload['requests'] is List) {
            dataPayload = dataPayload['requests'];
          } else if (dataPayload['rideRequests'] is List) {
            dataPayload = dataPayload['rideRequests'];
          } else if (dataPayload['rides'] is List) {
            dataPayload = dataPayload['rides'];
          } else if (dataPayload['pending'] is List) {
            dataPayload = dataPayload['pending'];
          }
        }

        List<RideRequestModel> requests = [];
        if (dataPayload is List) {
          for (var item in dataPayload) {
            final parsed = RideRequestModel.tryParse(item);
            if (parsed != null) requests.add(parsed);
          }
        } else if (dataPayload is Map<String, dynamic> && dataPayload.isNotEmpty) {
          final parsed = RideRequestModel.tryParse(dataPayload);
          if (parsed != null) requests.add(parsed);
        }

        state = state.copyWith(pendingRequests: requests);
      } catch (_) {}
    }
  }

  /// 6. Accept Ride (POST /driver/riderequests/{rideId}/accept or /driver/ride-requests/{rideId}/accept)
  Future<bool> acceptRide(String rideId, {double? driverLat, double? driverLng}) async {
    state = state.copyWith(isRideLoading: true, errorMessage: null);

    final existingReq = state.pendingRequests.firstWhere(
      (r) => r.id == rideId,
      orElse: () => state.activeRide ?? RideRequestModel(id: rideId, status: 'accepted'),
    );

    var response = await _apiService.post(ApiConstants.acceptRideRequest(rideId));

    // Endpoint fallback if primary accepts hyphenated route
    if (!response.isSuccess) {
      response = await _apiService.post('/driver/ride-requests/$rideId/accept');
    }

    if (response.isSuccess) {
      RideRequestModel? acceptedRide;
      RideRouteModel? acceptedRoute;

      if (response.data != null) {
        try {
          final raw = response.data is String ? jsonDecode(response.data) : response.data;
          final dataPayload = (raw is Map) ? (raw['data'] ?? raw['result'] ?? raw) : raw;

          if (dataPayload is Map<String, dynamic>) {
            acceptedRide = RideRequestModel.tryParse(dataPayload);
            if (dataPayload['route'] is Map) {
              acceptedRoute = RideRouteModel.fromJson({'data': dataPayload['route'], 'rideId': rideId});
            }
          }
        } catch (_) {}
      }

      final finalActive = acceptedRide != null
          ? existingReq.mergeWith(acceptedRide).copyWith(status: 'accepted')
          : existingReq.copyWith(status: 'accepted');

      state = state.copyWith(
        isRideLoading: false,
        activeRide: finalActive,
        activeRoute: acceptedRoute ?? state.activeRoute,
        rideStep: RideStep.accepted,
        pendingRequests: [],
      );

      // Fallback fetch route if not included in accept response
      if (acceptedRoute == null && driverLat != null && driverLng != null) {
        await fetchRideRoute(rideId, lat: driverLat, lng: driverLng);
      }

      return true;
    } else {
      state = state.copyWith(isRideLoading: false, errorMessage: response.errorMessage ?? 'Failed to accept ride request');
      return false;
    }
  }

  /// 7. Get Ride Details (GET /driver/rides/{rideId})
  Future<void> fetchRideDetails(String rideId) async {
    final response = await _apiService.get(ApiConstants.getRideDetails(rideId));

    if (response.isSuccess && response.data != null) {
      try {
        final raw = response.data is String ? jsonDecode(response.data) : response.data;
        var dataPayload = (raw is Map) ? (raw['data'] ?? raw['result'] ?? raw) : raw;

        if (dataPayload is Map) {
          if (dataPayload['ride'] is Map) {
            dataPayload = dataPayload['ride'];
          } else if (dataPayload['rideDetails'] is Map) {
            dataPayload = dataPayload['rideDetails'];
          } else if (dataPayload['request'] is Map) {
            dataPayload = dataPayload['request'];
          }
        }

        if (dataPayload is Map<String, dynamic>) {
          final fetchedRide = RideRequestModel.fromJson(dataPayload);
          final mergedRide = state.activeRide != null
              ? state.activeRide!.mergeWith(fetchedRide)
              : fetchedRide;
          state = state.copyWith(activeRide: mergedRide);
        }
      } catch (_) {}
    }
  }

  /// 7b. Get Ride Route (GET /driver/rides/{rideId}/route?lat={lat}&lng={lng})
  Future<RideRouteModel?> fetchRideRoute(String rideId, {required double lat, required double lng}) async {
    final response = await _apiService.get(ApiConstants.getRideRoute(rideId, lat, lng));

    if (response.isSuccess && response.data != null) {
      try {
        final raw = response.data is String ? jsonDecode(response.data) : response.data;
        final dataPayload = (raw is Map) ? (raw['data'] ?? raw['result'] ?? raw) : raw;

        if (dataPayload is Map<String, dynamic>) {
          final routeModel = RideRouteModel.fromJson(dataPayload);
          state = state.copyWith(activeRoute: routeModel);

          // Backfill missing fields in activeRide from routeModel if needed
          if (state.activeRide != null) {
            var active = state.activeRide!;
            bool updated = false;

            if (active.riderName.isEmpty && routeModel.riderName.isNotEmpty) {
              active = active.copyWith(riderName: routeModel.riderName, riderPhone: routeModel.riderPhone);
              updated = true;
            }
            if (active.pickupAddress.isEmpty && routeModel.target == 'pickup' && routeModel.targetAddress.isNotEmpty) {
              active = active.copyWith(pickupAddress: routeModel.targetAddress, pickupLat: routeModel.targetLat, pickupLng: routeModel.targetLng);
              updated = true;
            }
            if (active.dropAddress.isEmpty && routeModel.target == 'dropoff' && routeModel.targetAddress.isNotEmpty) {
              active = active.copyWith(dropAddress: routeModel.targetAddress, dropLat: routeModel.targetLat, dropLng: routeModel.targetLng);
              updated = true;
            }

            if (updated) {
              state = state.copyWith(activeRide: active);
            }
          }

          return routeModel;
        }
      } catch (_) {}
    }
    return null;
  }

  /// 8. Mark Arrived at Pickup (POST /driver/rides/{rideId}/arrived)
  Future<bool> markArrived(String rideId) async {
    state = state.copyWith(isRideLoading: true, errorMessage: null);

    final response = await _apiService.post(ApiConstants.arrivedAtPickup(rideId));

    if (response.isSuccess) {
      state = state.copyWith(
        isRideLoading: false,
        rideStep: RideStep.arrived,
        activeRide: state.activeRide?.copyWith(status: 'arrived'),
      );
      return true;
    } else {
      state = state.copyWith(isRideLoading: false, errorMessage: response.errorMessage ?? 'Failed to mark arrived');
      return false;
    }
  }

  /// 9. Start Ride with OTP (POST /driver/rides/{rideId}/start)
  Future<bool> startRide(String rideId, String otp, {double? driverLat, double? driverLng}) async {
    if (otp.length < 4) {
      state = state.copyWith(errorMessage: 'Please enter valid 4-digit OTP');
      return false;
    }

    state = state.copyWith(isRideLoading: true, errorMessage: null);

    final response = await _apiService.post(ApiConstants.startRide(rideId), data: {'otp': otp});

    if (response.isSuccess) {
      state = state.copyWith(
        isRideLoading: false,
        rideStep: RideStep.started,
        activeRide: state.activeRide?.copyWith(status: 'started'),
      );

      // Fetch route polyline to dropoff location
      if (driverLat != null && driverLng != null) {
        await fetchRideRoute(rideId, lat: driverLat, lng: driverLng);
      }

      return true;
    } else {
      state = state.copyWith(isRideLoading: false, errorMessage: response.errorMessage ?? 'Invalid OTP entered. Please try again.');
      return false;
    }
  }

  /// Reject Ride Request (POST /driver/riderequests/{rideId}/reject)
  Future<bool> rejectRide(String rideId, {String? reason}) async {
    state = state.copyWith(isRideLoading: true, errorMessage: null);

    final response = await _apiService.post(ApiConstants.rejectRideRequest(rideId), data: {'reason': reason ?? 'Too far'});

    state = state.copyWith(isRideLoading: false, pendingRequests: state.pendingRequests.where((r) => r.id != rideId).toList());
    return response.isSuccess;
  }

  /// 10. Cancel Ride (POST /driver/rides/{rideId}/cancel)
  Future<bool> cancelRide(String rideId, {String? reason}) async {
    state = state.copyWith(isRideLoading: true, errorMessage: null);

    await _apiService.post(ApiConstants.cancelRide(rideId), data: {'reason': reason ?? 'Driver cancelled'});

    state = state.copyWith(
      isRideLoading: false,
      clearActiveRide: true,
      clearActiveRoute: true,
      rideStep: RideStep.none,
    );
    return true;
  }

  /// Complete Ride (POST /driver/rides/{rideId}/complete)
  Future<bool> completeRide(String rideId) async {
    state = state.copyWith(isRideLoading: true, errorMessage: null);

    final response = await _apiService.post(ApiConstants.completeRide(rideId));

    if (response.isSuccess) {
      state = state.copyWith(
        isRideLoading: false,
        rideStep: RideStep.completed,
        clearActiveRide: true,
        clearActiveRoute: true,
      );
      return true;
    } else {
      state = state.copyWith(isRideLoading: false, errorMessage: response.errorMessage ?? 'Failed to complete ride');
      return false;
    }
  }

  /// Complete Ride local reset
  void completeActiveRide() {
    state = state.copyWith(
      isRideLoading: false,
      clearActiveRide: true,
      clearActiveRoute: true,
      rideStep: RideStep.none,
    );
  }

  /// Get Waiting Charges / Time (GET /driver/rides/{rideId}/waiting)
  Future<dynamic> getWaitingCharges(String rideId) async {
    final response = await _apiService.get(ApiConstants.getWaitingCharges(rideId));
    return response.isSuccess ? response.data : null;
  }

  /// Rate Rider (POST /driver/rides/{rideId}/rate)
  Future<bool> rateRider(String rideId, {required int rating, String? comment}) async {
    final response = await _apiService.post(
      ApiConstants.rateRider(rideId),
      data: {'rating': rating, if (comment != null) 'comment': comment},
    );
    return response.isSuccess;
  }

  /// Request Payout (POST /driver/payout-request)
  Future<bool> requestPayout({required double amount}) async {
    final response = await _apiService.post(ApiConstants.payoutRequest, data: {'amount': amount});
    return response.isSuccess;
  }
}

final rideProvider = StateNotifierProvider<RideNotifier, RideState>((ref) {
  return RideNotifier();
});
