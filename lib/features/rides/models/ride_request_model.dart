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
  final String vehicleType;
  final String paymentMethod;
  final String status; // searching, requested, accepted, arrived, started, completed, cancelled
  final String? otp;
  // 🟢 Nayi Fields (Rapido - Book for Someone Else)
  final bool isForSomeoneElse;
  final String passengerName;
  final String passengerPhone;
  final String bookedByName;
  final String bookedByPhone;

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
    this.vehicleType = '',
    this.paymentMethod = 'CASH',
    this.status = 'requested',
    this.otp,
    // 🟢 Constructor defaults
    this.isForSomeoneElse = false,
    this.passengerName = '',
    this.passengerPhone = '',
    this.bookedByName = '',
    this.bookedByPhone = '',
  });

  static RideRequestModel? tryParse(dynamic json) {
    if (json == null) return null;
    var map = (json is Map) ? (json['data'] ?? json['result'] ?? json) : null;
    if (map == null || map is! Map) return null;

    final mapDynamic = Map<String, dynamic>.from(map);

    // If map itself contains a nested list under 'requests', 'rideRequests', or 'rides'
    if (mapDynamic.containsKey('requests') && mapDynamic['requests'] is List && (mapDynamic['requests'] as List).isNotEmpty) {
      return RideRequestModel.tryParse(mapDynamic['requests'][0]);
    }

    final id = mapDynamic['id']?.toString() ?? mapDynamic['rideId']?.toString() ?? mapDynamic['ride_id']?.toString();
    if (id == null || id.isEmpty) {
      return null;
    }

    return RideRequestModel.fromJson(mapDynamic);
  }

  factory RideRequestModel.fromJson(Map<String, dynamic> json) {
    var rawMap = (json['data'] is Map<String, dynamic>) ? json['data'] : ((json['result'] is Map<String, dynamic>) ? json['result'] : json);

    if (rawMap is Map) {
      if (rawMap['ride'] is Map) {
        rawMap = rawMap['ride'];
      } else if (rawMap['rideDetails'] is Map) {
        rawMap = rawMap['rideDetails'];
      } else if (rawMap['request'] is Map) {
        rawMap = rawMap['request'];
      }
    }

    final map = Map<String, dynamic>.from(rawMap is Map ? rawMap : json);

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
      pAddress = map['pickup'] is String ? map['pickup'] : (map['pickupLocation']?.toString() ?? map['pickup_address']?.toString() ?? map['pickupAddress']?.toString() ?? '');
      pLat = double.tryParse(map['pickup_lat']?.toString() ?? map['pickupLat']?.toString() ?? (map['pickupLocation'] is Map ? map['pickupLocation']['lat']?.toString() : '') ?? '') ?? 0.0;
      pLng = double.tryParse(map['pickup_lng']?.toString() ?? map['pickupLng']?.toString() ?? (map['pickupLocation'] is Map ? map['pickupLocation']['lng']?.toString() : '') ?? '') ?? 0.0;
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
      dAddress = map['drop'] is String ? map['drop'] : (map['dropLocation']?.toString() ?? map['dropoff_address']?.toString() ?? map['dropAddress']?.toString() ?? '');
      dLat = double.tryParse(map['dropoff_lat']?.toString() ?? map['dropLat']?.toString() ?? (map['dropoffLocation'] is Map ? map['dropoffLocation']['lat']?.toString() : '') ?? '') ?? 0.0;
      dLng = double.tryParse(map['dropoff_lng']?.toString() ?? map['dropLng']?.toString() ?? (map['dropoffLocation'] is Map ? map['dropoffLocation']['lng']?.toString() : '') ?? '') ?? 0.0;
    }

    // Extract rider info
    String rName = '';
    String rPhone = '';
    if (map['rider'] is Map) {
      rName = map['rider']['fullName']?.toString() ?? map['rider']['name']?.toString() ?? map['rider']['full_name']?.toString() ?? '';
      rPhone = map['rider']['phone']?.toString() ?? map['rider']['mobileNumber']?.toString() ?? map['rider']['mobile_number']?.toString() ?? '';
    } else if (map['driver'] is Map && map['rider'] == null) {
      // Sometimes driver object is present
    } else if (map['user'] is Map) {
      rName = map['user']['fullName']?.toString() ?? map['user']['name']?.toString() ?? map['user']['full_name']?.toString() ?? '';
      rPhone = map['user']['phone']?.toString() ?? map['user']['mobileNumber']?.toString() ?? map['user']['mobile_number']?.toString() ?? '';
    } else {
      rName = map['riderName']?.toString() ?? map['rider_name']?.toString() ?? map['userName']?.toString() ?? '';
      rPhone = map['riderPhone']?.toString() ?? map['rider_phone']?.toString() ?? map['userPhone']?.toString() ?? '';
    }

    // Distance formatting
    String dist = map['distance']?.toString() ?? map['estimatedDistance']?.toString() ?? map['estimated_distance']?.toString() ?? '';
    if (dist.isEmpty && map['distance_km'] != null) {
      dist = '${map['distance_km']} km';
    } else if (dist.isEmpty && map['distanceKm'] != null) {
      dist = '${map['distanceKm']} km';
    }

    // Duration formatting
    String dur = map['duration']?.toString() ?? map['estimatedDuration']?.toString() ?? map['estimated_duration']?.toString() ?? '';
    if (dur.isEmpty && map['duration_minutes'] != null) {
      dur = '${map['duration_minutes']} mins';
    } else if (dur.isEmpty && map['durationMins'] != null) {
      dur = '${map['durationMins']} mins';
    }

    String vType = map['vehicleType']?.toString() ?? map['vehicle_type']?.toString() ?? '';
    String pMethod = map['paymentMethod']?.toString() ?? map['payment_method']?.toString() ?? 'CASH';

    // Fare Amount Extraction
    double fareAmt = double.tryParse(map['fare']?.toString() ??
            map['final_fare']?.toString() ??
            map['estimatedFare']?.toString() ??
            map['estimated_fare']?.toString() ??
            map['amount']?.toString() ??
            map['totalFare']?.toString() ??
            '0.0') ??
        0.0;

    String? otpVal = map['otp']?.toString() ?? map['otp_code']?.toString();

    // 🟢 Someone Else Extraction
    final bool isSomeoneElse = map['isForSomeoneElse'] == true || 
                               map['isBookedForSomeoneElse'] == true ||
                               map['bookingType'] == 'someone_else';
    final String passName = map['passengerName']?.toString() ?? 
                            (map['passenger'] is Map ? map['passenger']['name']?.toString() : null) ?? '';
    final String passPhone = map['passengerPhone']?.toString() ?? 
                             (map['passenger'] is Map ? map['passenger']['phone']?.toString() : null) ?? '';
    final String bookerName = (map['bookedBy'] is Map ? map['bookedBy']['name']?.toString() : null) ?? rName;
    final String bookerPhone = (map['bookedBy'] is Map ? map['bookedBy']['phone']?.toString() : null) ?? rPhone;

    return RideRequestModel(
      id: id,
      pickupAddress: pAddress,
      pickupLat: pLat,
      pickupLng: pLng,
      dropAddress: dAddress,
      dropLat: dLat,
      dropLng: dLng,
      fare: fareAmt,
      distance: dist,
      duration: dur,
      riderName: rName,
      riderPhone: rPhone,
      vehicleType: vType,
      paymentMethod: pMethod,
      status: map['status']?.toString() ?? 'requested',
      otp: otpVal,
      // 🟢 Pass parsed values
      isForSomeoneElse: isSomeoneElse,
      passengerName: passName,
      passengerPhone: passPhone,
      bookedByName: bookerName,
      bookedByPhone: bookerPhone,
    );
  }

  /// Merges current request model with another, preserving non-empty existing data
  RideRequestModel mergeWith(RideRequestModel other) {
    return RideRequestModel(
      id: other.id.isNotEmpty ? other.id : id,
      pickupAddress: other.pickupAddress.isNotEmpty ? other.pickupAddress : pickupAddress,
      pickupLat: other.pickupLat != 0.0 ? other.pickupLat : pickupLat,
      pickupLng: other.pickupLng != 0.0 ? other.pickupLng : dropLng,
      dropAddress: other.dropAddress.isNotEmpty ? other.dropAddress : dropAddress,
      dropLat: other.dropLat != 0.0 ? other.dropLat : dropLat,
      dropLng: other.dropLng != 0.0 ? other.dropLng : dropLng,
      fare: other.fare > 0.0 ? other.fare : fare,
      distance: other.distance.isNotEmpty ? other.distance : distance,
      duration: other.duration.isNotEmpty ? other.duration : duration,
      riderName: other.riderName.isNotEmpty ? other.riderName : riderName,
      riderPhone: other.riderPhone.isNotEmpty ? other.riderPhone : riderPhone,
      vehicleType: other.vehicleType.isNotEmpty ? other.vehicleType : vehicleType,
      paymentMethod: other.paymentMethod.isNotEmpty ? other.paymentMethod : paymentMethod,
      status: other.status.isNotEmpty ? other.status : status,
      otp: other.otp ?? otp,
      isForSomeoneElse: other.isForSomeoneElse || isForSomeoneElse,
      passengerName: other.passengerName.isNotEmpty ? other.passengerName : passengerName,
      passengerPhone: other.passengerPhone.isNotEmpty ? other.passengerPhone : passengerPhone,
      bookedByName: other.bookedByName.isNotEmpty ? other.bookedByName : bookedByName,
      bookedByPhone: other.bookedByPhone.isNotEmpty ? other.bookedByPhone : bookedByPhone,
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
      'vehicleType': vehicleType,
      'paymentMethod': paymentMethod,
      'status': status,
      'otp': otp,
      'isForSomeoneElse': isForSomeoneElse,
      'passengerName': passengerName,
      'passengerPhone': passengerPhone,
      'bookedByName': bookedByName,
      'bookedByPhone': bookedByPhone,
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
    String? vehicleType,
    String? paymentMethod,
    String? status,
    String? otp,
    bool? isForSomeoneElse,
    String? passengerName,
    String? passengerPhone,
    String? bookedByName,
    String? bookedByPhone,
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
      vehicleType: vehicleType ?? this.vehicleType,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      status: status ?? this.status,
      otp: otp ?? this.otp,
      isForSomeoneElse: isForSomeoneElse ?? this.isForSomeoneElse,
      passengerName: passengerName ?? this.passengerName,
      passengerPhone: passengerPhone ?? this.passengerPhone,
      bookedByName: bookedByName ?? this.bookedByName,
      bookedByPhone: bookedByPhone ?? this.bookedByPhone,
    );
  }
}
