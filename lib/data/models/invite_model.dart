import 'package:json_annotation/json_annotation.dart';

part 'invite_model.g.dart';

@JsonSerializable()
class InviteModel {
  final List<InviteCodeModel>? codes;
  @JsonKey(fromJson: _statFromJson)
  final InviteStatModel? stat;

  InviteModel({this.codes, this.stat});

  factory InviteModel.fromJson(Map<String, dynamic> json) =>
      _$InviteModelFromJson(json);

  Map<String, dynamic> toJson() => _$InviteModelToJson(this);

  /// V2Board `/invite/fetch` 把 stat 序列化成数组：
  /// `[registered_count, commission_earned, commission_pending,
  ///   commission_rate, commission_balance]`
  /// 全部为整数，金额单位为「分」。
  static InviteStatModel? _statFromJson(dynamic json) {
    if (json == null) return null;
    if (json is Map<String, dynamic>) return InviteStatModel.fromJson(json);
    if (json is List) {
      int? at(int i) => i < json.length ? (json[i] as num?)?.toInt() : null;
      return InviteStatModel(
        registeredCount: at(0),
        commissionEarned: at(1),
        commissionPending: at(2),
        commissionRate: at(3),
        commissionBalance: at(4),
      );
    }
    return null;
  }

  String? get availableCode {
    if (codes == null || codes!.isEmpty) return null;
    return codes!.first.code;
  }
}

@JsonSerializable()
class InviteCodeModel {
  final int? id;
  @JsonKey(name: 'user_id')
  final int? userId;
  final String? code;
  final int? status;
  @JsonKey(name: 'pv')
  final int? pageViews;
  /// V2Board 模型设了 `dateFormat = 'U'`，序列化时 created_at/updated_at
  /// 是 Unix 秒**字符串**（不是整数），需要兼容解析。
  @JsonKey(name: 'created_at', fromJson: _parseUnixTs)
  final int? createdAt;
  @JsonKey(name: 'updated_at', fromJson: _parseUnixTs)
  final int? updatedAt;

  InviteCodeModel({
    this.id,
    this.userId,
    this.code,
    this.status,
    this.pageViews,
    this.createdAt,
    this.updatedAt,
  });

  factory InviteCodeModel.fromJson(Map<String, dynamic> json) =>
      _$InviteCodeModelFromJson(json);

  Map<String, dynamic> toJson() => _$InviteCodeModelToJson(this);

  bool get isAvailable => status == 0;
}

int? _parseUnixTs(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

@JsonSerializable()
class InviteStatModel {
  /// 已注册的下级用户数
  @JsonKey(name: 'registered_count')
  final int? registeredCount;

  /// 已结算佣金累计（分）
  @JsonKey(name: 'commission_earned')
  final int? commissionEarned;

  /// 确认中佣金（分）
  @JsonKey(name: 'commission_pending')
  final int? commissionPending;

  /// 佣金比例（百分比整数）
  @JsonKey(name: 'commission_rate')
  final int? commissionRate;

  /// 当前可用佣金（分）
  @JsonKey(name: 'commission_balance')
  final int? commissionBalance;

  InviteStatModel({
    this.registeredCount,
    this.commissionEarned,
    this.commissionPending,
    this.commissionRate,
    this.commissionBalance,
  });

  factory InviteStatModel.fromJson(Map<String, dynamic> json) =>
      _$InviteStatModelFromJson(json);

  Map<String, dynamic> toJson() => _$InviteStatModelToJson(this);

  double get commissionEarnedYuan => (commissionEarned ?? 0) / 100;
  double get commissionPendingYuan => (commissionPending ?? 0) / 100;
  double get commissionBalanceYuan => (commissionBalance ?? 0) / 100;
}

/// `/invite/details` 单条记录：每行对应一笔订单产生的佣金。
@JsonSerializable()
class InviteRecordModel {
  final int? id;
  @JsonKey(name: 'trade_no')
  final String? tradeNo;
  /// 订单原始金额（分）
  @JsonKey(name: 'order_amount')
  final int? orderAmount;
  /// 本次获得的佣金（分）
  @JsonKey(name: 'get_amount')
  final int? getAmount;
  @JsonKey(name: 'created_at', fromJson: _parseUnixTs)
  final int? createdAt;

  InviteRecordModel({
    this.id,
    this.tradeNo,
    this.orderAmount,
    this.getAmount,
    this.createdAt,
  });

  factory InviteRecordModel.fromJson(Map<String, dynamic> json) =>
      _$InviteRecordModelFromJson(json);

  Map<String, dynamic> toJson() => _$InviteRecordModelToJson(this);

  double get orderAmountYuan => (orderAmount ?? 0) / 100;
  double get getAmountYuan => (getAmount ?? 0) / 100;

  DateTime? get createDate {
    if (createdAt == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(createdAt! * 1000);
  }
}
