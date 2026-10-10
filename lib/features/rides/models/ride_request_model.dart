class RideRequestModel {
  final String id;
  final String pickupAddress;
  final double pickupLat;
  final double pickupLng;
  final String dropAddress;
  final double dropLat;
  final double dropLng;
  final double fare;
  final String distance;
  final String duration;
  final String riderName;
  final String riderPhone;
  final String status; // requested, accepted, arrived, started, completed, cancelled
  final String? otp;

  RideRequestModel({
    required this.id,
    this.pickupAddress = '',
    this.pickupLat = 0.0,
    this.pickupLng = 0.0,
    this.dropAddress = '',
    this.dropLat = 0.0,
    this.dropLng = 0.0,
    this.fare = 0.0,
    this.distance = '',
    this.duration = '',
    this.riderName = '',
    this.riderPhone = '',
    this.status = 'requested',
    this.otp,
  });

  static RideRequestModel? tryParse(dynamic json) {
    if (json == null) return null;
    final map = (json is Map) ? (json['data'] ?? json['result'] ?? json) : null;
    if (map == null || map is! Map<String, dynamic>) return null;

    final id = map['id']?.toString() ?? map['rideId']?.toString() ?? map['ride_id']?.toString();
    if (id == null || id.isEmpty) {
      return null;
    }

    return RideRequestModel.fromJson(map);
  }

  factory RideRequestModel.fromJson(Map<String, dynamic> json) {
    final map = (json['data'] is Map<String, dynamic>) ? json['data'] : ((json['result'] is Map<String, dynamic>) ? json['result'] : json);

    String id = map['id']?.toString() ?? map['rideId']?.toString() ?? map['ride_id']?.toString() ?? '';

    // Extract pickup
    String pAddress = '';
    double pLat = 0.0;
    double pLng = 0.0;
    if (map['pickup'] is Map) {
      pAddress = map['pickup']['address']?.toString() ?? map['pickup']['name']?.toString() ?? '';
      pLat = double.tryParse(map['pickup']['lat']?.toString() ?? '') ?? 0.0;
      pLng = double.tryParse(map['pickup']['lng']?.toString() ?? '') ?? 0.0;
    } else {
      pAddress = map['pickupLocation']?.toString() ?? map['pickup_address']?.toString() ?? map['pickupAddress']?.toString() ?? '';
      pLat = double.tryParse(map['pickupLat']?.toString() ?? map['pickup_lat']?.toString() ?? '') ?? 0.0;
      pLng = double.tryParse(map['pickupLng']?.toString() ?? map['pickup_lng']?.toString() ?? '') ?? 0.0;
    }

    // Extract drop
    String dAddress = '';
    double dLat = 0.0;
    double dLng = 0.0;
    if (map['drop'] is Map) {
      dAddress = map['drop']['address']?.toString() ?? map['drop']['name']?.toString() ?? '';
      dLat = double.tryParse(map['drop']['lat']?.toString() ?? '') ?? 0.0;
      dLng = double.tryParse(map['drop']['lng']?.toString() ?? '') ?? 0.0;
    } else {
      dAddress = map['dropLocation']?.toString() ?? map['drop_address']?.toString() ?? map['dropAddress']?.toString() ?? '';
      dLat = double.tryParse(map['dropLat']?.toString() ?? map['drop_lat']?.toString() ?? '') ?? 0.0;
      dLng = double.tryParse(map['dropLng']?.toString() ?? map['drop_lng']?.toString() ?? '') ?? 0.0;
    }

    // Extract rider info
    String rName = '';
    String rPhone = '';
    if (map['rider'] is Map) {
      rName = map['rider']['name']?.toString() ?? map['rider']['fullName']?.toString() ?? map['rider']['full_name']?.toString() ?? '';
      rPhone =
          map['rider']['phone']?.toString() ?? map['rider']['mobileNumber']?.toString() ?? map['rider']['mobile_number']?.toString() ?? '';
    } else if (map['user'] is Map) {
      rName = map['user']['name']?.toString() ?? map['user']['fullName']?.toString() ?? map['user']['full_name']?.toString() ?? '';
      rPhone =
          map['user']['phone']?.toString() ?? map['user']['mobileNumber']?.toString() ?? map['user']['mobile_number']?.toString() ?? '';
    } else {
      rName = map['riderName']?.toString() ?? map['rider_name']?.toString() ?? map['userName']?.toString() ?? '';
      rPhone = map['riderPhone']?.toString() ?? map['rider_phone']?.toString() ?? map['userPhone']?.toString() ?? '';
    }

    return RideRequestModel(
      id: id,
      pickupAddress: pAddress,
      pickupLat: pLat,
      pickupLng: pLng,
      dropAddress: dAddress,
      dropLat: dLat,
      dropLng: dLng,
      fare:
          double.tryParse(map['fare']?.toString() ?? map['estimatedFare']?.toString() ?? map['estimated_fare']?.toString() ?? '0.0') ?? 0.0,
      distance: map['distance']?.toString() ?? map['estimatedDistance']?.toString() ?? map['estimated_distance']?.toString() ?? '',
      duration: map['duration']?.toString() ?? map['estimatedDuration']?.toString() ?? map['estimated_duration']?.toString() ?? '',
      riderName: rName,
      riderPhone: rPhone,
      status: map['status']?.toString() ?? 'requested',
      otp: map['otp']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'pickupAddress': pickupAddress,
      'pickupLat': pickupLat,
      'pickupLng': pickupLng,
      'dropAddress': dropAddress,
      'dropLat': dropLat,
      'dropLng': dropLng,
      'fare': fare,
      'distance': distance,
      'duration': duration,
      'riderName': riderName,
      'riderPhone': riderPhone,
      'status': status,
      'otp': otp,
    };
  }

  RideRequestModel copyWith({
    String? id,
    String? pickupAddress,
    double? pickupLat,
    double? pickupLng,
    String? dropAddress,
    double? dropLat,
    double? dropLng,
    double? fare,
    String? distance,
    String? duration,
    String? riderName,
    String? riderPhone,
    String? status,
    String? otp,
  }) {
    return RideRequestModel(
      id: id ?? this.id,
      pickupAddress: pickupAddress ?? this.pickupAddress,
      pickupLat: pickupLat ?? this.pickupLat,
      pickupLng: pickupLng ?? this.pickupLng,
      dropAddress: dropAddress ?? this.dropAddress,
      dropLat: dropLat ?? this.dropLat,
      dropLng: dropLng ?? this.dropLng,
      fare: fare ?? this.fare,
      distance: distance ?? this.distance,
      duration: duration ?? this.duration,
      riderName: riderName ?? this.riderName,
      riderPhone: riderPhone ?? this.riderPhone,
      status: status ?? this.status,
      otp: otp ?? this.otp,
    );
  }
}
