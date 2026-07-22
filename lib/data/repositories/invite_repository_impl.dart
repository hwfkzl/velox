import '../../domain/repositories/invite_repository.dart';
import '../datasources/remote/invite_remote_datasource.dart';
import '../models/invite_model.dart';

class InviteRepositoryImpl implements InviteRepository {
  final InviteRemoteDataSource _remoteDataSource;

  InviteModel? _cachedInviteInfo;

  InviteRepositoryImpl({required InviteRemoteDataSource remoteDataSource})
      : _remoteDataSource = remoteDataSource;

  @override
  Future<InviteModel> getInviteInfo() async {
    final info = await _remoteDataSource.getInviteInfo();
    _cachedInviteInfo = info;
    return info;
  }

  @override
  Future<void> generateInviteCode() async {
    await _remoteDataSource.generateInviteCode();
    // 清除缓存，下次获取时会重新加载
    _cachedInviteInfo = null;
  }

  @override
  InviteModel? getCachedInviteInfo() {
    return _cachedInviteInfo;
  }

  @override
  void clearCache() {
    _cachedInviteInfo = null;
  }
}
