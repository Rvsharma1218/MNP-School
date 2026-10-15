# School & Computer Institute — Student Management App

A full-featured Flutter Android application to manage School and Computer Institute students.

## Features

- ✅ **Student Management** — Add, Edit, Delete students (School & Computer both)
- ✅ **Dashboard** — Stats cards: Total, School, Computer, Attendance, Pending Fees, Collected
- ✅ **Fee Management** — Add payments, auto remaining fee, print PDF receipt
- ✅ **Attendance** — Daily P/A/L marking for all students, monthly report
- ✅ **Results** — Subject-wise marks, auto grade, PDF result card
- ✅ **ID Card** — Preview & PDF export with QR code
- ✅ **Reports** — Excel & PDF (Student list, Fees, Attendance)
- ✅ **WhatsApp** — Fee reminder, admission confirmation, attendance notification
- ✅ **Settings** — Institute name, logo, address, mobile

## Tech Stack

| Layer | Tech |
|-------|------|
| Frontend | Flutter (Dart) |
| State Management | Riverpod |
| Database | SQLite (sqflite) |
| PDF | pdf + printing packages |
| Excel | excel package |
| QR Code | qr_flutter |
| WhatsApp | url_launcher |

## Getting Started

### Prerequisites
- Flutter SDK (installed at `C:\flutter`)
- Android SDK
- Android device or emulator

### Setup
```bash
# Add Flutter to PATH
$env:PATH = "C:\flutter\bin;$env:PATH"

# Get dependencies
flutter pub get

# Run on device/emulator
flutter run
```

### Build APK
```bash
flutter build apk --release
```
APK will be at: `build/app/outputs/flutter-apk/app-release.apk`

## Project Structure

```
lib/
├── main.dart                     # Entry point
├── core/
│   ├── constants/                # Colors, routes
│   ├── theme/                    # App theme (Material 3)
│   └── utils/                   # Formatters, helpers
├── data/
│   ├── models/                  # Student, Fee, Attendance, Result, Settings
│   └── services/                # DatabaseService, Providers
├── features/
│   ├── dashboard/               # Dashboard screen
│   ├── students/                # Add/Edit/List/Profile
│   ├── fees/                    # Fee management + PDF
│   ├── attendance/              # Daily + Report
│   ├── results/                 # Result entry + PDF
│   ├── id_card/                 # ID Card + PDF
│   ├── reports/                 # Excel/PDF reports
│   ├── settings/                # Institute settings
│   └── whatsapp/               # WhatsApp integration
└── widgets/                     # Shared widgets
```

## Student Record Example

| Field | Value |
|-------|-------|
| Admission No | 1025 |
| Student ID | STU00001 |
| Name | Ravi Kumar |
| Father | Rajesh Kumar |
| Mobile | 9876543210 |
| Type | School |
| Class | 10 - A |
| Admission Date | 06-08-2026 |
| Total Fees | ₹10,000 |
| Paid | ₹6,000 |
| Remaining | ₹4,000 |
| Status | Pending |

## License
Private — All rights reserved.
