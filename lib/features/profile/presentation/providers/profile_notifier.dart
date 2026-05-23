import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/network/api_exception_mapper.dart';
import '../../domain/models/user_profile.dart';

class ProfileNotifier extends AsyncNotifier<UserProfile> {
  @override
  Future<UserProfile> build() => _fetch();

  Future<UserProfile> _fetch() async {
    try {
      final data = await ref.read(authRemoteDataSourceProvider).getMe();
      return UserProfile.fromJson(data);
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
