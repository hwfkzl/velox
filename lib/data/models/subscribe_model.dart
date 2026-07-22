import 'package:json_annotation/json_annotation.dart';

part 'subscribe_model.g.dart';

@JsonSerializable()
class SubscribeModel {
  @JsonKey(name: 'plan_id')
  final int? planId;
  final String? token;
  @JsonKey(name: 'expired_at')
  final int? expiredAt;
  final int? u; // 上传流量
  final int? d; // 下载流量
  @JsonKey(name: 'transfer_enable')
  final int? transferEnable; // 总流量
  @JsonKey(name: 'reset_day')
  final int? resetDay;
  @JsonKey(name: 'subscribe_url')
  final String? subscribeUrl;
  final PlanModel? plan;

  SubscribeModel({
    this.planId,
    this.token,
    this.expiredAt,
    this.u,
    this.d,
    this.transferEnable,
    this.resetDay,
    this.subscribeUrl,
    this.plan,
  });

  factory SubscribeModel.fromJson(Map<String, dynamic> json) =>
      _$SubscribeModelFromJson(json);

  Map<String, dynamic> toJson() => _$SubscribeModelToJson(this);

  /// 已用流量
  int get usedTraffic => (u ?? 0) + (d ?? 0);

  /// 剩余流量
  int get remainingTraffic => (transferEnable ?? 0) - usedTraffic;

  /// 使用百分比
  double get usagePercent {
    if (transferEnable == null || transferEnable == 0) return 0;
    return (usedTraffic / transferEnable!) * 100;
  }

  /// 是否已过期
  bool get isExpired {
    if (expiredAt == null) return false;
    return DateTime.now().millisecondsSinceEpoch > expiredAt! * 1000;
  }

  /// 到期日期
  DateTime? get expireDate {
    if (expiredAt == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(expiredAt! * 1000);
  }

  /// 下次重置日期
  DateTime? get nextResetDate {
    if (resetDay == null) return null;
    final now = DateTime.now();
    if (now.day < resetDay!) {
      return DateTime(now.year, now.month, resetDay!);
    } else {
      return DateTime(now.year, now.month + 1, resetDay!);
    }
  }
}

@JsonSerializable()
class PlanModel {
  final int? id;
  @JsonKey(name: 'group_id')
  final int? groupId;
  @JsonKey(name: 'transfer_enable')
  final int? transferEnable;
  final String? name;
  @JsonKey(name: 'speed_limit')
  final int? speedLimit;
  final int? show;
  final int? sort;
  final int? renew;
  final String? content;
  @JsonKey(name: 'month_price')
  final int? monthPrice;
  @JsonKey(name: 'quarter_price')
  final int? quarterPrice;
  @JsonKey(name: 'half_year_price')
  final int? halfYearPrice;
  @JsonKey(name: 'year_price')
  final int? yearPrice;
  @JsonKey(name: 'two_year_price')
  final int? twoYearPrice;
  @JsonKey(name: 'three_year_price')
  final int? threeYearPrice;
  @JsonKey(name: 'onetime_price')
  final int? onetimePrice;
  @JsonKey(name: 'reset_price')
  final int? resetPrice;
  @JsonKey(name: 'reset_traffic_method')
  final int? resetTrafficMethod;
  @JsonKey(name: 'capacity_limit')
  final int? capacityLimit;
  @JsonKey(name: 'created_at')
  final int? createdAt;
  @JsonKey(name: 'updated_at')
  final int? updatedAt;

  PlanModel({
    this.id,
    this.groupId,
    this.transferEnable,
    this.name,
    this.speedLimit,
    this.show,
    this.sort,
    this.renew,
    this.content,
    this.monthPrice,
    this.quarterPrice,
    this.halfYearPrice,
    this.yearPrice,
    this.twoYearPrice,
    this.threeYearPrice,
    this.onetimePrice,
    this.resetPrice,
    this.resetTrafficMethod,
    this.capacityLimit,
    this.createdAt,
    this.updatedAt,
  });

  factory PlanModel.fromJson(Map<String, dynamic> json) =>
      _$PlanModelFromJson(json);

  Map<String, dynamic> toJson() => _$PlanModelToJson(this);

  /// 月付价格 (元)
  double get monthPriceYuan => (monthPrice ?? 0) / 100;

  /// 季付价格 (元)
  double get quarterPriceYuan => (quarterPrice ?? 0) / 100;

  /// 半年付价格 (元)
  double get halfYearPriceYuan => (halfYearPrice ?? 0) / 100;

  /// 年付价格 (元)
  double get yearPriceYuan => (yearPrice ?? 0) / 100;

  /// 一次性价格 (元)
  double get onetimePriceYuan => (onetimePrice ?? 0) / 100;

  /// 流量 (GB)
  double get transferEnableGB => (transferEnable ?? 0) / 1024 / 1024 / 1024;
}
