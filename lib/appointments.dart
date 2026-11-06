import 'package:flutter/material.dart';

import 'models.dart';
import 'state.dart';

Future<void> openAppointmentForm(BuildContext context, AppState state,
    {Appointment? existing}) {
  return Navigator.push<bool>(
    context,
    MaterialPageRoute(
        builder: (_) => AppointmentFormPage(state: state, existing: existing)),
  );
}

class AppointmentsPage extends StatelessWidget {
  final AppState state;
  const AppointmentsPage({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final upcoming = state.appointments
        .where((a) => !a.when.isBefore(now))
        .toList()
      ..sort((a, b) => a.when.compareTo(b.when));
    final past = state.appointments.where((a) => a.when.isBefore(now)).toList()
      ..sort((a, b) => b.when.compareTo(a.when));

    if (state.appointments.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No appointments yet.\nTap "Add appointment" to create one. '
            'You will get reminders 1 day and 1 hour before.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
      children: [
        if (upcoming.isNotEmpty)
          const Text('Upcoming',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        for (final a in upcoming) _card(context, a, false),
        if (past.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text('Past',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          for (final a in past) _card(context, a, true),
        ],
      ],
    );
  }

  Widget _card(BuildContext context, Appointment a, bool past) {
    return Card(
      color: past ? Colors.grey.shade100 : null,
      child: ListTile(
        leading: CircleAvatar(
            child: Icon(past ? Icons.history : Icons.event_available)),
        title: Text(a.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
            '${fmtDateTime(a.when)}${a.place.isEmpty ? "" : "\n${a.place}"}'),
        isThreeLine: a.place.isNotEmpty,
        onTap: () => _detail(context, a),
      ),
    );
  }

  void _detail(BuildContext context, Appointment a) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(a.title, style: Theme.of(ctx).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text('When: ${fmtDateTime(a.when)}'),
              if (a.place.isNotEmpty) Text('Where: ${a.place}'),
              if (a.notes.isNotEmpty) Text('Notes: ${a.notes}'),
              const SizedBox(height: 16),
              if (state.caretaker)
                Row(children: [
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit'),
                      onPressed: () {
                        Navigator.pop(ctx);
                        openAppointmentForm(context, state, existing: a);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete'),
                      onPressed: () async {
                        await state.deleteAppointment(a);
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                    ),
                  ),
                ])
              else
                const Text('Ask your caretaker to change or delete this.',
                    style: TextStyle(color: Colors.black54)),
            ],
          ),
        ),
      ),
    );
  }
}

class AppointmentFormPage extends StatefulWidget {
  final AppState state;
  final Appointment? existing;
  const AppointmentFormPage({super.key, required this.state, this.existing});

  @override
  State<AppointmentFormPage> createState() => _AppointmentFormPageState();
}

class _AppointmentFormPageState extends State<AppointmentFormPage> {
  late final TextEditingController title;
  late final TextEditingController place;
  late final TextEditingController notes;
  late DateTime when;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    title = TextEditingController(text: e?.title ?? '');
    place = TextEditingController(text: e?.place ?? '');
    notes = TextEditingController(text: e?.notes ?? '');
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    when = e?.when ?? DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 10, 0);
  }

  @override
  void dispose() {
    title.dispose();
    place.dispose();
    notes.dispose();
    super.dispose();
  }

  Future<void> save() async {
    final t = title.text.trim();
    if (t.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter the doctor or purpose.')));
      return;
    }
    final e = widget.existing;
    if (e == null) {
      await widget.state.addAppointment(
          title: t, place: place.text.trim(), notes: notes.text.trim(), when: when);
    } else {
      e.title = t;
      e.place = place.text.trim();
      e.notes = notes.text.trim();
      e.when = when;
      await widget.state.updateAppointment(e);
    }
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.existing == null
              ? 'Add appointment'
              : 'Edit appointment')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: title,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
                labelText: 'Doctor / purpose *',
                hintText: 'e.g. Dr. Rao - diabetes check-up',
                border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: place,
            decoration: const InputDecoration(
                labelText: 'Hospital / place', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          ListTile(
            shape: RoundedRectangleBorder(
                side: const BorderSide(color: Colors.black26),
                borderRadius: BorderRadius.circular(4)),
            leading: const Icon(Icons.event),
            title: Text('Date: ${fmtDate(when)}'),
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: when,
                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
              );
              if (d != null) {
                setState(() =>
                    when = DateTime(d.year, d.month, d.day, when.hour, when.minute));
              }
            },
          ),
          const SizedBox(height: 12),
          ListTile(
            shape: RoundedRectangleBorder(
                side: const BorderSide(color: Colors.black26),
                borderRadius: BorderRadius.circular(4)),
            leading: const Icon(Icons.access_time),
            title: Text('Time: ${fmtTime(hhmmOf(when))}'),
            onTap: () async {
              final t = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay(hour: when.hour, minute: when.minute));
              if (t != null) {
                setState(() => when =
                    DateTime(when.year, when.month, when.day, t.hour, t.minute));
              }
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: notes,
            maxLines: 3,
            decoration: const InputDecoration(
                labelText: 'Notes (reports to carry, fasting, etc.)',
                border: OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          const Text('Reminders: 1 day before and 1 hour before.',
              style: TextStyle(color: Colors.black54)),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: save,
            icon: const Icon(Icons.check),
            label: const Text('Save appointment'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
          ),
        ],
      ),
    );
  }
}
