import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:developer' as dev;
import 'package:location/location.dart' as loc;
import 'package:url_launcher/url_launcher.dart';
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
  final TextEditingController _ratingCommentController = TextEditingController();
  final loc.Location _locationService = loc.Location();

  static const LatLng _defaultPosition = LatLng(20.2961, 85.8245); // Bhubaneswar fallback
  LatLng _currentPosition = LatLng(20.2961, 85.8245);
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  String? _lastRoutedRideId;
  bool _isLoadingLocation = true;
  int _selectedRating = 5;

  BitmapDescriptor? _pickupIcon;
  BitmapDescriptor? _destinationIcon;

  @override
  void initState() {
    super.initState();
    _loadCustomMarkerIcons();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _checkAndRequestLocation();
    });
  }

  Future<void> _loadCustomMarkerIcons() async {
    try {
      final pickupIcon = await BitmapDescriptor.asset(const ImageConfiguration(size: Size(48, 48)), 'assets/images/mapsPins/p.png');
      final destIcon = await BitmapDescriptor.asset(const ImageConfiguration(size: Size(48, 48)), 'assets/images/mapsPins/d.png');
      if (mounted) {
        setState(() {
          _pickupIcon = pickupIcon;
          _destinationIcon = destIcon;
        });
      }
    } catch (e) {
      dev.log('Error loading custom map pin icons: $e', name: 'DriverMapHomeTab');
    }
  }

  @override
  void dispose() {
    _otpController.dispose();
    _ratingCommentController.dispose();
    super.dispose();
  }

  Future<void> _checkAndRequestLocation() async {
    try {
      bool serviceEnabled = await _locationService.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _locationService.requestService();
        if (!serviceEnabled) {
          if (mounted) {
            AppFlushbar.warning(context, title: 'Location Required', message: 'Please turn on device location to receive nearby rides.');
          }
          setState(() {
            _currentPosition = _defaultPosition;
            _markers = {
              Marker(
                markerId: const MarkerId('driver_location'),
                position: _defaultPosition,
                infoWindow: const InfoWindow(title: 'Bhubaneswar (Default)', snippet: 'Location service turned off'),
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
              ),
            };
            _isLoadingLocation = false;
          });
          return;
        }
      }

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
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
              ),
            };
            _isLoadingLocation = false;
          });
          return;
        }
      }

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
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            ),
          };
          _isLoadingLocation = false;
        });

        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 16.0));

        ref
            .read(rideProvider.notifier)
            .updateDriverCoordinates(latLng.latitude, latLng.longitude, heading: locationData.heading, speed: locationData.speed);
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

  Future<void> _handleDutyToggle(bool isOnline) async {
    final rideNotifier = ref.read(rideProvider.notifier);
    final authNotifier = ref.read(authProvider.notifier);

    authNotifier.updateDutyStatus(isOnline);

    if (isOnline) {
      final success = await rideNotifier.goOnline(battery: 85);
      if (mounted) {
        if (success) {
          AppFlushbar.success(context, title: 'Duty Status: ONLINE 🟢', message: 'Broadcasting live location & ready for ride requests...');
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

  Future<void> _launchPhoneCall(String phone, String rideId) async {
    final rideNotifier = ref.read(rideProvider.notifier);
    final maskedNum = await rideNotifier.initiateMaskedCall(rideId);
    final targetPhone = (maskedNum != null && maskedNum.isNotEmpty) ? maskedNum : phone;

    if (targetPhone.isEmpty) {
      if (mounted) AppFlushbar.error(context, title: 'Call Failed', message: 'No phone number available.');
      return;
    }

    final url = Uri.parse('tel:$targetPhone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      if (mounted) AppFlushbar.error(context, title: 'Call Error', message: 'Could not launch phone dialer.');
    }
  }

  Future<void> _openExternalNavigation(double lat, double lng) async {
    if (lat == 0.0 || lng == 0.0) return;
    final url = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) AppFlushbar.error(context, title: 'Maps Error', message: 'Could not open Google Maps navigation.');
    }
  }

  void _showCancelConfirmationDialog(String rideId) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel Ride?'),
        content: const Text('Are you sure you want to cancel this trip? The customer will be notified.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('NO, KEEP RIDE')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              Navigator.pop(dialogContext);
              final success = await ref.read(rideProvider.notifier).cancelRide(rideId, reason: 'Driver cancelled');
              if (mounted && success) {
                AppFlushbar.info(context, title: 'Ride Cancelled', message: 'The ride has been cancelled.');
              }
            },
            child: const Text('YES, CANCEL'),
          ),
        ],
      ),
    );
  }

  void _updateRouteOnMap(RideState rideState) {
    final route = rideState.activeRoute;
    final activeRide = rideState.activeRide;

    if (activeRide == null || route == null || route.routeCoordinates.isEmpty) {
      if (_polylines.isNotEmpty || _lastRoutedRideId != null) {
        setState(() {
          _polylines = {};
          _lastRoutedRideId = null;
          _markers = {
            Marker(
              markerId: const MarkerId('driver_location'),
              position: _currentPosition,
              infoWindow: const InfoWindow(title: 'Your Current Location', snippet: 'Captain Online & Ready'),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            ),
          };
        });
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(_currentPosition, 16.0));
      }
      return;
    }

    final coords = route.routeCoordinates;
    final isPickup = route.target == 'pickup';

    final LatLng pickupLatLng = (activeRide.pickupLat != 0.0 && activeRide.pickupLng != 0.0)
        ? LatLng(activeRide.pickupLat, activeRide.pickupLng)
        : ((isPickup && route.targetLat != 0.0) ? LatLng(route.targetLat, route.targetLng) : const LatLng(0, 0));

    final LatLng dropLatLng = (activeRide.dropLat != 0.0 && activeRide.dropLng != 0.0)
        ? LatLng(activeRide.dropLat, activeRide.dropLng)
        : ((!isPickup && route.targetLat != 0.0) ? LatLng(route.targetLat, route.targetLng) : const LatLng(0, 0));

    final Set<Marker> updatedMarkers = {
      Marker(
        markerId: const MarkerId('driver_location'),
        position: _currentPosition,
        infoWindow: const InfoWindow(title: 'Driver (You)'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
      if (pickupLatLng.latitude != 0.0 && pickupLatLng.longitude != 0.0)
        Marker(
          markerId: const MarkerId('pickup_location'),
          position: pickupLatLng,
          infoWindow: InfoWindow(
            title: 'Pickup Location 🟢',
            snippet: activeRide.pickupAddress.isNotEmpty ? activeRide.pickupAddress : route.targetAddress,
          ),
          icon: _pickupIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        ),
      if (dropLatLng.latitude != 0.0 && dropLatLng.longitude != 0.0)
        Marker(
          markerId: const MarkerId('destination_location'),
          position: dropLatLng,
          infoWindow: InfoWindow(
            title: 'Destination 🔴',
            snippet: activeRide.dropAddress.isNotEmpty ? activeRide.dropAddress : route.targetAddress,
          ),
          icon: _destinationIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
    };

    final Set<Polyline> updatedPolylines = {
      Polyline(
        polylineId: const PolylineId('ride_navigation_route'),
        points: coords,
        color: AppColors.primary,
        width: 6,
        jointType: JointType.round,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
      ),
    };

    setState(() {
      _markers = updatedMarkers;
      _polylines = updatedPolylines;
    });

    if (_mapController != null && coords.isNotEmpty && _lastRoutedRideId != route.rideId) {
      _lastRoutedRideId = route.rideId;
      _fitMapBounds(coords);
    }
  }

  void _fitMapBounds(List<LatLng> points) {
    if (points.isEmpty || _mapController == null) return;

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (var p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(LatLngBounds(southwest: LatLng(minLat, minLng), northeast: LatLng(maxLat, maxLng)), 80.0),
    );
  }

  String _formatSeconds(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final rideState = ref.watch(rideProvider);

    ref.listen<RideState>(rideProvider, (previous, next) {
      if (previous?.activeRoute != next.activeRoute || previous?.activeRide != next.activeRide) {
        _updateRouteOnMap(next);
      }

      if (next.rideStep == RideStep.cancelled && previous?.rideStep != RideStep.cancelled) {
        showDialog(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Ride Cancelled'),
            content: Text(next.errorMessage ?? 'The ride was cancelled by the customer.'),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  ref.read(rideProvider.notifier).finishCompletedRide();
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    });

    final isOnline = rideState.isOnline;
    final activeRide = rideState.activeRide;
    final incomingRide = rideState.incomingPopupRide ?? (rideState.pendingRequests.isNotEmpty ? rideState.pendingRequests.first : null);

    return Scaffold(
      body: Stack(
        children: [
          // 1. Interactive Google Map Background
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _currentPosition, zoom: 16.0),
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            onMapCreated: (controller) {
              _mapController = controller;
              if (rideState.activeRoute != null) {
                _updateRouteOnMap(rideState);
              }
            },
          ),

          if (_isLoadingLocation) const Center(child: CircularProgressIndicator(color: AppColors.primary)),

          // 2. Top Bar (Duty Badge & Controls)
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
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ridenova Captain Side Menu')));
                  },
                ),

                // Duty Status Badge
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
                      mainAxisSize: minWidth(20),
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

          // 3. Real-Time Incoming Ride Popup Modal (15-Second Countdown)
          if (isOnline && activeRide == null && incomingRide != null)
            Positioned(left: 16, right: 16, bottom: 120, child: _buildIncomingRidePopupModal(incomingRide, rideState)),

          // 4. Ride Execution Flow Sheet or Default Duty Sheet
          if (activeRide != null && rideState.rideStep != RideStep.completed)
            Positioned(left: 0, right: 0, bottom: 0, child: _buildActiveRideExecutionSheet(activeRide, rideState))
          else if (rideState.rideStep == RideStep.completed)
            Positioned(left: 0, right: 0, bottom: 0, child: _buildCompletedSummarySheet(rideState))
          else
            Positioned(left: 0, right: 0, bottom: 0, child: _buildDefaultDutySheet(isOnline, rideState.isDutyLoading)),
        ],
      ),
    );
  }

  MainAxisSize minWidth(double w) => MainAxisSize.min;

  Widget _buildIncomingRidePopupModal(RideRequestModel req, RideState state) {
    final rideNotifier = ref.read(rideProvider.notifier);
    final countdown = state.incomingCountdownSeconds;
    final progress = countdown / 15.0;

    final pickupText = req.pickupAddress.isNotEmpty ? req.pickupAddress : 'Pickup Location';
    final dropText = req.dropAddress.isNotEmpty ? req.dropAddress : 'Drop Location';
    final riderName = req.riderName.isNotEmpty ? req.riderName : 'Customer';
    final vehicleTypeText = req.vehicleType.isNotEmpty ? ' • ${req.vehicleType}' : '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Countdown Timer Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(countdown > 5 ? AppColors.primary : AppColors.error),
            ),
          ),
          const SizedBox(height: 12),

          // 🟢 1. Badge Row (New Ride + Booked for Someone Else Badge)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Wrap(
                spacing: 6,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                    child: Text(
                      'NEW RIDE • ${countdown}s',
                      style: const TextStyle(color: AppColors.primaryDark, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (req.isForSomeoneElse) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        border: Border.all(color: Colors.orange.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.people_alt_rounded, size: 12, color: Colors.orange.shade800),
                          const SizedBox(width: 4),
                          Text(
                            'FOR SOMEONE ELSE',
                            style: TextStyle(color: Colors.orange.shade900, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              Text(
                '₹ ${req.fare.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.success),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 🟢 2. Passenger / Rider Info Row
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: req.isForSomeoneElse ? Colors.orange.shade700 : AppColors.primary,
                child: Icon(req.isForSomeoneElse ? Icons.person_pin_rounded : Icons.person, size: 18, color: Colors.white),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      req.isForSomeoneElse && req.passengerName.isNotEmpty ? 'Passenger: ${req.passengerName}' : '$riderName$vehicleTypeText',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                    ),
                    if (req.isForSomeoneElse)
                      Text(
                        'Booked by: ${req.bookedByName.isNotEmpty ? req.bookedByName : riderName}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                  ],
                ),
              ),
              if (req.paymentMethod.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(6)),
                  child: Text(
                    req.paymentMethod,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.trip_origin, color: Colors.green, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  pickupText,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.location_on, color: Colors.red, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  dropText,
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                flex: 1,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    side: const BorderSide(color: AppColors.error),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    rideNotifier.rejectRide(req.id, reason: 'Driver rejected');
                  },
                  child: const Text(
                    'DECLINE',
                    style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    backgroundColor: AppColors.success,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: state.isRideLoading
                      ? null
                      : () async {
                          final success = await rideNotifier.acceptRide(
                            req.id,
                            driverLat: _currentPosition.latitude,
                            driverLng: _currentPosition.longitude,
                          );
                          if (mounted) {
                            if (success) {
                              AppFlushbar.success(context, title: 'Ride Accepted! 🚖', message: 'Head to the pickup location.');
                            } else {
                              AppFlushbar.error(context, title: 'Accept Failed', message: state.errorMessage ?? 'Failed to accept ride.');
                            }
                          }
                        },
                  child: state.isRideLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text(
                          'ACCEPT RIDE',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveRideExecutionSheet(RideRequestModel ride, RideState state) {
    final rideNotifier = ref.read(rideProvider.notifier);
    final route = state.activeRoute;

    final riderName = ride.riderName.isNotEmpty ? ride.riderName : (route != null && route.riderName.isNotEmpty ? route.riderName : 'Customer');
    final riderPhone = ride.riderPhone.isNotEmpty ? ride.riderPhone : (route != null && route.riderPhone.isNotEmpty ? route.riderPhone : '');

    // Contact details determination
    final displayName = ride.isForSomeoneElse && ride.passengerName.isNotEmpty ? ride.passengerName : riderName;
    final displayPhone = ride.isForSomeoneElse && ride.passengerPhone.isNotEmpty ? ride.passengerPhone : riderPhone;

    final pickupText = ride.pickupAddress.isNotEmpty
        ? ride.pickupAddress
        : (route != null && route.target == 'pickup' && route.targetAddress.isNotEmpty ? route.targetAddress : 'Pickup Location');

    final dropText = ride.dropAddress.isNotEmpty
        ? ride.dropAddress
        : (route != null && route.target == 'dropoff' && route.targetAddress.isNotEmpty ? route.targetAddress : 'Drop Destination');

    final isPickupStep = state.rideStep == RideStep.accepted || state.rideStep == RideStep.arrived;
    final targetLat = isPickupStep ? ride.pickupLat : ride.dropLat;
    final targetLng = isPickupStep ? ride.pickupLng : ride.dropLng;

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                child: Text(
                  'TRIP STATUS: ${state.rideStep.name.toUpperCase()}',
                  style: const TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.navigation_rounded, color: AppColors.primary),
                    tooltip: 'Google Maps Navigation',
                    onPressed: () => _openExternalNavigation(targetLat, targetLng),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.error),
                    tooltip: 'Cancel Ride',
                    onPressed: () => _showCancelConfirmationDialog(ride.id),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              CircleAvatar(
                backgroundColor: ride.isForSomeoneElse ? Colors.orange.shade700 : AppColors.secondary,
                child: Icon(ride.isForSomeoneElse ? Icons.person_pin_rounded : Icons.person, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        if (ride.isForSomeoneElse) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(4)),
                            child: Text(
                              'Passenger',
                              style: TextStyle(color: Colors.orange.shade900, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      ride.isForSomeoneElse
                          ? 'Booked by ${ride.bookedByName} • ${ride.paymentMethod}'
                          : (displayPhone.isNotEmpty ? 'Phone: $displayPhone' : 'Payment: ${ride.paymentMethod}'),
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              if (displayPhone.isNotEmpty)
                IconButton(
                  style: IconButton.styleFrom(backgroundColor: AppColors.success.withValues(alpha: 0.12)),
                  icon: const Icon(Icons.phone_rounded, color: AppColors.success),
                  onPressed: () => _launchPhoneCall(displayPhone, ride.id),
                ),
              const SizedBox(width: 8),
              Text(
                '₹ ${ride.fare.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.success),
              ),
            ],
          ),
          const Divider(height: 20),

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
              onPressed: state.isRideLoading
                  ? null
                  : () async {
                      final success = await rideNotifier.markArrived(
                        ride.id,
                        driverLat: _currentPosition.latitude,
                        driverLng: _currentPosition.longitude,
                      );
                      if (mounted) {
                        if (success) {
                          AppFlushbar.success(
                            context,
                            title: 'Arrived at Pickup 📍',
                            message: 'Waiting timer started. Ask rider for 4-digit OTP.',
                          );
                        } else {
                          AppFlushbar.error(context, title: 'Action Failed', message: state.errorMessage ?? 'Failed to mark arrived.');
                        }
                      }
                    },
              child: state.isRideLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('I HAVE ARRIVED AT PICKUP'),
            ),
          ]
          // STEP 2: ARRIVED -> WAITING TIMER & ENTER OTP -> START RIDE
          else if (state.rideStep == RideStep.arrived) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.timer_outlined, color: Colors.amber, size: 20),
                      SizedBox(width: 8),
                      Text('Waiting Timer:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                  Text(
                    _formatSeconds(state.waitingSecondsElapsed),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.amber),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text('Enter Rider 4-Digit OTP to Start Ride:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
                      final success = await rideNotifier.startRide(
                        ride.id,
                        _otpController.text.trim(),
                        driverLat: _currentPosition.latitude,
                        driverLng: _currentPosition.longitude,
                      );
                      if (mounted) {
                        if (success) {
                          _otpController.clear();
                          AppFlushbar.success(context, title: 'Ride Started! 🚖', message: 'Navigation switched to drop destination.');
                        } else {
                          AppFlushbar.error(
                            context,
                            title: 'Start Ride Failed',
                            message: state.errorMessage ?? 'The OTP entered is incorrect. Please check with rider and try again.',
                          );
                        }
                      }
                    },
              child: state.isRideLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('VERIFY OTP & START RIDE'),
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
                  'TRIP IN PROGRESS 🚖 • NAVIGATING TO DROPOFF',
                  style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: AppColors.secondary),
              onPressed: state.isRideLoading
                  ? null
                  : () async {
                      final success = await rideNotifier.completeRide(ride.id);
                      if (mounted) {
                        if (success) {
                          AppFlushbar.success(context, title: 'Trip Completed! 🎉', message: 'Collect fare payment from rider.');
                        } else {
                          AppFlushbar.error(context, title: 'Completion Failed', message: state.errorMessage ?? 'Failed to complete trip.');
                        }
                      }
                    },
              child: state.isRideLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('COMPLETE RIDE & COLLECT FARE'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompletedSummarySheet(RideState state) {
    final summary = state.completedFareSummary ?? {};
    final fareAmt = summary['fare'] ?? summary['totalFare'] ?? summary['amount'] ?? 0.0;
    final paymentMethod = summary['paymentMethod']?.toString() ?? 'CASH';
    final riderName = summary['riderName']?.toString() ?? 'Customer';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, -4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
            child: const Icon(Icons.check_rounded, color: Colors.white, size: 30),
          ),
          const SizedBox(height: 12),
          const Text('Trip Completed Successfully! 🎉', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Collect payment from $riderName', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 16),

          // Fare Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(16)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Collectible Fare', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(height: 4),
                    Text(
                      '₹ ${fareAmt is num ? fareAmt.toStringAsFixed(0) : fareAmt}',
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.success),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    paymentMethod.toUpperCase(),
                    style: const TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Rating Bar
          const Text('Rate Rider:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final starIndex = index + 1;
              return IconButton(
                icon: Icon(starIndex <= _selectedRating ? Icons.star_rounded : Icons.star_outline_rounded, color: Colors.amber, size: 36),
                onPressed: () {
                  setState(() => _selectedRating = starIndex);
                },
              );
            }),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _ratingCommentController,
            decoration: InputDecoration(
              hintText: 'Feedback comment (optional)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 20),

          ElevatedButton(
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: AppColors.primary),
            onPressed: state.isRideLoading
                ? null
                : () async {
                    final rideNotifier = ref.read(rideProvider.notifier);
                    final rideId = state.activeRide?.id ?? '';
                    await rideNotifier.rateRider(rideId, rating: _selectedRating, comment: _ratingCommentController.text.trim());
                    _ratingCommentController.clear();
                    if (mounted) {
                      AppFlushbar.success(context, title: 'Rating Submitted! ⭐️', message: 'Ready for next ride request.');
                    }
                  },
            child: state.isRideLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('SUBMIT & RETURN TO DUTY'),
          ),
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
                      isOnline ? 'Broadcasting live location & ready for bookings...' : 'Turn on duty to start receiving ride bookings',
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
