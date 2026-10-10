import 'package:uuid/uuid.dart';

class VehicleModel {
  final String vehicleTypeId;
  final String registrationNumber;
  final String make;
  final String model;
  final int year;
  final String color;
  final String fuelType; // "petrol", "diesel", "cng", "electric"
  final String rcDocUrl;
  final String insuranceDocUrl;
  final String insuranceExpiry;
  final String vehiclePhotoUrl;

  VehicleModel({
    String? vehicleTypeId,
    this.registrationNumber = '',
    this.make = '',
    this.model = '',
    this.year = 2022,
    this.color = '',
    this.fuelType = 'cng',
    this.rcDocUrl = '',
    this.insuranceDocUrl = '',
    this.insuranceExpiry = '',
    this.vehiclePhotoUrl = '',
  }) : vehicleTypeId = vehicleTypeId ?? const Uuid().v4();

  VehicleModel copyWith({
    String? vehicleTypeId,
    String? registrationNumber,
    String? make,
    String? model,
    int? year,
    String? color,
    String? fuelType,
    String? rcDocUrl,
    String? insuranceDocUrl,
    String? insuranceExpiry,
    String? vehiclePhotoUrl,
  }) {
    return VehicleModel(
      vehicleTypeId: vehicleTypeId ?? this.vehicleTypeId,
      registrationNumber: registrationNumber ?? this.registrationNumber,
      make: make ?? this.make,
      model: model ?? this.model,
      year: year ?? this.year,
      color: color ?? this.color,
      fuelType: fuelType ?? this.fuelType,
      rcDocUrl: rcDocUrl ?? this.rcDocUrl,
      insuranceDocUrl: insuranceDocUrl ?? this.insuranceDocUrl,
      insuranceExpiry: insuranceExpiry ?? this.insuranceExpiry,
      vehiclePhotoUrl: vehiclePhotoUrl ?? this.vehiclePhotoUrl,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'vehicleTypeId': vehicleTypeId,
      'registrationNumber': registrationNumber,
      'make': make,
      'model': model,
      'year': year,
      'color': color,
      'fuelType': fuelType,
      'rcDocUrl': rcDocUrl,
      'insuranceDocUrl': insuranceDocUrl,
      'insuranceExpiry': insuranceExpiry,
      'vehiclePhotoUrl': vehiclePhotoUrl,
    };
  }

  factory VehicleModel.fromJson(Map<String, dynamic> json) {
    return VehicleModel(
      vehicleTypeId: json['vehicleTypeId'] ?? json['vehicle_type_id'] ?? const Uuid().v4(),
      registrationNumber: json['registrationNumber'] ?? json['registration_number'] ?? '',
      make: json['make'] ?? '',
      model: json['model'] ?? '',
      year: json['year'] is int ? json['year'] : int.tryParse(json['year']?.toString() ?? '') ?? 2022,
      color: json['color'] ?? '',
      fuelType: json['fuelType'] ?? json['fuel_type'] ?? 'cng',
      rcDocUrl: json['rcDocUrl'] ?? json['rc_doc_url'] ?? '',
      insuranceDocUrl: json['insuranceDocUrl'] ?? json['insurance_doc_url'] ?? '',
      insuranceExpiry: json['insuranceExpiry'] ?? json['insurance_expiry'] ?? '',
      vehiclePhotoUrl: json['vehiclePhotoUrl'] ?? json['vehicle_photo_url'] ?? '',
    );
  }
}
