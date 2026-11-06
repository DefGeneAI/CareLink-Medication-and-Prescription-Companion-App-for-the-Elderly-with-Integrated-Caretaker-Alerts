import 'dart:async';

import 'package:flutter/material.dart';

import 'appointments.dart';
import 'login.dart';
import 'medicine_form.dart';
import 'pages.dart';
import 'state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState();
  runApp(CareLinkApp(state: state));
  // Load data after first frame so the UI never blocks on startup.
  state.init();
}

class CareLinkApp extends StatelessWidget {
  final AppState state;
  const CareLinkApp({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Care Link',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F8F7),
      ),
      home: ListenableBuilder(
        listenable: state,
        builder: (context, _) {
          if (!state.loaded) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }
          if (!state.setupDone) return SetupPage(state: state);
          if (!state.loggedIn) return LoginPage(state: state);
          return HomeShell(state: state);
        },
      ),
    );
  }
}

class HomeShell extends StatefulWidget {
  final AppState state;
  const HomeShell({super.key, required this.state});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int tab = 0;
  Timer? _timer;
  bool _alarmOpen = false;

  AppState get s => widget.state;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _tick());
    WidgetsBinding.instance.addPostFrameCallback((_) => _tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    if (lifecycle == AppLifecycleState.resumed) _tick();
  }

  void _tick() {
    if (!mounted) return;
    s.evaluate();
    if (!s.caretaker) _checkAlarm();
  }

  /// In-app alarm: stays until the patient taps Taken (Snooze only delays it).
  Future<void> _checkAlarm() async {
    if (_alarmOpen || !mounted) return;
    final due = s.dueSlots(DateTime.now());
    if (due.isEmpty) return;
    final slot = due.first;
    _alarmOpen = true;
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          icon: const Icon(Icons.alarm, size: 48, color: Colors.teal),
          title: const Text('Time for your medicine'),
          content: Text(
            '${slot.med.name}\n${slot.med.pillsPerDose} x ${slot.med.dosage}\nScheduled ${fmtTime(slot.time)}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(ctx, 'snooze'),
              child: Text(s.snoozesLeft(slot) > 0
                  ? 'Snooze (${s.snoozesLeft(slot)} left)'
                  : 'Snooze (caretaker PIN)'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, 'taken'),
              child: const Text('Medicine Taken'),
            ),
          ],
        ),
      ),
    );
    if (result == 'taken') {
      await s.markTaken(slot);
      _alarmOpen = false;
    } else {
      final ok = mounted ? await secureSnooze(context, s, slot) : false;
      _alarmOpen = false;
      if (!ok && mounted) _checkAlarm(); // snooze cancelled: ring again
    }
  }

  Future<void> _switchRole() async {
    if (s.caretaker) {
      s.setRole(false);
      setState(() => tab = 0);
      return;
    }
    final ok = await askCaretakerPin(context, s);
    if (ok && mounted) {
      s.setRole(true);
      setState(() => tab = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final caretaker = s.caretaker;
        if (!caretaker && tab > 2) tab = 0;
        final pages = <Widget>[
          caretaker
              ? CaretakerDashboard(state: s)
              : PatientHome(state: s, onOpenTab: (i) => setState(() => tab = i)),
          MedicinesPage(state: s),
          AppointmentsPage(state: s),
          if (caretaker) SettingsPage(state: s),
        ];
        return Scaffold(
          appBar: AppBar(
            title: Text(caretaker ? 'Care Link • Caretaker' : 'Care Link',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            actions: [
              if (caretaker)
                IconButton(
                  tooltip: 'Log out',
                  icon: const Icon(Icons.logout),
                  onPressed: s.logout,
                ),
              TextButton.icon(
                onPressed: _switchRole,
                icon: Icon(caretaker ? Icons.person : Icons.supervisor_account),
                label: Text(caretaker ? 'Patient view' : 'Caretaker'),
              ),
            ],
          ),
          body: pages[tab],
          floatingActionButton: tab == 1
              ? FloatingActionButton.extended(
                  onPressed: () => startAddFlow(context, s),
                  icon: const Icon(Icons.add),
                  label: const Text('Add medicine'),
                )
              : tab == 2
                  ? FloatingActionButton.extended(
                      onPressed: () => openAppointmentForm(context, s),
                      icon: const Icon(Icons.add),
                      label: const Text('Add appointment'),
                    )
                  : null,
          bottomNavigationBar: NavigationBar(
            selectedIndex: tab,
            onDestinationSelected: (v) => setState(() => tab = v),
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.home_outlined),
                selectedIcon: const Icon(Icons.home),
                label: caretaker ? 'Dashboard' : 'Home',
              ),
              const NavigationDestination(
                icon: Icon(Icons.medication_outlined),
                selectedIcon: Icon(Icons.medication),
                label: 'Medicines',
              ),
              const NavigationDestination(
                icon: Icon(Icons.event_outlined),
                selectedIcon: Icon(Icons.event),
                label: 'Appointments',
              ),
              if (caretaker)
                const NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: 'Settings',
                ),
            ],
          ),
        );
      },
    );
  }
}
