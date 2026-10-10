class KycModel {
  final String fullName;
  final String email;
  final String mobileNumber;
  final String profilePhoto;
  final String aadharNumber;
  final String aadharDocUrl;
  final String panNumber;
  final String panDocUrl;
  final String drivingLicenseNumber;
  final String drivingLicenseDocUrl;
  final String drivingLicenseExpiry;
  final String bankAccountName;
  final String bankAccountNumber;
  final String bankIfscCode;
  final String bankName;
  final String upiId;

  KycModel({
    this.fullName = '',
    this.email = '',
    this.mobileNumber = '',
    this.profilePhoto = '',
    this.aadharNumber = '',
    this.aadharDocUrl = '',
    this.panNumber = '',
    this.panDocUrl = '',
    this.drivingLicenseNumber = '',
    this.drivingLicenseDocUrl = '',
    this.drivingLicenseExpiry = '',
    this.bankAccountName = '',
    this.bankAccountNumber = '',
    this.bankIfscCode = '',
    this.bankName = '',
    this.upiId = '',
  });

  KycModel copyWith({
    String? fullName,
    String? email,
    String? mobileNumber,
    String? profilePhoto,
    String? aadharNumber,
    String? aadharDocUrl,
    String? panNumber,
    String? panDocUrl,
    String? drivingLicenseNumber,
    String? drivingLicenseDocUrl,
    String? drivingLicenseExpiry,
    String? bankAccountName,
    String? bankAccountNumber,
    String? bankIfscCode,
    String? bankName,
    String? upiId,
  }) {
    return KycModel(
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      profilePhoto: profilePhoto ?? this.profilePhoto,
      aadharNumber: aadharNumber ?? this.aadharNumber,
      aadharDocUrl: aadharDocUrl ?? this.aadharDocUrl,
      panNumber: panNumber ?? this.panNumber,
      panDocUrl: panDocUrl ?? this.panDocUrl,
      drivingLicenseNumber: drivingLicenseNumber ?? this.drivingLicenseNumber,
      drivingLicenseDocUrl: drivingLicenseDocUrl ?? this.drivingLicenseDocUrl,
      drivingLicenseExpiry: drivingLicenseExpiry ?? this.drivingLicenseExpiry,
      bankAccountName: bankAccountName ?? this.bankAccountName,
      bankAccountNumber: bankAccountNumber ?? this.bankAccountNumber,
      bankIfscCode: bankIfscCode ?? this.bankIfscCode,
      bankName: bankName ?? this.bankName,
      upiId: upiId ?? this.upiId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fullName': fullName,
      'email': email,
      'mobileNumber': mobileNumber,
      'profilePhoto': profilePhoto,
      'aadharNumber': aadharNumber,
      'aadharDocUrl': aadharDocUrl,
      'panNumber': panNumber,
      'panDocUrl': panDocUrl,
      'drivingLicenseNumber': drivingLicenseNumber,
      'drivingLicenseDocUrl': drivingLicenseDocUrl,
      'drivingLicenseExpiry': drivingLicenseExpiry,
      'bankAccountName': bankAccountName,
      'bankAccountNumber': bankAccountNumber,
      'bankIfscCode': bankIfscCode,
      'bankName': bankName,
      'upiId': upiId,
    };
  }

  factory KycModel.fromJson(Map<String, dynamic> json) {
    return KycModel(
      fullName: json['fullName'] ?? json['full_name'] ?? '',
      email: json['email'] ?? '',
      mobileNumber: json['phone'] ?? json['mobileNumber'] ?? json['mobile_number'] ?? '',
      profilePhoto: json['profilePhoto'] ?? json['profile_photo'] ?? json['profilePhotoUrl'] ?? '',
      aadharNumber: json['aadharNumber'] ?? json['aadhar_number'] ?? '',
      aadharDocUrl: json['aadharDocUrl'] ?? json['aadhar_doc_url'] ?? '',
      panNumber: json['panNumber'] ?? json['pan_number'] ?? '',
      panDocUrl: json['panDocUrl'] ?? json['pan_doc_url'] ?? '',
      drivingLicenseNumber: json['drivingLicenseNumber'] ?? json['driving_license_number'] ?? '',
      drivingLicenseDocUrl: json['drivingLicenseDocUrl'] ?? json['driving_license_doc_url'] ?? '',
      drivingLicenseExpiry: json['drivingLicenseExpiry'] ?? json['driving_license_expiry'] ?? '',
      bankAccountName: json['bankAccountName'] ?? json['bank_account_name'] ?? '',
      bankAccountNumber: json['bankAccountNumber'] ?? json['bank_account_number'] ?? '',
      bankIfscCode: json['bankIfscCode'] ?? json['bank_ifsc_code'] ?? '',
      bankName: json['bankName'] ?? json['bank_name'] ?? '',
      upiId: json['upiId'] ?? json['upi_id'] ?? '',
    );
  }
}
