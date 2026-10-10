import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';

class DriverRidesTab extends ConsumerStatefulWidget {
  const DriverRidesTab({super.key});

  @override
  ConsumerState<DriverRidesTab> createState() => _DriverRidesTabState();
}

class _DriverRidesTabState extends ConsumerState<DriverRidesTab> {
  int _selectedFilterIndex = 0; // 0: All, 1: Completed, 2: Cancelled

  final List<Map<String, dynamic>> _mockRides = [
    {
      'id': 'TRIP-98124',
      'pickup': 'Jayadev Vihar Square',
      'drop': 'Apollo Hospital, Bhubaneswar',
      'fare': '₹ 140.00',
      'distance': '4.2 KM',
      'time': 'Today, 04:30 PM',
      'status': 'Completed',
      'payment': 'UPI',
    },
    {
      'id': 'TRIP-98118',
      'pickup': 'KIIT Campus 3',
      'drop': 'Patia Railway Station',
      'fare': '₹ 85.00',
      'distance': '2.8 KM',
      'time': 'Today, 02:15 PM',
      'status': 'Completed',
      'payment': 'Cash',
    },
    {
      'id': 'TRIP-98102',
      'pickup': 'Master Canteen Bus Stand',
      'drop': 'Khandagiri Caves',
      'fare': '₹ 210.00',
      'distance': '7.5 KM',
      'time': 'Yesterday, 06:40 PM',
      'status': 'Completed',
      'payment': 'Wallet',
    },
    {
      'id': 'TRIP-98091',
      'pickup': 'Janpath, Saheed Nagar',
      'drop': 'Bhubaneswar Railway Station',
      'fare': '₹ 0.00',
      'distance': '3.1 KM',
      'time': 'Yesterday, 11:10 AM',
      'status': 'Cancelled',
      'payment': 'None',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final filteredRides = _mockRides.where((ride) {
      if (_selectedFilterIndex == 1) return ride['status'] == 'Completed';
      if (_selectedFilterIndex == 2) return ride['status'] == 'Cancelled';
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Rides History'),
        backgroundColor: AppColors.secondary,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Filter Choice Chips
              Row(
                children: [
                  _buildFilterChip(0, 'All Rides'),
                  const SizedBox(width: 8),
                  _buildFilterChip(1, 'Completed'),
                  const SizedBox(width: 8),
                  _buildFilterChip(2, 'Cancelled'),
                ],
              ),

              const SizedBox(height: 16),

              Expanded(
                child: filteredRides.isEmpty
                    ? const Center(
                        child: Text(
                          'No rides found in this section.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      )
                    : ListView.builder(
                        itemCount: filteredRides.length,
                        itemBuilder: (context, index) {
                          final ride = filteredRides[index];
                          final isCompleted = ride['status'] == 'Completed';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        ride['id'],
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: AppColors.secondary,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isCompleted
                                              ? AppColors.success
                                                  .withValues(alpha: 0.12)
                                              : AppColors.error
                                                  .withValues(alpha: 0.12),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          ride['status'],
                                          style: TextStyle(
                                            color: isCompleted
                                                ? AppColors.success
                                                : AppColors.error,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    ride['time'],
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const Divider(height: 20),
                                  Row(
                                    children: [
                                      const Icon(Icons.trip_origin,
                                          color: Colors.green, size: 16),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          ride['pickup'],
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textPrimary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(Icons.location_on,
                                          color: Colors.red, size: 16),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          ride['drop'],
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: AppColors.textSecondary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 20),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Distance: ${ride['distance']} • Pay: ${ride['payment']}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      Text(
                                        ride['fare'],
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: isCompleted
                                              ? AppColors.textPrimary
                                              : AppColors.textSecondary,
                                        ),
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
        ),
      ),
    );
  }

  Widget _buildFilterChip(int index, String label) {
    final isSelected = _selectedFilterIndex == index;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : AppColors.textPrimary,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
      selected: isSelected,
      selectedColor: AppColors.primary,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedFilterIndex = index;
          });
        }
      },
    );
  }
}
