import 'package:flutter/material.dart';

import 'state.dart';

/// Asks for the caretaker PIN. 3 wrong tries lock entry for 60 seconds.
Future<bool> askCaretakerPin(BuildContext context, AppState state,
    {String title = 'Caretaker PIN'}) async {
  if (state.lockedOut) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'Too many wrong attempts. Try again in ${state.lockSecondsLeft} s.')));
    return false;
  }
  final c = TextEditingController();
  final entered = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: c,
        autofocus: true,
        obscureText: true,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(hintText: 'Enter PIN'),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, c.text.trim()),
            child: const Text('Confirm')),
      ],
    ),
  );
  if (entered == null) return false;
  final ok = state.verifyPin(entered);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(state.lockedOut
            ? 'Too many wrong attempts. Locked for 60 seconds.'
            : 'Wrong PIN.')));
  }
  return ok;
}

/// First launch: create the patient profile and the caretaker PIN.
class SetupPage extends StatefulWidget {
  final AppState state;
  const SetupPage({super.key, required this.state});

  @override
  State<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends State<SetupPage> {
  final patient = TextEditingController();
  final caretaker = TextEditingController();
  final pin = TextEditingController();
  final pin2 = TextEditingController();
  String? error;

  @override
  void dispose() {
    patient.dispose();
    caretaker.dispose();
    pin.dispose();
    pin2.dispose();
    super.dispose();
  }

  Future<void> create() async {
    final p = pin.text.trim();
    if (patient.text.trim().isEmpty) {
      setState(() => error = 'Please enter the patient name.');
    } else if (p.length < 4 || int.tryParse(p) == null) {
      setState(() => error = 'The PIN must be at least 4 digits.');
    } else if (p != pin2.text.trim()) {
      setState(() => error = 'The two PINs do not match.');
    } else {
      await widget.state.completeSetup(
        patient: patient.text.trim(),
        caretakerNameIn: caretaker.text.trim(),
        newPin: p,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Welcome to Care Link')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Icon(Icons.health_and_safety, size: 64, color: Colors.teal),
          const SizedBox(height: 8),
          const Text('Set up your account',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text(
              'The caretaker PIN protects settings, editing, and extra snoozes.',
              textAlign: TextAlign.center),
          const SizedBox(height: 20),
          TextField(
            controller: patient,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
                labelText: 'Patient name *', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: caretaker,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
                labelText: 'Caretaker name', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: pin,
            obscureText: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
                labelText: 'Create caretaker PIN (4+ digits) *',
                border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: pin2,
            obscureText: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
                labelText: 'Confirm PIN *', border: OutlineInputBorder()),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(error!, style: const TextStyle(color: Colors.red)),
            ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: create,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
            child: const Text('Create account', style: TextStyle(fontSize: 17)),
          ),
        ],
      ),
    );
  }
}

/// Shown on every launch. Patient: one tap. Caretaker: PIN required.
class LoginPage extends StatelessWidget {
  final AppState state;
  const LoginPage({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.health_and_safety, size: 80, color: Colors.teal),
                const SizedBox(height: 12),
                const Text('Care Link',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                  state.patientName.isEmpty
                      ? 'Welcome back'
                      : 'Welcome back, ${state.patientName}',
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: state.loginPatient,
                  icon: const Icon(Icons.person),
                  label: const Text('I am the patient',
                      style: TextStyle(fontSize: 18)),
                  style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(60)),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final ok = await askCaretakerPin(context, state,
                        title: 'Caretaker login');
                    if (ok) state.loginCaretaker();
                  },
                  icon: const Icon(Icons.supervisor_account),
                  label: Text('Caretaker login${state.caretakerName == "Caretaker" ? "" : " (${state.caretakerName})"}',
                      style: const TextStyle(fontSize: 18)),
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(60)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
