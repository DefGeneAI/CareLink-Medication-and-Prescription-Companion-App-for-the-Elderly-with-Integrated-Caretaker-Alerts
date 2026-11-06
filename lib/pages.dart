import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import 'login.dart';
import 'medicine_form.dart';
import 'models.dart';
import 'notification_service.dart';
import 'state.dart';

// ======================= SHARED BOARD WIDGETS =======================
String _inText(DateTime when, DateTime now) {
  final mins = when.difference(now).inMinutes;
  if (mins < 1) return 'now';
  if (mins < 60) return 'in $mins min';
  final sameDay = when.year == now.year &&
      when.month == now.month &&
      when.day == now.day;
  if (sameDay) return 'today, in ${mins ~/ 60} h ${mins % 60} min';
  return 'tomorrow';
}

class NextDoseCard extends StatelessWidget {
  final AppState state;
  const NextDoseCard({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final n = state.nextDose(now);
    return Card(
      color: Colors.teal.shade50,
      child: ListTile(
        leading: const Icon(Icons.alarm, size: 32),
        title: Text(
          n == null ? 'No upcoming dose' : 'Next dose: ${n.med.name}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(n == null
            ? 'Add a medicine to start reminders'
            : '${fmtTime(n.time)} (${_inText(n.when, now)})'),
      ),
    );
  }
}

class NextAppointmentCard extends StatelessWidget {
  final AppState state;
  final void Function(int)? onOpenTab;
  const NextAppointmentCard({super.key, required this.state, this.onOpenTab});

  @override
  Widget build(BuildContext context) {
    final a = state.nextAppointment(DateTime.now());
    return Card(
      child: ListTile(
        leading: const Icon(Icons.event_available, size: 32),
        title: Text(
          a == null ? 'No upcoming appointment' : a.title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(a == null
            ? 'Tap to add an appointment'
            : '${fmtDateTime(a.when)}${a.place.isEmpty ? "" : "\n${a.place}"}'),
        isThreeLine: a != null && a.place.isNotEmpty,
        trailing: const Icon(Icons.chevron_right),
        onTap: onOpenTab == null ? null : () => onOpenTab!(2),
      ),
    );
  }
}

class RecentActivity extends StatelessWidget {
  final AppState state;
  final int limit;
  const RecentActivity({super.key, required this.state, this.limit = 5});

  @override
  Widget build(BuildContext context) {
    final items = state.recentTaken(limit);
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('Nothing taken yet.'),
      );
    }
    final now = DateTime.now();
    return Column(
      children: [
        for (final h in items)
          Card(
            child: ListTile(
              dense: true,
              leading: const Icon(Icons.check_circle, color: Colors.green),
              title: Text('${h.medName} • ${fmtTime(h.time)} dose'),
              subtitle: Text(() {
                final d = DateTime.fromMillisecondsSinceEpoch(h.takenAt);
                final today = d.year == now.year &&
                    d.month == now.month &&
                    d.day == now.day;
                return 'Taken ${today ? "today" : fmtDate(d)} at ${fmtTimeOfMs(h.takenAt)}';
              }()),
            ),
          ),
      ],
    );
  }
}

// ======================= PATIENT HOME =======================
class PatientHome extends StatelessWidget {
  final AppState state;
  final void Function(int) onOpenTab;
  const PatientHome({super.key, required this.state, required this.onOpenTab});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final slots = state.slotsFor(now);
    final taken = slots.where((s) => s.taken).length;
    final later = state.laterNotices(now);
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Hello! Welcome to Care Link', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 12),
        NextDoseCard(state: state),
        NextAppointmentCard(state: state, onOpenTab: onOpenTab),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(children: [
              const Icon(Icons.today, size: 36),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  slots.isEmpty
                      ? 'No doses scheduled for today'
                      : 'Doses taken today: $taken of ${slots.length}',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w600),
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: () => startAddFlow(context, state),
          icon: const Icon(Icons.document_scanner),
          label: const Text('Scan prescription', style: TextStyle(fontSize: 18)),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(60)),
        ),
        const SizedBox(height: 20),
        const Text('Today’s schedule',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        if (slots.isEmpty && later.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Tap "Scan prescription" to add your first medicine.'),
          ),
        for (final s in slots) _SlotCard(state: state, slot: s, now: now),
        for (final l in later)
          Card(
            color: Colors.blueGrey.shade50,
            child: ListTile(
              leading: const Icon(Icons.schedule),
              title: Text(l),
              subtitle: const Text('This time had already passed when it was added.'),
            ),
          ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('My prescriptions',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            TextButton(
                onPressed: () => onOpenTab(1), child: const Text('View all')),
          ],
        ),
        if (state.medicines.isEmpty) const Text('No prescriptions added yet.'),
        for (final m in state.medicines.take(3))
          Card(
            child: ListTile(
              leading: const Icon(Icons.medication_outlined),
              title: Text(m.name,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(
                  '${m.dosage} • ${m.times.map(fmtTime).join(", ")}\n${state.supplyText(m, now)}'),
              isThreeLine: true,
              onTap: () => onOpenTab(1),
            ),
          ),
        const SizedBox(height: 16),
        const Text('Recently taken',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        RecentActivity(state: state),
      ],
    );
  }
}

class _SlotCard extends StatelessWidget {
  final AppState state;
  final DoseSlot slot;
  final DateTime now;
  const _SlotCard({required this.state, required this.slot, required this.now});

  @override
  Widget build(BuildContext context) {
    final due = slot.isDue(now, state.graceMin, state.snoozed[slot.key]);
    final esc = slot.isEscalated(now, state.graceMin);
    Color? bg;
    String status;
    if (slot.taken) {
      bg = Colors.green.shade50;
      status = 'Taken';
    } else if (esc) {
      bg = Colors.red.shade50;
      status = 'Missed - caretaker alerted';
    } else if (due) {
      bg = Colors.amber.shade50;
      status = 'Due now';
    } else if (state.snoozed[slot.key] != null &&
        now.millisecondsSinceEpoch < state.snoozed[slot.key]!) {
      bg = Colors.blue.shade50;
      status = 'Snoozed';
    } else {
      status = 'Upcoming';
    }
    return Card(
      color: bg,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              CircleAvatar(
                radius: 24,
                child: Icon(slot.taken ? Icons.check : Icons.medication, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(slot.med.name,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    Text(
                        '${fmtTime(slot.time)}  •  ${slot.med.pillsPerDose} x ${slot.med.dosage}',
                        style: const TextStyle(fontSize: 16)),
                    Text(status,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ]),
            if (!slot.taken) ...[
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () => state.markTaken(slot),
                    style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(50)),
                    child: const Text('Medicine Taken',
                        style: TextStyle(fontSize: 17)),
                  ),
                ),
                if (due) ...[
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () => secureSnooze(context, state, slot),
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size(90, 50)),
                    child: Text(state.snoozesLeft(slot) > 0
                        ? 'Snooze (${state.snoozesLeft(slot)})'
                        : 'Snooze (PIN)'),
                  ),
                ],
              ]),
            ],
          ],
        ),
      ),
    );
  }
}

// ======================= CARETAKER DASHBOARD =======================
class CaretakerDashboard extends StatelessWidget {
  final AppState state;
  const CaretakerDashboard({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final slots = state.slotsFor(now);
    final taken = slots.where((s) => s.taken).length;
    final openAlerts = state.alerts.where(state.alertOpen).toList();
    final low = state.medicines.where((m) => state.lowSupply(m, now)).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Caretaker Dashboard',
            style: Theme.of(context).textTheme.headlineSmall),
        const Text('Live overview of the patient'),
        const SizedBox(height: 12),
        NextDoseCard(state: state),
        NextAppointmentCard(state: state),
        Card(
          child: ListTile(
            leading: const Icon(Icons.check_circle_outline),
            title: const Text('Doses confirmed today'),
            subtitle: Text('$taken of ${slots.length}'),
          ),
        ),
        Card(
          color: openAlerts.isEmpty ? null : Colors.red.shade50,
          child: ListTile(
            leading: const Icon(Icons.warning_amber),
            title: const Text('Open missed-dose alerts'),
            subtitle: Text('${openAlerts.length} alert(s)'),
          ),
        ),
        Card(
          color: low.isEmpty ? null : Colors.orange.shade50,
          child: ListTile(
            leading: const Icon(Icons.shopping_cart_outlined),
            title: const Text('Refill reminders'),
            subtitle: Text(low.isEmpty
                ? 'All medicines sufficiently stocked'
                : low.map((m) => '${m.name} (~${state.supplyFor(m, now).daysLeft}d)').join(', ')),
          ),
        ),
        const SizedBox(height: 12),
        const Text('Escalation alerts',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        if (state.alerts.isEmpty)
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('No alerts. All doses confirmed in time.')),
        for (final a in state.alerts.take(20))
          Card(
            child: ListTile(
              leading: Icon(
                state.alertOpen(a) ? Icons.error : Icons.check_circle,
                color: state.alertOpen(a) ? Colors.red : Colors.green,
              ),
              title: Text('${a.medName} - ${fmtTime(a.time)} dose'),
              subtitle: Text(
                  '${state.alertOpen(a) ? "Not confirmed" : "Later confirmed"} • raised ${fmtDate(DateTime.fromMillisecondsSinceEpoch(a.raisedAt))}'),
            ),
          ),
        const SizedBox(height: 12),
        const Text('Today’s dose status',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        for (final s in slots)
          Card(
            child: ListTile(
              leading: Icon(
                s.taken
                    ? Icons.check_circle
                    : s.isEscalated(now, state.graceMin)
                        ? Icons.cancel
                        : Icons.schedule,
                color: s.taken
                    ? Colors.green
                    : s.isEscalated(now, state.graceMin)
                        ? Colors.red
                        : Colors.grey,
              ),
              title: Text('${s.med.name} • ${fmtTime(s.time)}'),
              subtitle: Text(s.taken
                  ? 'Taken at ${fmtTimeOfMs(state.log[s.key]!)}'
                  : s.isEscalated(now, state.graceMin)
                      ? 'Missed${(state.snoozeCount[s.key] ?? 0) > 0 ? " • snoozed ${state.snoozeCount[s.key]}x" : ""}'
                      : 'Pending${(state.snoozeCount[s.key] ?? 0) > 0 ? " • snoozed ${state.snoozeCount[s.key]}x" : ""}'),
            ),
          ),
        const SizedBox(height: 12),
        const Text('Recently taken',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        RecentActivity(state: state, limit: 8),
        const SizedBox(height: 12),
        const Text('Supply',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        for (final m in state.medicines)
          Card(
            child: ListTile(
              leading: const Icon(Icons.inventory_2_outlined),
              title: Text(m.name),
              subtitle: Text(state.supplyText(m, now, detailed: true)),
              isThreeLine: true,
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                if (state.lowSupply(m, now))
                  const Icon(Icons.warning, color: Colors.deepOrange),
                IconButton(
                  tooltip: 'Add refilled pills',
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () => refillDialog(context, state, m),
                ),
              ]),
            ),
          ),
      ],
    );
  }
}

String fmtTimeOfMs(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  return fmtTime(
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}');
}

// ======================= MEDICINES / PRESCRIPTIONS =======================
enum SortMode { newest, oldest, name }

class MedicinesPage extends StatefulWidget {
  final AppState state;
  const MedicinesPage({super.key, required this.state});

  @override
  State<MedicinesPage> createState() => _MedicinesPageState();
}

class _MedicinesPageState extends State<MedicinesPage> {
  String query = '';
  SortMode sort = SortMode.newest;
  DateTimeRange? range;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    var list = state.medicines.where((m) {
      final q = query.toLowerCase();
      final okText = q.isEmpty ||
          m.name.toLowerCase().contains(q) ||
          m.doctor.toLowerCase().contains(q);
      final okDate = range == null ||
          (!m.prescribedOn.isBefore(range!.start) &&
              !m.prescribedOn.isAfter(range!.end.add(const Duration(days: 1))));
      return okText && okDate;
    }).toList();
    list.sort((a, b) {
      switch (sort) {
        case SortMode.newest:
          return b.prescribedOn.compareTo(a.prescribedOn);
        case SortMode.oldest:
          return a.prescribedOn.compareTo(b.prescribedOn);
        case SortMode.name:
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }
    });

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(children: [
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search medicine or doctor',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => query = v),
              ),
            ),
            PopupMenuButton<SortMode>(
              icon: const Icon(Icons.sort),
              tooltip: 'Sort',
              onSelected: (v) => setState(() => sort = v),
              itemBuilder: (_) => const [
                PopupMenuItem(value: SortMode.newest, child: Text('Newest first')),
                PopupMenuItem(value: SortMode.oldest, child: Text('Oldest first')),
                PopupMenuItem(value: SortMode.name, child: Text('Name A-Z')),
              ],
            ),
            IconButton(
              tooltip: 'Filter by date range',
              icon: Icon(Icons.date_range,
                  color: range == null ? null : Theme.of(context).colorScheme.primary),
              onPressed: () async {
                final r = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                  initialDateRange: range,
                );
                if (r != null) setState(() => range = r);
              },
            ),
          ]),
        ),
        if (range != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: InputChip(
                label: Text('${fmtDate(range!.start)} - ${fmtDate(range!.end)}'),
                onDeleted: () => setState(() => range = null),
              ),
            ),
          ),
        Expanded(
          child: list.isEmpty
              ? const Center(child: Text('No medicines found'))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                  itemCount: list.length,
                  itemBuilder: (_, i) => _medCard(list[i]),
                ),
        ),
      ],
    );
  }

  Widget _medCard(Medicine m) {
    final low = widget.state.lowSupply(m, DateTime.now());
    final hasPhoto = m.photoPath != null && File(m.photoPath!).existsSync();
    return Card(
      child: ListTile(
        onTap: () => _showDetail(m),
        leading: hasPhoto
            ? ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.file(File(m.photoPath!),
                    width: 52, height: 52, fit: BoxFit.cover),
              )
            : const CircleAvatar(child: Icon(Icons.medication_outlined)),
        title: Text(m.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
            '${m.dosage} • ${m.times.map(fmtTime).join(", ")}\n'
            '${m.doctor.isEmpty ? "" : "${m.doctor} • "}${fmtDate(m.prescribedOn)}\n'
            '${widget.state.supplyText(m, DateTime.now())}${low ? "\n⚠ refill soon" : ""}'),
        isThreeLine: true,
      ),
    );
  }

  void _showDetail(Medicine m) {
    final state = widget.state;
    final hasPhoto = m.photoPath != null && File(m.photoPath!).existsSync();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(m.name, style: Theme.of(ctx).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text('Dosage: ${m.dosage}'),
              Text('Pills per dose: ${m.pillsPerDose}'),
              Text('Times: ${m.times.map(fmtTime).join(", ")}'),
              if (m.doctor.isNotEmpty) Text('Doctor: ${m.doctor}'),
              Text('Prescribed: ${fmtDate(m.prescribedOn)}'),
              Text(state.supplyText(m, DateTime.now(), detailed: true)),
              const SizedBox(height: 12),
              if (hasPhoto) ...[
                const Text('Medicine photo (for visual check):',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(File(m.photoPath!), fit: BoxFit.contain),
                ),
              ] else
                const Text('No photo attached.'),
              const SizedBox(height: 16),
              if (state.caretaker) ...[
                OutlinedButton.icon(
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Add refilled pills'),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await refillDialog(context, state, m);
                  },
                ),
                const SizedBox(height: 8),
              ],
              if (state.caretaker)
                Row(children: [
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit'),
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  MedicineFormPage(state: state, existing: m)),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete'),
                      onPressed: () async {
                        final ok = await showDialog<bool>(
                          context: ctx,
                          builder: (d) => AlertDialog(
                            title: const Text('Delete medicine?'),
                            content: Text('Remove ${m.name} and its reminders?'),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(d, false),
                                  child: const Text('Cancel')),
                              FilledButton(
                                  onPressed: () => Navigator.pop(d, true),
                                  child: const Text('Delete')),
                            ],
                          ),
                        );
                        if (ok == true) {
                          await state.deleteMedicine(m);
                          if (ctx.mounted) Navigator.pop(ctx);
                        }
                      },
                    ),
                  ),
                ])
              else
                const Text('Ask your caretaker to edit or delete this entry.',
                    style: TextStyle(color: Colors.black54)),
            ],
          ),
        ),
      ),
    );
  }
}

// ======================= SETTINGS (caretaker only) =======================
class SettingsPage extends StatelessWidget {
  final AppState state;
  const SettingsPage({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Settings', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        ListTile(
          leading: const Icon(Icons.person),
          title: const Text('Caretaker name'),
          subtitle: Text(state.caretakerName),
          onTap: () async {
            final v = await _askText(context, 'Caretaker name', state.caretakerName);
            if (v != null && v.isNotEmpty) state.setSettings(name: v);
          },
        ),
        ListTile(
          leading: const Icon(Icons.lock),
          title: const Text('Caretaker PIN'),
          subtitle: const Text('Required to open caretaker mode'),
          onTap: () async {
            final v = await _askText(context, 'New PIN (4+ digits)', '',
                numeric: true);
            if (v != null && v.length >= 4) {
              state.setSettings(newPin: v);
            }
          },
        ),
        const Divider(),
        const Text('Escalate to caretaker after',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 30, label: Text('30 min')),
            ButtonSegment(value: 45, label: Text('45 min')),
            ButtonSegment(value: 60, label: Text('60 min')),
          ],
          selected: {state.graceMin},
          onSelectionChanged: (s) => state.setSettings(grace: s.first),
        ),
        const SizedBox(height: 16),
        const Text('Snooze / re-ring every',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 5, label: Text('5 min')),
            ButtonSegment(value: 10, label: Text('10 min')),
            ButtonSegment(value: 15, label: Text('15 min')),
          ],
          selected: {state.snoozeMin},
          onSelectionChanged: (s) => state.setSettings(snooze: s.first),
        ),
        const Divider(height: 32),
        OutlinedButton.icon(
          icon: const Icon(Icons.notifications_active),
          label: const Text('Send test notification'),
          onPressed: () async {
            await NotificationService.show(
                999999999, 'Care Link test', 'Notifications are working.');
            if (context.mounted && !NotificationService.ready) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Notifications are not available/allowed.')));
            }
          },
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.timer),
          label: const Text('Test scheduled reminder (15 seconds)'),
          onPressed: () async {
            await NotificationService.scheduleTest(seconds: 15);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text(
                      'Reminder scheduled. Press Home on the phone and wait 15 seconds.')));
            }
          },
        ),
        const SizedBox(height: 16),
        const Text(
          'Note: in this build, the caretaker alert is delivered as a local '
          'notification and dashboard entry on this device. Delivering it to a '
          'different phone needs the Firebase (FCM) backend.',
          style: TextStyle(color: Colors.black54),
        ),
      ],
    );
  }
}

Future<String?> _askText(BuildContext context, String title, String initial,
    {bool numeric = false}) {
  final c = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: c,
        autofocus: true,
        keyboardType: numeric ? TextInputType.number : TextInputType.text,
        obscureText: numeric,
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, c.text.trim()),
            child: const Text('Save')),
      ],
    ),
  );
}

Future<void> refillDialog(
    BuildContext context, AppState state, Medicine m) async {
  final c = TextEditingController();
  final n = await showDialog<int>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Add pills to ${m.name}'),
      content: TextField(
        controller: c,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(hintText: 'Number of pills bought'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, int.tryParse(c.text.trim())),
            child: const Text('Add')),
      ],
    ),
  );
  if (n != null && n > 0) await state.addStock(m, n);
}

// ======================= SECURE SNOOZE =======================
/// Snoozing is deliberately hard: limited snoozes per dose, a warning with a
/// 5-second wait, and the caretaker PIN once the limit is used up.
/// Returns true only if the dose was really snoozed.
Future<bool> secureSnooze(
    BuildContext context, AppState state, DoseSlot slot) async {
  if (state.snoozesLeft(slot) <= 0) {
    final ok = await askCaretakerPin(context, state,
        title: 'Snooze limit reached. Caretaker PIN needed');
    if (!ok) return false;
  }
  if (!context.mounted) return false;
  final go = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _SnoozeConfirm(
      minutes: state.snoozeMin,
      graceMin: state.graceMin,
      caretakerName: state.caretakerName,
      leftAfter: (state.snoozesLeft(slot) - 1).clamp(0, 9).toInt(),
    ),
  );
  if (go != true) return false;
  await state.snooze(slot);
  return true;
}

class _SnoozeConfirm extends StatefulWidget {
  final int minutes;
  final int graceMin;
  final String caretakerName;
  final int leftAfter;
  const _SnoozeConfirm({
    required this.minutes,
    required this.graceMin,
    required this.caretakerName,
    required this.leftAfter,
  });

  @override
  State<_SnoozeConfirm> createState() => _SnoozeConfirmState();
}

class _SnoozeConfirmState extends State<_SnoozeConfirm> {
  int sec = 5;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (tm) {
      if (!mounted) {
        tm.cancel();
        return;
      }
      setState(() => sec = sec > 0 ? sec - 1 : 0);
      if (sec == 0) tm.cancel();
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        icon: const Icon(Icons.warning_amber, size: 44, color: Colors.orange),
        title: const Text('Delay this medicine?'),
        content: Text(
          'Missing or delaying a dose can affect your health.\n\n'
          'If it is not taken within ${widget.graceMin} minutes of its '
          'scheduled time, ${widget.caretakerName} is alerted automatically.\n\n'
          'Snoozes left after this: ${widget.leftAfter}',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Take it now'),
          ),
          TextButton(
            onPressed: sec == 0 ? () => Navigator.pop(context, true) : null,
            child: Text(sec == 0
                ? 'Snooze ${widget.minutes} min'
                : 'Snooze available in ${sec}s'),
          ),
        ],
      ),
    );
  }
}
