import 'package:encrypt/encrypt.dart';

/// Velox 订阅解密服务
///
/// 与后端 app/Utils/SubCrypto.php 的 KEY / IV 必须完全一致。
/// 算法：AES-128-CBC + PKCS7（OpenSSL 默认）
class SubCryptoService {
  SubCryptoService._();

  // ★ 与后端 SubCrypto.php 的 KEY/IV 严格对齐
  static const String _key = 'velox_subkey_16b';
  static const String _iv = '2a1b3c4d5e6f7890';

  /// 解密 /velox/sync 响应的 sub 字段（base64 密文）→ 明文 YAML
  static String decrypt(String base64Ciphertext) {
    final encrypter = Encrypter(
      AES(Key.fromUtf8(_key), mode: AESMode.cbc, padding: 'PKCS7'),
    );
    final iv = IV.fromUtf8(_iv);
    return encrypter.decrypt64(base64Ciphertext, iv: iv);
  }
}
