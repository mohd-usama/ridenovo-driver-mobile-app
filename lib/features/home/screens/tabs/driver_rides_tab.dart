import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_constants.dart';
import '../../../../core/network/api_service.dart';
import '../../../../core/theme/app_colors.dart';
import 'package:ridenovo_rider_mobile_app/features/rides/models/ride_history_model.dart';

class DriverRidesTab extends ConsumerStatefulWidget {
  const DriverRidesTab({super.key});

  @override
  ConsumerState<DriverRidesTab> createState() => _DriverRidesTabState();
}

class _DriverRidesTabState extends ConsumerState<DriverRidesTab> {
  int _selectedFilterIndex = 0; // 0: All, 1: Completed, 2: Cancelled
  bool _isLoading = true;
  List<RideHistoryItemModel> _rides = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchRideHistory();
  }

  Future<void> _fetchRideHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final apiService = ApiService();
      String filterParam = 'all';
      if (_selectedFilterIndex == 1) filterParam = 'complete';
      if (_selectedFilterIndex == 2) filterParam = 'cancel';

      final response = await apiService.get('${ApiConstants.driverRides}?type=$filterParam&page=1&limit=20');

      if (response.isSuccess && response.data != null) {
        final raw = response.data is String ? jsonDecode(response.data) : response.data;
        final dataPayload = (raw is Map) ? (raw['data'] ?? raw['result'] ?? raw) : raw;

        List<RideHistoryItemModel> loadedRides = [];
        if (dataPayload is Map && dataPayload['rides'] is List) {
          for (var item in dataPayload['rides']) {
            if (item is Map<String, dynamic>) {
              loadedRides.add(RideHistoryItemModel.fromJson(item));
            }
          }
        } else if (dataPayload is List) {
          for (var item in dataPayload) {
            if (item is Map<String, dynamic>) {
              loadedRides.add(RideHistoryItemModel.fromJson(item));
            }
          }
        }

        if (mounted) {
          setState(() {
            _rides = loadedRides;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = response.errorMessage ?? 'Failed to load ride history';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'An error occurred while fetching rides.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('History'),
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
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                    : _errorMessage != null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(_errorMessage!, style: const TextStyle(color: AppColors.error)),
                                const SizedBox(height: 12),
                                ElevatedButton(
                                  onPressed: _fetchRideHistory,
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          )
                        : _rides.isEmpty
                            ? const Center(
                                child: Text(
                                  'No ride history found.',
                                  style: TextStyle(color: AppColors.textSecondary),
                                ),
                              )
                            : RefreshIndicator(
                                onRefresh: _fetchRideHistory,
                                color: AppColors.primary,
                                child: ListView.builder(
                                  itemCount: _rides.length,
                                  itemBuilder: (context, index) {
                                    final ride = _rides[index];
                                    final isCompleted = ride.status.toLowerCase() == 'completed' || ride.status.toLowerCase() == 'complete';

                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      child: Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  ride.tripId,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                    color: AppColors.secondary,
                                                  ),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: isCompleted
                                                        ? AppColors.success.withValues(alpha: 0.12)
                                                        : AppColors.error.withValues(alpha: 0.12),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    ride.status.toUpperCase(),
                                                    style: TextStyle(
                                                      color: isCompleted ? AppColors.success : AppColors.error,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              ride.createdAt,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                            const Divider(height: 20),
                                            Row(
                                              children: [
                                                const Icon(Icons.trip_origin, color: Colors.green, size: 16),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    ride.pickupAddress,
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
                                                const Icon(Icons.location_on, color: Colors.red, size: 16),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    ride.dropAddress,
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
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  'Distance: ${ride.distance} KM • Pay: ${ride.paymentMethod}',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: AppColors.textSecondary,
                                                  ),
                                                ),
                                                Text(
                                                  '₹ ${ride.fare.toStringAsFixed(0)}',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                    color: isCompleted ? AppColors.textPrimary : AppColors.textSecondary,
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
          _fetchRideHistory();
        }
      },
    );
  }
}
