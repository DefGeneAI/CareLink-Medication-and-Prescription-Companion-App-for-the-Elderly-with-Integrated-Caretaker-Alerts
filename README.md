<div align="center">

# 💊 Care Link

### A Smart Medication and Prescription Companion App for the Elderly, with Integrated Caretaker Alerts

*MACSE512 – Operating Systems · Project Review · School of Computer Science and Engineering, VIT Chennai*

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![Android](https://img.shields.io/badge/Android-3DDC84?style=for-the-badge&logo=android&logoColor=white)
![Google ML Kit](https://img.shields.io/badge/Google%20ML%20Kit%20OCR-4285F4?style=for-the-badge&logo=google&logoColor=white)
![Notifications](https://img.shields.io/badge/Local%20Notifications-F4B400?style=for-the-badge&logo=android&logoColor=white)
![Android Studio](https://img.shields.io/badge/Android%20Studio-3DDC84?style=for-the-badge&logo=androidstudio&logoColor=white)
![VS Code](https://img.shields.io/badge/VS%20Code-007ACC?style=for-the-badge&logo=visualstudiocode&logoColor=white)
![Git](https://img.shields.io/badge/Git%20%26%20GitHub-F05032?style=for-the-badge&logo=git&logoColor=white)

| 📱 Mobile Development | 🔍 OCR & Parsing | ⏰ Alarms & Scheduling | 🔐 Access Control | 🧠 App Architecture | 🛠️ Build & Debugging |
|:---:|:---:|:---:|:---:|:---:|:---:|
| Flutter · Dart | ML Kit · Regex | Local notifications | Roles · PIN · Lockout | State management · JSON storage | Gradle · Emulator · adb |

</div>

---

## 📌 Why we are doing this project

Elderly people often manage many medicines at different times of the day, plus doctor appointments, with apps that are too complicated for them. A missed or doubled dose puts their safety at risk.

Their families carry the burden: sorting pills, filing paper prescriptions, and reminding the patient again and again. When the caretaker is at work, there is no way to know whether the medicine was actually taken.

**Care Link's goal:** effortless, low-friction use for senior citizens, and real-time visibility for their caregivers.

## ✨ What it does

| Feature | Description |
|---|---|
| 📷 **Prescription scanner** | Photograph a prescription; on-device OCR suggests medicine name, dosage, doctor, date and timing. Multiple medicines per prescription are supported, and the user always confirms before saving. |
| ⏰ **Fail-safe alarms** | Daily alarms with follow-up reminders. Snooze is limited (2 per dose, with a warning and a short wait, then the caretaker PIN). The alarm only clears when the patient taps **Medicine Taken**. |
| 🚨 **Caretaker escalation** | If a dose is not confirmed within 30, 45 or 60 minutes (configurable), an alert is raised on the caretaker dashboard and as a notification. |
| 💊 **Prescription management** | Add, edit, delete; search by medicine or doctor; sort by date or name; filter by date range. |
| 🖼️ **Medicine photos** | Attach a photo of the strip or box for visual verification. |
| 📦 **Supply forecast** | Calculates pills left, the approximate date they run out, and a "buy by" date; sends refill alerts. Caretakers can log refilled pills. |
| 📅 **Appointments** | Doctor visits with reminders 1 day and 1 hour before; shown on the home board. |
| 👥 **Two roles** | A large-button **patient view** and a PIN-protected **caretaker dashboard** with full edit rights, alerts, history and settings. |
| 🔑 **Login** | First-run setup (patient name, caretaker PIN), login on every launch, and a 60-second lockout after 3 wrong PINs. |

## 🧩 Modules

| # | Module | Status |
|---|---|---|
| 1 | User registration and login | 🟡 Partial: local login and PIN roles; cloud accounts future scope |
| 2 | AI prescription scanner | ✅ Done |
| 3 | Prescription management | ✅ Done |
| 4 | Medicine reminder and escalation | ✅ Done (same-device alerts) |
| 5 | Medicine label photo capture | ✅ Done |
| 6 | Caretaker dashboard | ✅ Done |
| 7 | Purchase reminder | ✅ Done |
| 8 | Notifications | 🟡 Partial: local done; push (FCM) future scope |
| 9 | Appointments | ✅ Done |

## 🏗️ Architecture

```
┌──────────────────────────  USER LAYER  ──────────────────────────┐
│        Patient view (simple)        Caretaker dashboard (PIN)    │
└────────────────────────────────┬─────────────────────────────────┘
                                 │
┌──────────────────  APPLICATION LAYER (Dart)  ────────────────────┐
│  Reminder & escalation · Prescription management · Supply        │
│  forecast · Appointments · Login & access control · OCR parser   │
└───────────────┬──────────────────────────────┬───────────────────┘
                │                              │
┌───────────────▼──────────────┐   ┌───────────▼───────────────────┐
│   STORAGE (on device)        │   │   EXTERNAL SERVICES           │
│   JSON in shared_preferences │   │   Google ML Kit (OCR)         │
│   Photos in app documents    │   │   Local notifications         │
│   (Firebase planned)         │   │   (Firebase / FCM planned)    │
└──────────────────────────────┘   └───────────────────────────────┘
```

## 🗂️ Project structure

```
lib/
├── main.dart                  App entry, login gate, navigation, in-app alarm
├── login.dart                 First-run setup, login, PIN prompt with lockout
├── state.dart                 App state, persistence, supply forecast, security rules
├── models.dart                Medicine, DoseSlot, AlertRecord, Appointment
├── pages.dart                 Patient home, caretaker dashboard, medicines list, settings, secure snooze
├── medicine_form.dart         Add/edit medicine, scan flow, tap-to-fill from OCR text
├── appointments.dart          Appointments list and form
├── ocr_service.dart           ML Kit OCR and prescription text parser
└── notification_service.dart  Alarm, reminder, escalation and appointment scheduling
```

## 🚀 How to use this repo

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (run `flutter doctor` and fix any issues)
- Android Studio (SDK and emulator) and/or VS Code with the Flutter extension
- An Android emulator (API 34, x86_64 recommended) or a real Android phone with USB debugging
- Internet for the first build (Gradle and libraries are downloaded)

### Run it
```bash
git clone <your-repo-url>
cd carelink
flutter pub get
flutter run
```

> **Important:** keep the project on the **same drive as your Flutter pub cache** (normally `C:`) and avoid spaces in the folder path. Different drives can break the Kotlin build.

### Android settings the project relies on
These are already set in this repo. If you rebuild the project from scratch, make sure of the following:

- `android/app/build.gradle.kts`: `minSdk = 24`, `isCoreLibraryDesugaringEnabled = true`, and the dependency `coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")`.
- `AndroidManifest.xml`: permissions for notifications, vibration, boot, camera and exact alarms, plus the `ScheduledNotificationReceiver` and `ScheduledNotificationBootReceiver` entries.
- `android/gradle.properties`: `kotlin.incremental=false` and `kotlin.compiler.execution.strategy=in-process` (avoids a known cache error); a modest `org.gradle.jvmargs` such as `-Xmx3G`.

### Using the app
1. **First launch:** enter the patient name, caretaker name, and create a caretaker PIN.
2. **Login:** tap **I am the patient**, or **Caretaker login** and enter the PIN.
3. **Add a medicine:** *Scan prescription* (camera or gallery) or *Enter manually*. Check every field, then confirm. If OCR misses something, tap a line of the scanned text to copy it into Name, Dosage or Doctor.
4. **Reminders:** when a dose is due, tap **Medicine Taken**. Snooze is limited and needs a warning wait; after the limit it needs the caretaker PIN.
5. **Caretaker mode:** open the dashboard to see missed-dose alerts, today's status, recent activity and supply; edit or delete prescriptions; add refilled pills; change settings.

### Tips for good scans
Use a straight, well-lit photo of **printed** text, filling most of the frame. Handwriting reads poorly with on-device OCR. A format like `Tab. Metformin 500mg 1-0-1 x 30 days` fills best. On the emulator, drag an image onto the emulator window to add it to the gallery.

### Troubleshooting
| Problem | Fix |
|---|---|
| Gradle download "Connection reset" | Switch network or use a mobile hotspot; confirm the Gradle version in `gradle-wrapper.properties` is cached in `~/.gradle/wrapper/dists`. |
| "this and base files have different roots" | Move the project to the same drive as the pub cache; set `kotlin.incremental=false`. |
| Emulator frozen | Cold boot or wipe data in Device Manager, give it 2 GB+ RAM, or use a real phone. |
| No alarm sound or notification | Allow notifications for the app; check battery-saver restrictions; use the test buttons. |

## ⚠️ Current limitations
- Data is stored **on one device**. The caretaker alert appears on the same device; delivering it to another phone needs Firebase.
- The PIN is stored locally, so it deters casual use but is not tamper-proof.
- OCR accuracy is best on printed text and may fail on handwriting.
- Tested on Android only.

## 🛣️ Roadmap
- [ ] Cloud login and caretaker-to-patient account linking (Firebase Authentication)
- [ ] Real-time sync across phones (Cloud Firestore)
- [ ] Push alerts to the caretaker's phone (Firebase Cloud Messaging)
- [ ] Secure **Dose Taken** (PIN or biometric confirmation, time-stamped log)
- [ ] Improved OCR: image pre-processing, handwriting accuracy, learning from corrections

## 🎓 Skills learnt

| Area | What we learnt |
|---|---|
| **Mobile development** | Building a multi-screen Flutter app in Dart, navigation, forms, dialogs, responsive and large-text layouts for elderly users |
| **State management and storage** | `ChangeNotifier` and `ListenableBuilder`, JSON persistence with `shared_preferences`, saving photos to app storage |
| **OCR and text processing** | Using Google ML Kit, then turning noisy text into fields with regular expressions, handling OCR mistakes and multi-medicine prescriptions |
| **Scheduling and notifications** | Timezone-aware scheduling, exact vs. inexact alarms, notification channels and permissions, unique notification IDs |
| **Security basics** | Role-based access control, PIN protection, attempt lockout, limiting a risky action (snooze) |
| **Algorithms** | Simulating future doses to forecast when pills run out and when to refill |
| **Design and UX** | Designing for seniors and caretakers, flow and architecture diagrams, module breakdown |
| **Tooling and debugging** | Gradle and Android build configuration, emulator management, `adb`, fixing network and cross-drive build errors |
| **Teamwork** | Git and GitHub, dividing modules between two people, testing and documentation |

## 👩‍💻 Team

| Name | Reg. No. |
|---|---|
| Numa Jalal | 26MCB1018 |
| Karen Francina Morais | 26MCB1019 |

*School of Computer Science and Engineering, VIT Chennai · MACSE512 – OS*

## 📄 License and disclaimer
Created as an academic project. Care Link is **not a medical device** and does not replace professional medical advice; always follow your doctor's instructions.
