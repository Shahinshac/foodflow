import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class DialerHelper {
  /// Opens the device dialer with the phone number pre-filled.
  /// Does NOT automatically place the call (requires user confirmation in dialer).
  static Future<void> openDialer(BuildContext context, String? phoneNumber, {String contactLabel = 'Contact'}) async {
    if (phoneNumber == null || phoneNumber.trim().isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$contactLabel phone number is not available'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleanPhone.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invalid phone number for $contactLabel'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final uri = Uri.parse('tel:$cleanPhone');
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open phone dialer for $cleanPhone'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open phone dialer: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
