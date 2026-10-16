class RideHistoryItemModel {
  final String id;
  final String tripId;
  final String status;
  final String createdAt;
  final String pickupAddress;
  final String dropAddress;
  final double distance;
  final String duration;
  final String paymentMethod;
  final double fare;
  final String riderName;

  RideHistoryItemModel({
    required this.id,
    this.tripId = '',
    this.status = 'completed',
    this.createdAt = '',
    this.pickupAddress = '',
    this.dropAddress = '',
    this.distance = 0.0,
    this.duration = '',
    this.paymentMethod = 'CASH',
    this.fare = 0.0,
    this.riderName = '',
  });

  factory RideHistoryItemModel.fromJson(Map<String, dynamic> json) {
    String id = json['id']?.toString() ?? json['tripId']?.toString() ?? '';
    String tripId = json['tripId']?.toString() ?? (id.isNotEmpty ? 'TRIP-${id.substring(0, 6).toUpperCase()}' : 'TRIP-0000');
    String status = json['status']?.toString() ?? 'completed';
    String createdAt = json['createdAt']?.toString() ?? json['created_at']?.toString() ?? '';

    String pickup = '';
    if (json['pickup'] is Map) {
      pickup = json['pickup']['address']?.toString() ?? json['pickup']['name']?.toString() ?? '';
    } else {
      pickup = json['pickup']?.toString() ?? json['pickup_address']?.toString() ?? '';
    }

    String drop = '';
    if (json['drop'] is Map) {
      drop = json['drop']['address']?.toString() ?? json['drop']['name']?.toString() ?? '';
    } else {
      drop = json['drop']?.toString() ?? json['dropoff_address']?.toString() ?? '';
    }

    double dist = double.tryParse(json['distance']?.toString() ?? json['distanceKm']?.toString() ?? '0') ?? 0.0;
    String dur = json['duration']?.toString() ?? json['durationMinutes']?.toString() ?? '';
    if (dur.isNotEmpty && !dur.contains('min') && !dur.contains('hr')) {
      dur = '$dur mins';
    }
    String pay = json['paymentMethod']?.toString() ?? json['payment_method']?.toString() ?? 'CASH';
    double fare = double.tryParse(json['fare']?.toString() ?? json['finalFare']?.toString() ?? json['final_fare']?.toString() ?? '0') ?? 0.0;

    String rName = '';
    if (json['rider'] is Map) {
      rName = json['rider']['fullName']?.toString() ?? json['rider']['name']?.toString() ?? '';
    }

    return RideHistoryItemModel(
      id: id,
      tripId: tripId,
      status: status,
      createdAt: createdAt,
      pickupAddress: pickup,
      dropAddress: drop,
      distance: dist,
      duration: dur,
      paymentMethod: pay,
      fare: fare,
      riderName: rName,
    );
  }
}
