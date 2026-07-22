import 'dart:convert';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/sub_crypto_service.dart';
import '../../models/server_model.dart';

/// Velox 加密订阅数据源
///
/// 对接后端 POST /api/v1/client/velox/sync：
///   1. 请求时 ApiClient 拦截器自动附带 Authorization（user middleware 解密鉴权）
///   2. 响应为 { status, msg, sub, updated_at }，其中 sub 为 AES-128-CBC 密文
///   3. 本地解密 → {"data":[...]} JSON → List ServerModel
///
/// DPI 在传输层看到的是 base64 密文，识别不出 vless/trojan/public_key 等 VPN 特征。
abstract class VeloxSyncDataSource {
  /// 拉取加密节点列表
  Future<List<ServerModel>> fetchServers();
}

class VeloxSyncDataSourceImpl implements VeloxSyncDataSource {
  final ApiClient _apiClient;

  VeloxSyncDataSourceImpl({required ApiClient apiClient})
      : _apiClient = apiClient;

  @override
  Future<List<ServerModel>> fetchServers() async {
    // POST，显式带 {} 空对象 body，避免 webman/adapterman 对 Content-Type: application/json
    // 空 body 的 json_decode 异常；auth 由 ApiClient interceptor 自动注入 Authorization header
    final response = await _apiClient.post(
      ApiConstants.veloxSync,
      data: const <String, dynamic>{},
    );

    final body = response.data as Map<String, dynamic>;
    if (body['status'] != 1) {
      throw Exception((body['msg'] as String?) ?? 'velox sync failed');
    }

    final cipher = body['sub'] as String?;
    if (cipher == null || cipher.isEmpty) {
      throw Exception('velox sync: empty sub');
    }

    // DEBUG: 需要验证 DPI 视角时取消下面的注释。release 构建保持注释。
    // print('═══════════════════════════════════════════════════════════');
    // print('🔒 /velox/sync RAW response (what DPI would see):');
    // print('   status: ${body['status']}, msg: ${body['msg']}');
    // print('   updated_at: ${body['updated_at']}');
    // print('   sub length: ${cipher.length} chars');
    // print('   sub preview (first 200): ${cipher.substring(0, cipher.length > 200 ? 200 : cipher.length)}...');
    // print('═══════════════════════════════════════════════════════════');

    // 解密 → JSON → ServerModel[]
    final plain = SubCryptoService.decrypt(cipher);
    final decoded = jsonDecode(plain);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('velox sync: decrypted payload not a JSON object');
    }

    final list = decoded['data'];
    if (list is! List) {
      throw Exception('velox sync: data field not a list');
    }

    return list
        .map((e) => ServerModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
