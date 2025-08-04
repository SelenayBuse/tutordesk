import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';


Future<void> requestExactAlarmPermission() async {
  if (Platform.isAndroid) {
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    final sdkInt = androidInfo.version.sdkInt;
    if (sdkInt >= 31) {
      final intent = AndroidIntent(
        action: 'android.settings.REQUEST_SCHEDULE_EXACT_ALARM',
        flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
      );
      await intent.launch();
    }
  }
}

class NotificationService {
  static final _notifications = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initializationSettings = InitializationSettings(android: android);

    await _notifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (response) async {
        final payload = response.payload ?? '';
        final parts = payload.split('|');
        if (parts.length == 2) {
          final docId = parts[0];
          final stuName = parts[1];
          final action = response.actionId;

          final lessonDoc = FirebaseFirestore.instance.collection('lessons').doc(docId);
          final studentQuery = await FirebaseFirestore.instance
              .collection('students')
              .where('stuName', isEqualTo: stuName)
              .limit(1)
              .get();

          if (studentQuery.docs.isNotEmpty) {
            final studentDoc = studentQuery.docs.first;
            final studentId = studentDoc.id;
            final fee = studentDoc['fee'] ?? 0;

            if (action == 'evet') {
              await lessonDoc.update({'isPaid': true});
              await FirebaseFirestore.instance.collection('students').doc(studentId).update({
                'paidAmount': FieldValue.increment(fee),
              });
            } else if (action == 'hayir') {
              await lessonDoc.update({'isPaid': false});
              await FirebaseFirestore.instance.collection('students').doc(studentId).update({
                'unpaidAmount': FieldValue.increment(fee),
              });
            }
          }
        }
      },
    );
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    try {
      final tzDate = tz.TZDateTime.from(scheduledDate, tz.local);

      if (tzDate.isBefore(tz.TZDateTime.now(tz.local))) {
        debugPrint("🛑 Notification not scheduled — date is in the past: $tzDate");
        return;
      }

      debugPrint("⏰ Scheduling notification for: $tzDate");

      await _notifications.zonedSchedule(
        id,
        title,
        body,
        tzDate,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'lesson_channel',
            'Lesson Reminders',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e, st) {
      debugPrint("❌ Failed to schedule notification: $e\n$st");
    }
  }

  Future<void> scheduleFollowUpNotification({
    required int id,
    required String docId,
    required String stuName,
    required DateTime scheduledDate,
  }) async {
    final tzDate = tz.TZDateTime.from(scheduledDate.add(const Duration(hours: 1)), tz.local);
    if (tzDate.isBefore(tz.TZDateTime.now(tz.local))) return;

    await _notifications.zonedSchedule(
      id,
      'Ödeme Kontrolü',
      '$stuName ile dersinizin ödemesini aldınız mı?',
      tzDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'payment_check_channel',
          'Payment Check',
          importance: Importance.max,
          priority: Priority.high,
          actions: <AndroidNotificationAction>[
            AndroidNotificationAction('evet', 'Evet'),
            AndroidNotificationAction('hayir', 'Hayır'),
          ],
        ),
      ),
      payload: '$docId|$stuName',
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}
