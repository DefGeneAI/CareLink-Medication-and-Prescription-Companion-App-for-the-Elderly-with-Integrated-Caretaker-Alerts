import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'models.dart';
import 'ocr_service.dart';
import 'state.dart';

final ImagePicker _picker = ImagePicker();

Future<String?> pickPhoto(ImageSource source) async {
  try {
    final x = await _picker.pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
    return x?.path;
  } catch (e) {
    return null;
  }
}

/// Bottom sheet: scan prescription / choose photo / manual entry.
Future<void> startAddFlow(BuildContext context, AppState state) async {
  final choice = await showModalBottomSheet<String>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: const Text('Scan prescription with camera'),
            onTap: () => Navigator.pop(ctx, 'camera'),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Scan prescription from gallery'),
            onTap: () => Navigator.pop(ctx, 'gallery'),
          ),
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Enter manually'),
            onTap: () => Navigator.pop(ctx, 'manual'),
          ),
        ],
      ),
    ),
  );
  if (choice == null || !context.mounted) return;

  if (choice == 'manual') {
    await Navigator.push<bool>(context,
        MaterialPageRoute(builder: (_) => MedicineFormPage(state: state)));
    return;
  }

  final path = await pickPhoto(
      choice == 'camera' ? ImageSource.camera : ImageSource.gallery);
  if (path == null || !context.mounted) return;

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(children: [
          CircularProgressIndicator(),
          SizedBox(width: 20),
          Expanded(child: Text('Reading prescription...')),
        ]),
      ),
    ),
  );

  List<ParsedRx> parsedList = [];
  String? error;
  try {
    final text = await OcrService.extractText(path);
    if (text.trim().isEmpty) {
      error = 'No text found. Try a clearer, well-lit photo.';
    } else {
      parsedList = OcrService.parseAll(text);
    }
  } catch (e) {
    error = 'Scanning failed or timed out. You can enter details manually.';
  }

  if (!context.mounted) return;
  Navigator.of(context, rootNavigator: true).pop(); // close loading dialog

  if (error != null) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    await Navigator.push<bool>(context,
        MaterialPageRoute(builder: (_) => MedicineFormPage(state: state)));
    return;
  }

  final named = parsedList.where((p) => p.name.isNotEmpty).length;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(parsedList.length > 1
        ? 'Found ${parsedList.length} medicines. Confirm each one (go back to skip).'
        : named == 0
            ? 'Text was read, but no medicine name was recognised. Please fill in the details.'
            : 'Medicine found. Please check the details.'),
  ));

  for (var i = 0; i < parsedList.length; i++) {
    if (!context.mounted) return;
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => MedicineFormPage(
          state: state,
          parsed: parsedList[i],
          progress:
              parsedList.length > 1 ? 'Medicine ${i + 1} of ${parsedList.length}' : null,
        ),
      ),
    );
  }
}

class MedicineFormPage extends StatefulWidget {
  final AppState state;
  final Medicine? existing;
  final ParsedRx? parsed;
  final String? progress;
  const MedicineFormPage({
    super.key,
    required this.state,
    this.existing,
    this.parsed,
    this.progress,
  });

  @override
  State<MedicineFormPage> createState() => _MedicineFormPageState();
}

class _MedicineFormPageState extends State<MedicineFormPage> {
  late final TextEditingController name;
  late final TextEditingController dosage;
  late final TextEditingController doctor;
  late final TextEditingController pills;
  late final TextEditingController stock;
  late DateTime date;
  late List<String> times;
  String? newPhoto; // path of a not-yet-saved photo
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final p = widget.parsed;
    name = TextEditingController(text: e?.name ?? p?.name ?? '');
    dosage = TextEditingController(text: e?.dosage ?? p?.dosage ?? '');
    doctor = TextEditingController(text: e?.doctor ?? p?.doctor ?? '');
    pills = TextEditingController(
        text: '${e?.pillsPerDose ?? p?.pillsPerDose ?? 1}');
    stock = TextEditingController(text: '${e?.stock ?? p?.stock ?? 30}');
    date = e?.prescribedOn ?? p?.date ?? DateTime.now();
    times = List<String>.from(e?.times ?? p?.times ?? ['08:00']);
  }

  @override
  void dispose() {
    name.dispose();
    dosage.dispose();
    doctor.dispose();
    pills.dispose();
    stock.dispose();
    super.dispose();
  }

  void snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _useLine(String line) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text('"$line"',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          ListTile(
              leading: const Icon(Icons.medication),
              title: const Text('Use as medicine name'),
              onTap: () => Navigator.pop(ctx, 'name')),
          ListTile(
              leading: const Icon(Icons.scale),
              title: const Text('Use as dosage / strength'),
              onTap: () => Navigator.pop(ctx, 'dosage')),
          ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Use as doctor'),
              onTap: () => Navigator.pop(ctx, 'doctor')),
        ]),
      ),
    );
    if (choice == null) return;
    final strength = RegExp(r'(\d+(?:\.\d+)?)\s?(mg|mcg|g|ml|iu)\b',
        caseSensitive: false);
    setState(() {
      if (choice == 'name') {
        name.text = line
            .replaceAll(
                RegExp(r'^[^A-Za-z]*(tab|tablet|cap|capsule|syp|syrup|inj)\b\.?\s*',
                    caseSensitive: false),
                '')
            .replaceAll(strength, '')
            .replaceAll(RegExp(r'[^A-Za-z ]+$'), '')
            .trim();
      } else if (choice == 'dosage') {
        final m = strength.firstMatch(line);
        dosage.text = m != null ? m.group(0)! : line;
      } else {
        doctor.text = line;
      }
    });
  }

  Future<void> addTime() async {
    final t = await showTimePicker(
        context: context, initialTime: const TimeOfDay(hour: 8, minute: 0));
    if (t == null) return;
    final s =
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    if (times.contains(s)) return;
    if (times.length >= 8) {
      snack('Maximum 8 doses per day.');
      return;
    }
    setState(() {
      times.add(s);
      times.sort();
    });
  }

  Future<void> choosePhoto() async {
    final src = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: const Text('Take photo'),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Choose from gallery'),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
        ]),
      ),
    );
    if (src == null) return;
    final path = await pickPhoto(src);
    if (path != null && mounted) setState(() => newPhoto = path);
  }

  Future<void> save() async {
    final n = name.text.trim();
    final d = dosage.text.trim();
    final pp = int.tryParse(pills.text.trim());
    final st = int.tryParse(stock.text.trim());
    if (n.isEmpty || d.isEmpty) {
      snack('Please enter the medicine name and dosage.');
      return;
    }
    if (pp == null || pp <= 0 || st == null || st < 0) {
      snack('Pills per dose must be above 0 and stock cannot be negative.');
      return;
    }
    if (times.isEmpty) {
      snack('Add at least one dose time.');
      return;
    }
    setState(() => saving = true);
    final s = widget.state;
    final e = widget.existing;
    if (e == null) {
      await s.newMedicine(
        name: n,
        dosage: d,
        doctor: doctor.text.trim(),
        prescribedOn: date,
        times: times,
        pillsPerDose: pp,
        stock: st,
        photoPath: newPhoto,
      );
    } else {
      e.name = n;
      e.dosage = d;
      e.doctor = doctor.text.trim();
      e.prescribedOn = date;
      e.times = times;
      e.pillsPerDose = pp;
      e.stock = st;
      await s.updateMedicine(e, newPhotoPath: newPhoto);
    }
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final photo = newPhoto ?? widget.existing?.photoPath;
    final raw = widget.parsed?.raw;
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.progress ??
              (widget.existing == null ? 'Add medicine' : 'Edit medicine'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (raw != null) ...[
            Card(
              color: Colors.amber.shade50,
              child: ExpansionTile(
                leading: const Icon(Icons.document_scanner),
                initiallyExpanded: true,
                title: const Text('Scanned text: tap a line to use it'),
                subtitle: const Text(
                    'Tap any line to copy it into Name, Dosage or Doctor.'),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Wrap(
                      spacing: 6,
                      children: [
                        for (final l in raw
                            .split('\n')
                            .map((e) => e.trim())
                            .where((e) => e.isNotEmpty)
                            .take(40))
                          ActionChip(
                            label: Text(l.length > 40 ? '${l.substring(0, 40)}...' : l),
                            onPressed: () => _useLine(l),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          TextField(
            controller: name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
                labelText: 'Medicine name *', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: dosage,
            decoration: const InputDecoration(
                labelText: 'Dosage / strength * (e.g. 500 mg)',
                border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: doctor,
            decoration: const InputDecoration(
                labelText: 'Doctor', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          ListTile(
            shape: RoundedRectangleBorder(
                side: const BorderSide(color: Colors.black26),
                borderRadius: BorderRadius.circular(4)),
            leading: const Icon(Icons.event),
            title: Text('Prescription date: ${fmtDate(date)}'),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: date,
                firstDate: DateTime(2000),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null) setState(() => date = picked);
            },
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: TextField(
                controller: pills,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Pills per dose *',
                    border: OutlineInputBorder()),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: stock,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Pills you have now *',
                    border: OutlineInputBorder()),
              ),
            ),
          ]),
          const SizedBox(height: 16),
          const Text('Dose times *',
              style: TextStyle(fontWeight: FontWeight.bold)),
          Wrap(
            spacing: 8,
            children: [
              for (final t in times)
                InputChip(
                  label: Text(fmtTime(t)),
                  onDeleted: () => setState(() => times.remove(t)),
                ),
              ActionChip(
                avatar: const Icon(Icons.add_alarm),
                label: const Text('Add time'),
                onPressed: addTime,
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Medicine strip / cover photo',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (photo != null && File(photo).existsSync())
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(File(photo), height: 180, fit: BoxFit.cover),
            ),
          OutlinedButton.icon(
            onPressed: choosePhoto,
            icon: const Icon(Icons.add_a_photo),
            label: Text(photo == null ? 'Add photo' : 'Change photo'),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: saving ? null : save,
            icon: const Icon(Icons.check),
            label: Text(widget.existing == null ? 'Confirm and save' : 'Save changes'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
          ),
        ],
      ),
    );
  }
}
