import 'dart:async';
import 'package:flutter/foundation.dart';

/// Severity levels for in-app notifications.
enum NotifLevel { info, warning, success, critical }

/// A single in-app notification entry.
class AppNotification {
  final String id;
  final String title;
  final String body;
  final NotifLevel level;
  final DateTime timestamp;
  final String? txHash;
  final bool read;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.level,
    DateTime? timestamp,
    this.txHash,
    this.read = false,
  }) : timestamp = timestamp ?? DateTime.now();

  AppNotification copyWith({bool? read}) {
    return AppNotification(
      id: id,
      title: title,
      body: body,
      level: level,
      timestamp: timestamp,
      txHash: txHash,
      read: read ?? this.read,
    );
  }
}

/// Singleton notification service for VibeShield.
///
/// Stores in-app notifications and fires Browser Notification API alerts
/// when the user has granted permission (works on Chrome Android/Desktop even
/// when the tab is in the background).
class NotificationService extends ChangeNotifier {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final List<AppNotification> _items = [];

  bool _browserPermissionGranted = false;
  bool get browserPermissionGranted => _browserPermissionGranted;

  /// All notifications, newest first.
  List<AppNotification> get items => List.unmodifiable(_items);

  int get unreadCount => _items.where((n) => !n.read).length;

  /// Add a notification and optionally fire a browser push.
  void push({
    required String title,
    required String body,
    NotifLevel level = NotifLevel.info,
    String? txHash,
    bool browserPush = true,
  }) {
    final notif = AppNotification(
      id: '${DateTime.now().microsecondsSinceEpoch}',
      title: title,
      body: body,
      level: level,
      txHash: txHash,
    );
    _items.insert(0, notif);

    if (_items.length > 100) _items.removeLast();

    notifyListeners();

    if (browserPush && _browserPermissionGranted && kIsWeb) {
      _fireBrowserNotification(title, body);
    }
  }

  void markRead(String id) {
    final idx = _items.indexWhere((n) => n.id == id);
    if (idx >= 0) {
      _items[idx] = _items[idx].copyWith(read: true);
      notifyListeners();
    }
  }

  void markAllRead() {
    for (var i = 0; i < _items.length; i++) {
      if (!_items[i].read) _items[i] = _items[i].copyWith(read: true);
    }
    notifyListeners();
  }

  void clearAll() {
    _items.clear();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Browser Notification API (Web only)
  // ---------------------------------------------------------------------------

  /// Request browser notification permission. Call once from UI.
  Future<bool> requestBrowserPermission() async {
    if (!kIsWeb) return false;
    try {
      final granted = await _requestPermission();
      _browserPermissionGranted = granted;
      notifyListeners();
      return granted;
    } catch (_) {
      return false;
    }
  }

  void checkBrowserPermission() {
    if (!kIsWeb) return;
    try {
      _browserPermissionGranted = _checkPermission();
      notifyListeners();
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // JS interop stubs — implemented via conditional import in web entrypoint.
  // For Flutter Web we use dart:js_interop; on other platforms these are no-ops.
  // ---------------------------------------------------------------------------

  static Future<bool> Function() _requestPermission = () async => false;
  static bool Function() _checkPermission = () => false;
  static void Function(String title, String body) _fireBrowserNotification =
      (_, __) {};

  /// Called once from the web bootstrap to wire up the JS interop functions.
  static void configureBrowserApi({
    required Future<bool> Function() requestPermission,
    required bool Function() checkPermission,
    required void Function(String title, String body) fireNotification,
  }) {
    _requestPermission = requestPermission;
    _checkPermission = checkPermission;
    _fireBrowserNotification = fireNotification;
  }
}
