import 'dart:convert';

import '../../core/storage/local_storage.dart';
import '../../core/storage/storage_keys.dart';
import '../../domain/repositories/user_repository.dart';
import '../datasources/remote/user_remote_datasource.dart';
import '../models/user_model.dart';
import '../models/subscribe_model.dart';

class UserRepositoryImpl implements UserRepository {
  final UserRemoteDataSource _remoteDataSource;
  final LocalStorageService _localStorage;

  UserModel? _cachedUser;
  SubscribeModel? _cachedSubscribe;

  UserRepositoryImpl({
    required UserRemoteDataSource remoteDataSource,
    required LocalStorageService localStorage,
  })  : _remoteDataSource = remoteDataSource,
        _localStorage = localStorage;

  @override
  Future<UserModel> getUserInfo() async {
    final user = await _remoteDataSource.getUserInfo();
    _cachedUser = user;

    // 缓存到本地
    await _localStorage.setString(
      StorageKeys.userInfo,
      jsonEncode(user.toJson()),
    );

    return user;
  }

  @override
  Future<SubscribeModel> getSubscribeInfo() async {
    final subscribe = await _remoteDataSource.getSubscribeInfo();
    _cachedSubscribe = subscribe;

    // 缓存到本地
    await _localStorage.setString(
      StorageKeys.subscribeInfo,
      jsonEncode(subscribe.toJson()),
    );

    return subscribe;
  }

  @override
  Future<List<PlanModel>> getPlanList() async {
    return await _remoteDataSource.getPlanList();
  }

  @override
  UserModel? getCachedUserInfo() {
    if (_cachedUser != null) return _cachedUser;

    final jsonStr = _localStorage.getString(StorageKeys.userInfo);
    if (jsonStr == null) return null;

    try {
      _cachedUser = UserModel.fromJson(jsonDecode(jsonStr));
      return _cachedUser;
    } catch (_) {
      return null;
    }
  }

  @override
  SubscribeModel? getCachedSubscribeInfo() {
    if (_cachedSubscribe != null) return _cachedSubscribe;

    final jsonStr = _localStorage.getString(StorageKeys.subscribeInfo);
    if (jsonStr == null) return null;

    try {
      _cachedSubscribe = SubscribeModel.fromJson(jsonDecode(jsonStr));
      return _cachedSubscribe;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> clearCache() async {
    _cachedUser = null;
    _cachedSubscribe = null;
    await _localStorage.remove(StorageKeys.userInfo);
    await _localStorage.remove(StorageKeys.subscribeInfo);
  }
}
