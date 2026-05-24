import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'core/config/app_env.dart';
import 'core/providers/onboarding_provider.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

// Pass --dart-define=SENTRY_DSN=https://... to enable crash reporting.
const _sentryDsn = String.fromEnvironment('SENTRY_DSN');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase.initializeApp() goes here once google-services.json / GoogleService-Info.plist
  // are added and firebase_options.dart is generated via flutterfire configure.

  final onboardingSeen = await getOnboardingSeen();

  final overrides = [
    onboardingSeenProvider.overrideWith(() => OnboardingNotifier(onboardingSeen)),
  ];

  if (_sentryDsn.isNotEmpty) {
    await SentryFlutter.init(
      (options) {
        options.dsn = _sentryDsn;
        options.environment = AppEnv.flavor;
        options.tracesSampleRate = AppEnv.isDev ? 1.0 : 0.2;
        options.debug = AppEnv.isDev;
      },
      appRunner: () =>
          runApp(ProviderScope(overrides: overrides, child: const UniRideApp())),
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
    return MaterialApp.router(
      title: 'UniRide',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
    );
  }
}
