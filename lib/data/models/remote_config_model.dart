/// OSS 远程配置数据模型
class RemoteConfigModel {
  /// 多 API 地址列表（按优先级，第 0 个为首选）。
  /// 客户端按列表顺序起 + 出错时 hedge 下一个；管理 → ApiEndpointManager。
  final List<String> apiBaseUrls;
  final RemoteApiHealthCheck apiHealthCheck;
  final String? crispId;
  final String? inviteBaseUrl;
  final String? websiteUrl;
  final String? telegramUrl;
  final String? siteName;
  final String? brandName;
  final bool faqEnabled;
  final bool showAnnouncement;
  final List<RemoteFaqItem> faq;
  final RemoteAnnouncementConfig? announcement;
  final RemoteUpdateConfig? update;
  final RemoteExpireNotice? expireNotice;
  final RemoteFakeLatency fakeLatency;

  RemoteConfigModel({
    this.apiBaseUrls = const [],
    RemoteApiHealthCheck? apiHealthCheck,
    this.crispId,
    this.inviteBaseUrl,
    this.websiteUrl,
    this.telegramUrl,
    this.siteName,
    this.brandName,
    this.faqEnabled = true,
    this.showAnnouncement = true,
    this.faq = const [],
    this.announcement,
    this.update,
    this.expireNotice,
    RemoteFakeLatency? fakeLatency,
  })  : apiHealthCheck = apiHealthCheck ?? const RemoteApiHealthCheck(),
        fakeLatency = fakeLatency ?? const RemoteFakeLatency();

  factory RemoteConfigModel.fromJson(Map<String, dynamic> json) {
    return RemoteConfigModel(
      apiBaseUrls: (json['api_base_urls'] as List<dynamic>?)
              ?.map((e) => e.toString().trim())
              .where((s) => s.isNotEmpty)
              .toList() ??
          const [],
      apiHealthCheck: json['api_health_check'] != null
          ? RemoteApiHealthCheck.fromJson(
              json['api_health_check'] as Map<String, dynamic>)
          : const RemoteApiHealthCheck(),
      crispId: json['crisp_id'] as String?,
      inviteBaseUrl: json['invite_base_url'] as String?,
      websiteUrl: json['website_url'] as String?,
      telegramUrl: json['telegram_url'] as String?,
      siteName: json['site_name'] as String?,
      brandName: json['brand_name'] as String?,
      faqEnabled: json['faq_enabled'] as bool? ?? true,
      showAnnouncement: json['show_announcement'] as bool? ?? true,
      faq: (json['faq'] as List<dynamic>?)
              ?.map((e) =>
                  RemoteFaqItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      announcement: json['announcement'] != null
          ? RemoteAnnouncementConfig.fromJson(
              json['announcement'] as Map<String, dynamic>)
          : null,
      update: json['update'] != null
          ? RemoteUpdateConfig.fromJson(
              json['update'] as Map<String, dynamic>)
          : null,
      expireNotice: json['expire_notice'] != null
          ? RemoteExpireNotice.fromJson(
              json['expire_notice'] as Map<String, dynamic>)
          : null,
      fakeLatency: json['fake_latency'] != null
          ? RemoteFakeLatency.fromJson(
              json['fake_latency'] as Map<String, dynamic>)
          : const RemoteFakeLatency(),
    );
  }
}

/// 节点延迟显示包装（OSS 控制）。
/// enabled=true 时，UI 上把每个节点的真实 ping 替换成 [minMs, maxMs] 之间的"装饰数字"。
/// DEAD/失败节点(latency<=0)不装饰，仍显示真实失败状态。
/// 同一节点同一天看到的数字稳定（种子=serverId+dayOfYear），跨天微变。
class RemoteFakeLatency {
  final bool enabled;
  final int minMs;
  final int maxMs;

  const RemoteFakeLatency({
    this.enabled = false,
    this.minMs = 50,
    this.maxMs = 80,
  });

  factory RemoteFakeLatency.fromJson(Map<String, dynamic> json) {
    return RemoteFakeLatency(
      enabled: json['enabled'] as bool? ?? false,
      minMs: (json['min_ms'] as int?) ?? 50,
      maxMs: (json['max_ms'] as int?) ?? 80,
    );
  }
}

class RemoteExpireNotice {
  /// 是否启用到期提醒
  final bool enabled;

  /// 提前多少天开始提醒
  final int days;

  /// 提示文案，%s 会被替换为实际剩余天数
  final String msg;

  RemoteExpireNotice({this.enabled = true, required this.days, required this.msg});

  factory RemoteExpireNotice.fromJson(Map<String, dynamic> json) {
    return RemoteExpireNotice(
      enabled: json['enabled'] as bool? ?? true,
      days: (json['days'] as int?) ?? 7,
      msg: json['msg'] as String? ?? '',
    );
  }

  /// 将 %s 替换为实际天数
  String format(int daysLeft) => msg.replaceAll('%s', '$daysLeft');
}

class RemoteFaqItem {
  final String question;
  final String answer;

  RemoteFaqItem({required this.question, required this.answer});

  factory RemoteFaqItem.fromJson(Map<String, dynamic> json) {
    return RemoteFaqItem(
      question: json['question'] as String? ?? '',
      answer: json['answer'] as String? ?? '',
    );
  }
}

class RemoteAnnouncementConfig {
  final bool enabled;
  final String id;
  final String? title;
  final String content;
  final String? buttonText;

  RemoteAnnouncementConfig({
    this.enabled = true,
    required this.id,
    this.title,
    required this.content,
    this.buttonText,
  });

  factory RemoteAnnouncementConfig.fromJson(Map<String, dynamic> json) {
    return RemoteAnnouncementConfig(
      enabled: json['enabled'] as bool? ?? true,
      id: json['id'] as String? ?? '',
      title: json['title'] as String?,
      content: json['content'] as String? ?? '',
      buttonText: json['button_text'] as String?,
    );
  }
}

class RemoteUpdateConfig {
  final RemotePlatformUpdate? android;
  final RemotePlatformUpdate? windows;
  final RemotePlatformUpdate? macos;

  RemoteUpdateConfig({this.android, this.windows, this.macos});

  factory RemoteUpdateConfig.fromJson(Map<String, dynamic> json) {
    return RemoteUpdateConfig(
      android: json['android'] != null
          ? RemotePlatformUpdate.fromJson(
              json['android'] as Map<String, dynamic>)
          : null,
      windows: json['windows'] != null
          ? RemotePlatformUpdate.fromJson(
              json['windows'] as Map<String, dynamic>)
          : null,
      macos: json['macos'] != null
          ? RemotePlatformUpdate.fromJson(
              json['macos'] as Map<String, dynamic>)
          : null,
    );
  }
}

class RemotePlatformUpdate {
  final bool enabled;
  final String version;
  final String? downloadUrl;
  final String? message;
  final bool must;
  /// 安装包的 SHA256 指纹(小写十六进制)。填了就强制校验,空着则跳过校验。
  final String? sha256;

  RemotePlatformUpdate({
    this.enabled = true,
    required this.version,
    this.downloadUrl,
    this.message,
    this.must = false,
    this.sha256,
  });

  factory RemotePlatformUpdate.fromJson(Map<String, dynamic> json) {
    return RemotePlatformUpdate(
      enabled: json['enabled'] as bool? ?? true,
      version: json['version'] as String? ?? '',
      downloadUrl: json['download_url'] as String?,
      message: json['message'] as String?,
      must: json['must'] as bool? ?? false,
      sha256: (json['sha256'] as String?)?.trim(),
    );
  }
}

/// API 探活（主动健康检查）配置 —— 由 OSS config.json 控制。
///
/// 默认 [enabled]=false：被动失活检测（请求失败时切换）足够；不发任何主动探测请求，
/// 对面向中国大陆的客户端更友好（不留固定模式探测包）。
///
/// 启用后每 [intervalSec] 秒后台向每个 API 的 [probePath] 发一次 GET，
/// [timeoutMs] 内未回 → 标记该 API 暂时不可用。
class RemoteApiHealthCheck {
  final bool enabled;
  final int intervalSec;
  final String probePath;
  final int timeoutMs;

  const RemoteApiHealthCheck({
    this.enabled = false,
    this.intervalSec = 60,
    this.probePath = '/api/v1/guest/comm/config',
    this.timeoutMs = 3000,
  });

  factory RemoteApiHealthCheck.fromJson(Map<String, dynamic> json) {
    return RemoteApiHealthCheck(
      enabled: json['enabled'] as bool? ?? false,
      intervalSec: (json['interval_sec'] as int?) ?? 60,
      probePath: (json['probe_path'] as String?)?.trim().isNotEmpty == true
          ? (json['probe_path'] as String).trim()
          : '/api/v1/guest/comm/config',
      timeoutMs: (json['timeout_ms'] as int?) ?? 3000,
    );
  }
}

/// 版本更新检测结果
class UpdateCheckResult {
  final String currentVersion;
  final String latestVersion;
  final String downloadUrl;
  final String message;
  final bool must;
  /// 期望的 SHA256 指纹;空表示该次发布未提供,下载后跳过校验。
  final String? sha256;

  UpdateCheckResult({
    required this.currentVersion,
    required this.latestVersion,
    required this.downloadUrl,
    required this.message,
    required this.must,
    this.sha256,
  });
}
