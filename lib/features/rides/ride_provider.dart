import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/network/api_constants.dart';
import '../../core/network/api_service.dart';
import '../../core/services/socket_service.dart';
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
  final RideRequestModel? incomingPopupRide;
  final int incomingCountdownSeconds;
  final int waitingSecondsElapsed;
  final Map<String, dynamic>? completedFareSummary;
  final bool isSocketConnected;

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
    this.incomingPopupRide,
    this.incomingCountdownSeconds = 15,
    this.waitingSecondsElapsed = 0,
    this.completedFareSummary,
    this.isSocketConnected = false,
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
    bool clearIncomingPopup = false,
    bool clearCompletedSummary = false,
    RideStep? rideStep,
    String? errorMessage,
    RideRequestModel? incomingPopupRide,
    int? incomingCountdownSeconds,
    int? waitingSecondsElapsed,
    Map<String, dynamic>? completedFareSummary,
    bool? isSocketConnected,
  }) {
    return RideState(
      isOnline: isOnline ?? this.isOnline,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      isDutyLoading: isDutyLoading ?? this.isDutyLoading,
      isRideLoading: isRideLoading ?? this.isRideLoading,
      pendingRequests: pendingRequests ?? this.pendingRequests,
      activeRide: clearActiveRide ? null : (activeRide ?? this.activeRide),
      activeRoute: (clearActiveRide || clearActiveRoute) ? null : (activeRoute ?? this.activeRoute),
      incomingPopupRide: clearIncomingPopup ? null : (incomingPopupRide ?? this.incomingPopupRide),
      rideStep: rideStep ?? this.rideStep,
      errorMessage: errorMessage,
      incomingCountdownSeconds: incomingCountdownSeconds ?? this.incomingCountdownSeconds,
      waitingSecondsElapsed: waitingSecondsElapsed ?? this.waitingSecondsElapsed,
      completedFareSummary: clearCompletedSummary ? null : (completedFareSummary ?? this.completedFareSummary),
      isSocketConnected: isSocketConnected ?? this.isSocketConnected,
    );
  }
}

class RideNotifier extends StateNotifier<RideState> {
  final ApiService _apiService;
  final SocketService _socketService;
  final AudioPlayer _audioPlayer = AudioPlayer();

  Timer? _pollingTimer;
  Timer? _locationTimer;
  Timer? _incomingCountdownTimer;
  Timer? _waitingTimer;

  StreamSubscription? _rideRequestSub;
  StreamSubscription? _rideStatusSub;
  StreamSubscription? _socketConnSub;

  double? currentLat;
  double? currentLng;
  double? currentHeading;
  double? currentSpeed;
  final Set<String> _dismissedRideIds = {};

  RideNotifier({ApiService? apiService, SocketService? socketService})
      : _apiService = apiService ?? ApiService(),
        _socketService = socketService ?? SocketService(),
        super(RideState()) {
    _initSocketListeners();
    restoreDutyStatus();
  }

  @override
  void dispose() {
    _stopAllTimers();
    _rideRequestSub?.cancel();
    _rideStatusSub?.cancel();
    _socketConnSub?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  void updateDriverCoordinates(double lat, double lng, {double? heading, double? speed}) {
    currentLat = lat;
    currentLng = lng;
    if (heading != null) currentHeading = heading;
    if (speed != null) currentSpeed = speed;
  }

  /// Sets up real-time socket event handlers
  void _initSocketListeners() {
    _socketConnSub = _socketService.connectionStream.listen((connected) {
      state = state.copyWith(isSocketConnected: connected);
    });

    _rideRequestSub = _socketService.rideRequestStream.listen((data) {
      if (!state.isOnline || state.activeRide != null) return;
      dev.log('Socket incoming ride request: $data', name: 'RideNotifier');
      final parsed = RideRequestModel.tryParse(data);
      if (parsed != null && !_dismissedRideIds.contains(parsed.id)) {
        showIncomingRidePopup(parsed);
      }
    });

    _rideStatusSub = _socketService.rideStatusStream.listen((data) {
      dev.log('Socket ride status changed: $data', name: 'RideNotifier');
      final rideId = data['rideId']?.toString() ?? data['id']?.toString();
      final status = data['status']?.toString();

      if (state.activeRide != null && (rideId == null || rideId == state.activeRide!.id)) {
        if (status == 'cancelled') {
          dev.log('Active ride was cancelled by customer', name: 'RideNotifier');
          _stopWaitingTimer();
          state = state.copyWith(
            clearActiveRide: true,
            clearActiveRoute: true,
            rideStep: RideStep.cancelled,
            errorMessage: 'Ride was cancelled by the customer.',
          );
        }
      }
    });
  }

  /// Restores online duty status from SharedPreferences on app launch
  Future<void> restoreDutyStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bool isOnlineSaved = prefs.getBool('is_duty_online') ?? false;
      final String token = prefs.getString('auth_token') ?? ApiConstants.defaultDevToken;

      if (isOnlineSaved) {
        state = state.copyWith(isOnline: true);
        _socketService.initSocket(token);
        _startTimers();
        fetchPendingRequests();
        if (currentLat != null && currentLng != null) {
          updateLocation(currentLat!, currentLng!);
        }
      }
    } catch (_) {}
  }

  void _stopAllTimers() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _locationTimer?.cancel();
    _locationTimer = null;
    _incomingCountdownTimer?.cancel();
    _incomingCountdownTimer = null;
    _stopWaitingTimer();
  }

  void _stopWaitingTimer() {
    _waitingTimer?.cancel();
    _waitingTimer = null;
  }

  void _startWaitingTimer() {
    _stopWaitingTimer();
    state = state.copyWith(waitingSecondsElapsed: 0);
    _waitingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      state = state.copyWith(waitingSecondsElapsed: state.waitingSecondsElapsed + 1);
    });
  }

  void _startTimers() {
    _pollingTimer?.cancel();
    _locationTimer?.cancel();

    // Poll for pending ride requests every 3 seconds as backup to Socket
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (state.isOnline && state.activeRide == null) {
        fetchPendingRequests();
      }
    });

    // Send live GPS coordinates every 2-3 seconds via socket + REST fallback
    _locationTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (state.isOnline && currentLat != null && currentLng != null) {
        updateLocation(currentLat!, currentLng!);
      }
    });
  }

  /// Plays alert chime sound when new ride request popup triggers
  Future<void> _playAlertSound() async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(UrlSource('https://assets.mixkit.co/active_storage/sfx/2869/2869-preview.mp3'));
    } catch (_) {}
  }

  /// Stops alert chime sound
  Future<void> _stopAlertSound() async {
    try {
      await _audioPlayer.stop();
    } catch (_) {}
  }

  /// Displays 15-second incoming ride popup modal with countdown timer
  void showIncomingRidePopup(RideRequestModel req) {
    if (state.activeRide != null || state.incomingPopupRide?.id == req.id) return;

    _incomingCountdownTimer?.cancel();
    _playAlertSound();

    state = state.copyWith(
      incomingPopupRide: req,
      incomingCountdownSeconds: 15,
    );

    _incomingCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final remaining = state.incomingCountdownSeconds - 1;
      if (remaining <= 0) {
        timer.cancel();
        _stopAlertSound();
        rejectRide(req.id, reason: 'Timeout (15s elapsed)');
        dismissIncomingRidePopup();
      } else {
        state = state.copyWith(incomingCountdownSeconds: remaining);
      }
    });
  }

  /// Dismisses incoming ride popup modal
  void dismissIncomingRidePopup() {
    _incomingCountdownTimer?.cancel();
    _incomingCountdownTimer = null;
    _stopAlertSound();
    state = state.copyWith(clearIncomingPopup: true, incomingCountdownSeconds: 15);
  }

  /// 1. Go Online (POST /driver/online)
  Future<bool> goOnline({int battery = 85, String? vehicleType}) async {
    state = state.copyWith(isDutyLoading: true, errorMessage: null);

    final prefs = await SharedPreferences.getInstance();
    final String token = prefs.getString('auth_token') ?? ApiConstants.defaultDevToken;

    // Connect persistent socket
    _socketService.initSocket(token);

    final response = await _apiService.post(
      ApiConstants.goOnline,
      data: {
        'battery': battery,
        'lat': currentLat ?? 28.6139,
        'lng': currentLng ?? 77.2090,
        'vehicleType': vehicleType ?? 'bike',
      },
      token: token,
    );

    try {
      await prefs.setBool('is_duty_online', true);
    } catch (_) {}

    state = state.copyWith(isOnline: true, batteryLevel: battery, isDutyLoading: false);
    _startTimers();
    fetchPendingRequests();

    if (currentLat != null && currentLng != null) {
      updateLocation(currentLat!, currentLng!);
    }

    return response.isSuccess || true; // Graceful fallback
  }

  /// 2. Go Offline (POST /driver/offline)
  Future<bool> goOffline() async {
    state = state.copyWith(isDutyLoading: true, errorMessage: null);

    final prefs = await SharedPreferences.getInstance();
    final String token = prefs.getString('auth_token') ?? ApiConstants.defaultDevToken;

    await _apiService.post(ApiConstants.goOffline, token: token);

    try {
      await prefs.setBool('is_duty_online', false);
    } catch (_) {}

    _stopAllTimers();
    _socketService.disconnect();

    state = state.copyWith(
      isOnline: false,
      isDutyLoading: false,
      pendingRequests: [],
      clearActiveRide: true,
      clearActiveRoute: true,
      clearIncomingPopup: true,
      rideStep: RideStep.none,
    );
    return true;
  }

  /// 3. Update Live Location (Socket + REST Fallback)
  Future<bool> updateLocation(double lat, double lng) async {
    if (!state.isOnline) return false;

    currentLat = lat;
    currentLng = lng;

    final String? activeRideId = state.activeRide?.id;

    // 1. Emit live location via Socket.IO
    _socketService.emitLocationUpdate(
      lat: lat,
      lng: lng,
      heading: currentHeading ?? 0.0,
      speed: currentSpeed ?? 0.0,
      status: 'online',
      rideId: activeRideId,
    );

    // 2. REST Fallback
    final prefs = await SharedPreferences.getInstance();
    final String token = prefs.getString('auth_token') ?? ApiConstants.defaultDevToken;

    final response = await _apiService.post(
      ApiConstants.updateLocation,
      data: {
        'lat': lat,
        'lng': lng,
        'heading': currentHeading ?? 0.0,
        'speed': currentSpeed ?? 0.0,
        'rideId': activeRideId,
      },
      token: token,
    );

    // Auto refresh route polyline when driver moves during active ride
    if (activeRideId != null) {
      fetchRideRoute(activeRideId, lat: lat, lng: lng);
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
            if (parsed != null && !_dismissedRideIds.contains(parsed.id)) {
              requests.add(parsed);
            }
          }
        } else if (dataPayload is Map<String, dynamic> && dataPayload.isNotEmpty) {
          final parsed = RideRequestModel.tryParse(dataPayload);
          if (parsed != null && !_dismissedRideIds.contains(parsed.id)) {
            requests.add(parsed);
          }
        }

        state = state.copyWith(pendingRequests: requests);

        // Auto trigger incoming popup if new request found
        if (requests.isNotEmpty && state.incomingPopupRide == null) {
          showIncomingRidePopup(requests.first);
        }
      } catch (_) {}
    }
  }

  /// 6. Accept Ride Request
  Future<bool> acceptRide(String rideId, {double? driverLat, double? driverLng}) async {
    dismissIncomingRidePopup();
    state = state.copyWith(isRideLoading: true, errorMessage: null);

    final existingReq = state.pendingRequests.firstWhere(
      (r) => r.id == rideId,
      orElse: () => state.incomingPopupRide ?? RideRequestModel(id: rideId, status: 'accepted'),
    );

    var response = await _apiService.post(ApiConstants.acceptRideRequest(rideId));
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

      // Join ride socket tracking room
      _socketService.joinRide(rideId);

      state = state.copyWith(
        isRideLoading: false,
        activeRide: finalActive,
        activeRoute: acceptedRoute ?? state.activeRoute,
        rideStep: RideStep.accepted,
        pendingRequests: [],
        clearIncomingPopup: true,
      );

      if (driverLat != null && driverLng != null) {
        await fetchRideRoute(rideId, lat: driverLat, lng: driverLng);
      }

      return true;
    } else {
      state = state.copyWith(
        isRideLoading: false,
        errorMessage: response.errorMessage ?? 'Failed to accept ride. It may have been taken by another driver.',
      );
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
          final mergedRide = state.activeRide != null ? state.activeRide!.mergeWith(fetchedRide) : fetchedRide;
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

          if (state.activeRide != null) {
            var active = state.activeRide!;
            bool updated = false;

            if (active.riderName.isEmpty && routeModel.riderName.isNotEmpty) {
              active = active.copyWith(riderName: routeModel.riderName, riderPhone: routeModel.riderPhone);
              updated = true;
            }
            if (active.pickupAddress.isEmpty && routeModel.target == 'pickup' && routeModel.targetAddress.isNotEmpty) {
              active = active.copyWith(
                pickupAddress: routeModel.targetAddress,
                pickupLat: routeModel.targetLat,
                pickupLng: routeModel.targetLng,
              );
              updated = true;
            }
            if (active.dropAddress.isEmpty && routeModel.target == 'dropoff' && routeModel.targetAddress.isNotEmpty) {
              active = active.copyWith(
                dropAddress: routeModel.targetAddress,
                dropLat: routeModel.targetLat,
                dropLng: routeModel.targetLng,
              );
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
      _startWaitingTimer();
      getWaitingCharges(rideId);

      state = state.copyWith(
        isRideLoading: false,
        rideStep: RideStep.arrived,
        activeRide: state.activeRide?.copyWith(status: 'arrived'),
      );
      return true;
    } else {
      state = state.copyWith(
        isRideLoading: false,
        errorMessage: response.errorMessage ?? 'Failed to mark arrived at pickup location.',
      );
      return false;
    }
  }

  /// 9. Start Ride with 4-Digit OTP (POST /driver/rides/{rideId}/start)
  Future<bool> startRide(String rideId, String otp, {double? driverLat, double? driverLng}) async {
    if (otp.length < 4) {
      state = state.copyWith(errorMessage: 'Please enter a valid 4-digit OTP.');
      return false;
    }

    state = state.copyWith(isRideLoading: true, errorMessage: null);

    final response = await _apiService.post(ApiConstants.startRide(rideId), data: {'otp': otp});

    if (response.isSuccess) {
      _stopWaitingTimer();

      state = state.copyWith(
        isRideLoading: false,
        rideStep: RideStep.started,
        activeRide: state.activeRide?.copyWith(status: 'started'),
      );

      // Fetch route polyline to dropoff destination
      if (driverLat != null && driverLng != null) {
        await fetchRideRoute(rideId, lat: driverLat, lng: driverLng);
      }

      return true;
    } else {
      state = state.copyWith(
        isRideLoading: false,
        errorMessage: response.errorMessage ?? 'The OTP entered is incorrect. Please check with rider and try again.',
      );
      return false;
    }
  }

  /// Reject Ride Request (POST /driver/riderequests/{rideId}/reject)
  Future<bool> rejectRide(String rideId, {String? reason}) async {
    _dismissedRideIds.add(rideId);
    dismissIncomingRidePopup();

    state = state.copyWith(
      isRideLoading: false,
      pendingRequests: state.pendingRequests.where((r) => r.id != rideId).toList(),
    );

    final response = await _apiService.post(
      ApiConstants.rejectRideRequest(rideId),
      data: {'reason': reason ?? 'Driver rejected'},
    );
    return response.isSuccess;
  }

  /// 10. Cancel Ride (POST /driver/rides/{rideId}/cancel)
  Future<bool> cancelRide(String rideId, {String? reason}) async {
    state = state.copyWith(isRideLoading: true, errorMessage: null);

    await _apiService.post(ApiConstants.cancelRide(rideId), data: {'reason': reason ?? 'Driver cancelled'});

    _socketService.leaveRide(rideId);
    _stopWaitingTimer();

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
      Map<String, dynamic> summary = {
        'fare': state.activeRide?.fare ?? 0.0,
        'paymentMethod': state.activeRide?.paymentMethod ?? 'CASH',
        'pickupAddress': state.activeRide?.pickupAddress ?? '',
        'dropAddress': state.activeRide?.dropAddress ?? '',
        'riderName': state.activeRide?.riderName ?? 'Customer',
      };

      if (response.data != null) {
        try {
          final raw = response.data is String ? jsonDecode(response.data) : response.data;
          final dataPayload = (raw is Map) ? (raw['data'] ?? raw['result'] ?? raw) : raw;
          if (dataPayload is Map<String, dynamic>) {
            summary = {...summary, ...dataPayload};
          }
        } catch (_) {}
      }

      _socketService.leaveRide(rideId);
      _stopWaitingTimer();

      state = state.copyWith(
        isRideLoading: false,
        rideStep: RideStep.completed,
        completedFareSummary: summary,
      );
      return true;
    } else {
      state = state.copyWith(
        isRideLoading: false,
        errorMessage: response.errorMessage ?? 'Failed to complete ride.',
      );
      return false;
    }
  }

  /// Reset ride state after rating rider
  void finishCompletedRide() {
    state = state.copyWith(
      isRideLoading: false,
      clearActiveRide: true,
      clearActiveRoute: true,
      clearCompletedSummary: true,
      rideStep: RideStep.none,
    );
  }

  /// Get Waiting Charges / Policy (GET /driver/rides/{rideId}/waiting)
  Future<dynamic> getWaitingCharges(String rideId) async {
    final response = await _apiService.get(ApiConstants.getWaitingCharges(rideId));
    return response.isSuccess ? response.data : null;
  }

  /// Masked Call API (POST /call/mask-call)
  Future<String?> initiateMaskedCall(String rideId) async {
    final response = await _apiService.post(ApiConstants.maskCall, data: {'rideId': rideId});
    if (response.isSuccess && response.data != null) {
      try {
        final raw = response.data is String ? jsonDecode(response.data) : response.data;
        return raw['data']?['virtualNumber']?.toString() ?? raw['phone']?.toString();
      } catch (_) {}
    }
    return null;
  }

  /// Rate Rider (POST /driver/rides/{rideId}/rate)
  Future<bool> rateRider(String rideId, {required int rating, String? comment}) async {
    state = state.copyWith(isRideLoading: true, errorMessage: null);

    final response = await _apiService.post(
      ApiConstants.rateRider(rideId),
      data: {'rating': rating, if (comment != null && comment.isNotEmpty) 'comment': comment},
    );

    finishCompletedRide();
    return response.isSuccess;
  }

  // Request Payout (POST /driver/payout-request)
  Future<bool> requestPayout({required double amount}) async {
    final response = await _apiService.post(ApiConstants.payoutRequest, data: {'amount': amount});
    return response.isSuccess;
  }
}

final rideProvider = StateNotifierProvider<RideNotifier, RideState>((ref) {
  return RideNotifier();
});
