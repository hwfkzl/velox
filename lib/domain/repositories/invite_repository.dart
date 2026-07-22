import '../../data/models/invite_model.dart';

abstract class InviteRepository {
  /// 获取邀请信息
  Future<InviteModel> getInviteInfo();

  /// 生成新邀请码
  Future<void> generateInviteCode();

  /// 获取缓存的邀请信息
  InviteModel? getCachedInviteInfo();

  /// 清除缓存
  void clearCache();
}
