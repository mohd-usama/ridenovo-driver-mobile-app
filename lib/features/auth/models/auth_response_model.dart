class AuthResponseModel {
  final bool success;
  final String message;
  final AuthData? data;

  AuthResponseModel({
    required this.success,
    required this.message,
    this.data,
  });

  factory AuthResponseModel.fromJson(Map<String, dynamic> json) {
    return AuthResponseModel(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data: json['data'] != null ? AuthData.fromJson(json['data']) : null,
    );
  }
}

class AuthData {
  final String? token;
  final UserModel? user;
  final SessionModel? session;
  final int? retryAfter;

  AuthData({
    this.token,
    this.user,
    this.session,
    this.retryAfter,
  });

  factory AuthData.fromJson(Map<String, dynamic> json) {
    return AuthData(
      token: json['token'],
      user: json['user'] != null ? UserModel.fromJson(json['user']) : null,
      session: json['session'] != null ? SessionModel.fromJson(json['session']) : null,
      retryAfter: json['retryAfter'],
    );
  }
}

class UserModel {
  final String id;
  final String phone;
  final String? fullName;
  final String? email;
  final String role;
  final String? profilePhoto;
  final bool isNewUser;

  UserModel({
    required this.id,
    required this.phone,
    this.fullName,
    this.email,
    required this.role,
    this.profilePhoto,
    required this.isNewUser,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      phone: json['phone'] ?? '',
      fullName: json['fullName'],
      email: json['email'],
      role: json['role'] ?? 'driver',
      profilePhoto: json['profilePhoto'],
      isNewUser: json['isNewUser'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phone': phone,
      'fullName': fullName,
      'email': email,
      'role': role,
      'profilePhoto': profilePhoto,
      'isNewUser': isNewUser,
    };
  }

  UserModel copyWith({
    String? id,
    String? phone,
    String? fullName,
    String? email,
    String? role,
    String? profilePhoto,
    bool? isNewUser,
  }) {
    return UserModel(
      id: id ?? this.id,
      phone: phone ?? this.phone,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      role: role ?? this.role,
      profilePhoto: profilePhoto ?? this.profilePhoto,
      isNewUser: isNewUser ?? this.isNewUser,
    );
  }
}

class SessionModel {
  final String id;
  final String expiresAt;
  final String deviceName;

  SessionModel({
    required this.id,
    required this.expiresAt,
    required this.deviceName,
  });

  factory SessionModel.fromJson(Map<String, dynamic> json) {
    return SessionModel(
      id: json['id'] ?? '',
      expiresAt: json['expiresAt'] ?? '',
      deviceName: json['deviceName'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'expiresAt': expiresAt,
      'deviceName': deviceName,
    };
  }
}
