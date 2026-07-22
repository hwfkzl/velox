import 'package:json_annotation/json_annotation.dart';

part 'knowledge_model.g.dart';

@JsonSerializable()
class KnowledgeModel {
  final int? id;
  final String? category;
  final String? title;
  final String? body;
  final int? sort;
  final int? show;
  @JsonKey(name: 'created_at')
  final int? createdAt;
  @JsonKey(name: 'updated_at')
  final int? updatedAt;

  KnowledgeModel({
    this.id,
    this.category,
    this.title,
    this.body,
    this.sort,
    this.show,
    this.createdAt,
    this.updatedAt,
  });

  factory KnowledgeModel.fromJson(Map<String, dynamic> json) =>
      _$KnowledgeModelFromJson(json);

  Map<String, dynamic> toJson() => _$KnowledgeModelToJson(this);

  /// 创建时间
  DateTime? get createDate {
    if (createdAt == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(createdAt! * 1000);
  }

  /// 更新时间
  DateTime? get updateDate {
    if (updatedAt == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(updatedAt! * 1000);
  }
}

@JsonSerializable()
class KnowledgeCategoryModel {
  final String? category;
  final List<KnowledgeModel>? articles;

  KnowledgeCategoryModel({
    this.category,
    this.articles,
  });

  factory KnowledgeCategoryModel.fromJson(Map<String, dynamic> json) =>
      _$KnowledgeCategoryModelFromJson(json);

  Map<String, dynamic> toJson() => _$KnowledgeCategoryModelToJson(this);
}
