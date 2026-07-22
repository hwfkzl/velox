import NetworkExtension
import Foundation
import Libbox

/// PacketTunnelProvider — 使用 Libbox (sing-box) 实现真实的 iOS VPN 隧道。
///
/// 工作原理：
/// 1. startTunnel 先应用隧道网络设置（告诉 iOS 创建 utun 接口）
/// 2. 通过 KVC 获取 packetFlow 底层的 TUN 文件描述符
/// 3. 调用 LibboxCommandServer.startOrReloadService 启动 sing-box 内核
/// 4. sing-box 通过 PlatformInterface.openTun 回调获取 TUN fd，我们返回步骤 2 获取的 fd
/// 5. sing-box 直接读写该 fd 处理所有流量
class PacketTunnelProvider: NEPacketTunnelProvider {

    // MARK: - Properties

    private var commandServer: LibboxCommandServer?
    private var statsTimer: Timer?

    /// Libbox 回调 openTun 时我们返回的预分配 TUN fd
    private var preallocatedTunFD: Int32 = -1

    /// sing-box 启动完成信号量（让 startTunnel 等待 openTun 完成）
    private let tunReadySemaphore = DispatchSemaphore(value: 0)
    private var tunSetupError: Error?

    private let appGroupId: String = {
        let bundleId = Bundle.main.bundleIdentifier ?? ""
        let parentBundleId = bundleId.replacingOccurrences(of: ".PacketTunnel", with: "")
        return "group.\(parentBundleId)"
    }()

    private var containerURL: URL {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId)
            ?? FileManager.default.temporaryDirectory
    }

    // MARK: - Lifecycle

    override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        log("startTunnel called")
        updateStatus("starting")

        // 从 providerConfiguration 取出 sing-box JSON 配置
        guard
            let providerConfig = (protocolConfiguration as? NETunnelProviderProtocol)?.providerConfiguration,
            let configJSON = providerConfig["config"] as? String
        else {
            finish(completionHandler, error: makeError(1, "Missing sing-box configuration"))
            return
        }

        log("config length = \(configJSON.count)")

        // Step 1: 初始化 Libbox 路径（Go runtime 需要）
        do {
            try setupLibbox()
        } catch {
            finish(completionHandler, error: error)
            return
        }

        // Step 2: 先应用隧道网络设置，让 iOS 创建 utun 接口
        // 这些参数需与 sing-box config 中的 TUN inbound 保持一致：
        //   inet4Address: 172.19.0.1/30，mtu: 1500
        let tunnelSettings = buildTunnelNetworkSettings()
        setTunnelNetworkSettings(tunnelSettings) { [weak self] error in
            guard let self else { return }

            if let error = error {
                self.finish(completionHandler, error: error)
                return
            }

            // Step 3: 网络设置已应用，通过 KVC 获取 packetFlow 底层的 TUN fd
            self.preallocatedTunFD = self.acquirePacketFlowFD()
            self.log("preallocatedTunFD = \(self.preallocatedTunFD)")

            // Step 4: 创建并启动 LibboxCommandServer
            let handler = CommandServerHandlerImpl(provider: self)
            let platform = PlatformInterfaceImpl(provider: self)

            guard let server = LibboxCommandServer(handler, platformInterface: platform) else {
                self.finish(completionHandler, error: self.makeError(2, "Failed to create LibboxCommandServer"))
                return
            }
            self.commandServer = server

            // 启动 IPC 命令通道（供主 app 连接查询状态/选择节点）
            // Swift ObjC 互操作：(BOOL)start:(NSError**) → func start() throws
            do {
                try server.start()
            } catch {
                self.log("CommandServer.start warning: \(error.localizedDescription) — continuing")
            }

            // Step 5: 启动 sing-box VPN 服务（异步，会回调 openTun）
            // 同样：startOrReloadService 改为 throws 函数
            do {
                try server.startOrReloadService(configJSON, options: LibboxOverrideOptions())
            } catch {
                self.finish(completionHandler, error: error as NSError)
                return
            }

            // Step 6: 等待 openTun 回调完成（PlatformInterface.openTun 会 signal）
            // 最多等 30 秒，超时视为 sing-box 启动失败
            let waitResult = self.tunReadySemaphore.wait(timeout: .now() + 30)
            if waitResult == .timedOut {
                self.finish(completionHandler, error: self.makeError(5, "Timeout waiting for sing-box openTun callback"))
                return
            }

            if let err = self.tunSetupError {
                self.finish(completionHandler, error: err)
                return
            }

            self.log("sing-box started successfully")
            self.updateStatus("connected")
            self.startStatsMonitoring()
            self.finish(completionHandler, error: nil)
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        log("stopTunnel called, reason=\(reason.rawValue)")
        stopStatsMonitoring()

        if let server = commandServer {
            // closeService 变成 throws 函数
            do {
                try server.closeService()
            } catch {
                log("closeService error: \(error.localizedDescription)")
            }
            server.close()
            commandServer = nil
        }

        updateStatus("disconnected")
        completionHandler()
    }

    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        guard
            let msg = try? JSONSerialization.jsonObject(with: messageData) as? [String: Any],
            let cmd = msg["command"] as? String
        else {
            completionHandler?(nil)
            return
        }

        if cmd == "getStats" {
            let stats: [String: Any] = [
                "uploadSpeed":    readShared("uploadSpeed"),
                "downloadSpeed":  readShared("downloadSpeed"),
                "totalUpload":    readShared("totalUpload"),
                "totalDownload":  readShared("totalDownload"),
            ]
            completionHandler?(try? JSONSerialization.data(withJSONObject: stats))
        } else {
            completionHandler?(nil)
        }
    }

    // MARK: - Internal: called from PlatformInterfaceImpl

    /// sing-box 调用 openTun 时，我们返回预分配的 TUN fd，并通知 startTunnel 继续
    func onOpenTunCalled(ret0_: UnsafeMutablePointer<Int32>?, error: NSErrorPointer) -> Bool {
        if preallocatedTunFD < 0 {
            let err = makeError(10, "TUN fd not available (preallocatedTunFD < 0)")
            log("openTun error: \(err.localizedDescription)")
            error?.pointee = err
            tunSetupError = err
            tunReadySemaphore.signal()
            return false
        }

        ret0_?.pointee = preallocatedTunFD
        log("openTun returned fd=\(preallocatedTunFD)")
        tunReadySemaphore.signal()
        return true
    }

    // MARK: - TUN Network Settings

    /// 构建与 sing-box TUN inbound 配置匹配的 NEPacketTunnelNetworkSettings
    private func buildTunnelNetworkSettings() -> NEPacketTunnelNetworkSettings {
        // 隧道远端地址：172.19.0.2（/30 网络中的另一端）
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "172.19.0.2")

        // IPv4：172.19.0.1/30 → mask 255.255.255.252
        let ipv4 = NEIPv4Settings(addresses: ["172.19.0.1"], subnetMasks: ["255.255.255.252"])
        ipv4.includedRoutes = [NEIPv4Route.default()]
        settings.ipv4Settings = ipv4

        // DNS
        let dns = NEDNSSettings(servers: ["1.1.1.1", "8.8.8.8"])
        dns.matchDomains = [""]
        settings.dnsSettings = dns

        // MTU（与 iOS TUN inbound 配置一致）
        settings.mtu = 1500

        return settings
    }

    // MARK: - TUN File Descriptor

    /// 通过 KVC 获取 NEPacketTunnelFlow 的底层 utun 文件描述符。
    /// 这是 iOS VPN 生态中广泛使用的私有 API 访问方式（iOS 12+）。
    private func acquirePacketFlowFD() -> Int32 {
        let flow = self.packetFlow

        // 尝试路径 1: socket.fileDescriptor（大多数 iOS 版本有效）
        if let fd = (flow as AnyObject).value(forKeyPath: "socket.fileDescriptor") as? Int32,
           fd >= 0 {
            log("acquirePacketFlowFD via 'socket.fileDescriptor': fd=\(fd)")
            return fd
        }

        // 尝试路径 2: _socket.fileDescriptor
        if let fd = (flow as AnyObject).value(forKeyPath: "_socket.fileDescriptor") as? Int32,
           fd >= 0 {
            log("acquirePacketFlowFD via '_socket.fileDescriptor': fd=\(fd)")
            return fd
        }

        // 尝试路径 3: 通过 perform selector
        let sock = NSSelectorFromString("socket")
        let fdSel = NSSelectorFromString("fileDescriptor")
        if (flow as AnyObject).responds(to: sock),
           let sockObj = (flow as AnyObject).perform(sock)?.takeUnretainedValue(),
           (sockObj as AnyObject).responds(to: fdSel),
           let fdResult = (sockObj as AnyObject).perform(fdSel) {
            let fd = Int32(truncatingIfNeeded: UInt(bitPattern: fdResult.toOpaque()))
            if fd >= 0 {
                log("acquirePacketFlowFD via selector: fd=\(fd)")
                return fd
            }
        }

        log("acquirePacketFlowFD: ERROR — could not get TUN fd via any KVC path. VPN will not function.")
        // 注意：TUN fd 获取失败是致命错误。
        // 真实设备 iOS 12+ 上 KVC 路径应当有效。
        // 如果在模拟器上运行，Network Extension 是虚拟的，VPN 流量路由不工作。
        return -1
    }

    // MARK: - Libbox Setup

    private func setupLibbox() throws {
        let tempDir = containerURL.appendingPathComponent("singbox_tmp")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let opts = LibboxSetupOptions()
        opts.basePath = containerURL.path
        opts.workingPath = containerURL.path
        opts.tempPath = tempDir.path
        opts.logMaxLines = 500
        opts.debug = false

        var err: NSError?
        guard LibboxSetup(opts, &err) else {
            throw err ?? makeError(20, "LibboxSetup failed")
        }

        log("LibboxSetup complete, basePath=\(opts.basePath)")
    }

    // MARK: - Stats Monitoring

    private func startStatsMonitoring() {
        stopStatsMonitoring()
        statsTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.pollStats()
        }
    }

    private func stopStatsMonitoring() {
        statsTimer?.invalidate()
        statsTimer = nil
    }

    /// 通过 LibboxCommandClient 订阅流量统计（如有连接）
    /// 简化版：暂时用空实现，未来可通过 CommandClient 订阅
    private func pollStats() {
        // TODO: 通过 LibboxCommandClient 连接到 CommandServer 订阅 status 统计
        // 当前 stats 由 CommandClient 在主 app 侧通过 Clash API 或 CommandServer 查询
    }

    // MARK: - Shared State

    private func updateStatus(_ status: String) {
        let fmt = ISO8601DateFormatter()
        let defaults = UserDefaults(suiteName: appGroupId)
        defaults?.set(status, forKey: "vpnStatus")
        defaults?.set(fmt.string(from: Date()), forKey: "vpnLastUpdate")
        defaults?.synchronize()
        log("status → \(status)")
    }

    private func readShared(_ key: String) -> Int {
        UserDefaults(suiteName: appGroupId)?.integer(forKey: key) ?? 0
    }

    // MARK: - Helpers

    private func finish(_ completionHandler: @escaping (Error?) -> Void, error: Error?) {
        if let error = error {
            log("startTunnel FAILED: \(error.localizedDescription)")
            updateStatus("error")
        }
        completionHandler(error)
    }

    private func makeError(_ code: Int, _ message: String) -> NSError {
        NSError(domain: "PacketTunnelProvider", code: code,
                userInfo: [NSLocalizedDescriptionKey: message])
    }

    private func log(_ msg: String) {
        NSLog("PacketTunnelProvider: \(msg)")
    }
}

// MARK: - LibboxCommandServerHandler

/// 处理来自 CommandServer 的服务控制回调
///
/// 重要：Swift ObjC 互操作规则：
/// - `(BOOL)method:error:` → `func method() throws`
/// - `(X*)method:error:` → `func method() throws -> X`（非 optional，失败时 throw）
/// - `method:` → `method(_:)`
/// - 同名 class + protocol → protocol 在 Swift 里加 `Protocol` 后缀
///
/// `LibboxCommandServerHandler` 头文件里是同名 class + protocol，所以这里继承
/// `LibboxCommandServerHandlerProtocol`。所有原本 `error:` 参数的方法都改为 `throws`。
private class CommandServerHandlerImpl: NSObject, LibboxCommandServerHandlerProtocol {
    weak var provider: PacketTunnelProvider?

    init(provider: PacketTunnelProvider) { self.provider = provider }

    func serviceReload() throws {
        NSLog("[CommandServerHandler] serviceReload")
    }

    func serviceStop() throws {
        NSLog("[CommandServerHandler] serviceStop")
        provider?.cancelTunnelWithError(nil)
    }

    func setSystemProxyEnabled(_ enabled: Bool) throws {
        // no-op: iOS Network Extension 不支持用户态设置系统代理
    }

    func getSystemProxyStatus() throws -> LibboxSystemProxyStatus {
        // 非 optional 返回类型：没有数据时必须 throw，不能返 nil
        throw NSError(domain: "Velox", code: -1,
                      userInfo: [NSLocalizedDescriptionKey: "System proxy not supported on iOS"])
    }

    func triggerNativeCrash() throws {
        // no-op
    }

    func writeDebugMessage(_ message: String?) {
        if let m = message { NSLog("[sing-box] \(m)") }
    }
}

// MARK: - LibboxPlatformInterface

/// sing-box 用来与 iOS 网络交互的平台接口
///
/// 注意：`LibboxPlatformInterface` 在 ObjC 头文件里既是 `@protocol` 又是 `@interface`
/// （Go gomobile bind 的产物）。Swift 在遇到同名冲突时会把**具体类**保留原名，
/// **协议**重命名为带 `Protocol` 后缀，所以这里我们要继承的是 `LibboxPlatformInterfaceProtocol`，
/// 不是 `LibboxPlatformInterface`（那是类，会导致多重继承错误）。
/// 同理所有 `Libbox*Listener` / `Libbox*Iterator` / `Libbox*Transport` 之类的协议参数
/// 都要加 `Protocol` 后缀。
private class PlatformInterfaceImpl: NSObject, LibboxPlatformInterfaceProtocol {
    weak var provider: PacketTunnelProvider?

    init(provider: PacketTunnelProvider) { self.provider = provider }

    // ── Swift ObjC 互操作方法重写规则 ──
    // 所有带 `NSError**` 的方法变为 `throws`；非 optional 返回值通过 throw 表达失败；
    // `autoDetectInterfaceControl` / `usePlatformAutoDetectInterfaceControl` 被重命名
    // (去掉 Interface)；`sendNotification:error:` 被重命名为 `send(_:)`（参数类型暗示）。

    // 核心方法：sing-box 请求 TUN 文件描述符
    func openTun(_ options: (any LibboxTunOptionsProtocol)?, ret0_: UnsafeMutablePointer<Int32>?) throws {
        NSLog("[PlatformInterface] openTun called")
        var err: NSError?
        let ok = provider?.onOpenTunCalled(ret0_: ret0_, error: &err) ?? false
        if !ok {
            throw err ?? NSError(domain: "Velox", code: -1,
                                 userInfo: [NSLocalizedDescriptionKey: "openTun failed"])
        }
    }

    // 自动探测网络接口：Swift 把 `autoDetectInterfaceControl:error:` 重命名为 `autoDetectControl(_:)`，
    // `usePlatformAutoDetectInterfaceControl` 重命名为 `usePlatformAutoDetectControl()`（去 Interface）
    func autoDetectControl(_ fd: Int32) throws {
        // no-op（Swift 自动处理）
    }
    func usePlatformAutoDetectControl() -> Bool { true }

    // iOS Network Extension 标识（返回 Bool，无 error 参数 → 非 throws）
    func underNetworkExtension() -> Bool { true }
    func useProcFS() -> Bool { false }
    func includeAllNetworks() -> Bool { false }

    // WiFi 状态（optional 返回 + 无 error 参数 → 非 throws）
    func readWIFIState() -> LibboxWIFIState? { nil }

    // 网络接口枚举：有 error 参数且返回非空，必须 throws。`getInterfaces` 保留 get 前缀。
    func getInterfaces() throws -> any LibboxNetworkInterfaceIteratorProtocol {
        throw NSError(domain: "Velox", code: -1,
                      userInfo: [NSLocalizedDescriptionKey: "getInterfaces not implemented"])
    }
    func findConnectionOwner(_ ipProtocol: Int32, sourceAddress: String?,
                             sourcePort: Int32, destinationAddress: String?,
                             destinationPort: Int32) throws -> LibboxConnectionOwner {
        throw NSError(domain: "Velox", code: -1,
                      userInfo: [NSLocalizedDescriptionKey: "findConnectionOwner not implemented"])
    }

    // 网络变化监听（NWPathMonitor 可实现，暂时空实现）
    func startDefaultInterfaceMonitor(_ listener: (any LibboxInterfaceUpdateListenerProtocol)?) throws { }
    func closeDefaultInterfaceMonitor(_ listener: (any LibboxInterfaceUpdateListenerProtocol)?) throws { }
    func startNeighborMonitor(_ listener: (any LibboxNeighborUpdateListenerProtocol)?) throws { }
    func closeNeighborMonitor(_ listener: (any LibboxNeighborUpdateListenerProtocol)?) throws { }

    // 通知：Swift 把 `sendNotification:error:` 重命名为 `send(_:)`（参数类型暗示）
    func send(_ notification: LibboxNotification?) throws {
        if let n = notification { NSLog("[sing-box notify] \(n.title): \(n.body)") }
    }

    // 证书/DNS（无 error 参数 → 非 throws，保留 optional 返回）
    func systemCertificates() -> (any LibboxStringIteratorProtocol)? { nil }
    func localDNSTransport() -> (any LibboxLocalDNSTransportProtocol)? { nil }
    func clearDNSCache() {}
    func registerMyInterface(_ name: String?) {}
}
