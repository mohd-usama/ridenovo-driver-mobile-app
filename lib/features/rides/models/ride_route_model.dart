import 'package:google_maps_flutter/google_maps_flutter.dart';

class RideRouteModel {
  final String rideId;
  final String status;
  final String target; // 'pickup' or 'dropoff'
  final String targetAddress;
  final double targetLat;
  final double targetLng;
  final double driverLat;
  final double driverLng;
  final double distanceKm;
  final int durationMinutes;
  final String polyline;
  final List<LatLng> points;
  final String riderName;
  final String riderPhone;

  RideRouteModel({
    required this.rideId,
    this.status = '',
    this.target = 'pickup',
    this.targetAddress = '',
    this.targetLat = 0.0,
    this.targetLng = 0.0,
    this.driverLat = 0.0,
    this.driverLng = 0.0,
    this.distanceKm = 0.0,
    this.durationMinutes = 0,
    this.polyline = '',
    this.points = const [],
    this.riderName = '',
    this.riderPhone = '',
  });

  /// Returns route coordinates from points list or by decoding polyline string
  List<LatLng> get routeCoordinates {
    if (points.isNotEmpty) {
      return points;
    } else if (polyline.isNotEmpty) {
      return decodePolyline(polyline);
    }
    return [];
  }

  factory RideRouteModel.fromJson(Map<String, dynamic> json) {
    final map = (json['data'] is Map<String, dynamic>)
        ? json['data']
        : ((json['result'] is Map<String, dynamic>) ? json['result'] : json);

    String rideId = map['rideId']?.toString() ?? map['id']?.toString() ?? '';
    String status = map['status']?.toString() ?? '';
    String target = map['target']?.toString() ?? 'pickup';
    String targetAddress = map['targetAddress']?.toString() ?? '';

    double tLat = 0.0;
    double tLng = 0.0;
    if (map['targetLocation'] is Map) {
      tLat = double.tryParse(map['targetLocation']['lat']?.toString() ?? '') ?? 0.0;
      tLng = double.tryParse(map['targetLocation']['lng']?.toString() ?? '') ?? 0.0;
    }

    double dLat = 0.0;
    double dLng = 0.0;
    if (map['driverLocation'] is Map) {
      dLat = double.tryParse(map['driverLocation']['lat']?.toString() ?? '') ?? 0.0;
      dLng = double.tryParse(map['driverLocation']['lng']?.toString() ?? '') ?? 0.0;
    }

    double dist = double.tryParse(map['distanceKm']?.toString() ?? map['distance_km']?.toString() ?? '0') ?? 0.0;
    int dur = int.tryParse(map['durationMinutes']?.toString() ?? map['duration_mins']?.toString() ?? '0') ?? 0;
    String poly = map['polyline']?.toString() ?? '';

    List<LatLng> pointsList = [];
    if (map['points'] is List) {
      for (var item in map['points']) {
        if (item is Map) {
          final lat = double.tryParse(item['lat']?.toString() ?? '');
          final lng = double.tryParse(item['lng']?.toString() ?? '');
          if (lat != null && lng != null) {
            pointsList.add(LatLng(lat, lng));
          }
        }
      }
    }

    String rName = '';
    String rPhone = '';
    if (map['rider'] is Map) {
      rName = map['rider']['fullName']?.toString() ?? map['rider']['name']?.toString() ?? map['rider']['full_name']?.toString() ?? '';
      rPhone = map['rider']['phone']?.toString() ?? map['rider']['mobileNumber']?.toString() ?? map['rider']['mobile_number']?.toString() ?? '';
    }

    return RideRouteModel(
      rideId: rideId,
      status: status,
      target: target,
      targetAddress: targetAddress,
      targetLat: tLat,
      targetLng: tLng,
      driverLat: dLat,
      driverLng: dLng,
      distanceKm: dist,
      durationMinutes: dur,
      polyline: poly,
      points: pointsList,
      riderName: rName,
      riderPhone: rPhone,
    );
  }

  /// Helper algorithm to decode Google Encoded Polyline String
  static List<LatLng> decodePolyline(String encoded) {
    List<LatLng> poly = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      poly.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return poly;
  }
}
