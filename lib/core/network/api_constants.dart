class ApiConstants {
  static const String baseUrl = 'http://103.160.107.238:5000/api';
  static const String driverBaseUrl = 'http://103.160.107.238:5000/api/driver';
  static const String defaultDevToken = 'dev-driver-test';

  // Auth Endpoints
  static const String sendOtp = '/auth/send-otp';
  static const String verifyOtp = '/auth/verify-otp';
  static const String resendOtp = '/auth/resend-otp';
  static const String logout = '/auth/logout';

  // Driver Profile & KYC Endpoints
  static const String driverProfile = '/driver/profile';
  static const String driverKyc = '/driver/kyc';
  static const String driverVehicle = '/driver/vehicle';
  static const String dutyStatus = '/driver/duty-status';
  static const String changeEmailSendOtp = '/driver/change-email/send-otp';
  static const String changeEmailVerify = '/driver/change-email/verify';
  static const String changeMobileSendOtp = '/driver/change-mobile/send-otp';
  static const String changeMobileVerifyOld = '/driver/change-mobile/verify-old';
  static const String changeMobileVerifyNew = '/driver/change-mobile/verify-new';

  // Driver REST Execution APIs
  static const String goOnline = '/driver/online';
  static const String goOffline = '/driver/offline';
  static const String updateLocation = '/driver/location';
  static const String updateBattery = '/driver/battery';
  static const String getRideRequests = '/driver/ride-requests';

  static String acceptRideRequest(String rideId) => '/driver/riderequests/$rideId/accept';
  static String rejectRideRequest(String rideId) => '/driver/riderequests/$rideId/reject';
  static String getRideDetails(String rideId) => '/driver/rides/$rideId';
  static String getRideRoute(String rideId, double lat, double lng) => '/driver/rides/$rideId/route?lat=$lat&lng=$lng';
  static String arrivedAtPickup(String rideId) => '/driver/rides/$rideId/arrived';
  static String getWaitingCharges(String rideId) => '/driver/rides/$rideId/waiting';
  static String startRide(String rideId) => '/driver/rides/$rideId/start';
  static String completeRide(String rideId) => '/driver/rides/$rideId/complete';
  static String cancelRide(String rideId) => '/driver/rides/$rideId/cancel';
  static String rateRider(String rideId) => '/driver/rides/$rideId/rate';

  // Navigation & Places
  static const String fetchRoute = '/places/route';

  // Wallet, History & Payout
  static const String driverWallet = '/driver/wallet';
  static const String driverRides = '/driver/rides';
  static const String payoutRequest = '/driver/payout-request';
}
