// Morning read notification service — BS-012 N3 delivery layer
//
// Local-only notification delivery. One daily morning read, never more than
// one per day. Uses zonedSchedule for local timezone handling.
//
// Sensitive lock-screen: shows a generic body when device is locked, the full
// state message only when unlocked. badge: false (iOS). Tap → TodayScreen.
//
// Scheduling triggers: app resume + post-ingest. The gate is evaluated at
// schedule time; if the gate says silent, no notification is scheduled.

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'morning_read_gate.dart';

/// Notification IDs — single constant for the morning read.
const _kMorningReadNotificationId = 1;

/// Android notification channel for morning reads.
const _kChannelId = 'mivalta_morning_read';
const _kChannelName = 'Morning Read';
const _kChannelDescription = 'Daily morning state notification from MiValta';

/// Callback type for handling notification taps (routes to TodayScreen).
typedef NotificationTapCallback = void Function();

/// The morning read notification service.
///
/// Singleton that initializes once and provides:
/// - [initialize]: Set up plugin + channels + permissions
/// - [scheduleMorningRead]: Schedule (or cancel) based on gate result
/// - [cancelMorningRead]: Cancel any pending notification
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  NotificationTapCallback? _onTap;

  /// Default morning delivery hour (local time). User-configurable later.
  static const int defaultDeliveryHour = 7;
  static const int defaultDeliveryMinute = 0;

  /// Initialize the notification plugin. Call once at app startup.
  ///
  /// [onTap] is called when the user taps the notification (route to Today).
  Future<void> initialize({NotificationTapCallback? onTap}) async {
    if (_initialized) return;

    _onTap = onTap;

    // Initialize timezone database.
    tz.initializeTimeZones();

    // Android initialization settings.
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization settings — no badge, request sound/alert permissions.
    // Note: onDidReceiveLocalNotification was removed in v18 (iOS <10 no longer supported).
    const iosSettings = DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: false, // badge: false per spec
      requestAlertPermission: true,
    );

    final initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    // Create Android notification channel.
    if (Platform.isAndroid) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              _kChannelId,
              _kChannelName,
              description: _kChannelDescription,
              importance: Importance.defaultImportance,
              playSound: false, // Quiet by default
            ),
          );
    }

    _initialized = true;
  }

  /// Schedule the morning read notification based on gate result.
  ///
  /// If [result.shouldFire] is false, any pending notification is cancelled.
  /// Otherwise, schedules for the next occurrence of [deliveryHour:deliveryMinute].
  Future<void> scheduleMorningRead({
    required MorningReadResult result,
    int deliveryHour = defaultDeliveryHour,
    int deliveryMinute = defaultDeliveryMinute,
  }) async {
    if (!_initialized) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('[NotificationService] Not initialized, skipping schedule');
      }
      return;
    }

    // Cancel any existing notification first.
    await cancelMorningRead();

    if (!result.shouldFire) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('[NotificationService] Gate says silent: ${result.reason}');
      }
      return;
    }

    // Build notification content.
    final title = _buildTitle(result);
    final body = _buildBody(result);

    // Calculate next delivery time.
    final scheduledTime = _nextDeliveryTime(deliveryHour, deliveryMinute);

    // Notification details.
    final androidDetails = AndroidNotificationDetails(
      _kChannelId,
      _kChannelName,
      channelDescription: _kChannelDescription,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      playSound: false,
      // Sensitive: hide body when locked.
      visibility: NotificationVisibility.secret,
    );

    // iOS notification details.
    // Note: iOS lock-screen privacy is handled via the app's notification
    // settings (Show Previews: When Unlocked). The notification body itself
    // doesn't contain highly sensitive info — just the state word and advisory.
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: false,
      presentBadge: false, // badge: false per spec
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.zonedSchedule(
      _kMorningReadNotificationId,
      title,
      body,
      scheduledTime,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: null, // One-shot, not recurring
      // Required in flutter_local_notifications 18.x: interpret the
      // scheduled time as absolute local time. (Removed only in later
      // majors — CI falsified the removal-at-18 claim on 2026-07-06.)
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );

    if (kDebugMode) {
      // ignore: avoid_print
      print('[NotificationService] Scheduled for $scheduledTime: $title / $body');
    }
  }

  /// Cancel any pending morning read notification.
  Future<void> cancelMorningRead() async {
    if (!_initialized) return;
    await _plugin.cancel(_kMorningReadNotificationId);
  }

  /// Build notification title from gate result.
  String _buildTitle(MorningReadResult result) {
    final stateWord = result.stateWord ?? 'Ready';
    return stateWord;
  }

  /// Build notification body from gate result.
  String _buildBody(MorningReadResult result) {
    final advisory = result.advisoryText;
    if (advisory != null && advisory.isNotEmpty) {
      return advisory;
    }
    // Fallback to a generic message if no advisory.
    return "Check in to see today's plan.";
  }

  /// Calculate the next occurrence of [hour:minute] in local time.
  tz.TZDateTime _nextDeliveryTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);

    // If the time has already passed today, schedule for tomorrow.
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    return scheduled;
  }

  /// Handle notification tap — route to TodayScreen.
  void _onNotificationResponse(NotificationResponse response) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('[NotificationService] Notification tapped: ${response.payload}');
    }
    _onTap?.call();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DEBUG PREVIEW (kDebugMode only)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Preview the notification content without scheduling (kDebugMode only).
  /// Returns a map with title, body, and scheduledTime for display in UI.
  Map<String, String>? previewMorningRead({
    required MorningReadResult result,
    int deliveryHour = defaultDeliveryHour,
    int deliveryMinute = defaultDeliveryMinute,
  }) {
    if (!kDebugMode) return null;

    if (!result.shouldFire) {
      return {
        'status': 'silent',
        'reason': result.reason ?? 'unknown',
      };
    }

    final title = _buildTitle(result);
    final body = _buildBody(result);
    final scheduledTime = _nextDeliveryTime(deliveryHour, deliveryMinute);

    return {
      'status': 'scheduled',
      'title': title,
      'body': body,
      'scheduledTime': scheduledTime.toIso8601String(),
      'stateColor': result.stateColor ?? '',
    };
  }
}
