# UniRide Flutter App — Project Specification & Implementation Plan

## Overview

The UniRide mobile app is a **Flutter (Dart)** application for Android and iOS that lets university students post ride offers, browse and join rides, track rides in real-time, chat with their ride partner, and manage their profile and trust score.

- **Target platforms**: Android (API 21+), iOS (13+)
- **State management**: Riverpod (StateNotifier + Freezed)
- **Navigation**: GoRouter
- **API**: UniRide Backend REST + Socket.IO

---

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter 3.41.6 (Dart) |
| State Management | flutter_riverpod + riverpod_annotation |
| Navigation | go_router |
| HTTP Client | dio with auth + refresh interceptors |
| Real-time | socket_io_client |
| Maps | google_maps_flutter |
| Push Notifications | firebase_messaging |
| Secure Storage | flutter_secure_storage |
| Local Storage | shared_preferences |
| Code Generation | build_runner + freezed |
| Image Upload | image_picker → S3 presigned URL |
| Image Display | cached_network_image |
| Localization | intl |

---

## Project Structure

```
lib/
├── features/
│   ├── auth/
│   │   ├── data/
│   │   │   ├── datasources/auth_remote_datasource.dart
│   │   │   └── repositories/auth_repository_impl.dart
│   │   ├── domain/
│   │   │   └── models/
│   │   │       ├── auth_tokens.dart          (Freezed)
│   │   │       └── user.dart                 (Freezed)
│   │   └── presentation/
│   │       ├── screens/
│   │       │   ├── login_screen.dart
│   │       │   ├── register_screen.dart
│   │       │   ├── otp_screen.dart
│   │       │   ├── forgot_password_screen.dart
│   │       │   └── reset_password_screen.dart
│   │       ├── widgets/
│   │       │   └── auth_text_field.dart
│   │       └── providers/
│   │           └── auth_notifier.dart        (StateNotifier)
│   ├── home/
│   │   └── presentation/
│   │       ├── screens/home_screen.dart
│   │       └── widgets/
│   │           ├── ride_card.dart
│   │           └── filter_chips.dart
│   ├── rides/
│   │   ├── data/
│   │   │   ├── datasources/rides_remote_datasource.dart
│   │   │   └── repositories/rides_repository_impl.dart
│   │   ├── domain/
│   │   │   └── models/
│   │   │       ├── ride.dart                 (Freezed)
│   │   │       └── ride_request.dart         (Freezed)
│   │   └── presentation/
│   │       ├── screens/
│   │       │   ├── create_ride_screen.dart
│   │       │   ├── ride_detail_screen.dart
│   │       │   ├── active_ride_screen.dart
│   │       │   └── ride_history_screen.dart
│   │       ├── widgets/
│   │       │   └── rating_sheet.dart
│   │       └── providers/
│   │           └── rides_notifier.dart
│   ├── chat/
│   │   ├── data/
│   │   │   └── repositories/chat_repository_impl.dart
│   │   ├── domain/
│   │   │   └── models/message.dart           (Freezed)
│   │   └── presentation/
│   │       ├── screens/chat_screen.dart
│   │       └── providers/chat_notifier.dart
│   ├── notifications/
│   │   └── presentation/
│   │       ├── screens/notifications_screen.dart
│   │       └── providers/notifications_notifier.dart
│   └── profile/
│       └── presentation/
│           ├── screens/
│           │   ├── profile_screen.dart
│           │   ├── edit_profile_screen.dart
│           │   └── rider_verification_screen.dart
│           └── providers/profile_notifier.dart
├── core/
│   ├── di/
│   │   └── providers.dart                    (all Riverpod providers)
│   ├── network/
│   │   ├── api_client.dart                   (Dio instance)
│   │   └── auth_interceptor.dart             (401 → refresh → retry)
│   ├── router/
│   │   └── app_router.dart                   (GoRouter, auth guard)
│   ├── storage/
│   │   ├── secure_storage.dart               (tokens)
│   │   └── local_storage.dart                (preferences)
│   ├── socket/
│   │   └── socket_service.dart               (Socket.IO lifecycle)
│   └── theme/
│       └── app_theme.dart                    (colors, typography, spacing)
├── shared/
│   ├── widgets/
│   │   ├── app_button.dart
│   │   ├── app_text_field.dart
│   │   ├── loading_overlay.dart
│   │   ├── error_view.dart
│   │   └── avatar_widget.dart
│   ├── providers/
│   │   └── socket_provider.dart
│   └── exceptions/
│       └── app_exception.dart                (sealed class)
└── main.dart
```

---

## State Management Pattern

Every feature follows this pattern:

```dart
// 1. Freezed model
@freezed
class Ride with _$Ride {
  const factory Ride({
    required String id,
    required String originAddress,
    required double originLat,
    required double originLng,
    required RideStatus status,
    required double fare,
  }) = _Ride;

  factory Ride.fromJson(Map<String, dynamic> json) => _$RideFromJson(json);
}

// 2. StateNotifier
@riverpod
class RidesNotifier extends _$RidesNotifier {
  @override
  Future<List<Ride>> build() => ref.watch(ridesRepositoryProvider).getFeed();

  Future<void> createRide(CreateRideDto dto) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(ridesRepositoryProvider).create(dto),
    );
  }
}

// 3. Repository interface
abstract class RidesRepository {
  Future<List<Ride>> getFeed({RideFeedFilter? filter});
  Future<Ride> create(CreateRideDto dto);
  Future<Ride> getById(String id);
}
```

---

## Navigation (GoRouter)

```dart
// Auth guard — redirects to /login if not authenticated
redirect: (context, state) {
  final isAuthenticated = ref.read(authNotifierProvider).hasValue;
  final isAuthRoute = ['/login', '/register', '/otp'].contains(state.location);
  if (!isAuthenticated && !isAuthRoute) return '/login';
  if (isAuthenticated && isAuthRoute) return '/home';
  return null;
},

// Routes
/login             → LoginScreen
/register          → RegisterScreen
/otp               → OtpScreen
/forgot-password   → ForgotPasswordScreen
/home              → HomeScreen (ride feed)
/rides/create      → CreateRideScreen
/rides/active      → ActiveRideScreen
/rides/:id         → RideDetailScreen
/rides/history     → RideHistoryScreen
/chat/:rideId      → ChatScreen
/notifications     → NotificationsScreen
/profile           → ProfileScreen
/profile/edit      → EditProfileScreen
/verification      → RiderVerificationScreen
```

---

## API Client (Dio)

```dart
// Auth interceptor — auto refresh on 401
class AuthInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      final newTokens = await _refreshTokens();
      if (newTokens != null) {
        // retry original request with new token
        final retryResponse = await _retry(err.requestOptions, newTokens.accessToken);
        return handler.resolve(retryResponse);
      }
    }
    handler.next(err);
  }
}
```

---

## Socket.IO Service

```dart
class SocketService {
  late IO.Socket _socket;

  void connect(String token) {
    _socket = IO.io(
      AppConstants.wsUrl,
      IO.OptionBuilder()
        .setTransports(['websocket'])
        .setAuth({'token': token})
        .enableReconnection()
        .setReconnectionDelay(1000)        // exponential: 1,2,4,8,16s
        .setReconnectionAttempts(10)
        .build(),
    );
  }

  void joinRide(String rideId) => _socket.emit('join_ride', {'rideId': rideId});

  void sendLocationUpdate(double lat, double lng) =>
      _socket.emit('location_update', {'lat': lat, 'lng': lng});

  Stream<Map<String, dynamic>> get onLocationUpdate =>
      _onEvent('location_update');

  Stream<Map<String, dynamic>> get onMessage =>
      _onEvent('message');

  Stream<Map<String, dynamic>> get onRideStatus =>
      _onEvent('ride_status');
}
```

---

## Error Handling

```dart
// sealed AppException hierarchy
sealed class AppException implements Exception { ... }
class NetworkException extends AppException { ... }
class UnauthorizedException extends AppException { ... }
class ServerException extends AppException { ... }
class ValidationException extends AppException { ... }

// Usage in repository
Future<List<Ride>> getFeed() async {
  try {
    final response = await _apiClient.get('/rides');
    return (response.data['data'] as List)
        .map((e) => Ride.fromJson(e as Map<String, dynamic>))
        .toList();
  } on DioException catch (e) {
    throw ServerException(e.message ?? 'Unknown error', statusCode: e.response?.statusCode);
  }
}
```

---

## Screen-by-Screen Implementation Plan

### Phase 2 — Auth Screens (Week 5–6)

- [ ] `RegisterScreen` — name, email, university (dropdown), password, phone; form validation; call `/auth/register`
- [ ] `OtpScreen` — 6-digit PIN input widget, 60s resend countdown, auto-submit on last digit; call `/auth/verify-otp`
- [ ] `LoginScreen` — email + password, "Forgot password?" link; call `/auth/login`
- [ ] `ForgotPasswordScreen` — email input; call `/auth/forgot-password`
- [ ] `ResetPasswordScreen` — OTP + new password; call `/auth/reset-password`
- [ ] `AuthNotifier` — manages `AuthState` (unauthenticated / loading / authenticated / error)
- [ ] `SecureStorage` — store/read/delete `accessToken` and `refreshToken`
- [ ] `AuthInterceptor` — Dio interceptor: attach token, handle 401 → refresh → retry
- [ ] GoRouter auth redirect guard wired to `AuthNotifier`
- [ ] `main.dart` — `ProviderScope` wrapping `MaterialApp.router`, FCM init

### Phase 3 — Rides & Profile (Week 7–10)

- [ ] `HomeScreen` — `ListView` of `RideCard` widgets, filter chips (offer/request, time, proximity)
- [ ] `RideCard` — origin → destination, fare, scheduled time, rider avatar + trust score badge
- [ ] `CreateRideScreen` — `GoogleMap` with tap-to-pin for origin/destination, fare input, seat count, gender preference, scheduled time picker
- [ ] `RideDetailScreen` — full ride info, rider public profile snippet, "Request to Join" / "Cancel Request" button
- [ ] `ActiveRideScreen` — live `GoogleMap` with both users' markers, ride status banner, "Confirm Completion" button
- [ ] `RideHistoryScreen` — past rides list with status chips
- [ ] `RatingSheet` — `BottomSheet` with star selector, tag chips (punctual, safe_driver, friendly, etc.), optional review text
- [ ] `ProfileScreen` — avatar, name, university, trust score ring, stats grid (rides, rating, cancellations)
- [ ] `EditProfileScreen` — `ImagePicker` → upload to S3 presigned URL → update profile picture URL
- [ ] `RiderVerificationScreen` — document picker for license, vehicle photo, student ID; call verification API

### Phase 4 — Real-time (Week 11–12)

- [ ] `SocketService` — connect on app resume (if authenticated), disconnect on logout; exponential backoff reconnect
- [ ] `SocketProvider` (Riverpod) — expose `SocketService` instance, auto-connect on auth state change
- [ ] `ActiveRideScreen` — subscribe to `ride:{rideId}`, update map markers on `location_update`
- [ ] Background location: send `location_update` every 5 seconds using `geolocator` + `Timer.periodic`
- [ ] `ChatScreen` — `StreamBuilder` on socket `message` events; send via `_socket.emit('message', ...)`; load history from REST on init
- [ ] `ChatNotifier` — manages message list; prepends socket messages in real-time
- [ ] System message bubbles (grey, centered, italic) vs. user bubbles (blue/white)
- [ ] `NotificationsScreen` — pull from REST `/notifications`; unread badge on bottom nav
- [ ] FCM foreground handler — show in-app `SnackBar`; background handler — navigate to relevant screen on tap

### Phase 7 — Polish (Week 15–16)

- [ ] Offline mode — queue actions, show "No internet" banner, retry on reconnect
- [ ] Skeleton loading states on all list screens
- [ ] Pull-to-refresh on feed and history
- [ ] Empty states (no rides yet, no notifications, etc.)
- [ ] Sentry crash reporting (`sentry_flutter` SDK)
- [ ] Widget tests: `AuthNotifier`, `RideCard`, `OtpScreen`

---

## App Theme

```dart
// Primary: UniRide Blue
static const primary = Color(0xFF2563EB);      // blue-600
static const secondary = Color(0xFF10B981);    // emerald-500
static const error = Color(0xFFEF4444);        // red-500
static const warning = Color(0xFFF59E0B);      // amber-500
static const background = Color(0xFFF9FAFB);   // gray-50
static const surface = Color(0xFFFFFFFF);

// Trust score color ramp
// 0–40: red, 41–70: amber, 71–100: green
```

---

## Firebase Setup

```
1. Create Firebase project: uniride-dev (dev) / uniride (prod)
2. Add Android app: app.uniride.uniride_app
   - Download google-services.json → android/app/
3. Add iOS app: app.uniride.unirideApp
   - Download GoogleService-Info.plist → ios/Runner/
4. Enable Cloud Messaging in Firebase console
5. Add SHA-1 fingerprint for debug keystore
```

---

## Google Maps Setup

```
1. Enable Maps SDK for Android + iOS in Google Cloud Console
2. android/app/src/main/AndroidManifest.xml:
   <meta-data android:name="com.google.android.geo.API_KEY"
              android:value="YOUR_KEY" />
3. ios/Runner/AppDelegate.swift:
   GMSServices.provideAPIKey("YOUR_KEY")
```

---

## Coding Standards

```dart
// Always use final/const where possible
final rides = <Ride>[];
const emptyState = SizedBox.shrink();

// Freezed for all models — no mutable data classes
// Either<Failure, T> pattern for repository error handling (optional)
// Named routes via GoRouter — no Navigator.push() directly
// No business logic in widgets — all in Notifiers
// One feature per folder — no cross-feature imports except through core/
```

---

## Running the App

```bash
# Get dependencies
flutter pub get

# Run code generation (Freezed models)
dart run build_runner build --delete-conflicting-outputs

# Run on device
flutter run

# Build APK
flutter build apk --release

# Build iOS
flutter build ios --release
```
