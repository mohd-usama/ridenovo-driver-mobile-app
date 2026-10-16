import 'dart:async';
import 'dart:developer' as dev;
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../network/api_constants.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  io.Socket? _socket;
  bool _isConnected = false;

  bool get isConnected => _isConnected;
  io.Socket? get socket => _socket;

  final StreamController<Map<String, dynamic>> _rideRequestController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _rideStatusController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();

  Stream<Map<String, dynamic>> get rideRequestStream => _rideRequestController.stream;
  Stream<Map<String, dynamic>> get rideStatusStream => _rideStatusController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;

  /// Initializes persistent Socket.IO connection on driver login or duty ON
  void initSocket(String token) {
    if (_socket != null) {
      if (_socket!.connected) return;
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
    }

    final activeToken = token.isNotEmpty ? token : ApiConstants.defaultDevToken;

    dev.log('Initializing Socket.IO connection to ${ApiConstants.socketUrl} with auth token...', name: 'SocketService');

    _socket = io.io(
      ApiConstants.socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(999999)
          .setReconnectionDelay(1000)
          .setAuth({'token': activeToken})
          .build(),
    );

    _socket!.onConnect((_) {
      _isConnected = true;
      _connectionController.add(true);
      dev.log('Driver Socket Connected successfully! Socket ID: ${_socket?.id}', name: 'SocketService');
    });

    _socket!.onDisconnect((reason) {
      _isConnected = false;
      _connectionController.add(false);
      dev.log('Driver Socket Disconnected: $reason', name: 'SocketService');
    });

    _socket!.onConnectError((data) {
      _isConnected = false;
      _connectionController.add(false);
      dev.log('Driver Socket Connect Error: $data', name: 'SocketService');
    });

    // Handle incoming ride booking broadcasts
    void handleNewRide(dynamic data) {
      dev.log('Received new ride request broadcast: $data', name: 'SocketService');
      if (data != null && data is Map) {
        _rideRequestController.add(Map<String, dynamic>.from(data));
      }
    }

    _socket!.on('new_ride_request', handleNewRide);
    _socket!.on('ride:new_request', handleNewRide);
    _socket!.on('ride.new_request', handleNewRide);

    // Handle ride status changed events (e.g., rider cancelled)
    void handleStatusChanged(dynamic data) {
      dev.log('Received ride status changed event: $data', name: 'SocketService');
      if (data != null && data is Map) {
        _rideStatusController.add(Map<String, dynamic>.from(data));
      }
    }

    _socket!.on('ride:status_changed', handleStatusChanged);
    _socket!.on('ride.status_changed', handleStatusChanged);

    _socket!.connect();
  }

  /// Emits live GPS coordinates to Socket Server every 2–3 seconds
  void emitLocationUpdate({
    required double lat,
    required double lng,
    double heading = 0.0,
    double speed = 0.0,
    double accuracy = 0.0,
    String? vehicleType,
    String? plateNumber,
    String status = 'online',
    String? rideId,
  }) {
    final payload = {
      'lat': lat,
      'lng': lng,
      'heading': heading,
      'speed': speed,
      'accuracy': accuracy,
      'vehicleType': vehicleType ?? 'bike',
      'plateNumber': plateNumber ?? '',
      'status': status,
      'rideId': rideId,
    };

    if (_socket != null && _socket!.connected) {
      _socket!.emit('updateLocation', payload);
      _socket!.emit('driver:location_update', payload);
      dev.log('Emitted live GPS to socket: lat=$lat, lng=$lng, heading=$heading, rideId=$rideId', name: 'SocketService');
    } else {
      dev.log('Socket not connected. Skipping socket location emit.', name: 'SocketService');
    }
  }

  /// Joins ride tracking socket room when ride is accepted
  void joinRide(String rideId) {
    if (rideId.isEmpty) return;
    if (_socket != null && _socket!.connected) {
      _socket!.emit('join_ride', {'rideId': rideId});
      dev.log('Joined ride socket room: $rideId', name: 'SocketService');
    }
  }

  /// Leaves ride tracking socket room when ride finishes or is cancelled
  void leaveRide(String rideId) {
    if (rideId.isEmpty) return;
    if (_socket != null && _socket!.connected) {
      _socket!.emit('leave_ride', {'rideId': rideId});
      dev.log('Left ride socket room: $rideId', name: 'SocketService');
    }
  }

  /// Closes socket connection on driver logout
  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
    _connectionController.add(false);
    dev.log('Disconnected and disposed SocketService', name: 'SocketService');
  }
}
