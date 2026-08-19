import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/account_enums.dart';

const _kGenderKey = 'user_gender';

/// The signed-in user's gender, cached on the device.
///
/// Gender decides whether the women-only option is offered when posting a
/// ride, and that decision should not wait on a network round-trip every time
/// the compose screen opens. The profile is still the source of truth — this
/// is written from it on every successful fetch and only read to render UI.
///
/// Safe to cache precisely because it is not the enforcement point: the server
/// re-checks the poster's real gender before accepting a restricted ride
/// (`assertMayRestrictByGender`). A stale or tampered value here can change
/// what a screen *offers*, never what the platform *allows*.
class CachedGenderNotifier extends Notifier<Gender?> {
  CachedGenderNotifier([this._initial]);

  final Gender? _initial;

  @override
  Gender? build() => _initial;

  /// Called when the profile loads. Writes through to disk so the next cold
  /// start already knows.
  void set(Gender? gender) {
    if (gender == null || gender == state) return;
    state = gender;
    saveCachedGender(gender);
  }

  /// Signing out must not leave the next account looking at the previous
  /// user's options.
  void clear() {
    state = null;
    clearCachedGender();
  }
}

final cachedGenderProvider = NotifierProvider<CachedGenderNotifier, Gender?>(
  CachedGenderNotifier.new,
);

Future<Gender?> getCachedGender() async {
  final prefs = await SharedPreferences.getInstance();
  return Gender.fromWire(prefs.getString(_kGenderKey));
}

Future<void> saveCachedGender(Gender gender) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_kGenderKey, gender.wire);
}

Future<void> clearCachedGender() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_kGenderKey);
}
