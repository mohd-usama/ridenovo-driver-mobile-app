import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum FlushbarType { success, error, warning, info }

class AppFlushbar {
  /// Shows a custom Flushbar alert on top of the screen based on the type
  static void show({
    required BuildContext context,
    required String message,
    String? title,
    FlushbarType type = FlushbarType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    Color backgroundColor;
    IconData icon;

    switch (type) {
      case FlushbarType.success:
        backgroundColor = AppColors.success;
        icon = Icons.check_circle_outline;
        title ??= 'Success';
        break;
      case FlushbarType.error:
        backgroundColor = AppColors.error;
        icon = Icons.error_outline;
        title ??= 'Error';
        break;
      case FlushbarType.warning:
        backgroundColor = AppColors.primary; // Brand Orange
        icon = Icons.warning_amber_rounded;
        title ??= 'Warning';
        break;
      case FlushbarType.info:
        backgroundColor = AppColors.secondary; // Brand Dark Blue
        icon = Icons.info_outline;
        title ??= 'Notice';
        break;
    }

    Flushbar(
      title: title,
      message: message,
      icon: Icon(icon, size: 28.0, color: Colors.white),
      duration: duration,
      backgroundColor: backgroundColor,
      borderRadius: BorderRadius.circular(12),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(16),
      flushbarPosition: FlushbarPosition.TOP,
      animationDuration: const Duration(milliseconds: 350),
      isDismissible: true,
      dismissDirection: FlushbarDismissDirection.HORIZONTAL,
      forwardAnimationCurve: Curves.easeOutCirc,
    ).show(context);
  }

  /// Convenience method for Success alert
  static void success(
    BuildContext context, {
    required String message,
    String? title = 'Success',
  }) {
    show(
      context: context,
      message: message,
      title: title,
      type: FlushbarType.success,
    );
  }

  /// Convenience method for Error alert
  static void error(
    BuildContext context, {
    required String message,
    String? title = 'Error',
  }) {
    show(
      context: context,
      message: message,
      title: title,
      type: FlushbarType.error,
    );
  }

  /// Convenience method for Warning alert
  static void warning(
    BuildContext context, {
    required String message,
    String? title = 'Warning',
  }) {
    show(
      context: context,
      message: message,
      title: title,
      type: FlushbarType.warning,
    );
  }

  /// Convenience method for Info alert
  static void info(
    BuildContext context, {
    required String message,
    String? title = 'Info',
  }) {
    show(
      context: context,
      message: message,
      title: title,
      type: FlushbarType.info,
    );
  }
}
