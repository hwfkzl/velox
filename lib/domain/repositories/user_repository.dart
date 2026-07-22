import '../../data/models/user_model.dart';
import '../../data/models/subscribe_model.dart';

abstract class UserRepository {
  /// 获取用户信息
  Future<UserModel> getUserInfo();

  /// 获取订阅信息
  Future<SubscribeModel> getSubscribeInfo();

  /// 获取套餐列表
  Future<List<PlanModel>> getPlanList();

  /// 获取缓存的用户信息
  UserModel? getCachedUserInfo();

  /// 获取缓存的订阅信息
  SubscribeModel? getCachedSubscribeInfo();

  /// 清除缓存
  Future<void> clearCache();
}
