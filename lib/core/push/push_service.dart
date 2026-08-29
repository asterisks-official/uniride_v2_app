import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';

/// Firebase Cloud Messaging, reduced to the two things the app needs: a token
/// to hand the backend, and a callback when that token changes.
///
/// Nothing here throws. Push is a nice-to-have on top of the in-app
/// notification list, and a device with Play Services missing, permission
/// denied, or Firebase unreachable must still be able to book a ride — so
/// every failure is logged and swallowed.
class PushService {
  PushService._();

  static bool _initialised = false;
  static StreamSubscription<String>? _refreshSub;

  /// True once Firebase started successfully. False on a device where it did
  /// not, which is a normal state rather than an error.
  static bool get isAvailable => _initialised;

  /// `deviceType` as the backend records it on UserDevice.
  static String get deviceType {
    if (kIsWeb) return 'web';
    return Platform.isIOS ? 'ios' : 'android';
  }

  /// Starts Firebase. Safe to call more than once.
  ///
  /// Configured from the generated [DefaultFirebaseOptions] rather than from
  /// whatever platform config file happens to be on disk, so a build that is
  /// missing google-services.json fails here -- loudly, in one place -- instead
  /// of producing an app that looks fine and never receives a notification.
  static Future<void> init() async {
    if (_initialised) return;
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _initialised = true;
    } catch (e) {
      debugPrint('Push unavailable — Firebase did not start: $e');
    }
  }

  /// Asks for permission and returns the FCM token, or null if push cannot be
  /// used on this device.
  ///
  /// Called after sign-in rather than at launch, so the permission prompt lands
  /// when the app can explain itself instead of on a cold first open.
  static Future<String?> token() async {
    if (!_initialised) return null;
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission();
      // Android below 13 reports `authorized` without prompting; 13+ and iOS
      // can come back denied, and a token would then never deliver anything.
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        return null;
      }
      return await messaging.getToken();
    } catch (e) {
      debugPrint('Push unavailable — could not obtain an FCM token: $e');
      return null;
    }
  }

  /// Calls [onToken] whenever FCM issues a new token for this install.
  ///
  /// FCM rotates on reinstall, on restore to a new device, and periodically on
  /// its own. Registering only at sign-in would leave a user who simply stays
  /// signed in silently unreachable from the first rotation onward.
  static void onTokenRefresh(void Function(String token) onToken) {
    if (!_initialised) return;
    _refreshSub?.cancel();
    _refreshSub = FirebaseMessaging.instance.onTokenRefresh.listen(
      onToken,
      onError: (Object e) => debugPrint('FCM token refresh stream failed: $e'),
    );
  }

  static Future<void> stopListening() async {
    await _refreshSub?.cancel();
    _refreshSub = null;
  }
}
