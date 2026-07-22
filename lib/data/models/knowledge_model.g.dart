// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'knowledge_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

KnowledgeModel _$KnowledgeModelFromJson(Map<String, dynamic> json) =>
    KnowledgeModel(
      id: (json['id'] as num?)?.toInt(),
      category: json['category'] as String?,
      title: json['title'] as String?,
      body: json['body'] as String?,
      sort: (json['sort'] as num?)?.toInt(),
      show: (json['show'] as num?)?.toInt(),
      createdAt: (json['created_at'] as num?)?.toInt(),
      updatedAt: (json['updated_at'] as num?)?.toInt(),
    );

Map<String, dynamic> _$KnowledgeModelToJson(KnowledgeModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'category': instance.category,
      'title': instance.title,
      'body': instance.body,
      'sort': instance.sort,
      'show': instance.show,
      'created_at': instance.createdAt,
      'updated_at': instance.updatedAt,
    };

KnowledgeCategoryModel _$KnowledgeCategoryModelFromJson(
  Map<String, dynamic> json,
) => KnowledgeCategoryModel(
  category: json['category'] as String?,
  articles: (json['articles'] as List<dynamic>?)
      ?.map((e) => KnowledgeModel.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$KnowledgeCategoryModelToJson(
  KnowledgeCategoryModel instance,
) => <String, dynamic>{
  'category': instance.category,
  'articles': instance.articles,
};
