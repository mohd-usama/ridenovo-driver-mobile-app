import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart' as loc;
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_flushbar.dart';
import '../../../auth/auth_provider.dart';
import '../../../rides/models/ride_request_model.dart';
import '../../../rides/ride_provider.dart';

class DriverMapHomeTab extends ConsumerStatefulWidget {
  const DriverMapHomeTab({super.key});

  @override
  ConsumerState<DriverMapHomeTab> createState() => _DriverMapHomeTabState();
}

class _DriverMapHomeTabState extends ConsumerState<DriverMapHomeTab> {
  GoogleMapController? _mapController;
  final TextEditingController _otpController = TextEditingController();
  final loc.Location _locationService = loc.Location();

  static const LatLng _defaultPosition = LatLng(20.2961, 85.8245); // Bhubaneswar fallback
  LatLng _currentPosition = LatLng(20.2961, 85.8245);
  Set<Marker> _markers = {};
  bool _isLoadingLocation = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _checkAndRequestLocation();
    });
  }

  Future<void> _checkAndRequestLocation() async {
    try {
      // 1. Check if location service is enabled (Triggers native Google Accuracy dialog as shown in the screenshot)
      bool serviceEnabled = await _locationService.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _locationService.requestService();
        if (!serviceEnabled) {
          if (mounted) {
            AppFlushbar.warning(context, title: 'Location Required', message: 'Please turn on device location to use Ridenova Captain.');
          }
          setState(() {
            _currentPosition = _defaultPosition;
            _markers = {
              Marker(
                markerId: const MarkerId('driver_location'),
                position: _defaultPosition,
                infoWindow: const InfoWindow(title: 'Bhubaneswar (Default)', snippet: 'Location service turned off'),
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
              ),
            };
            _isLoadingLocation = false;
          });
          return;
        }
      }

      // 2. Check & Request Location Permission
      loc.PermissionStatus permissionGranted = await _locationService.hasPermission();
      if (permissionGranted == loc.PermissionStatus.denied) {
        permissionGranted = await _locationService.requestPermission();
        if (permissionGranted != loc.PermissionStatus.granted) {
          if (mounted) {
            AppFlushbar.warning(context, title: 'Permission Denied', message: 'Location permission is required to receive nearby rides.');
          }
          setState(() {
            _currentPosition = _defaultPosition;
            _markers = {
              Marker(
                markerId: const MarkerId('driver_location'),
                position: _defaultPosition,
                infoWindow: const InfoWindow(title: 'Bhubaneswar (Default)', snippet: 'Permission denied'),
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
              ),
            };
            _isLoadingLocation = false;
          });
          return;
        }
      }

      // 3. Get Current Location
      loc.LocationData locationData = await _locationService.getLocation();
      if (locationData.latitude != null && locationData.longitude != null) {
        final latLng = LatLng(locationData.latitude!, locationData.longitude!);
        setState(() {
          _currentPosition = latLng;
          _markers = {
            Marker(
              markerId: const MarkerId('driver_location'),
              position: latLng,
              infoWindow: const InfoWindow(title: 'Your Current Location', snippet: 'Captain Online & Ready'),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
            ),
          };
          _isLoadingLocation = false;
        });

        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 16.0));

        // Broadcast location to ride provider
        ref.read(rideProvider.notifier).updateLocation(latLng.latitude, latLng.longitude);
      } else {
        setState(() => _isLoadingLocation = false);
      }
    } catch (e) {
      setState(() {
        _currentPosition = _defaultPosition;
        _isLoadingLocation = false;
      });
      if (mounted) {
        AppFlushbar.error(context, title: 'Location Error', message: 'Could not fetch current GPS location.');
      }
    }
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _handleDutyToggle(bool isOnline) async {
    final rideNotifier = ref.read(rideProvider.notifier);
    final authNotifier = ref.read(authProvider.notifier);

    authNotifier.updateDutyStatus(isOnline);

    if (isOnline) {
      final success = await rideNotifier.goOnline(battery: 85);
      if (mounted) {
        if (success) {
          AppFlushbar.success(context, title: 'Duty Status: ONLINE 🟢', message: 'Searching for nearby rides & broadcasting live location...');
        } else {
          AppFlushbar.info(context, title: 'Duty Status: ONLINE', message: 'Switched online successfully.');
        }
      }
    } else {
      await rideNotifier.goOffline();
      if (mounted) {
        AppFlushbar.warning(context, title: 'Duty Status: OFFLINE 🔴', message: 'You are now offline and won\'t receive new ride requests.');
      }
    }
  }

  void _showCancelConfirmationDialog(String rideId) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel Ride?'),
        content: const Text('Are you sure you want to cancel this ride request? The rider will be notified.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('NO, KEEP RIDE')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              Navigator.pop(dialogContext);
              final success = await ref.read(rideProvider.notifier).cancelRide(rideId);
              if (mounted && success) {
                AppFlushbar.info(context, title: 'Ride Cancelled', message: 'The ride has been cancelled successfully.');
              }
            },
            child: const Text('YES, CANCEL'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final rideState = ref.watch(rideProvider);

    final isOnline = rideState.isOnline;
    final activeRide = rideState.activeRide;
    final pendingRequests = rideState.pendingRequests;

    return Scaffold(
      body: Stack(
        children: [
          // 1. Google Map Background
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _currentPosition, zoom: 16.0),
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            onMapCreated: (controller) {
              _mapController = controller;
            },
          ),

          // Loading indicator for GPS location
          if (_isLoadingLocation) const Center(child: CircularProgressIndicator(color: AppColors.primary)),

          // 2. Top Controls (Menu, Duty Badge & Re-center)
          Positioned(
            top: topPadding + 12,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildFloatingIconButton(
                  icon: Icons.menu_rounded,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Captain Side Menu')));
                  },
                ),

                // Duty Status Pill Badge
                GestureDetector(
                  onTap: rideState.isDutyLoading ? null : () => _handleDutyToggle(!isOnline),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 4))],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (rideState.isDutyLoading)
                          const SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        else
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(color: isOnline ? AppColors.success : AppColors.error, shape: BoxShape.circle),
                          ),
                        const SizedBox(width: 8),
                        Text(
                          isOnline ? 'Online' : 'Offline',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),

                _buildFloatingIconButton(
                  icon: Icons.my_location_rounded,
                  onTap: () {
                    _checkAndRequestLocation();
                  },
                ),
              ],
            ),
          ),

          // 3. Real Incoming Ride Request Card (From GET /driver/ride-requests)
          if (isOnline && activeRide == null && pendingRequests.isNotEmpty)
            Positioned(left: 16, right: 16, bottom: 200, child: _buildIncomingRideCard(pendingRequests.first)),

          // 4. Active Ride Execution Flow Sheet (Step-Based State Machine)
          if (activeRide != null)
            Positioned(left: 0, right: 0, bottom: 0, child: _buildActiveRideExecutionSheet(activeRide, rideState))
          else
            // 5. Default Bottom Duty Sheet
            Positioned(left: 0, right: 0, bottom: 0, child: _buildDefaultDutySheet(isOnline, rideState.isDutyLoading)),
        ],
      ),
    );
  }

  Widget _buildIncomingRideCard(RideRequestModel req) {
    final distanceText = req.distance.isNotEmpty ? req.distance : 'Nearby';
    final pickupText = req.pickupAddress.isNotEmpty ? req.pickupAddress : 'Pickup Location';
    final dropText = req.dropAddress.isNotEmpty ? req.dropAddress : 'Drop Location';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 16, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                child: Text(
                  'NEW RIDE REQUEST • $distanceText',
                  style: const TextStyle(color: AppColors.primaryDark, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                '₹ ${req.fare.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.success),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.trip_origin, color: Colors.green, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Pickup: $pickupText',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.location_on, color: Colors.red, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Drop: $dropText', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 48), backgroundColor: AppColors.success),
            onPressed: () {
              ref.read(rideProvider.notifier).acceptRide(req.id);
            },
            child: const Text('ACCEPT RIDE'),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveRideExecutionSheet(RideRequestModel ride, RideState state) {
    final rideNotifier = ref.read(rideProvider.notifier);
    final riderName = ride.riderName.isNotEmpty ? ride.riderName : 'Rider Customer';
    final riderPhone = ride.riderPhone.isNotEmpty ? ride.riderPhone : 'Available in app';
    final pickupText = ride.pickupAddress.isNotEmpty ? ride.pickupAddress : 'Pickup Location';
    final dropText = ride.dropAddress.isNotEmpty ? ride.dropAddress : 'Drop Destination';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 16, offset: Offset(0, -4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step Header Status Indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                child: Text(
                  'ACTIVE RIDE • STEP: ${state.rideStep.name.toUpperCase()}',
                  style: const TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: AppColors.error),
                onPressed: () => _showCancelConfirmationDialog(ride.id),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Rider Info
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: AppColors.secondary,
                child: Icon(Icons.person, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(riderName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text('Phone: $riderPhone', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Text(
                '₹ ${ride.fare.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.success),
              ),
            ],
          ),
          const Divider(height: 24),

          // Pickup & Drop
          Row(
            children: [
              const Icon(Icons.circle, color: Colors.green, size: 14),
              const SizedBox(width: 8),
              Expanded(
                child: Text(pickupText, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.square, color: Colors.red, size: 14),
              const SizedBox(width: 8),
              Expanded(
                child: Text(dropText, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // STEP 1: ACCEPTED -> MARK ARRIVED
          if (state.rideStep == RideStep.accepted) ...[
            ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: AppColors.primary),
              onPressed: state.isRideLoading ? null : () => rideNotifier.markArrived(ride.id),
              child: state.isRideLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('MARK ARRIVED AT PICKUP'),
            ),
          ]
          // STEP 2: ARRIVED -> ENTER OTP -> START RIDE
          else if (state.rideStep == RideStep.arrived) ...[
            const Text('Enter Rider OTP to Start Ride:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              maxLength: 4,
              decoration: InputDecoration(
                hintText: 'Enter 4-digit OTP',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                counterText: '',
                errorText: state.errorMessage,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: AppColors.success),
              onPressed: state.isRideLoading
                  ? null
                  : () async {
                      final success = await rideNotifier.startRide(ride.id, _otpController.text.trim());
                      if (mounted && success) {
                        _otpController.clear();
                        AppFlushbar.success(context, title: 'Ride Started! 🚖', message: 'Trip is now in progress.');
                      }
                    },
              child: state.isRideLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('START RIDE'),
            ),
          ]
          // STEP 3: STARTED -> COMPLETE RIDE
          else if (state.rideStep == RideStep.started) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
              child: const Center(
                child: Text(
                  'TRIP IN PROGRESS 🚖',
                  style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: AppColors.secondary),
              onPressed: () {
                rideNotifier.completeActiveRide();
                AppFlushbar.success(context, title: 'Trip Completed! 🎉', message: 'Payment collected & trip ended successfully.');
              },
              child: const Text('COMPLETE RIDE'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDefaultDutySheet(bool isOnline, bool isLoading) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 16, offset: Offset(0, -4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isOnline ? "You're on duty" : "You're off duty",
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isOnline ? 'Broadcasting location & waiting for bookings...' : 'Turn on duty to start receiving bookings',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Switch(
                value: isOnline,
                activeThumbColor: Colors.white,
                activeTrackColor: AppColors.success,
                onChanged: isLoading ? null : (val) => _handleDutyToggle(val),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingIconButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Icon(icon, color: AppColors.textPrimary, size: 24),
      ),
    );
  }
}
