import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_flushbar.dart';
import '../../../wallet/wallet_provider.dart';
import '../../../wallet/wallet_model.dart';

class DriverEarningsTab extends ConsumerStatefulWidget {
  const DriverEarningsTab({super.key});

  @override
  ConsumerState<DriverEarningsTab> createState() => _DriverEarningsTabState();
}

class _DriverEarningsTabState extends ConsumerState<DriverEarningsTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(walletProvider.notifier).fetchWalletEarnings();
      ref.read(walletProvider.notifier).fetchPayouts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final walletState = ref.watch(walletProvider);
    final wallet = walletState.wallet;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Earnings & Wallet'),
        backgroundColor: AppColors.secondary,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Payout History',
            onPressed: () => _showPayoutHistorySheet(context, walletState.payouts),
          ),
          IconButton(
            icon: walletState.status == WalletStatus.loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref.read(walletProvider.notifier).fetchWalletEarnings();
              ref.read(walletProvider.notifier).fetchPayouts();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await ref.read(walletProvider.notifier).fetchWalletEarnings();
            await ref.read(walletProvider.notifier).fetchPayouts();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Warning Banner if balance is in warning or negative range
                if (wallet.balance < 0)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: wallet.balance <= -1000
                          ? Colors.red.shade50
                          : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: wallet.balance <= -1000
                            ? Colors.red.shade300
                            : Colors.orange.shade300,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          wallet.balance <= -1000 ? Icons.block_rounded : Icons.warning_amber_rounded,
                          color: wallet.balance <= -1000 ? Colors.red : Colors.orange.shade800,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            wallet.balance <= -1000
                                ? 'Your balance is ₹${wallet.balance.toStringAsFixed(2)}. Ride acceptance is blocked until dues are cleared.'
                                : 'Wallet dues: ₹${wallet.balance.toStringAsFixed(2)}. Please clear dues to avoid ride blocking.',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: wallet.balance <= -1000 ? Colors.red.shade900 : Colors.orange.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // 1. Wallet Balance Hero Card
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
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.secondary.withValues(alpha: 0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Available Wallet Balance',
                            style: TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: wallet.walletStatus == 'active'
                                  ? Colors.green.withValues(alpha: 0.3)
                                  : Colors.orange.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              wallet.walletStatusText,
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        wallet.formattedBalance.isNotEmpty ? wallet.formattedBalance : '₹ ${wallet.availableBalance.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.account_balance_outlined, color: Colors.white70, size: 14),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${wallet.bankDetails.bankName} (${wallet.bankDetails.accountNumber})',
                              style: const TextStyle(color: Colors.white70, fontSize: 11),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: walletState.isPayoutLoading
                              ? null
                              : () => _showInstantCashoutDialog(context, ref, wallet),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: walletState.isPayoutLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.flash_on_rounded, size: 18),
                          label: const Text(
                            'INSTANT CASHOUT TO BANK',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 2. Today's Earnings Breakdown Grid
                const Text(
                  "Today's Overview",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: _buildEarningMiniCard(
                        title: 'Net Earnings',
                        amount: wallet.today.formattedNetEarnings.isNotEmpty
                            ? wallet.today.formattedNetEarnings
                            : '₹ ${wallet.today.netEarnings.toStringAsFixed(2)}',
                        icon: Icons.payments_outlined,
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildEarningMiniCard(
                        title: 'Cash Collected',
                        amount: wallet.today.formattedCashCollected.isNotEmpty
                            ? wallet.today.formattedCashCollected
                            : '₹ ${wallet.today.cashCollected.toStringAsFixed(2)}',
                        icon: Icons.money_outlined,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildEarningMiniCard(
                        title: 'Trips Completed',
                        amount: '${wallet.today.tripsCompleted} Trips',
                        icon: Icons.done_all_rounded,
                        color: AppColors.secondary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildEarningMiniCard(
                        title: 'Platform Commission',
                        amount: '₹ ${wallet.today.platformCommission.toStringAsFixed(2)}',
                        icon: Icons.remove_circle_outline_rounded,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // 3. Daily Target & Incentive Progress Card
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.card_giftcard_rounded,
                                  color: AppColors.primary, size: 22),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    wallet.dailyIncentive.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    wallet.dailyIncentive.subtitle,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        LinearProgressIndicator(
                          value: (wallet.dailyIncentive.progressPercentage / 100.0).clamp(0.0, 1.0),
                          backgroundColor: const Color(0xFFE2E8F0),
                          color: AppColors.primary,
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              wallet.dailyIncentive.progressText.isNotEmpty
                                  ? wallet.dailyIncentive.progressText
                                  : '${wallet.dailyIncentive.completedTrips} of ${wallet.dailyIncentive.targetTrips} trips completed',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                            Text(
                              wallet.dailyIncentive.remainingText.isNotEmpty
                                  ? wallet.dailyIncentive.remainingText
                                  : '${wallet.dailyIncentive.remainingTrips} trips left',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryDark,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // 4. Weekly Summary List
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Weekly Summary',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Last 7 Days',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (wallet.weeklySummary.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Text('No weekly earnings summary available.'),
                    ),
                  )
                else
                  ...wallet.weeklySummary.map((item) => _buildDayEarningTile(
                        day: item.day.isNotEmpty ? item.day : item.dayName,
                        rides: '${item.trips} Trips',
                        amount: item.formattedEarnings.isNotEmpty ? item.formattedEarnings : '₹ ${item.earnings.toStringAsFixed(2)}',
                      )),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEarningMiniCard({
    required String title,
    required String amount,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 2),
          Text(
            amount,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayEarningTile({
    required String day,
    required String rides,
    required String amount,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                day,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                rides,
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          ),
          Text(
            amount,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  void _showInstantCashoutDialog(BuildContext context, WidgetRef ref, WalletModel wallet) {
    final amountController = TextEditingController(text: wallet.availableBalance.toStringAsFixed(2));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Instant Cashout to Bank',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  Icon(Icons.flash_on_rounded, color: AppColors.primary),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Transfer available balance instantly to ${wallet.bankDetails.bankName} (${wallet.bankDetails.accountNumber}).',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Withdrawal Amount (₹)',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Minimum Payout:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        Text('₹ ${wallet.payoutRules.minPayoutAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Instant Cashout Fee:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        Text('₹ ${wallet.payoutRules.instantCashoutFee.toStringAsFixed(2)} (Zero Fee)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.success)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Payouts Left Today:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        Text('${wallet.payoutRules.payoutsRemainingToday} of ${wallet.payoutRules.maxPayoutsPerDay}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    final amt = double.tryParse(amountController.text.trim()) ?? 0.0;
                    if (amt < wallet.payoutRules.minPayoutAmount) {
                      AppFlushbar.error(
                        context,
                        title: 'Minimum Payout Error',
                        message: 'Minimum payout amount is ₹${wallet.payoutRules.minPayoutAmount.toStringAsFixed(2)} as per platform policy.',
                      );
                      return;
                    }

                    Navigator.pop(context);
                    final success = await ref.read(walletProvider.notifier).requestPayout(amount: amt);
                    if (!context.mounted) return;
                    if (success) {
                      AppFlushbar.success(
                        context,
                        title: 'Instant Cashout Successful',
                        message: '₹ ${amt.toStringAsFixed(2)} successfully transferred to ${wallet.bankDetails.bankName} (${wallet.bankDetails.accountNumber}).',
                      );
                    } else {
                      final err = ref.read(walletProvider).errorMessage;
                      AppFlushbar.error(
                        context,
                        title: 'Cashout Failed',
                        message: err ?? 'Could not process payout.',
                      );
                    }
                  },
                  child: const Text('CONFIRM & WITHDRAW', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  void _showPayoutHistorySheet(BuildContext context, List<PayoutItemModel> payouts) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Payout History (Last 30 Days)',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  Icon(Icons.history_rounded, color: AppColors.secondary),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: payouts.isEmpty
                    ? const Center(
                        child: Text(
                          'No recent payout history found.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      )
                    : ListView.builder(
                        itemCount: payouts.length,
                        itemBuilder: (context, index) {
                          final p = payouts[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: Padding(
                              padding: const EdgeInsets.all(14.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '₹ ${p.amount.toStringAsFixed(2)}',
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.success),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: p.status.toLowerCase() == 'processed' || p.status.toLowerCase() == 'success'
                                              ? Colors.green.shade100
                                              : Colors.orange.shade100,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          p.status.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: p.status.toLowerCase() == 'processed' || p.status.toLowerCase() == 'success'
                                                ? Colors.green.shade800
                                                : Colors.orange.shade800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${p.method} • ${p.accountDetails}',
                                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'TXN: ${p.transactionId}',
                                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                                      ),
                                      Text(
                                        p.createdAt.isNotEmpty ? p.createdAt.substring(0, 10) : '',
                                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
