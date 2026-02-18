/// Web implementation of Browser Notification API for VibeShield.
///
/// This file is imported conditionally only when compiling for web.
/// It wires up the JS interop functions into [NotificationService].
// ignore_for_file: avoid_web_libraries_in_flutter
library;

import 'dart:html' as html;
import 'notification_service.dart';

/// Call once during app startup on web to enable browser notifications.
void configureBrowserNotifications() {
  NotificationService.configureBrowserApi(
    requestPermission: _requestPermission,
    checkPermission: _checkPermission,
    fireNotification: _fireNotification,
  );

  // Check current permission state immediately.
  NotificationService.instance.checkBrowserPermission();
}

Future<bool> _requestPermission() async {
  try {
    final permission = await html.Notification.requestPermission();
    return permission == 'granted';
  } catch (_) {
    return false;
  }
}

bool _checkPermission() {
  try {
    return html.Notification.permission == 'granted';
  } catch (_) {
    return false;
  }
}

void _fireNotification(String title, String body) {
  try {
    html.Notification(title, body: body, icon: 'icons/Icon-192.png');
  } catch (_) {
 
  }
}
