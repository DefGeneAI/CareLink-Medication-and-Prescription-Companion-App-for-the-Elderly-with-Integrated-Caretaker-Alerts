import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'models.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool ready = false;

  static const NotificationDetails _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'carelink_meds_v2',
      'Medicine reminders',
      channelDescription:
          'Medicine alarms, caretaker alerts, appointments and refill notices',
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.alarm,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      enableVibration: true,
      playSound: true,
    ),
  );

  static Future<void> init() async {
    try {
      tzdata.initializeTimeZones();
      await _plugin.initialize(const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ));
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();
      try {
        await android?.requestExactAlarmsPermission();
      } catch (e) {
        debugPrint('Exact alarm permission request failed: $e');
      }
      ready = true;
    } catch (e) {
      debugPrint('Notification init failed: $e');
    }
  }

  static Future<void> show(int id, String title, String body) async {
    if (!ready) return;
    try {
      await _plugin.show(id, title, body, _details);
    } catch (e) {
      debugPrint('show failed: $e');
    }
  }

  /// Schedules one notification. Tries an exact alarm first and falls back to
  /// an inexact one. A failure here never stops the other notifications.
  static Future<void> _at(int id, String title, String body, DateTime when,
      {bool daily = false}) async {
    final date = tz.TZDateTime.from(when, tz.local);
    for (final mode in [
      AndroidScheduleMode.exactAllowWhileIdle,
      AndroidScheduleMode.inexactAllowWhileIdle,
    ]) {
      try {
        await _plugin.zonedSchedule(
          id,
          title,
          body,
          date,
          _details,
          androidScheduleMode: mode,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: daily ? DateTimeComponents.time : null,
        );
        return;
      } catch (e) {
        debugPrint('schedule($id, $mode) failed: $e');
      }
    }
  }

  /// A reminder that fires [seconds] from now, to prove notifications work.
  static Future<void> scheduleTest({int seconds = 15}) async {
    if (!ready) return;
    await _at(998000000, 'Care Link test reminder',
        'This is how your medicine reminders will look.',
        DateTime.now().add(Duration(seconds: seconds)));
  }

  /// Rebuilds every scheduled notification from scratch.
  static Future<void> rescheduleAll(
    List<Medicine> meds,
    List<Appointment> appts, {
    required int graceMin,
    required int nudgeEveryMin,
    required String caretakerName,
    required bool Function(Medicine, String, DateTime) isTakenToday,
  }) async {
    if (!ready) return;
    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('cancelAll failed: $e');
    }
    final now = DateTime.now();

    for (final m in meds) {
      for (var i = 0; i < m.times.length && i < 9; i++) {
        final t = m.times[i];
        final parts = t.split(':');
        final today = DateTime(now.year, now.month, now.day,
            int.parse(parts[0]), int.parse(parts[1]));
        final id0 = m.notifBase * 1000 + i * 100;

        final nextMain =
            today.isAfter(now) ? today : today.add(const Duration(days: 1));
        await _at(id0, 'Time for ${m.name}',
            '${m.pillsPerDose} x ${m.dosage}. Open Care Link and tap "Medicine Taken".',
            nextMain,
            daily: true);

        var occ = today;
        if (now.isAfter(occ.add(Duration(minutes: graceMin)))) {
          occ = occ.add(const Duration(days: 1));
        } else if (isTakenToday(m, t, today)) {
          occ = occ.add(const Duration(days: 1));
        }

        for (var k = 1; k <= 3; k++) {
          final when = occ.add(Duration(minutes: nudgeEveryMin * k));
          if (when.isBefore(occ.add(Duration(minutes: graceMin))) &&
              when.isAfter(now)) {
            await _at(id0 + k, 'Reminder: ${m.name}',
                'You have not confirmed the $t dose yet.', when);
          }
        }
        final esc = occ.add(Duration(minutes: graceMin));
        if (esc.isAfter(now)) {
          await _at(
              id0 + 4,
              'Caretaker alert: ${m.name}',
              'The $t dose was not confirmed. $caretakerName has been alerted.',
              esc);
        }
      }
    }

    for (final a in appts) {
      final base = 1500000000 + a.notifBase * 10;
      final dayBefore = a.when.subtract(const Duration(days: 1));
      final hourBefore = a.when.subtract(const Duration(hours: 1));
      if (dayBefore.isAfter(now)) {
        await _at(base, 'Appointment tomorrow: ${a.title}',
            a.place.isEmpty ? 'Tomorrow' : 'Tomorrow at ${a.place}', dayBefore);
      }
      if (hourBefore.isAfter(now)) {
        await _at(base + 1, 'Appointment in 1 hour: ${a.title}',
            a.place.isEmpty ? 'Starting soon' : 'At ${a.place}', hourBefore);
      }
    }
  }
}
