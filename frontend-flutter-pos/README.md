# Frontend Flutter POS — Quick Start

This README gives a concise developer-oriented onboarding for the `frontend-flutter-pos` app so new team members can get running quickly.

Prerequisites

- Flutter SDK (recommended: stable channel matching project)
- Java (for Android emulator) or Xcode for iOS simulator
- Docker & docker-compose (backend services)

Repository layout (important)

- `lib/` — Flutter app sources
  - `lib/core/services` — HTTP client (`ApiService`), `AuthService`
  - `lib/pos/screens` — top-level POS screens (entry: `pos_screen.dart`)
  - `lib/pos/providers` — Riverpod providers and state notifiers
  - `lib/pos/services` — domain service wrappers (products, customers, tables)
  - `lib/pos/widgets` — reusable widgets (cart, product grid, dialogs)

Quick setup

1. Start the backend (from repo root):

```bash
docker-compose up --build
```

2. Install dependencies and run the app:

```bash
cd frontend-flutter-pos
flutter pub get
flutter run
```

Running tests & analysis

```bash
cd frontend-flutter-pos
flutter analyze
flutter test
```

Key developer notes

- API requests attach the JWT token from `SharedPreferences` via `ApiService` interceptor. Login flows write token using `AuthService`.
- Prefer using providers/state notifiers for data loading and avoid calling `ref` after async operations without checking `mounted` in widgets.
- Services intentionally propagate `ApiService` exceptions so UI can show retry/fallback (see `product_service.dart`).

Common tasks

- Add a new provider: create a `StateNotifier` under `lib/pos/providers`, add tests in `test/` and register provider where used.
- Add a new backend call: add typed method to `lib/core/services/api_service.dart` or use generic `get<T>(...)` with a `fromJson` mapper.

Style & tooling

- Run `dart fix --apply` and `dart format .` before committing.
- Run `flutter analyze` and fix critical errors (warnings are OK but prefer to keep the critical errors zeroed).

Where to look first

- `lib/pos/screens/pos_screen.dart` — main entry for POS behavior.
- `lib/core/services/api_service.dart` — HTTP client and token interceptor.
- `lib/pos/providers` — patterns for state management and examples to follow.

If you get stuck

- Check backend logs (docker-compose) for 4xx/5xx responses.
- If API calls return 403, ensure a valid token is present in SharedPreferences or use the provided seeded test user.

Maintainers: add any team contact info here.

Happy hacking — keep components small and add unit tests for logic you add.

# Frontend Flutter POS

A Flutter-based Point of Sale (POS) system that replicates the functionality of the Angular-based KAKNNEA POS system.

## Features

- **Authentication**: JWT-based login system
- **Product Management**: Browse products by categories, search functionality
- **Cart Management**: Add/remove items, quantity management, notes
- **Payment Processing**: Multiple payment methods (Cash, KHQR, Card, Bank Transfer)
- **Offline-First**: Local storage with IndexedDB equivalent using sqflite
- **Category Management**: Filter products by categories
- **Order Management**: Create and manage orders
- **Responsive Design**: Works on tablets and desktops

## Architecture

### State Management

- **Riverpod**: For reactive state management
- **StateNotifier**: For complex state logic

### Data Layer

- **API Service**: HTTP client for backend communication
- **Local Storage**: SharedPreferences for auth, sqflite for offline data
- **Services**: Business logic separation

### UI Layer

- **Material Design 3**: Modern Flutter UI components
- **Custom Widgets**: Reusable POS-specific components
- **Responsive Layout**: Adaptive for different screen sizes

## Project Structure

```
lib/
├── core/                    # Core functionality
│   ├── config/             # App configuration
│   ├── models/             # Shared data models
│   ├── providers/          # Global providers
│   └── services/           # Core services
├── features/               # Feature modules
│   └── auth/               # Authentication
├── pos/                    # POS functionality
│   ├── models/             # POS data models
│   ├── providers/          # POS state management
│   ├── services/           # POS business logic
│   ├── screens/            # POS screens
│   └── widgets/            # POS UI components
└── main.dart               # App entry point
```

## Backend Integration

This Flutter app integrates with the existing Spring Boot backend:

- **Base URL**: `http://localhost:8080/api`
- **Authentication**: JWT tokens stored in SharedPreferences
- **API Endpoints**: Products, categories, orders, payments, etc.

## Setup Instructions

1. **Prerequisites**:
   - Flutter SDK (3.0+)
   - Dart SDK
   - Android Studio / VS Code with Flutter extensions

2. **Clone and Setup**:

   ```bash
   git clone <repository-url>
   cd frontend-flutter-pos
   flutter pub get
   ```

3. **Backend Setup**:
   - Ensure the Spring Boot backend is running on `localhost:8080`
   - Update `lib/core/config/app_config.dart` if needed

4. **Run the App**:
   ```bash
   flutter run
   ```

## Key Components

### Authentication

- Login screen with email/password
- JWT token management
- Auto-logout on token expiry

### POS Screen

- Product grid with category filtering
- Search functionality
- Cart panel with item management
- Payment modal with multiple payment methods

### Services

- **ApiService**: HTTP client with Dio
- **AuthService**: Authentication logic
- **ProductService**: Product data management
- **CartService**: Cart operations

### Models

- **User**: Authentication user data
- **Product**: Product information
- **Category**: Product categories
- **CartItem**: Shopping cart items
- **Order**: Order data structure

## Development

### Code Generation

```bash
flutter pub run build_runner build
```

### Testing

```bash
flutter test
```

### Linting

```bash
flutter analyze
```

## Backend Compatibility

This Flutter app is designed to work with the existing KAKNNEA POS backend:

- All API endpoints are compatible
- Data models match backend DTOs
- Authentication flow matches existing implementation
- Supports all POS features from the Angular version

## Demo Users

- **Owner**: `owner@kaknnea.local` / `Password123!`
- **Manager**: `manager@kaknnea.local` / `Password123!`
- **Cashier**: `cashier@kaknnea.local` / `Password123!`

## Contributing

1. Follow Flutter best practices
2. Use Riverpod for state management
3. Write tests for new features
4. Update documentation

## License

Same as the original KAKNNEA POS project.
