import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_flushbar.dart';
import '../../../auth/auth_provider.dart';
import '../../../auth/phone_login_screen.dart';
import '../../../kyc/kyc_provider.dart';
import '../../../vehicle/vehicle_provider.dart';
import '../../../rides/ride_provider.dart';
import '../../../support/support_tickets_screen.dart';

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
        user?.fullName ?? (kyc.fullName.isNotEmpty ? kyc.fullName : (kyc.bankAccountName.isNotEmpty ? kyc.bankAccountName : 'Captain Partner'));
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
                            decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
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
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const SupportTicketsScreen()));
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.privacy_tip_rounded, color: AppColors.secondary),
                      title: const Text('Privacy Policy', style: TextStyle(fontSize: 14)),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                      onTap: () {
                        _showPrivacyPolicyDialog(context);
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.delete_forever_rounded, color: AppColors.error),
                      title: const Text(
                        'Delete Account',
                        style: TextStyle(fontSize: 14, color: AppColors.error, fontWeight: FontWeight.bold),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                      onTap: () {
                        _showDeleteAccountBottomSheet(context, ref);
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.logout_rounded, color: AppColors.error),
                      title: const Text(
                        'Logout',
                        style: TextStyle(fontSize: 14, color: AppColors.error, fontWeight: FontWeight.bold),
                      ),
                      onTap: () {
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (dialogContext) {
                            bool isLoggingOut = false;
                            return StatefulBuilder(
                              builder: (context, setDialogState) {
                                return AlertDialog(
                                  title: const Text('Logout?'),
                                  content: const Text(
                                    'Are you sure you want to logout? You will be set offline and all active processes will be closed.',
                                  ),
                                  actions: [
                                    TextButton(onPressed: isLoggingOut ? null : () => Navigator.pop(dialogContext), child: const Text('CANCEL')),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                                      onPressed: isLoggingOut
                                          ? null
                                          : () async {
                                              setDialogState(() {
                                                isLoggingOut = true;
                                              });

                                              // 1. Go offline and stop all timers/processes in ride provider
                                              await ref.read(rideProvider.notifier).goOffline();

                                              // 2. Call auth logout & clear session
                                              await ref.read(authProvider.notifier).logout();

                                              // 3. Clear duty status in SharedPreferences explicitly
                                              try {
                                                final prefs = await SharedPreferences.getInstance();
                                                await prefs.setBool('is_duty_online', false);
                                                await prefs.remove('is_duty_online');
                                              } catch (_) {}

                                              if (context.mounted) {
                                                Navigator.pop(dialogContext);
                                                AppFlushbar.success(
                                                  context,
                                                  title: 'Logged Out 🔴',
                                                  message: 'You have been logged out successfully.',
                                                );
                                                Navigator.pushAndRemoveUntil(
                                                  context,
                                                  MaterialPageRoute(builder: (_) => const PhoneLoginScreen()),
                                                  (route) => false,
                                                );
                                              }
                                            },
                                      child: isLoggingOut
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                            )
                                          : const Text('YES, LOGOUT'),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        );
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

  void _showPrivacyPolicyDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.all(20),
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Privacy Policy - Ridonova Driver',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
                  ],
                ),
                const Divider(),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Effective Date: October 17, 2026',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Ridonova ("we", "our", or "us") operates the Ridonova Driver Mobile Application. This Privacy Policy informs you regarding the collection, use, and disclosure of personal data when you use our app.',
                          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                        SizedBox(height: 12),
                        Text(
                          '1. Information We Collect',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '• Personal Data: Full name, phone number (7978800300), email (support@ridonova.com).\n'
                          '• KYC Documents: Aadhar, PAN, Driving License.\n'
                          '• Vehicle Information: Registration number, insurance, RC details.\n'
                          '• Precise Location: Real-time GPS location data when online on duty for ride matching, navigation, and trip tracking.\n'
                          '• Financial Information: Bank account number, IFSC code, and UPI ID for instant daily payouts.',
                          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                        SizedBox(height: 12),
                        Text(
                          '2. How We Use Your Information',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'We use your data to verify KYC compliance, connect you with nearby riders, calculate earnings, process instant cashouts, and provide 24/7 support assistance.',
                          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                        SizedBox(height: 12),
                        Text(
                          '3. Contact Us',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                        ),
                        SizedBox(height: 4),
                        Text('Email: support@ridonova.com\nPhone: 7978800300', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final url = Uri.parse('http://103.160.107.238:5000/privacy-policy.html');
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url, mode: LaunchMode.externalApplication);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('OPEN FULL WEB PRIVACY POLICY', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDeleteAccountBottomSheet(BuildContext context, WidgetRef ref) async {
    List<Map<String, dynamic>> reasons = [];
    try {
      reasons = await ref.read(authProvider.notifier).fetchDeletionReasons();
    } catch (_) {}

    if (reasons.isEmpty) {
      reasons = [
        {"id": "low_earnings", "label": "Earnings are lower than expected"},
        {"id": "switching_platform", "label": "Switching to another platform / company"},
        {"id": "vehicle_issues", "label": "Vehicle sold or no longer available"},
        {"id": "personal_reasons", "label": "Personal or health reasons"},
        {"id": "other", "label": "Other (Please describe)"},
      ];
    }

    String selectedReasonId = reasons.first['id'];
    final feedbackController = TextEditingController();
    bool isDeleting = false;

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return SafeArea(
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return Padding(
                padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 26),
                        SizedBox(width: 10),
                        Text(
                          'Permanently Delete Account',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.error),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This action is permanent and cannot be undone. All your profile data, KYC, and earnings history will be permanently deleted.',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Please select a reason for leaving:',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 180,
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: reasons.length,
                        itemBuilder: (context, index) {
                          final r = reasons[index];
                          return RadioListTile<String>(
                            title: Text(r['label'] ?? '', style: const TextStyle(fontSize: 13)),
                            value: r['id'],
                            groupValue: selectedReasonId,
                            activeColor: AppColors.error,
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            onChanged: (val) {
                              if (val != null) {
                                setModalState(() {
                                  selectedReasonId = val;
                                });
                              }
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: feedbackController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Additional feedback (Optional)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: isDeleting
                            ? null
                            : () async {
                                setModalState(() {
                                  isDeleting = true;
                                });

                                final response = await ref
                                    .read(authProvider.notifier)
                                    .deleteAccount(
                                      reason: selectedReasonId,
                                      feedback: feedbackController.text.trim().isNotEmpty ? feedbackController.text.trim() : null,
                                    );

                                if (!context.mounted) return;

                                if (response.isSuccess) {
                                  Navigator.pop(context); // close sheet
                                  AppFlushbar.success(
                                    context,
                                    title: 'Account Deleted 🔴',
                                    message: 'Your account has been permanently deleted.',
                                  );
                                  Navigator.pushAndRemoveUntil(
                                    context,
                                    MaterialPageRoute(builder: (_) => const PhoneLoginScreen()),
                                    (route) => false,
                                  );
                                } else {
                                  setModalState(() {
                                    isDeleting = false;
                                  });
                                  Navigator.pop(context); // close sheet
                                  AppFlushbar.error(
                                    context,
                                    title: 'Deletion Failed',
                                    message: response.errorMessage ?? 'Could not delete account. Make sure you have no active rides.',
                                  );
                                }
                              },
                        child: isDeleting
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('CONFIRM PERMANENT DELETE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
