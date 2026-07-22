import Cocoa
import FlutterMacOS
import singbox_flutter

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func applicationWillTerminate(_ notification: Notification) {
    // 清 vpn_was_connected → 0，防止下次启动 auto-reconnect。
    // Dart 层 bloc._saveLastConnectedState(false) 跑在 _onStatusChanged(disconnected) 里，
    // 但 macOS Cmd+Q 直接进 applicationWillTerminate（NSApplication terminate 路径），
    // 不会走 bloc 的 VpnDisconnectRequested → status=disconnected 流程，
    // 所以 Dart 的 await 修复在此场景下无效，必须在原生层显式清并强制落盘。
    // key 名 "flutter.vpn_was_connected" 对应 SharedPreferences 默认前缀 "flutter."
    let defaults = UserDefaults.standard
    defaults.set(false, forKey: "flutter.vpn_was_connected")
    // 同时清 TUN/mode UI 偏好：让 Cmd+Q 后再启动是干净状态（用户期望，对齐"应用退出 = 全归零"）
    defaults.removeObject(forKey: "flutter.proxy_mode")
    defaults.removeObject(forKey: "flutter.tun_enabled")
    defaults.removeObject(forKey: "flutter.last_proxy_mode")
    defaults.synchronize()  // 强制立即写盘；deprecated 但仍生效，进程将退出无重试机会

    // 复用插件已缓存的 AuthorizationRef 清除系统代理，避免 macOS 13+ 权限不足
    SingboxFlutterPlugin.shared?.cleanupOnExit()
  }
}
