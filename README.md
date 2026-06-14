# Blukios Marketplace - Flutter Mobile App

Aplikasi mobile marketplace berbasis Flutter yang terintegrasi dengan Laravel 12 API (api-blue).

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

Edit `lib/config/api_config.dart`:

```dart
// Untuk Android Emulator:
static const String baseUrl = 'http://10.0.2.2:8000/api';

// Untuk iOS Simulator:
static const String baseUrl = 'http://localhost:8000/api';

// Untuk device fisik (gunakan IP lokal):
static const String baseUrl = 'http://192.168.x.x:8000/api';
```

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

## Catatan Pengembangan

- Token disimpan di `flutter_secure_storage` (encrypted)
- API interceptor otomatis menambah Bearer token
- Semua error ditangani melalui `ApiException`
- UI menggunakan bahasa Indonesia
