import 'package:json_annotation/json_annotation.dart';

part 'user_model.g.dart';

@JsonSerializable()
class UserModel {
  final int? id;
  final String? email;
  final String? uuid;
  @JsonKey(name: 'transfer_enable')
  final int? transferEnable; // 总流量 (字节)
  @JsonKey(name: 'last_login_at')
  final int? lastLoginAt;
  @JsonKey(name: 'created_at')
  final int? createdAt;
  final int? banned;
  @JsonKey(name: 'remind_expire')
  final int? remindExpire;
  @JsonKey(name: 'remind_traffic')
  final int? remindTraffic;
  final int? u; // 上传流量 (字节)
  final int? d; // 下载流量 (字节)
  @JsonKey(name: 'expired_at')
  final int? expiredAt; // 到期时间戳
  @JsonKey(name: 'plan_id')
  final int? planId;
  final double? balance; // 余额 (分)
  final double? commission; // 佣金 (分)
  @JsonKey(name: 'commission_balance')
  final double? commissionBalance;
  @JsonKey(name: 'invite_user_id')
  final int? inviteUserId;
  @JsonKey(name: 'telegram_id')
  final int? telegramId;

  UserModel({
    this.id,
    this.email,
    this.uuid,
    this.transferEnable,
    this.lastLoginAt,
    this.createdAt,
    this.banned,
    this.remindExpire,
    this.remindTraffic,
    this.u,
    this.d,
    this.expiredAt,
    this.planId,
    this.balance,
    this.commission,
    this.commissionBalance,
    this.inviteUserId,
    this.telegramId,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) =>
      _$UserModelFromJson(json);

  Map<String, dynamic> toJson() => _$UserModelToJson(this);

  /// 已用流量 (字节)
  int get usedTraffic => (u ?? 0) + (d ?? 0);

  /// 剩余流量 (字节)
  int get remainingTraffic => (transferEnable ?? 0) - usedTraffic;

  /// 流量使用百分比 (0-100)
  double get usagePercent {
    if (transferEnable == null || transferEnable == 0) return 0;
    return (usedTraffic / transferEnable!) * 100;
  }

  /// 是否已过期
  bool get isExpired {
    if (expiredAt == null) return false;
    return DateTime.now().millisecondsSinceEpoch > expiredAt! * 1000;
  }

  /// 余额 (元)
  double get balanceYuan => (balance ?? 0) / 100;

  /// 佣金 (元)
  double get commissionYuan => (commission ?? 0) / 100;
}
