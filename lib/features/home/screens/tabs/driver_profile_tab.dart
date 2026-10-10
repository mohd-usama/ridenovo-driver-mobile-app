import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_flushbar.dart';
import '../../../auth/auth_provider.dart';
import '../../../auth/phone_login_screen.dart';
import '../../../kyc/kyc_provider.dart';
import '../../../vehicle/vehicle_provider.dart';

class DriverProfileTab extends ConsumerStatefulWidget {
  const DriverProfileTab({super.key});

  @override
  ConsumerState<DriverProfileTab> createState() => _DriverProfileTabState();
}

class _DriverProfileTabState extends ConsumerState<DriverProfileTab> {
  @override
  void initState() {
    super.initState();
    // Fetch latest profile dynamically from server on load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authProvider.notifier).fetchProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    final kycState = ref.watch(kycProvider);
    final vehicleState = ref.watch(vehicleProvider);
    final authState = ref.watch(authProvider);

    final kyc = kycState.kycData;
    final vehicle = vehicleState.vehicleData;
    final user = authState.user;

    final displayName =
        user?.fullName ??
        (kyc.fullName.isNotEmpty ? kyc.fullName : (kyc.bankAccountName.isNotEmpty ? kyc.bankAccountName : 'Captain Partner'));
    final displayPhone = user?.phone ?? authState.phoneNumber;
    final displayEmail = user?.email ?? kyc.email;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Captain Profile & Vehicle'), backgroundColor: AppColors.secondary, centerTitle: true),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Driver Profile Hero Header Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(color: AppColors.secondary, shape: BoxShape.circle),
                      child: const Icon(Icons.person_rounded, color: Colors.white, size: 38),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            displayPhone.isNotEmpty ? '+91 $displayPhone' : 'Phone not available',
                            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          ),
                          if (displayEmail.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(displayEmail, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          ],
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.verified, color: AppColors.success, size: 12),
                                    SizedBox(width: 4),
                                    Text(
                                      'VERIFIED CAPTAIN',
                                      style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 10),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Row(
                                children: [
                                  Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                                  SizedBox(width: 2),
                                  Text('5.0', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 2. Registered Vehicle Details Section
              const Text(
                'My Registered Vehicle',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 10),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.local_taxi_rounded, color: AppColors.primary, size: 26),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  vehicle.make.isNotEmpty && vehicle.model.isNotEmpty
                                      ? '${vehicle.make} ${vehicle.model}'
                                      : 'No Vehicle Registered',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
                                ),
                                Text(
                                  vehicle.registrationNumber.isNotEmpty
                                      ? 'Reg No: ${vehicle.registrationNumber} • ${vehicle.fuelType.toUpperCase()}'
                                      : 'Please register your vehicle',
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: (vehicle.registrationNumber.isNotEmpty ? AppColors.success : AppColors.textSecondary).withValues(
                                alpha: 0.12,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              vehicle.registrationNumber.isNotEmpty ? 'ACTIVE' : 'PENDING',
                              style: TextStyle(
                                color: vehicle.registrationNumber.isNotEmpty ? AppColors.success : AppColors.textSecondary,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildDetailValue('Year', '${vehicle.year}'),
                          _buildDetailValue('Color', vehicle.color.isNotEmpty ? vehicle.color : 'N/A'),
                          _buildDetailValue('RC Status', vehicle.rcDocUrl.isNotEmpty ? 'Verified' : 'Pending'),
                          _buildDetailValue('Insurance', vehicle.insuranceExpiry.isNotEmpty ? vehicle.insuranceExpiry : 'N/A'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // 3. KYC Verification Status
              const Text(
                'KYC & Document Verification',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 10),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      _buildKycDocRow(
                        title: 'Aadhar Card',
                        subtitle: kyc.aadharNumber.isNotEmpty
                            ? (kyc.aadharNumber.length > 4
                                  ? 'XXXX-XXXX-${kyc.aadharNumber.substring(kyc.aadharNumber.length - 4)}'
                                  : kyc.aadharNumber)
                            : 'Not Provided',
                        isVerified: kyc.aadharNumber.isNotEmpty,
                      ),
                      const Divider(height: 16),
                      _buildKycDocRow(
                        title: 'PAN Card',
                        subtitle: kyc.panNumber.isNotEmpty ? kyc.panNumber : 'Not Provided',
                        isVerified: kyc.panNumber.isNotEmpty,
                      ),
                      const Divider(height: 16),
                      _buildKycDocRow(
                        title: 'Driving License',
                        subtitle: kyc.drivingLicenseNumber.isNotEmpty ? kyc.drivingLicenseNumber : 'Not Provided',
                        isVerified: kyc.drivingLicenseNumber.isNotEmpty,
                      ),
                      const Divider(height: 16),
                      _buildKycDocRow(
                        title: 'Bank Account & UPI',
                        subtitle: kyc.bankName.isNotEmpty ? '${kyc.bankName} • ${kyc.upiId}' : 'Not Provided',
                        isVerified: kyc.bankName.isNotEmpty,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // 4. Quick Support & Account Settings
              const Text(
                'Account Settings & Help',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 10),

              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.language_rounded, color: AppColors.secondary),
                      title: const Text('App Language', style: TextStyle(fontSize: 14)),
                      trailing: const Text('English / Hindi', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      onTap: () {
                        AppFlushbar.info(context, title: 'Language', message: 'Language selection menu opened.');
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.headset_mic_rounded, color: AppColors.secondary),
                      title: const Text('24x7 Captain Support', style: TextStyle(fontSize: 14)),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                      onTap: () {
                        AppFlushbar.info(context, title: 'Captain Helpline', message: 'Connecting to Captain Support team...');
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.logout_rounded, color: AppColors.error),
                      title: const Text(
                        'Logout',
                        style: TextStyle(fontSize: 14, color: AppColors.error, fontWeight: FontWeight.bold),
                      ),
                      onTap: () async {
                        // Call Logout API
                        await ref.read(authProvider.notifier).logout();
                        if (context.mounted) {
                          AppFlushbar.success(context, title: 'Logged Out', message: 'You have been logged out successfully.');
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (_) => const PhoneLoginScreen()),
                            (route) => false,
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailValue(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
      ],
    );
  }

  Widget _buildKycDocRow({required String title, required String subtitle, required bool isVerified}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
            ),
            Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ],
        ),
        if (isVerified)
          const Row(
            children: [
              Icon(Icons.check_circle, color: AppColors.success, size: 16),
              SizedBox(width: 4),
              Text(
                'Verified',
                style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 11),
              ),
            ],
          ),
      ],
    );
  }
}
