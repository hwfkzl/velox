import 'package:json_annotation/json_annotation.dart';

part 'notice_model.g.dart';

@JsonSerializable()
class NoticeModel {
  final int? id;
  final String? title;
  final String? content;
  final int? show;
  @JsonKey(name: 'img_url')
  final String? imgUrl;
  final List<String>? tags;
  @JsonKey(name: 'created_at')
  final int? createdAt;
  @JsonKey(name: 'updated_at')
  final int? updatedAt;

  NoticeModel({
    this.id,
    this.title,
    this.content,
    this.show,
    this.imgUrl,
    this.tags,
    this.createdAt,
    this.updatedAt,
  });

  factory NoticeModel.fromJson(Map<String, dynamic> json) =>
      _$NoticeModelFromJson(json);

  Map<String, dynamic> toJson() => _$NoticeModelToJson(this);

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

  /// 格式化的创建日期
  String get formattedDate {
    final date = createDate;
    if (date == null) return '';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// 公告富文本 —— 供 flutter_html 渲染，保留后端的加粗/颜色/链接等样式。
  ///
  /// 后端 notice.content 是 HTML（含 <strong>、style="color:..."、<a> 等），
  /// 段落之间用换行符分隔。flutter_html 会把 \n 当空白折叠掉导致换行丢失，
  /// 因此把换行（含字面量转义的 \n）无条件转成 <br>，再交给 Html 渲染。
  ///
  /// v1.0.11 修复:后端如果把 HTML 标签属性写在多行（如
  ///   `<a href="url"\ntarget="_blank">下载链接</a>`），
  /// 直接 replaceAll '\n' → '<br>' 会把标签打断成
  ///   `<a href="url"<br>target="_blank">`，flutter_html 解析失败，
  /// `target="_blank">下载链接` 就以文本形式泄漏到 UI 上（用户反馈的公告栏 bug）。
  /// 修法:先把 HTML 标签内部的所有空白（含换行）折叠为单空格，
  /// 再把剩下的换行（= 真正的段落分隔）转成 <br>。
  String get contentHtml {
    var s = content ?? '';
    if (s.isEmpty) return '';
    s = s.replaceAll(r'\r\n', '\n').replaceAll(r'\n', '\n'); // 字面量转义 → 真实换行
    s = s.replaceAll('\r\n', '\n').replaceAll('\r', '\n');   // CRLF → LF

    // 关键:HTML 标签内部的换行/多余空白 → 单空格。保护标签结构不被下一步 <br> 打断。
    s = s.replaceAllMapped(
      RegExp(r'<[^>]*>'),
      (m) => m.group(0)!.replaceAll(RegExp(r'\s+'), ' '),
    );

    s = s.replaceAll('\n', '<br>');                          // 段落级换行 → <br>
    return s;
  }
}
