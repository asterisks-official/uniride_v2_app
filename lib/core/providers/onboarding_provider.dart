import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kOnboardingKey = 'onboarding_seen';

class OnboardingNotifier extends Notifier<bool> {
  OnboardingNotifier([this._initial = false]);
  final bool _initial;

  @override
  bool build() => _initial;

  void markSeen() => state = true;
}

/// Holds whether the user has completed onboarding.
/// Initialised via a ProviderScope override in main() — the initial value is
/// passed through the constructor so build() returns the correct flag without
/// needing any state mutation before the notifier is mounted.
final onboardingSeenProvider = NotifierProvider<OnboardingNotifier, bool>(
  OnboardingNotifier.new,
);

Future<bool> getOnboardingSeen() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_kOnboardingKey) ?? false;
}

Future<void> markOnboardingSeen() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_kOnboardingKey, true);
}
