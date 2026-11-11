# Blukios Marketplace — Flutter Mobile App

Aplikasi mobile marketplace berbasis Flutter yang terintegrasi dengan Laravel 12 API (api-blue).

CI/CD: GitHub Actions (`.github/workflows/ci.yml`), lihat [CI/CD](#cicd).

## Arsitektur

Menggunakan **Clean Architecture** dengan struktur folder:

```
lib/
├── main.dart                  # Entry point
├── app.dart                   # MaterialApp configuration
├── config/                    # Configuration (API, theme, routes)
├── core/                      # Core utilities (network, storage, formatters)
├── features/                  # Feature modules (auth, home, product, cart, transaction)
│   └── [feature]/
│       ├── data/              # Repository layer
│       ├── models/            # Data models
│       └── screens/           # UI screens
└── shared/                    # Shared widgets
```

## Tech Stack

- **Flutter** ^3.5 (SDK)
- **Dio** — HTTP client dengan interceptors
- **Provider** — State management
- **GoRouter** — Deklaratif routing
- **Flutter Secure Storage** — Token storage
- **Cached Network Image** — Efisien image loading
- **Shimmer** — Loading placeholders

## Setup & Konfigurasi

### 1. Prasyarat

- Flutter SDK ^3.5.0
- Android Studio / Xcode
- API backend berjalan (Laravel / api-blue)

### 2. Install Dependencies

```bash
cd flutter-app
flutter pub get
```

### 3. Konfigurasi API

Default (tanpa flag apa pun) selalu mengarah ke production (`https://blukios.store/api`) — ini disengaja, bukan placeholder. Untuk mengarahkan build ke backend lain tanpa mengedit source, pakai `--dart-define`:

```bash
# Server testing (Tailscale)
flutter run --dart-define=API_BASE_URL=http://100.77.244.19:8888/api

# Android Emulator ke backend lokal
flutter run --dart-define=API_BASE_URL=http://10.0.2.2/api

# iOS Simulator ke backend lokal
flutter run --dart-define=API_BASE_URL=http://localhost/api

# Device fisik (gunakan IP lokal mesin dev)
flutter run --dart-define=API_BASE_URL=http://192.168.x.x/api
```

`--dart-define` juga berlaku untuk `flutter build apk`/`build appbundle`/`build ios`.

### 4. Jalankan Aplikasi

```bash
flutter run
```

## API Integration

Semua endpoint mengacu ke Laravel API (`api-blue/`):

| Feature       | Endpoint                     |
|---------------|------------------------------|
| Login         | POST `/api/login`            |
| Register      | POST `/api/register`         |
| Profile       | GET `/api/me`                |
| Products      | GET `/api/product`           |
| Product Slug  | GET `/api/product/slug/:slug`|
| Categories    | GET `/api/product-category`  |
| Cart          | GET/POST `/api/cart`         |
| Transactions  | GET/POST `/api/transaction`  |

## Tema & Design System

- **Primary**: #2563EB (Blue-600)
- **Dark Mode**: Charcoal (#0A0A0A / #171717)
- **Font**: Plus Jakarta Sans
- **Border Radius**: 12-16px
- **Material 3** enabled

## Crash Reporting & Analytics

Firebase Crashlytics + Analytics sudah di-wire di kode (`lib/core/monitoring/analytics_service.dart`, diinisialisasi di `lib/main.dart`), tapi **belum diprovisioning** — belum ada project Firebase asli, jadi `google-services.json` (Android) / `GoogleService-Info.plist` (iOS) belum ada. Tanpa file itu, `Firebase.initializeApp()` gagal secara aman (di-try/catch) dan app tetap jalan normal, cuma crash reporting/analytics diam saja (no-op).

Untuk mengaktifkan:
1. Jalankan `flutterfire configure` (butuh akun Google + login interaktif di browser — tidak bisa dilakukan dari sesi otomatis) — akan generate kedua file config di atas dan mendaftarkan app ini ke project Firebase.
2. Setelah file config ada, tidak perlu ubah kode apa pun — `android/app/build.gradle.kts` sudah otomatis apply plugin Google Services begitu `google-services.json` terdeteksi.

## Fitur

- [x] Autentikasi (Login / Register) via Laravel Sanctum
- [x] Beranda dengan kategori & produk grid
- [x] Detail produk
- [x] Keranjang belanja
- [x] Daftar transaksi
- [x] Dark mode support
- [x] Shimmer loading
- [x] Error handling dengan retry
- [x] Indonesian localization

## CI/CD

GitHub Actions ([.github/workflows/ci.yml](.github/workflows/ci.yml)) berjalan di runner
GitHub (`ubuntu-24.04`) dan menjadi status check di setiap pull request serta setiap push ke `main`:

- **Analyze & Test**: `flutter pub get`, `flutter analyze`, `flutter test`.
- **Build debug APK**: `flutter build apk --debug`, hanya untuk push ke `main` dan run manual
  (Actions, CI, Run workflow). Tidak jalan di pull request. Ini compile smoke test: tanpa
  signing, tanpa secret, APK tidak diunggah.

Flutter di-pin ke 3.47.4 (sama dengan laptop yang membuat `pubspec.lock` dan APK rilis); naikkan
lewat `FLUTTER_VERSION` di workflow. Setiap action di-pin ke commit SHA penuh dan token workflow
hanya `contents: read`. APK rilis tetap dibuat dan di-sign dari laptop, lihat
[Rilis Android](#rilis-android).

Pipeline Jenkins lama (`Jenkinsfile`, job `blukios-mobile-pipeline`) sudah dipensiunkan dan
filenya dihapus dari repo ini.

## Rilis Android

Rilis dibagikan sebagai APK bertanda tangan di
[GitHub Releases](https://github.com/Hazjel/marketplace-mobile/releases).

**Keystore rilis.** Android hanya memasang update yang ditandatangani kunci yang sama
dengan versi terpasang. Kunci v1.0.0 sampai v1.1.4 hilang, jadi v1.2.0 memakai kunci baru
dan pengguna lama harus uninstall sekali sebelum memasangnya. Simpan keystore dan
passwordnya di dua tempat terpisah (mis. password manager dan penyimpanan cloud
pribadi); jangan pernah di repo ini (`*.jks` dan `android/key.properties` di-gitignore).

`android/key.properties` (lokal, tidak di-commit):

```properties
storePassword=...
keyPassword=...
keyAlias=blukios
storeFile=C:/Users/<user>/.blukios-release/blukios-release.jks
```

Tanpa file ini build rilis jatuh ke kunci debug (lihat `android/app/build.gradle.kts`):
APK-nya jalan, tapi jangan pernah dibagikan.

**Membuat rilis:**

```bash
flutter test
flutter build apk --release   # API default: https://blukios.store/api
```

Periksa tanda tangannya sebelum diunggah, sertifikatnya harus `CN=Blukios Marketplace`:

```bash
apksigner verify --print-certs build/app/outputs/flutter-apk/app-release.apk
```

Lalu naikkan `version` di `pubspec.yaml` (versionCode harus selalu naik), buat tag
`vX.Y.Z`, dan unggah APK ke GitHub Release dengan tag itu.

## Catatan Pengembangan

- Token disimpan di `flutter_secure_storage` (encrypted)
- API interceptor otomatis menambah Bearer token
- Semua error ditangani melalui `ApiException`
- UI menggunakan bahasa Indonesia
