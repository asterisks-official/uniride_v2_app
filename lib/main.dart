import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'shared/widgets/app_snack.dart';
import 'core/config/app_env.dart';
import 'core/providers/gender_provider.dart';
import 'core/providers/onboarding_provider.dart';
import 'core/push/push_service.dart';
import 'core/realtime/realtime_navigator.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'shared/widgets/loading_overlay.dart';

// Pass --dart-define=SENTRY_DSN=https://... to enable crash reporting.
const _sentryDsn = String.fromEnvironment('SENTRY_DSN');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Push. Never throws: a device without Play Services, or with notifications
  // denied, still has to be able to book a ride. The token is fetched and
  // registered after sign-in, not here, so the permission prompt arrives when
  // the app can explain itself rather than on a cold first open.
  await PushService.init();

  // Read before the first frame so the router's very first redirect already
  // knows whether to show onboarding — deciding it asynchronously would flash
  // the login screen on a fresh install.
  final onboardingSeen = await getOnboardingSeen();
  // Read alongside it so the compose screen knows on its first frame whether
  // to offer the women-only option, rather than after /users/me lands.
  final cachedGender = await getCachedGender();
  final overrides = [
    onboardingSeenProvider.overrideWith(
      () => OnboardingNotifier(onboardingSeen),
    ),
    cachedGenderProvider.overrideWith(() => CachedGenderNotifier(cachedGender)),
  ];

  if (_sentryDsn.isNotEmpty) {
    await SentryFlutter.init(
      (options) {
        options.dsn = _sentryDsn;
        options.environment = AppEnv.flavor;
        options.tracesSampleRate = AppEnv.isDev ? 1.0 : 0.2;
        options.debug = AppEnv.isDev;
      },
      appRunner: () => runApp(
        ProviderScope(overrides: overrides, child: const UniRideApp()),
      ),
    );
  } else {
    runApp(ProviderScope(overrides: overrides, child: const UniRideApp()));
  }
}

class UniRideApp extends ConsumerWidget {
  const UniRideApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    // Watched here and nowhere else: it is the app's single live-navigation
    // listener, and a second subscription would navigate twice.
    ref.watch(realtimeNavigatorProvider);
    return MaterialApp.router(
      title: 'UniRide',
      // Lets the realtime listeners raise a message without a screen — they
      // fire because the server said something, not because anyone tapped.
      scaffoldMessengerKey: scaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
      // Above the navigator, so a HUD raised on one screen fades out over the
      // next one rather than disappearing with the route that raised it.
      builder: (context, child) =>
          AppLoadingScope(child: child ?? const SizedBox.shrink()),
    );
  }
}
