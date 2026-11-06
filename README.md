# Care Link - setup (do these in order)

## 0. Fix the hung emulator first
1. Android Studio > Device Manager > your AVD > the 3-dot menu > **Cold Boot Now**.
   If still stuck: 3-dot menu > **Wipe Data**, then start again.
2. If it keeps hanging: Edit AVD > Show Advanced Settings:
   RAM 2048 MB (or more), VM heap 512 MB, Graphics = **Hardware - GLES 2.0**
   (or "Automatic"), system image = **x86_64** (not ARM).
3. Close Chrome/other heavy apps. Make sure Windows virtualization
   (Intel VT-x / AMD-V, Hyper-V or WHPX) is enabled.
4. Best option: use a real Android phone (Settings > Developer options > USB
   debugging, plug in, `flutter devices`). OCR and notifications are far
   faster and more reliable on a real device.

## 1. Create a clean Flutter project
    flutter doctor
    flutter create --org com.example --platforms android carelink
    cd carelink

## 2. Copy the project files in
- Replace `pubspec.yaml` with the one in this folder.
- Delete the old `lib/` contents and copy in all files from this `lib/`.
- Delete `test/widget_test.dart` (it refers to the default app).
- Replace `android/app/src/main/AndroidManifest.xml` with
  `android_patch/AndroidManifest.xml`.

## 3. Edit android/app/build.gradle.kts
Inside `android { ... }` make sure you have:

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
    defaultConfig {
        minSdk = 24
        // keep the other lines that are already there
    }

and at the bottom of the file add:

    dependencies {
        coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
    }

(If your file is `build.gradle` in Groovy: `coreLibraryDesugaringEnabled true`,
`minSdkVersion 24`, and `coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.0.4'`.)

## 4. Run
    flutter clean
    flutter pub get
    flutter run

The first Gradle build can take 5-10 minutes. Do not stop it.
Caretaker PIN is **1234** (change it in Settings).
