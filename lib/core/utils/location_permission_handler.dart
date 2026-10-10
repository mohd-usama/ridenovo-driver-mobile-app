import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../theme/app_colors.dart';
import 'app_flushbar.dart';

class LocationPermissionHandler {
  /// Requests location permission with robust handling for denied and permanently denied states.
  static Future<bool> requestPermission(BuildContext context) async {
    // Check current status
    PermissionStatus status = await Permission.location.status;

    if (status.isGranted) {
      return true;
    }

    if (status.isDenied) {
      // Request permission
      status = await Permission.location.request();
      if (status.isGranted) {
        return true;
      }
    }

    if (status.isPermanentlyDenied) {
      // Show dialog guiding user to App Settings
      if (context.mounted) {
        _showSettingsDialog(context);
      }
      return false;
    }

    if (status.isDenied) {
      if (context.mounted) {
        AppFlushbar.warning(
          context,
          title: 'Location Permission Required',
          message: 'Ridonova Captain needs location access to receive nearby ride requests and navigate.',
        );
      }
    }

    return false;
  }

  static void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.location_off_rounded, color: AppColors.error),
              SizedBox(width: 10),
              Text('Location Permission', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            'Location permission is permanently denied. To accept rides and navigate, please enable location access in your device settings.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                await openAppSettings();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size(90, 38),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Open Settings', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }
}
