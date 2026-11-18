# Sahayak Mobile & Web Application

The Flutter client for **Sahayak (सहायक)**, a unified assistive AI application for deaf, mute, and visually impaired individuals.

## 🚀 Implemented Features

1. **Sign-to-Speech (Sign AI)**:
   - Real-time gesture recognition using camera and MediaPipe Hands.
   - Text captions and automatic audio speech output (`flutter_tts`).
2. **Blind Path Navigator**:
   - Live obstacle detection, distance perception, and spatial awareness.
   - Spoken audio directions to guide visually impaired users safely.
3. **Offline Currency Detector**:
   - On-device Indian Rupee banknote recognition using YOLOv10n ONNX (`assets/models/best.onnx`).
   - Supports ₹5, ₹10, ₹20, ₹50, ₹100, ₹200, and ₹500 denominations.
   - Real-time bounding boxes and voice announcement.
4. **Sahayak Home Dashboard**:
   - Modern Material 3 interface with intuitive navigation and fast tool launchers.
   - Privacy-first design with 100% on-device vision processing.

## 📱 Quick Start

For detailed step-by-step setup and troubleshooting, refer to [frontend_guide.md](frontend_guide.md).

### 1. Install Dependencies
```bash
flutter pub get
```

### 2. Run the App
```bash
# Run on connected mobile device or emulator
flutter run

# Run on Chrome
flutter run -d chrome
```

### 3. Build Release
```bash
# Android APK
flutter build apk --release

# Web
flutter build web --release
```

## 🔒 Permissions
Declared in `android/app/src/main/AndroidManifest.xml`:
- `android.permission.CAMERA`
- `android.permission.INTERNET`
- `android.permission.RECORD_AUDIO`

## 📚 Related Documentation
- Main Project Documentation: [../README.md](../README.md)
- Frontend Run Guide: [frontend_guide.md](frontend_guide.md)
- Backend Run Guide: [../backend/docs/backend_run_guide.md](../backend/docs/backend_run_guide.md)
