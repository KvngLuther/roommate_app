import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';

/// Handles local push notifications without Firebase Cloud Messaging.
///
/// Uses flutter_local_notifications to show notifications triggered by
/// in-app events (new expense, chore due, balance reminder, etc.).
///
/// Setup:
///   1. Call [NotificationService.init] once from main().
///   2. Call [NotificationService.requestPermission] after user authenticates.
///   3. Call [NotificationService.show] anywhere in the app to push a notification.
class NotificationService {
  NotificationService._();

  static final _localNotifications = FlutterLocalNotificationsPlugin();

  static const _channelId = 'roommate_channel';
  static const _channelName = 'Roommate Notifications';
  static const _channelDesc = 'Chores, expenses and balance reminders';

  // ── Shared notification details ───────────────────────────────────

  static NotificationDetails get _notificationDetails =>
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

  static const InitializationSettings _initSettings = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    iOS: DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    ),
  );

  // ── Init ─────────────────────────────────────────────────────────

  /// Call once from main() — creates the Android notification channel
  /// and initialises flutter_local_notifications.
  static Future<void> init() async {
    // Android 8+: create the notification channel
    const androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.high,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(androidChannel);

    await _localNotifications.initialize(
      settings: _initSettings,
      onDidReceiveNotificationResponse: (details) {
        // Handle notification tap — extend as needed.
        debugPrint('[Notifications] tapped: ${details.payload}');
      },
    );
  }

  // ── Permissions ──────────────────────────────────────────────────

  /// Requests notification permission on Android 13+ and iOS.
  /// Returns true when granted.
  static Future<bool> requestPermission() async {
    // Android 13+
    final android = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      return granted ?? false;
    }

    // iOS
    final ios = _localNotifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      final granted = await ios.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }

    return true; // older Android — no runtime permission needed
  }

  // ── Show Notification ────────────────────────────────────────────

  /// Shows a local notification immediately.
  ///
  /// [id]      – unique int; use the same id to replace a prior notification.
  /// [title]   – bold headline shown on the notification.
  /// [body]    – detail text below the headline.
  /// [payload] – optional string passed back on tap (e.g. a route name).
  static Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    await _localNotifications.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: _notificationDetails,
      payload: payload,
    );
  }

  // ── Convenience helpers ──────────────────────────────────────────

  /// Notify the household that a new expense was added.
  static Future<void> notifyNewExpense(String title, double amount) => show(
    id: 1001,
    title: '💸 New expense added',
    body: '$title · ₵${amount.toStringAsFixed(2)}',
    payload: 'expenses',
  );

  /// Notify that a chore is due today.
  static Future<void> notifyChoreDue(String choreTitle, String assigneeName) =>
      show(
        id: 1002,
        title: '🧹 Chore due today',
        body: '$choreTitle – assigned to $assigneeName',
        payload: 'chores',
      );

  /// Notify that a balance has been settled.
  static Future<void> notifySettled(String fromName, double amount) => show(
    id: 1003,
    title: '✅ Payment confirmed',
    body: '$fromName paid ₵${amount.toStringAsFixed(2)}',
    payload: 'settle',
  );

  /// Cancel a specific notification by id.
  static Future<void> cancel(int id) => _localNotifications.cancel(id: id);

  /// Cancel all pending notifications.
  static Future<void> cancelAll() => _localNotifications.cancelAll();
}
