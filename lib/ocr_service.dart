import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class ParsedRx {
  String name = '';
  String dosage = '';
  String doctor = '';
  DateTime? date;
  int pillsPerDose = 1;
  List<String> times = ['08:00'];
  int? stock;
  String raw = '';
}

class OcrService {
  /// On-device ML Kit OCR with a timeout so the UI can never hang.
  static Future<String> extractText(String path) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final input = InputImage.fromFilePath(path);
      final result = await recognizer
          .processImage(input)
          .timeout(const Duration(seconds: 40));
      return result.text;
    } finally {
      await recognizer.close();
    }
  }

  static final RegExp _strengthRe = RegExp(
      r'(\d+(?:\.\d+)?)\s?(mg|mcg|µg|g|ml|iu)\b',
      caseSensitive: false);

  static final RegExp _prefixRe = RegExp(
      r'^[\W_]*(?:\d+\s*[\).:\-]\s*)?(?:tab|tabs|tablet|tablets|cap|caps|capsule|capsules|syp|syrup|inj|injection|drops|oint|ointment|[tc](?=\.))\b\.?\s*([A-Za-z][A-Za-z0-9\- ]{1,32})',
      caseSensitive: false);

  // 1-0-1 style, tolerant of OCR mistakes (l, I, | read as 1 and O as 0)
  static final RegExp _freqRe = RegExp(
      r'(?<![0-9])([0-9lIOo|])\s*[-–—]\s*([0-9lIOo|])\s*[-–—]\s*([0-9lIOo|])(?![0-9])');

  static int _digit(String c) {
    if ('lI|'.contains(c)) return 1;
    if (c == 'O' || c == 'o') return 0;
    return int.tryParse(c) ?? 0;
  }

  static void _applyFrequency(String text, ParsedRx p) {
    final m = _freqRe.firstMatch(text);
    if (m != null) {
      final d = [_digit(m.group(1)!), _digit(m.group(2)!), _digit(m.group(3)!)];
      final t = <String>[];
      if (d[0] > 0) t.add('08:00');
      if (d[1] > 0) t.add('14:00');
      if (d[2] > 0) t.add('21:00');
      if (t.isNotEmpty) {
        p.times = t;
        p.pillsPerDose = d.reduce((a, b) => a > b ? a : b);
        return;
      }
    }
    final lower = text.toLowerCase();
    final ev = RegExp(r'every\s+(\d{1,2})\s*(?:hours|hrs|hr|h)\b').firstMatch(lower);
    if (ev != null) {
      final h = int.parse(ev.group(1)!);
      if (h >= 4 && h <= 24) {
        final t = <String>[];
        for (var x = 8, n = 0; n < 24 ~/ h && n < 6; x += h, n++) {
          t.add('${(x % 24).toString().padLeft(2, '0')}:00');
        }
        p.times = t;
        return;
      }
    }
    final words = <String>[];
    if (RegExp(r'\bmorning\b').hasMatch(lower)) words.add('08:00');
    if (RegExp(r'\b(afternoon|noon)\b').hasMatch(lower)) words.add('14:00');
    if (RegExp(r'\bevening\b').hasMatch(lower)) words.add('18:00');
    if (RegExp(r'\bnight\b').hasMatch(lower)) words.add('21:00');
    if (words.isNotEmpty) {
      p.times = words;
      return;
    }
    if (RegExp(r'\b(qid|four times)\b').hasMatch(lower)) {
      p.times = ['08:00', '12:00', '16:00', '20:00'];
    } else if (RegExp(r'\b(tds|tid|thrice|three times)\b').hasMatch(lower)) {
      p.times = ['08:00', '14:00', '21:00'];
    } else if (RegExp(r'\b(bd|bid|twice)\b').hasMatch(lower)) {
      p.times = ['08:00', '20:00'];
    } else if (RegExp(r'\b(hs|at night|bedtime)\b').hasMatch(lower)) {
      p.times = ['21:00'];
    } else if (RegExp(r'\b(od|once)\b').hasMatch(lower)) {
      p.times = ['08:00'];
    }
  }

  /// Returns one entry per medicine found (at least one). Results are only
  /// suggestions; the user confirms each in a form.
  static List<ParsedRx> parseAll(String text) {
    final lines = text
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    // shared info: doctor and date
    String doctor = '';
    for (final line in lines) {
      final m = RegExp(r'\bdr\.?\s+[A-Za-z][A-Za-z. ]{2,30}',
              caseSensitive: false)
          .firstMatch(line);
      if (m != null) {
        doctor = m.group(0)!.trim();
        break;
      }
    }
    DateTime? date;
    final dm =
        RegExp(r'(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2,4})').firstMatch(text);
    if (dm != null) {
      final d = int.parse(dm.group(1)!);
      final mo = int.parse(dm.group(2)!);
      var y = int.parse(dm.group(3)!);
      if (y < 100) y += 2000;
      if (mo >= 1 && mo <= 12 && d >= 1 && d <= 31 && y > 2000 && y < 2100) {
        date = DateTime(y, mo, d);
      }
    }

    // find medicine lines
    var medIdx = <int>[];
    for (var i = 0; i < lines.length; i++) {
      if (_prefixRe.hasMatch(lines[i])) medIdx.add(i);
    }
    if (medIdx.isEmpty) {
      for (var i = 0; i < lines.length; i++) {
        final l = lines[i];
        if (_strengthRe.hasMatch(l) &&
            RegExp(r'^[^A-Za-z]*[A-Za-z]{3,}').hasMatch(l)) {
          medIdx.add(i);
        }
      }
    }

    final results = <ParsedRx>[];
    for (var k = 0; k < medIdx.length; k++) {
      final start = medIdx[k];
      var end = k + 1 < medIdx.length ? medIdx[k + 1] : lines.length;
      if (end > start + 4) end = start + 4;
      final block = lines.sublist(start, end).join(' ');
      final p = ParsedRx()
        ..raw = text
        ..doctor = doctor
        ..date = date;

      var name = '';
      final pm = _prefixRe.firstMatch(lines[start]);
      if (pm != null) {
        name = pm.group(1)!;
      } else {
        final sm = _strengthRe.firstMatch(lines[start]);
        name = sm == null
            ? lines[start]
            : lines[start].substring(0, sm.start);
      }
      name = name
          .split(RegExp(r'\s+(?:tds|tid|qid|bd|bid|od|hs|once|twice|thrice)\b',
              caseSensitive: false))
          .first
          .replaceAll(_strengthRe, '')
          .replaceAll(_freqRe, '')
          .replaceAll(RegExp(r'^[^A-Za-z]+'), '')
          .replaceAll(RegExp(r'[^A-Za-z]+$'), '')
          .trim();
      if (name.isEmpty && start > 0) {
        name = lines[start - 1]
            .replaceAll(RegExp(r'^[^A-Za-z]+'), '')
            .replaceAll(RegExp(r'[^A-Za-z ]+$'), '')
            .trim();
        if (RegExp(r'\b(dr|date|name|age|rx)\b', caseSensitive: false)
            .hasMatch(name)) {
          name = '';
        }
      }
      p.name = name;

      final sm = _strengthRe.firstMatch(block);
      if (sm != null) p.dosage = sm.group(0)!.trim();

      _applyFrequency(block, p);
      if (p.pillsPerDose == 1) {
        final pm2 = RegExp(
                r'(\d)\s*(?:tab|tabs|tablet|tablets|cap|caps|capsule|capsules)\b',
                caseSensitive: false)
            .firstMatch(block);
        if (pm2 != null) {
          final n = int.parse(pm2.group(1)!);
          if (n >= 1 && n <= 6) p.pillsPerDose = n;
        }
      }

      final dd = RegExp(r'(\d{1,3})\s*(?:days|day)\b', caseSensitive: false)
          .firstMatch(block);
      if (dd != null) {
        final days = int.parse(dd.group(1)!);
        if (days > 0 && days < 400) {
          p.stock = days * p.pillsPerDose * p.times.length;
        }
      }
      results.add(p);
    }

    if (results.isEmpty) {
      results.add(ParsedRx()
        ..raw = text
        ..doctor = doctor
        ..date = date);
    }
    return results;
  }
}
