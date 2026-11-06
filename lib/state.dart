import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'notification_service.dart';

String dateKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

String hhmmOf(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

String fmtDateTime(DateTime d) => '${fmtDate(d)}  ${fmtTime(hhmmOf(d))}';

String fmtTime(String hhmm) {
  final p = hhmm.split(':');
  var h = int.parse(p[0]);
  final m = p[1];
  final suffix = h >= 12 ? 'PM' : 'AM';
  h = h % 12;
  if (h == 0) h = 12;
  return '$h:$m $suffix';
}

class NextDose {
  final Medicine med;
  final String time;
  final DateTime when;
  NextDose(this.med, this.time, this.when);
}

class HistoryItem {
  final String medName;
  final String time;
  final int takenAt;
  HistoryItem(this.medName, this.time, this.takenAt);
}

class SupplyInfo {
  final int pills;
  final int dosesLeft;
  final DateTime? lastDose;
  final int daysLeft;
  SupplyInfo(this.pills, this.dosesLeft, this.lastDose, this.daysLeft);
}

class AppState extends ChangeNotifier {
  static const _prefsKey = 'carelink_v1';
  static const refillDays = 5;
  static const buyBufferDays = 3;
  static const maxSnoozes = 2; // snoozes allowed per dose

  List<Medicine> medicines = [];
  Map<String, int> log = {}; // doseKey -> taken at (ms)
  Map<String, int> snoozed = {}; // doseKey -> snoozed until (ms)
  Map<String, int> snoozeCount = {}; // doseKey -> times snoozed
  List<AlertRecord> alerts = [];
  List<Appointment> appointments = [];
  int apptBase = 1;
  Map<String, String> refillNotified = {}; // medId -> dateKey

  int graceMin = 30;
  int snoozeMin = 10;
  String pin = '1234';
  String caretakerName = 'Caretaker';
  int nextBase = 1;

  String patientName = '';
  bool setupDone = false; // first-run account setup finished
  bool loggedIn = false; // not saved: login is required on every launch
  int failedPins = 0;
  int lockedUntil = 0; // ms; PIN entry locked until this time

  bool caretaker = false; // current role
  bool loaded = false;

  Future<void> init() async {
    await NotificationService.init();
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null) {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        medicines = (j['medicines'] as List)
            .map((e) => Medicine.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        log = Map<String, int>.from(j['log'] as Map);
        alerts = (j['alerts'] as List)
            .map((e) => AlertRecord.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        refillNotified = Map<String, String>.from(j['refillNotified'] as Map);
        appointments = ((j['appointments'] as List?) ?? [])
            .map((e) => Appointment.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        apptBase = (j['apptBase'] as int?) ?? 1;
        graceMin = j['graceMin'] as int;
        snoozeMin = j['snoozeMin'] as int;
        pin = j['pin'] as String;
        caretakerName = j['caretakerName'] as String;
        nextBase = j['nextBase'] as int;
        snoozeCount = Map<String, int>.from((j['snoozeCount'] as Map?) ?? {});
        patientName = (j['patientName'] as String?) ?? '';
        setupDone = (j['setupDone'] as bool?) ?? false;
      }
    } catch (e) {
      debugPrint('Load failed (starting fresh): $e');
    }
    loaded = true;
    await _reschedule();
    notifyListeners();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKey,
        jsonEncode({
          'medicines': medicines.map((e) => e.toJson()).toList(),
          'log': log,
          'alerts': alerts.map((e) => e.toJson()).toList(),
          'refillNotified': refillNotified,
          'appointments': appointments.map((e) => e.toJson()).toList(),
          'apptBase': apptBase,
          'graceMin': graceMin,
          'snoozeMin': snoozeMin,
          'pin': pin,
          'caretakerName': caretakerName,
          'nextBase': nextBase,
          'snoozeCount': snoozeCount,
          'patientName': patientName,
          'setupDone': setupDone,
        }),
      );
    } catch (e) {
      debugPrint('Save failed: $e');
    }
  }

  Future<void> _reschedule() {
    return NotificationService.rescheduleAll(
      medicines,
      appointments,
      graceMin: graceMin,
      nudgeEveryMin: snoozeMin,
      caretakerName: caretakerName,
      isTakenToday: (m, t, today) =>
          log.containsKey('${m.id}|${dateKey(today)}|$t'),
    );
  }

  Future<void> _commit() async {
    notifyListeners();
    await _save();
    await _reschedule();
  }

  // ---------- slots ----------
  List<DoseSlot> slotsFor(DateTime now) {
    final out = <DoseSlot>[];
    for (final m in medicines) {
      for (final t in m.times) {
        final p = t.split(':');
        final sched = DateTime(
            now.year, now.month, now.day, int.parse(p[0]), int.parse(p[1]));
        if (sched.isBefore(m.createdAt)) continue; // not prescribed yet
        final key = '${m.id}|${dateKey(now)}|$t';
        out.add(DoseSlot(m, t, sched, key, log.containsKey(key)));
      }
    }
    out.sort((a, b) => a.scheduled.compareTo(b.scheduled));
    return out;
  }

  List<DoseSlot> dueSlots(DateTime now) => slotsFor(now)
      .where((s) => s.isDue(now, graceMin, snoozed[s.key]))
      .toList();

  // ---------- actions ----------
  Future<void> markTaken(DoseSlot s) async {
    if (log.containsKey(s.key)) return;
    log[s.key] = DateTime.now().millisecondsSinceEpoch;
    snoozed.remove(s.key);
    s.med.stock = (s.med.stock - s.med.pillsPerDose).clamp(0, 1 << 30).toInt();
    await _commit();
  }

  int snoozesLeft(DoseSlot s) =>
      (maxSnoozes - (snoozeCount[s.key] ?? 0)).clamp(0, maxSnoozes).toInt();

  Future<void> snooze(DoseSlot s) async {
    snoozeCount[s.key] = (snoozeCount[s.key] ?? 0) + 1;
    snoozed[s.key] = DateTime.now()
        .add(Duration(minutes: snoozeMin))
        .millisecondsSinceEpoch;
    await _commit();
  }

  /// Checks for newly escalated doses and low stock. Called by a timer.
  void evaluate() {
    final now = DateTime.now();
    var changed = false;
    for (final s in slotsFor(now)) {
      if (s.isEscalated(now, graceMin) &&
          !alerts.any((a) => a.key == s.key)) {
        alerts.insert(0,
            AlertRecord(s.key, s.med.name, s.time, now.millisecondsSinceEpoch));
        changed = true;
      }
    }
    for (final m in medicines) {
      final sp = supplyFor(m, now);
      if (sp.daysLeft <= refillDays && refillNotified[m.id] != dateKey(now)) {
        refillNotified[m.id] = dateKey(now);
        NotificationService.show(
          1000000000 + m.notifBase,
          'Refill needed: ${m.name}',
          sp.lastDose == null
              ? 'Out of pills. Time to buy more.'
              : 'Supply ends about ${fmtDate(sp.lastDose!)} (~${sp.daysLeft} day(s)). Time to buy more.',
        );
        changed = true;
      }
    }
    if (changed) _save();
    notifyListeners(); // refresh time-dependent UI
  }

  bool alertOpen(AlertRecord a) => !log.containsKey(a.key);

  Future<Medicine> newMedicine({
    required String name,
    required String dosage,
    required String doctor,
    required DateTime prescribedOn,
    required List<String> times,
    required int pillsPerDose,
    required int stock,
    String? photoPath,
  }) async {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final m = Medicine(
      id: id,
      name: name,
      dosage: dosage,
      doctor: doctor,
      prescribedOn: prescribedOn,
      times: times,
      pillsPerDose: pillsPerDose,
      stock: stock,
      notifBase: nextBase++,
      createdAt: DateTime.now(),
    );
    if (photoPath != null) m.photoPath = await savePhoto(photoPath, id);
    medicines.add(m);
    await _commit();
    return m;
  }

  Future<void> updateMedicine(Medicine m, {String? newPhotoPath}) async {
    if (newPhotoPath != null) m.photoPath = await savePhoto(newPhotoPath, m.id);
    await _commit();
  }

  Future<void> deleteMedicine(Medicine m) async {
    medicines.removeWhere((x) => x.id == m.id);
    await _commit();
  }

  Future<String> savePhoto(String src, String id) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final photos = Directory('${dir.path}/photos');
      if (!await photos.exists()) await photos.create(recursive: true);
      final dest =
          '${photos.path}/$id-${DateTime.now().millisecondsSinceEpoch}.jpg';
      await File(src).copy(dest);
      return dest;
    } catch (e) {
      debugPrint('Photo copy failed: $e');
      return src;
    }
  }

  Future<void> setSettings({
    int? grace,
    int? snooze,
    String? newPin,
    String? name,
  }) async {
    if (grace != null) graceMin = grace;
    if (snooze != null) snoozeMin = snooze;
    if (newPin != null) pin = newPin;
    if (name != null) caretakerName = name;
    await _commit();
  }

  // ---------- supply forecast ----------
  /// Simulates the coming doses (today's untaken ones, then every day) and
  /// consumes pills until the stock cannot cover another dose.
  SupplyInfo supplyFor(Medicine m, DateTime now) {
    final per = m.pillsPerDose <= 0 ? 1 : m.pillsPerDose;
    final total = m.stock ~/ per;
    if (total <= 0 || m.times.isEmpty) return SupplyInfo(m.stock, 0, null, 0);
    final times = List<String>.from(m.times)..sort();
    var doses = total;
    DateTime? last;
    for (var d = 0; d < 400 && doses > 0; d++) {
      for (final t in times) {
        final p = t.split(':');
        final when = DateTime(now.year, now.month, now.day + d,
            int.parse(p[0]), int.parse(p[1]));
        if (d == 0) {
          if (log.containsKey('${m.id}|${dateKey(when)}|$t')) continue;
          if (when.isBefore(m.createdAt)) continue;
          if (when.isBefore(now.subtract(Duration(minutes: graceMin)))) continue;
        }
        last = when;
        doses--;
        if (doses == 0) break;
      }
    }
    if (last == null) return SupplyInfo(m.stock, total, null, 0);
    final today = DateTime(now.year, now.month, now.day);
    final lastDay = DateTime(last.year, last.month, last.day);
    var n = lastDay.difference(today).inDays;
    if (last.isAfter(now)) n += 1;
    return SupplyInfo(m.stock, total, last, n);
  }

  bool lowSupply(Medicine m, DateTime now) =>
      supplyFor(m, now).daysLeft <= refillDays;

  String supplyText(Medicine m, DateTime now, {bool detailed = false}) {
    final sp = supplyFor(m, now);
    if (sp.dosesLeft <= 0 || sp.lastDose == null) {
      return '${m.stock} pills • out of stock, refill needed';
    }
    final last = sp.lastDose!;
    var t =
        '${sp.pills} pills (${sp.dosesLeft} doses) • ~${sp.daysLeft} day(s) left\nLasts until ~${fmtDate(last)} (last dose ${fmtTime(hhmmOf(last))})';
    if (detailed) {
      final today = DateTime(now.year, now.month, now.day);
      final buyBy = DateTime(last.year, last.month, last.day - buyBufferDays);
      t += buyBy.isAfter(today) ? '\nBuy by ~${fmtDate(buyBy)}' : '\nBuy now';
    }
    return t;
  }

  Future<void> addStock(Medicine m, int pills) async {
    m.stock += pills;
    refillNotified.remove(m.id);
    await _commit();
  }

  // ---------- appointments ----------
  Future<void> addAppointment({
    required String title,
    required String place,
    required String notes,
    required DateTime when,
  }) async {
    appointments.add(Appointment(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: title,
      place: place,
      notes: notes,
      when: when,
      notifBase: apptBase++,
    ));
    await _commit();
  }

  Future<void> updateAppointment(Appointment a) => _commit();

  Future<void> deleteAppointment(Appointment a) async {
    appointments.removeWhere((x) => x.id == a.id);
    await _commit();
  }

  Appointment? nextAppointment(DateTime now) {
    final up = appointments.where((a) => a.when.isAfter(now)).toList()
      ..sort((a, b) => a.when.compareTo(b.when));
    return up.isEmpty ? null : up.first;
  }

  // ---------- board helpers ----------
  NextDose? nextDose(DateTime now) {
    NextDose? best;
    for (final m in medicines) {
      for (final t in m.times) {
        final p = t.split(':');
        var when = DateTime(
            now.year, now.month, now.day, int.parse(p[0]), int.parse(p[1]));
        final doneToday = log.containsKey('${m.id}|${dateKey(now)}|$t');
        if (doneToday || when.isBefore(now) || when.isBefore(m.createdAt)) {
          when = when.add(const Duration(days: 1));
        }
        if (best == null || when.isBefore(best.when)) {
          best = NextDose(m, t, when);
        }
      }
    }
    return best;
  }

  /// Dose times that already passed before the medicine was added today.
  List<String> laterNotices(DateTime now) {
    final out = <String>[];
    for (final m in medicines) {
      for (final t in m.times) {
        final p = t.split(':');
        final sched = DateTime(
            now.year, now.month, now.day, int.parse(p[0]), int.parse(p[1]));
        if (sched.isBefore(m.createdAt)) {
          out.add('${m.name} ${fmtTime(t)} starts tomorrow');
        }
      }
    }
    return out;
  }

  List<HistoryItem> recentTaken(int limit) {
    final entries = log.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final out = <HistoryItem>[];
    for (final e in entries) {
      final parts = e.key.split('|');
      if (parts.length < 3) continue;
      final idx = medicines.indexWhere((m) => m.id == parts[0]);
      if (idx < 0) continue;
      out.add(HistoryItem(medicines[idx].name, parts[2], e.value));
      if (out.length >= limit) break;
    }
    return out;
  }

  // ---------- login / security ----------
  bool get lockedOut => DateTime.now().millisecondsSinceEpoch < lockedUntil;

  int get lockSecondsLeft =>
      ((lockedUntil - DateTime.now().millisecondsSinceEpoch) / 1000).ceil();

  /// Checks the caretaker PIN. 3 wrong tries lock PIN entry for 60 seconds.
  bool verifyPin(String entered) {
    if (lockedOut) return false;
    if (entered == pin) {
      failedPins = 0;
      return true;
    }
    failedPins++;
    if (failedPins >= 3) {
      failedPins = 0;
      lockedUntil = DateTime.now().millisecondsSinceEpoch + 60000;
    }
    return false;
  }

  Future<void> completeSetup(
      {required String patient,
      required String caretakerNameIn,
      required String newPin}) async {
    patientName = patient;
    if (caretakerNameIn.isNotEmpty) caretakerName = caretakerNameIn;
    pin = newPin;
    setupDone = true;
    loggedIn = true;
    caretaker = false;
    await _commit();
  }

  void loginPatient() {
    loggedIn = true;
    caretaker = false;
    notifyListeners();
  }

  void loginCaretaker() {
    loggedIn = true;
    caretaker = true;
    notifyListeners();
  }

  void logout() {
    loggedIn = false;
    caretaker = false;
    notifyListeners();
  }

  void setRole(bool isCaretaker) {
    caretaker = isCaretaker;
    notifyListeners();
  }
}
