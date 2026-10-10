import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_flushbar.dart';
import '../../kyc/kyc_provider.dart';
import '../../vehicle/vehicle_provider.dart';

class DriverDashboardScreen extends ConsumerStatefulWidget {
  const DriverDashboardScreen({super.key});

  @override
  ConsumerState<DriverDashboardScreen> createState() =>
      _DriverDashboardScreenState();
}

class _DriverDashboardScreenState
    extends ConsumerState<DriverDashboardScreen> {
  bool _isOnline = false;

  @override
  Widget build(BuildContext context) {
    final kycState = ref.watch(kycProvider);
    final vehicleState = ref.watch(vehicleProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.secondary,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset(
                  'assets/images/app-logo.png',
                  width: 24,
                  height: 24,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ridonova Captain',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Verified Driver',
                  style: TextStyle(fontSize: 10, color: AppColors.primary),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () {
              AppFlushbar.info(
                context,
                title: 'Notifications',
                message: 'You have no new notifications.',
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Duty Toggle Header Card
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isOnline ? 'YOU ARE ONLINE' : 'YOU ARE OFFLINE',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _isOnline
                                  ? AppColors.success
                                  : AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _isOnline
                                ? 'Searching for nearby ride requests...'
                                : 'Toggle switch to start accepting rides',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      Switch(
                        value: _isOnline,
                        activeThumbColor: AppColors.primary,
                        activeTrackColor: AppColors.primary.withValues(alpha: 0.3),
                        onChanged: (val) {
                          setState(() {
                            _isOnline = val;
                          });
                          if (val) {
                            AppFlushbar.success(
                              context,
                              title: 'Duty Status: ONLINE',
                              message: 'You are now online and ready to receive ride requests!',
                            );
                          } else {
                            AppFlushbar.warning(
                              context,
                              title: 'Duty Status: OFFLINE',
                              message: 'You have gone offline.',
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Earnings Summary Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.secondary, Color(0xFF1E427B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Today's Earnings",
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'LIVE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '₹ 1,245.00',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(color: Colors.white24, height: 24),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _StatItem(title: 'Rides Done', value: '12'),
                        _StatItem(title: 'Hours Online', value: '5.2 hrs'),
                        _StatItem(title: 'Acceptance', value: '98%'),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              const Text(
                'Registration Summary',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),

              // Verified Info Cards
              _buildSummaryTile(
                icon: Icons.person_search,
                title: 'KYC Document Verification',
                subtitle:
                    'DL: ${kycState.kycData.drivingLicenseNumber.isNotEmpty ? kycState.kycData.drivingLicenseNumber : "DL1420110012345"}',
                isVerified: true,
              ),
              const SizedBox(height: 10),
              _buildSummaryTile(
                icon: Icons.directions_car,
                title: 'Registered Vehicle',
                subtitle:
                    '${vehicleState.vehicleData.make.isNotEmpty ? vehicleState.vehicleData.make : "Maruti"} ${vehicleState.vehicleData.model.isNotEmpty ? vehicleState.vehicleData.model : "Swift Dzire"} (${vehicleState.vehicleData.registrationNumber.isNotEmpty ? vehicleState.vehicleData.registrationNumber : "DL01AB1234"})',
                isVerified: true,
              ),

              const SizedBox(height: 20),

              const Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),

              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.5,
                children: [
                  _buildQuickActionCard(
                    title: 'My Rides',
                    subtitle: 'View history & logs',
                    icon: Icons.history,
                    color: Colors.blue,
                    onTap: () {
                      AppFlushbar.info(
                        context,
                        title: 'Ride History',
                        message: '12 rides completed today.',
                      );
                    },
                  ),
                  _buildQuickActionCard(
                    title: 'Wallet & Payouts',
                    subtitle: 'Instant Bank Transfer',
                    icon: Icons.account_balance_wallet,
                    color: Colors.green,
                    onTap: () {
                      AppFlushbar.success(
                        context,
                        title: 'Wallet Balance',
                        message: 'Available for Instant Transfer: ₹ 1,245.00',
                      );
                    },
                  ),
                  _buildQuickActionCard(
                    title: 'Incentives',
                    subtitle: 'Daily targets & bonus',
                    icon: Icons.card_giftcard,
                    color: Colors.orange,
                    onTap: () {
                      AppFlushbar.info(
                        context,
                        title: 'Incentive Goal',
                        message: 'Complete 3 more rides to earn ₹200 bonus!',
                      );
                    },
                  ),
                  _buildQuickActionCard(
                    title: 'Support',
                    subtitle: 'Help & Helpline',
                    icon: Icons.headset_mic,
                    color: Colors.purple,
                    onTap: () {
                      AppFlushbar.info(
                        context,
                        title: 'Captain Helpline',
                        message: 'Calling 24x7 Helpline Support...',
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isVerified,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (isVerified)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle, color: AppColors.success, size: 14),
                  SizedBox(width: 4),
                  Text(
                    'Active',
                    style: TextStyle(
                      color: AppColors.success,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFF1F5F9)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String title;
  final String value;

  const _StatItem({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(color: Colors.white60, fontSize: 11),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
