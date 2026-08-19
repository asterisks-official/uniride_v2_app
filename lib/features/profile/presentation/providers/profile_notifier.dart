import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/providers/gender_provider.dart';
import '../../../../core/network/api_exception_mapper.dart';
import '../../domain/models/user_profile.dart';

class ProfileNotifier extends AsyncNotifier<UserProfile> {
  @override
  Future<UserProfile> build() => _fetch();

  Future<UserProfile> _fetch() async {
    try {
      final data = await ref.read(authRemoteDataSourceProvider).getMe();
      final profile = UserProfile.fromJson(data);
      // Write gender through to the device cache so screens that only need it
      // to decide what to offer do not have to wait on this call.
      ref.read(cachedGenderProvider.notifier).set(profile.gender);
      return profile;
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }
}

final profileNotifierProvider =
    AsyncNotifierProvider<ProfileNotifier, UserProfile>(ProfileNotifier.new);
