class Medicine {
  String id;
  String name;
  String dosage;
  String doctor;
  DateTime prescribedOn;
  List<String> times; // "HH:mm" 24h
  int pillsPerDose;
  int stock;
  int notifBase; // unique number used to build notification ids
  String? photoPath;
  DateTime createdAt;

  Medicine({
    required this.id,
    required this.name,
    required this.dosage,
    required this.doctor,
    required this.prescribedOn,
    required this.times,
    required this.pillsPerDose,
    required this.stock,
    required this.notifBase,
    required this.createdAt,
    this.photoPath,
  });

  int get dosesPerDay => times.length;
  int get dailyUse => pillsPerDose * dosesPerDay;
  int get daysLeft => dailyUse <= 0 ? 0 : stock ~/ dailyUse;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'dosage': dosage,
        'doctor': doctor,
        'prescribedOn': prescribedOn.millisecondsSinceEpoch,
        'times': times,
        'pillsPerDose': pillsPerDose,
        'stock': stock,
        'notifBase': notifBase,
        'photoPath': photoPath,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  factory Medicine.fromJson(Map<String, dynamic> j) => Medicine(
        id: j['id'] as String,
        name: j['name'] as String,
        dosage: (j['dosage'] as String?) ?? '',
        doctor: (j['doctor'] as String?) ?? '',
        prescribedOn:
            DateTime.fromMillisecondsSinceEpoch(j['prescribedOn'] as int),
        times: List<String>.from(j['times'] as List),
        pillsPerDose: (j['pillsPerDose'] as int?) ?? 1,
        stock: (j['stock'] as int?) ?? 0,
        notifBase: j['notifBase'] as int,
        photoPath: j['photoPath'] as String?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(j['createdAt'] as int),
      );
}

/// One scheduled dose of one medicine on one day.
class DoseSlot {
  final Medicine med;
  final String time;
  final DateTime scheduled;
  final String key;
  final bool taken;
  DoseSlot(this.med, this.time, this.scheduled, this.key, this.taken);

  bool isEscalated(DateTime now, int graceMin) =>
      !taken && !now.isBefore(scheduled.add(Duration(minutes: graceMin)));

  bool isDue(DateTime now, int graceMin, int? snoozedUntilMs) {
    if (taken) return false;
    if (now.isBefore(scheduled)) return false;
    if (isEscalated(now, graceMin)) return false;
    if (snoozedUntilMs != null &&
        now.millisecondsSinceEpoch < snoozedUntilMs) {
      return false;
    }
    return true;
  }
}

class AlertRecord {
  final String key;
  final String medName;
  final String time;
  final int raisedAt;
  AlertRecord(this.key, this.medName, this.time, this.raisedAt);

  Map<String, dynamic> toJson() =>
      {'key': key, 'medName': medName, 'time': time, 'raisedAt': raisedAt};

  factory AlertRecord.fromJson(Map<String, dynamic> j) => AlertRecord(
        j['key'] as String,
        j['medName'] as String,
        j['time'] as String,
        j['raisedAt'] as int,
      );
}

class Appointment {
  String id;
  String title; // doctor / purpose
  String place;
  String notes;
  DateTime when;
  int notifBase;

  Appointment({
    required this.id,
    required this.title,
    required this.place,
    required this.notes,
    required this.when,
    required this.notifBase,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'place': place,
        'notes': notes,
        'when': when.millisecondsSinceEpoch,
        'notifBase': notifBase,
      };

  factory Appointment.fromJson(Map<String, dynamic> j) => Appointment(
        id: j['id'] as String,
        title: j['title'] as String,
        place: (j['place'] as String?) ?? '',
        notes: (j['notes'] as String?) ?? '',
        when: DateTime.fromMillisecondsSinceEpoch(j['when'] as int),
        notifBase: j['notifBase'] as int,
      );
}
