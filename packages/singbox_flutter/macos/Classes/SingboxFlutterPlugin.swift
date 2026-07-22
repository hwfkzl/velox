import Cocoa
import FlutterMacOS
import Foundation
import SystemConfiguration
import Security

public class SingboxFlutterPlugin: NSObject, FlutterPlugin {

    /// 全局单例，供 AppDelegate 在退出时调用（strong 确保退出期间不被释放）
    public static var shared: SingboxFlutterPlugin?

    // MARK: - File-based debug log
    // NSLog 在某些场景下 log show 捞不到。我们把关键日志同时写到文件，
    // 确保调试时能 100% 读到。
    private static let pluginLogPath = "/tmp/velox_plugin.log"

    /// 写一行日志到 /tmp/velox_plugin.log + NSLog，双通道。
    private func vlog(_ message: String) {
        NSLog("SingboxFlutterPlugin: \(message)")
        let line = "[\(Date())] \(message)\n"
        guard let data = line.data(using: .utf8) else { return }
        if let handle = FileHandle(forWritingAtPath: SingboxFlutterPlugin.pluginLogPath) {
            handle.seekToEndOfFile()
            handle.write(data)
            handle.closeFile()
        } else {
            // 文件不存在，创建
            FileManager.default.createFile(atPath: SingboxFlutterPlugin.pluginLogPath, contents: data, attributes: nil)
        }
    }

    private var channel: FlutterMethodChannel?
    private var eventChannel: FlutterEventChannel?
    private var eventSink: FlutterEventSink?

    private var mihomoProcess: Process?
    private var tunPid: Int32 = -1
    private let tunPidFile = "/tmp/velox_mihomo_tun.pid"
    private let tunLogFile = "/tmp/velox_mihomo_tun.log"
    private var isConnected = false
    private var isTunMode = false
    private var connectionStartTime: Date?
    private var statsTimer: Timer?

    // 连接代次：每次 disconnect 时递增，startMihomo completion 检查代次是否匹配，
    // 防止 disconnect 后 completion 回调将状态重置回 "connected"（竞态）
    private var connectGeneration: Int = 0

    // ── 日志实时输出（测试阶段）────────────────────────────────────────────
    private var logTailHandle: FileHandle?
    private var logTailSource: DispatchSourceRead?

    // Stats
    private var lastUpload: Int64 = 0
    private var lastDownload: Int64 = 0
    private var totalUpload: Int64 = 0
    private var totalDownload: Int64 = 0

    // Use non-default ports to avoid conflict with other Clash clients (e.g. Clash Verge)
    // Clash Verge defaults: mixed-port 7890, api 9090
    // mihomo defaults: mixed-port 10808, api 9090
    private let proxyPort = 17890
    private let clashApiPort = 19090

    // MARK: - Helper paths

    private let helperSocketPath  = "/var/run/com.velox.app.helper.sock"
    private let helperInstalledAt = "/Library/PrivilegedHelperTools/com.velox.app.helper"
    private let helperPlistAt     = "/Library/LaunchDaemons/com.velox.app.helper.plist"

    /// 仅在 installHelper / uninstallHelper（一次性授权）时使用，不对外暴露
    private var cachedAuth: AuthorizationRef?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = SingboxFlutterPlugin()
        shared = instance

        let methodChannel = FlutterMethodChannel(
            name: "com.velox.singbox_flutter/method",
            binaryMessenger: registrar.messenger
        )
        instance.channel = methodChannel
        registrar.addMethodCallDelegate(instance, channel: methodChannel)

        let eventChannel = FlutterEventChannel(
            name: "com.velox.singbox_flutter/events",
            binaryMessenger: registrar.messenger
        )
        instance.eventChannel = eventChannel
        eventChannel.setStreamHandler(instance)

        // 应用启动时清理孤立 TUN 进程（上次未正常退出残留的 root mihomo 进程）
        instance.cleanupOrphanedTun()
    }

    /// 应用启动时清理所有残留状态：
    /// 1. 卸载旧版 LaunchDaemon（com.velox.app.mihomo）—— 我们现在用 child process 架构
    /// 2. 强杀所有孤立的 mihomo 进程
    /// 3. 清理 stale TUN 路由
    private func cleanupOrphanedTun() {
        NSLog("SingboxFlutterPlugin: cleanupOrphanedTun: cleaning up old LaunchDaemon + orphans + stale routes...")
        DispatchQueue.global().async { [weak self] in
            guard let self = self else { return }
            // 一次性卸载旧版 mihomo LaunchDaemon（从 v1/v2 架构残留，现在已不使用）
            let uninstallCmd: [String: Any] = ["cmd": "uninstall_mihomo_svc"]
            _ = self.sendHelperCommand(uninstallCmd)
            // 强杀所有孤立 mihomo 进程 + 清理 stale TUN 路由（helper 内部处理）
            let killCmd: [String: Any] = ["cmd": "kill_all_mihomo"]
            let resp = self.sendHelperCommand(killCmd)
            let killed = resp?["killed"] as? Int ?? 0
            let routesCleaned = resp?["routes_cleaned"] as? Int ?? 0
            NSLog("SingboxFlutterPlugin: cleanupOrphanedTun done, killed=\(killed), routes_cleaned=\(routesCleaned)")
            try? FileManager.default.removeItem(atPath: self.tunPidFile)

            // 崩溃/强退恢复：上次非正常退出（dirty 仍为 true）会残留系统代理或被强制的
            // DNS。此刻刚启动、必然未连接，安全地把它们都还原（dirty 仅由本应用置位，
            // 不会误清用户自己设置的代理）。对标 Clash Verge 启动重置残留代理。
            if UserDefaults.standard.bool(forKey: self.systemDirtyKey) {
                NSLog("SingboxFlutterPlugin: detected unclean exit → restoring system proxy/DNS")
                self.clearProxySettings()
                self.restoreSystemDns()
                self.markSystemDirty(false)
            }
        }
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "connect":
            guard let args = call.arguments as? [String: Any],
                  let config = args["config"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "Config is required", details: nil))
                return
            }
            let selectedProxyName = args["selectedProxyName"] as? String ?? "proxy"
            connect(config: config, selectedProxyName: selectedProxyName, result: result)

        case "disconnect":
            disconnect(result: result)

        case "getStats":
            getStats(result: result)

        case "hasVpnPermission":
            result(true)

        case "requestVpnPermission":
            result(true)

        case "getVersion":
            result(getVersion())

        case "warmupAuth":
            // App 启动时调用：安装 helper（仅首次弹一次密码），之后直接返回 true
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { return }
                let ok = self.ensureHelperAvailable()
                DispatchQueue.main.async { result(ok) }
            }

        case "uninstallHelper":
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { return }
                let ok = self.uninstallHelper()
                DispatchQueue.main.async { result(ok) }
            }

        case "patchTunMode":
            guard let args = call.arguments as? [String: Any],
                  let config = args["config"] as? String,
                  let enabled = args["enabled"] as? Bool else {
                result(false)
                return
            }
            let selectedProxyName = args["selectedProxyName"] as? String ?? "proxy"
            patchTunMode(config: config, enabled: enabled,
                         selectedProxyName: selectedProxyName, result: result)

        case "switchProxy":
            guard let args = call.arguments as? [String: Any],
                  let name = args["name"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "name is required", details: nil))
                return
            }
            switchProxyByName(name: name, result: result)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Connection Management

    // 记录当前选中的代理名，用于热重载后恢复 GLOBAL Selector
    private var currentSelectedProxyName: String = "proxy"

    private func connect(config: String, selectedProxyName: String, result: @escaping FlutterResult) {
        let isTun = configIsTun(config)
        vlog("=== connect() called, selectedProxy=\(selectedProxyName) isTun=\(isTun) configSize=\(config.count) ===")
        currentSelectedProxyName = selectedProxyName

        let configPath = getConfigFilePath()
        do {
            try config.write(toFile: configPath, atomically: true, encoding: .utf8)
            // 备份 TUN 配置，即使后续用户切回代理模式也能读到最后一次 TUN 配置用于调试
            if isTun {
                try? config.write(toFile: "/tmp/velox_mihomo_last_tun.yaml", atomically: true, encoding: .utf8)
                vlog("connect: wrote TUN config to \(configPath) and backup to /tmp/velox_mihomo_last_tun.yaml")
            } else {
                vlog("connect: wrote non-TUN config to \(configPath)")
            }
        } catch {
            sendStatus("error")
            result(FlutterError(code: "CONFIG_ERROR", message: error.localizedDescription, details: nil))
            return
        }

        // 立刻进入 connecting 状态（主线程，fast）
        sendStatus("connecting")

        // ── 行业标准（Clash Verge / Tauri async）：
        // 所有阻塞调用（helper socket I/O、Thread.sleep、install 等待 3+ 秒）
        // 全部移到后台线程，主线程立刻释放回 Flutter runloop，UI 不卡。
        // result() 从任意线程调用都安全（Flutter 会自动 marshal 回主线程）。
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            // CV 式架构：核心永远以 root LaunchDaemon 服务（startMihomoAsSvc）运行，
            // 不存在 root↔user 权限切换 → 只要服务在跑，任何变更（切节点/切规则↔全局/
            // 开关 TUN）都走热重载 PUT /configs，进程不重启、连接不中断。
            let processRunning = self.isConnected
            let tunStateChanged = (isTun != self.isTunMode)

            if processRunning {
                NSLog("SingboxFlutterPlugin: svc running, hot-reload (Clash Verge style), tunStateChanged=\(tunStateChanged)")
                self.hotReloadAndSwitch(configPath: configPath, proxyName: selectedProxyName) { [weak self] success in
                    guard let self = self else { return }
                    if success {
                        // TUN 状态变了才动 DNS/系统代理（避免每次切节点都跑 networksetup）。
                        // 后台线程跑 networksetup（耗时），不阻塞 UI 返回。
                        if tunStateChanged {
                            DispatchQueue.global(qos: .userInitiated).async {
                                if isTun {
                                    self.setSystemDns("114.114.114.114")
                                    self.applyProxySettings(enabled: false)
                                } else {
                                    self.restoreSystemDns()
                                    self.applyProxySettings(enabled: true)
                                }
                            }
                        }
                        DispatchQueue.main.async {
                            self.isTunMode = isTun
                            self.connectionStartTime = Date()
                            self.sendStatus("connected")
                            result(true)
                        }
                    } else {
                        // 热重载失败 → 完整重启（仍在后台线程）
                        NSLog("SingboxFlutterPlugin: hot-reload failed, falling back to full restart")
                        self.fullRestartConnect(config: config, configPath: configPath, isTun: isTun,
                                               selectedProxyName: selectedProxyName, result: result)
                    }
                }
                return
            }

            // 首次连接（服务未跑）→ 完整启动：装 + kickstart root mihomo 服务。
            self.fullRestartConnect(config: config, configPath: configPath, isTun: isTun,
                                   selectedProxyName: selectedProxyName, result: result)
        }
    }

    /// 热重载配置 + 切换 GLOBAL 节点（不重启进程，系统代理不中断）
    private func hotReloadAndSwitch(configPath: String, proxyName: String, completion: @escaping (Bool) -> Void) {
        vlog(">>> hotReloadAndSwitch PUT /configs?force=true path=\(configPath)")
        guard let url = URL(string: "http://127.0.0.1:\(clashApiPort)/configs?force=true") else {
            completion(false)
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = "{\"path\":\"\(configPath)\"}".data(using: .utf8)
        request.timeoutInterval = 5

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            let ok = status >= 200 && status < 300 && error == nil
            if ok {
                self.vlog("<<< hotReloadAndSwitch SUCCESS status=\(status), switching GLOBAL to '\(proxyName)'")
                self.switchGlobalToNamedProxy(proxyName)
                // 热重载只换规则、不杀已有连接 → 浏览器的 keep-alive 老连接会继续按旧规则走
                // （如 规则→全局 后 ip.cn 仍走 DIRECT 显示本地 IP）。清掉所有活动连接，
                // 强制重连走新规则，让模式切换"立即生效"，且不重启进程（仍丝滑）。
                self.flushAllConnections()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { completion(true) }
            } else {
                let body = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                self.vlog("<<< hotReloadAndSwitch FAILED status=\(status) error=\(error?.localizedDescription ?? "nil") body=\(body.prefix(300))")
                DispatchQueue.main.async { completion(false) }
            }
        }.resume()
    }

    /// 关闭所有活动连接（mihomo Clash API: DELETE /connections）。
    /// 配置热重载后调用：浏览器/app 的 keep-alive 长连接是按旧规则建立的，热重载不会
    /// 主动断开它们 → 切 规则↔全局 对"已开的连接"不生效。清掉后强制重连走新规则，
    /// 立即生效（且不重启 mihomo 进程，系统代理不中断）。
    private func flushAllConnections() {
        guard let url = URL(string: "http://127.0.0.1:\(clashApiPort)/connections") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.timeoutInterval = 3
        URLSession.shared.dataTask(with: request) { _, response, _ in
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            NSLog("SingboxFlutterPlugin: flushAllConnections (DELETE /connections) → \(code)")
        }.resume()
    }

    /// 完整重启流程（首次连接 / 热重载失败时使用）。
    /// 行业标准（Clash Verge）：通过 VeloxHelper 以 root 身份 fork mihomo 作为 child process，
    /// 不使用 LaunchDaemon 服务管理。这样：
    /// - 启动快（fork 立即返回，不需要 bootout/bootstrap 的 3-4 秒等待）
    /// - 状态清晰（PID 明确，进程退出时资源自动清理）
    /// - 无 install 开销
    private func fullRestartConnect(config: String, configPath: String, isTun: Bool,
                                    selectedProxyName: String, result: @escaping FlutterResult) {
        // 记录上一次会话是否为 TUN（在 stopMihomo 重置前捕获），用于决定是否恢复 DNS
        let wasTunMode = isTunMode
        // 停止现有进程
        if isConnected || mihomoProcess?.isRunning == true || tunPid > 0 {
            // 必须先把 isConnected 置 false，再 stopMihomo()：否则在"已连接代理时开 TUN"
            // （proxy→TUN）这条路径上，stopMihomo 会 terminate 用户态 mihomo 进程，其
            // terminationHandler 触发 handleUnexpectedTermination；此刻若 isConnected 仍为
            // true，会误报一次 "Connection terminated unexpectedly" + sendStatus("disconnected")，
            // 导致 UI 闪一下"断开"。提前置 false 让 handleUnexpectedTermination 的 if 守卫拦住
            // 误报（与 disconnect() 的处理一致）。
            isConnected = false
            stopMihomo()
            // 删了 sleep(0.3)：waitForPortFree（下面 _trySequential 起新核心前调）
            // 会精确等到端口真空出来，再固定 sleep 是冗余的，省 0.3s。
        }
        // 清理所有孤立 root mihomo 进程（跨会话残留 + 清理 stale TUN 路由）
        let killCmd: [String: Any] = ["cmd": "kill_all_mihomo"]
        let killResp = sendHelperCommand(killCmd)
        let killed = killResp?["killed"] as? Int ?? 0
        if killed > 0 {
            NSLog("SingboxFlutterPlugin: full restart: killed \(killed) orphaned mihomo processes")
            // 同样删了 sleep(0.3)：kill_all_mihomo 内部已等到死透，端口由 waitForPortFree 兜底。
        }
        clearProxySettings()
        // 上次是 TUN（设过系统 DNS=114.114.114.114）→ 重启前恢复 DNS，
        // 否则 TUN→代理 切换（现在走完整重启）后 DNS 会卡在 114。
        if wasTunMode { restoreSystemDns() }

        sendStatus("connecting")
        let myGeneration = connectGeneration

        // 启动 mihomo：TUN 模式需 root（helper fork）；纯代理模式以普通用户运行。
        // 对齐 Clash Verge：TUN 关时不以 root 跑（sidecar 用户态），更安全。
        let onStarted: (Bool, String?) -> Void = { [weak self] success, error in
            guard let self = self else { return }
            guard self.connectGeneration == myGeneration else {
                NSLog("SingboxFlutterPlugin: connect cancelled (generation mismatch)")
                return
            }
            if success {
                self.isConnected = true
                self.isTunMode = isTun
                self.connectionStartTime = Date()
                self.startStatsMonitoring()
                self.switchGlobalToNamedProxy(selectedProxyName)
                self.sendStatus("connected")
                // CV 式：核心永远 root svc，根据 isTun 设置系统 DNS（TUN）或系统代理（非 TUN）。
                // 两边都要做"对侧关闭"，因为现在 hot-reload 时只切换 tun.enable，系统层
                // 状态由我们这里管。
                if isTun {
                    self.setSystemDns("114.114.114.114")
                    self.applyProxySettings(enabled: false)
                    NSLog("SingboxFlutterPlugin: TUN mode active (root svc)")
                } else {
                    self.restoreSystemDns()
                    self.applyProxySettings(enabled: true)
                    NSLog("SingboxFlutterPlugin: proxy mode active (root svc)")
                }
                result(true)
            } else {
                self.sendStatus("error")
                result(FlutterError(code: "START_ERROR", message: error ?? "Failed to start Mihomo", details: nil))
            }
        }

        // ✅ 行业主流（CV / sing-box / Tunnelblick 模式）：mihomo 永远作为 helper 的
        // **child process** 跑（fork+exec via helper "start_tun" 命令），不走 launchctl。
        // 名字叫 startMihomoAsTun 是历史遗留——它实际只是"helper-managed mihomo child"，
        // TUN 与否由 config 里 tun.enable 决定，helper 不关心。
        // 后续切 TUN/模式/节点都走 PUT /configs 热重载（同一 child 不重启），连接不断。
        startMihomoAsTun(configPath: configPath, completion: onStarted)
    }

    // MARK: - Mihomo LaunchDaemon Service Management

    private let mihomoSvcLog = "/tmp/velox_mihomo_svc.log"

    /// 启动 mihomo 作为独立 LaunchDaemon 系统服务。
    /// 首次调用时安装（copy binary + 写 plist + bootstrap），之后直接 kickstart。
    private func startMihomoAsSvc(configPath: String, completion: @escaping (Bool, String?) -> Void) {
        let mihomoSrc = URL(fileURLWithPath: getMihomoPath()).resolvingSymlinksInPath().path
        NSLog("SingboxFlutterPlugin: startMihomoAsSvc binary=\(mihomoSrc)")

        guard FileManager.default.isExecutableFile(atPath: mihomoSrc) else {
            completion(false, "Mihomo not found or not executable at \(mihomoSrc)")
            return
        }

        // 确保 VeloxHelper 已安装（首次时弹一次密码）
        guard ensureHelperAvailable() else {
            completion(false, "请重新输入管理员密码启动！")
            return
        }

        // 安装 mihomo LaunchDaemon（首次安装、binary 更新或 geo 数据库缺失时安装）
        // 若 plist+binary+两个 geo 数据库都已就位则跳过，直接 kickstart（加速连接）
        let svcPlistPath = "/Library/LaunchDaemons/com.velox.app.mihomo.plist"
        let svcBinPath   = "/Library/Application Support/Velox/mihomo"
        let geoipPath    = "/Library/Application Support/Velox/geoip.metadb"
        let geositePath  = "/Library/Application Support/Velox/geosite.dat"
        let alreadyInstalled = FileManager.default.fileExists(atPath: svcPlistPath)
                            && FileManager.default.isExecutableFile(atPath: svcBinPath)
                            && FileManager.default.fileExists(atPath: geoipPath)
                            && FileManager.default.fileExists(atPath: geositePath)

        // App bundle 内 geo 数据库的路径（flutter_assets/assets/geo/*）。
        // 这俩文件由 pubspec.yaml 的 assets:[assets/geo/] 在 build 时打入 App.framework。
        let flutterAssets = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Frameworks/App.framework/Resources/flutter_assets")
        let geoipSrc   = flutterAssets.appendingPathComponent("assets/geo/geoip.metadb").path
        let geositeSrc = flutterAssets.appendingPathComponent("assets/geo/geosite.dat").path

        if !alreadyInstalled {
            var installCmd: [String: Any] = [
                "cmd": "install_mihomo_svc",
                "binary": mihomoSrc
            ]
            if FileManager.default.fileExists(atPath: geoipSrc) {
                installCmd["geoip"] = geoipSrc
            } else {
                NSLog("SingboxFlutterPlugin: bundled geoip.metadb not found at \(geoipSrc)")
            }
            if FileManager.default.fileExists(atPath: geositeSrc) {
                installCmd["geosite"] = geositeSrc
            } else {
                NSLog("SingboxFlutterPlugin: bundled geosite.dat not found at \(geositeSrc)")
            }
            let installResp = sendHelperCommand(installCmd, timeoutSec: 20)
            guard installResp?["ok"] as? Bool == true else {
                let err = installResp?["error"] as? String ?? "install_mihomo_svc failed"
                NSLog("SingboxFlutterPlugin: startMihomoAsSvc install failed: \(err)")
                completion(false, err)
                return
            }
            NSLog("SingboxFlutterPlugin: startMihomoAsSvc: service installed (with geo databases)")
        } else {
            NSLog("SingboxFlutterPlugin: startMihomoAsSvc: service already installed, skipping install")
        }

        // plist 的 KeepAlive 会在 bootstrap 后【自动拉起】mihomo；start_mihomo_svc
        // (kickstart -k) 只是确保用最新配置重启。⚠️ launchd 对同一服务的重启有 ~10s
        // 节流：KeepAlive 刚自动启动后立即 kickstart 会返回非零，但此时 mihomo 其实已经
        // 在跑——所以 kickstart 返回码不可靠，best-effort 即可，以 Clash API 就绪为唯一判据。
        let startCmd: [String: Any] = ["cmd": "start_mihomo_svc"]
        _ = sendHelperCommand(startCmd, timeoutSec: 8)

        DispatchQueue.global().async { [weak self] in
            guard let self = self else { return }
            // 第一次等 API 就绪（KeepAlive bootstrap 已应启动 mihomo）
            if self.waitClashApiReady(seconds: 8.0) {
                NSLog("SingboxFlutterPlugin: startMihomoAsSvc: API ready")
                DispatchQueue.main.async {
                    self.startLogTailing(path: self.mihomoSvcLog)
                    completion(true, nil)
                }
                return
            }
            // API 没起来 → 重装一次（覆盖"plist 在但未 bootstrap / 损坏"），再 kickstart 再等
            NSLog("SingboxFlutterPlugin: startMihomoAsSvc: API not ready, reinstalling once...")
            var reinstallCmd: [String: Any] = ["cmd": "install_mihomo_svc", "binary": mihomoSrc]
            if FileManager.default.fileExists(atPath: geoipSrc) { reinstallCmd["geoip"] = geoipSrc }
            if FileManager.default.fileExists(atPath: geositeSrc) { reinstallCmd["geosite"] = geositeSrc }
            _ = self.sendHelperCommand(reinstallCmd, timeoutSec: 20)
            _ = self.sendHelperCommand(startCmd, timeoutSec: 8)
            let ok = self.waitClashApiReady(seconds: 8.0)
            let logContent = (try? String(contentsOfFile: self.mihomoSvcLog, encoding: .utf8)) ?? ""
            NSLog("SingboxFlutterPlugin: startMihomoAsSvc apiReady(after reinstall)=\(ok)")
            DispatchQueue.main.async {
                if ok {
                    self.startLogTailing(path: self.mihomoSvcLog)
                    completion(true, nil)
                } else {
                    completion(false, logContent.isEmpty ? "Mihomo 服务未能启动" : logContent)
                }
            }
        }
    }

    /// 同步检查 Clash API 是否就绪（GET /version → 200）。在后台线程调用。
    private func isClashApiReady() -> Bool {
        guard let url = URL(string: "http://127.0.0.1:\(clashApiPort)/version") else { return false }
        var request = URLRequest(url: url)
        request.timeoutInterval = 1
        var ready = false
        let sem = DispatchSemaphore(value: 0)
        URLSession.shared.dataTask(with: request) { _, response, _ in
            ready = (response as? HTTPURLResponse)?.statusCode == 200
            sem.signal()
        }.resume()
        sem.wait()
        return ready
    }

    /// 轮询等 Clash API 就绪（每 100ms 一次，最多 [seconds] 秒）。在后台线程调用。
    /// 用来替代"硬 sleep 等 mihomo 启动"——通常 200-400ms 就 ready，省下 1.5s。
    @discardableResult
    private func waitClashApiReady(seconds: Double) -> Bool {
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            if isClashApiReady() { return true }
            Thread.sleep(forTimeInterval: 0.1)
        }
        return false
    }

    private func disconnect(result: @escaping FlutterResult) {
        sendStatus("disconnecting")
        stopStatsMonitoring()
        // 递增代次：让正在进行的 startMihomo completion 感知到已取消
        connectGeneration += 1
        // 先标记为已断开，避免 terminationHandler 触发 "Connection terminated unexpectedly" 误报
        isConnected = false
        let wasTun = isTunMode
        isTunMode = false
        connectionStartTime = nil
        DispatchQueue.global().async { [weak self] in
            guard let self = self else { return }
            if wasTun {
                // TUN 断开：恢复系统 DNS（清除 114.114.114.114 强制设置）
                self.restoreSystemDns()
            } else {
                self.clearProxySettings()
            }
            self.markSystemDirty(false)  // 干净断开，系统状态已还原
            self.stopMihomo()
            DispatchQueue.main.async {
                self.resetStats()
                self.sendStatus("disconnected")
                result(true)
            }
        }
    }

    private func getStats(result: @escaping FlutterResult) {
        let connectionTime: Int
        if let startTime = connectionStartTime {
            connectionTime = Int(Date().timeIntervalSince(startTime))
        } else {
            connectionTime = 0
        }
        result([
            "uploadSpeed":    Int(totalUpload - lastUpload),
            "downloadSpeed":  Int(totalDownload - lastDownload),
            "totalUpload":    Int(totalUpload),
            "totalDownload":  Int(totalDownload),
            "connectionTime": connectionTime
        ])
    }

    private func getVersion() -> String {
        let task = Process()
        let mihomoPath = URL(fileURLWithPath: getMihomoPath()).resolvingSymlinksInPath().path
        task.executableURL = URL(fileURLWithPath: mihomoPath)
        task.arguments = ["-v"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8),
               let line = output.components(separatedBy: "\n").first {
                return line.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        } catch { }
        return "unknown"
    }

    // MARK: - Mihomo Process Management

    /// YAML config contains "tun:\n  enable: true" for TUN mode.
    private func configIsTun(_ config: String) -> Bool {
        // Simple line-based check: look for "tun:" section with "enable: true"
        let lines = config.components(separatedBy: "\n")
        var inTunSection = false
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("tun:") {
                inTunSection = true
                continue
            }
            if inTunSection {
                // Exit section if we hit another top-level key
                if !line.hasPrefix(" ") && !line.hasPrefix("\t") && !trimmed.isEmpty {
                    inTunSection = false
                    continue
                }
                if trimmed == "enable: true" { return true }
            }
        }
        return false
    }

    private func startMihomo(configPath: String, useTun: Bool, completion: @escaping (Bool, String?) -> Void) {
        if useTun {
            startMihomoAsTun(configPath: configPath, completion: completion)
        } else {
            startMihomoAsProcess(configPath: configPath, completion: completion)
        }
    }

    /// TUN 模式：通过 helper 以 root 身份运行（首次安装时弹一次密码，之后免密）
    private func startMihomoAsTun(configPath: String, completion: @escaping (Bool, String?) -> Void) {
        let mihomoPath = URL(fileURLWithPath: getMihomoPath()).resolvingSymlinksInPath().path
        NSLog("SingboxFlutterPlugin: startMihomoAsTun path=\(mihomoPath)")

        guard FileManager.default.isExecutableFile(atPath: mihomoPath) else {
            completion(false, "Mihomo not found or not executable at \(mihomoPath)")
            return
        }

        // 确保 helper 已安装（首次时弹一次密码）
        guard ensureHelperAvailable() else {
            completion(false, "请重新输入管理员密码启动！")
            return
        }

        // 清理上一次遗留的 PID 文件
        try? FileManager.default.removeItem(atPath: tunPidFile)

        // Mihomo working directory for TUN mode
        let workDir = getMihomoWorkDir()

        var cmd: [String: Any] = [
            "cmd":      "start_tun",
            "singbox":  mihomoPath,   // helper key: path to mihomo binary
            "config":   configPath,   // -f <config>
            "workdir":  workDir,      // -d <workdir>  (GeoSite/GeoIP database directory)
            "pid_file": tunPidFile,
            "log_file": tunLogFile,
        ]
        // 把内置 geo 数据库路径传给 helper（root），由它拷进 workDir，
        // 让 TUN 规则模式的 GEOSITE/GEOIP 分流可用（不依赖 GitHub 下载）。
        let flutterAssets = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Frameworks/App.framework/Resources/flutter_assets")
        let geoipSrc   = flutterAssets.appendingPathComponent("assets/geo/geoip.metadb").path
        let geositeSrc = flutterAssets.appendingPathComponent("assets/geo/geosite.dat").path
        if FileManager.default.fileExists(atPath: geoipSrc)   { cmd["geoip"]   = geoipSrc }
        if FileManager.default.fileExists(atPath: geositeSrc) { cmd["geosite"] = geositeSrc }

        let tunResp = sendHelperCommand(cmd)
        guard tunResp?["ok"] as? Bool == true else {
            let err = tunResp?["error"] as? String ?? "helper start_tun failed"
            completion(false, err)
            return
        }

        // 等待 Mihomo 进程启动（轮询 PID 文件，最多 5 秒）
        DispatchQueue.global().async { [weak self] in
            guard let self = self else { return }
            var pid: Int32 = -1
            let deadline = Date().addingTimeInterval(5)
            while Date() < deadline {
                if let pidStr = try? String(contentsOfFile: self.tunPidFile, encoding: .utf8),
                   let p = Int32(pidStr.trimmingCharacters(in: .whitespacesAndNewlines)), p > 0 {
                    pid = p
                    break
                }
                Thread.sleep(forTimeInterval: 0.2)
            }

            guard pid > 0 else {
                let log = (try? String(contentsOfFile: self.tunLogFile, encoding: .utf8)) ?? "Unknown error"
                NSLog("SingboxFlutterPlugin: TUN start timeout. log=\(log)")
                DispatchQueue.main.async { completion(false, log) }
                return
            }

            // 确认进程存活
            var alive = false
            let aliveDeadline = Date().addingTimeInterval(3.0)
            while Date() < aliveDeadline {
                let psCheck = self.runCommand("/bin/ps", arguments: ["-p", "\(pid)", "-o", "pid="])
                if psCheck.status == 0 && !psCheck.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    alive = true
                    break
                }
                Thread.sleep(forTimeInterval: 0.3)
            }

            let logContent = (try? String(contentsOfFile: self.tunLogFile, encoding: .utf8)) ?? ""
            NSLog("SingboxFlutterPlugin: TUN PID=\(pid) alive=\(alive)")

            if alive {
                self.tunPid = pid
                // 开始实时输出日志到 Xcode / Console.app（测试阶段）
                self.startLogTailing(path: self.tunLogFile)
                DispatchQueue.main.async { completion(true, nil) }
            } else {
                let summary = logContent.isEmpty ? "Mihomo 进程未能启动" : logContent
                NSLog("SingboxFlutterPlugin: TUN start failed. summary=\(summary.prefix(200))")
                DispatchQueue.main.async { completion(false, summary) }
            }
        }
    }

    /// 系统代理模式：以普通用户运行 Mihomo（不需要 root）
    private func startMihomoAsProcess(configPath: String, completion: @escaping (Bool, String?) -> Void) {
        let mihomoPath = URL(fileURLWithPath: getMihomoPath()).resolvingSymlinksInPath().path
        NSLog("SingboxFlutterPlugin: startMihomoAsProcess path=\(mihomoPath)")

        guard FileManager.default.isExecutableFile(atPath: mihomoPath) else {
            completion(false, "Mihomo not found or not executable at \(mihomoPath)")
            return
        }

        // Mihomo 工作目录（非 TUN 子进程）：必须用户可写，且启动前注入内置 geo 数据库。
        // 不能用 root 拥有的 /Library/Application Support/Velox —— 普通用户进程写不进去，
        // 缺 geo 时 mihomo 无法落盘/下载 → 规则模式 GEOSITE/GEOIP 分流失效。
        let workDir = getUserWorkDir()
        provisionGeoFiles(to: workDir)
        NSLog("SingboxFlutterPlugin: mihomo workDir=\(workDir)")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: mihomoPath)
        // -f <config.yaml>  -d <workdir>
        process.arguments = ["-f", configPath, "-d", workDir]
        // SAFE_PATHS=/tmp：mihomo 的 PUT /configs 热重载只允许加载 HOME 或 SAFE_PATHS
        // 下的配置；我们的 config 写在 /tmp/velox_mihomo.yaml。不设的话用户态热重载会
        // 400 失败 → 切 规则↔全局 退化成完整重启（不丝滑）。root/TUN 路径由 helper
        // 设了同样的 SAFE_PATHS，这里给用户态进程补上。
        var env = ProcessInfo.processInfo.environment
        env["SAFE_PATHS"] = "/tmp"
        process.environment = env
        process.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async { self?.handleUnexpectedTermination() }
        }

        // Pipe stderr → 实时 NSLog（测试阶段），失败时错误已通过 NSLog 可见
        let stderrPipe = Pipe()
        process.standardError = stderrPipe
        startPipeLogTailing(pipe: stderrPipe)

        do {
            try process.run()
            mihomoProcess = process
        } catch {
            completion(false, error.localizedDescription)
            return
        }

        // 起来就轮询 Clash API（通常 200-400ms 就 ready），不硬 sleep 2s。
        DispatchQueue.global().async { [weak self] in
            guard let self = self else { return }
            let ready = self.waitClashApiReady(seconds: 3.0)
            if ready && process.isRunning {
                NSLog("SingboxFlutterPlugin: Mihomo (proxy mode) ready, PID=\(process.processIdentifier)")
                DispatchQueue.main.async { completion(true, nil) }
            } else {
                NSLog("SingboxFlutterPlugin: Mihomo (proxy mode) failed: apiReady=\(ready), running=\(process.isRunning) — killing to prevent orphan")
                // 关键：失败时必须杀掉刚启动的进程，不然它会留下占 19090 端口的孤儿，
                // 下次启动新核心就会重复同样的 bind 错误。
                if process.isRunning {
                    process.terminate()
                    let deadline = Date().addingTimeInterval(1)
                    while process.isRunning && Date() < deadline {
                        Thread.sleep(forTimeInterval: 0.05)
                    }
                    if process.isRunning {
                        kill(process.processIdentifier, SIGKILL)
                    }
                }
                self.mihomoProcess = nil
                // 兜底：扫一遍所有 velox_mihomo（含 root），保证下次启动干净
                _ = self.sendHelperCommand(["cmd": "kill_all_mihomo"])
                DispatchQueue.main.async { completion(false, "Mihomo 启动失败，请查看控制台 [Mihomo] 日志") }
            }
        }
    }

    // MARK: - 日志实时输出（测试阶段）

    /// 开始实时读取 mihomo 日志文件，每行通过 NSLog 输出到 Xcode / Console.app。
    /// 采用 DispatchSourceRead 监听文件描述符，比轮询更高效。
    private func startLogTailing(path: String) {
        stopLogTailing()
        // 等文件出现（TUN 模式日志文件由 root 进程创建，可能有短暂延迟）
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            let fd = open(path, O_RDONLY | O_NONBLOCK)
            guard fd >= 0 else {
                NSLog("[VeloxLog] 无法打开日志文件: \(path)")
                return
            }
            // Seek to end：只看本次连接产生的新日志
            lseek(fd, 0, SEEK_END)
            let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
            self.logTailHandle = handle
            var lineBuffer = ""
            let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: .global())
            source.setEventHandler {
                let data = handle.availableData
                guard !data.isEmpty, let chunk = String(data: data, encoding: .utf8) else { return }
                lineBuffer += chunk
                while let nl = lineBuffer.firstIndex(of: "\n") {
                    let line = String(lineBuffer[lineBuffer.startIndex..<nl])
                    if !line.trimmingCharacters(in: .whitespaces).isEmpty {
                        NSLog("[Mihomo] %@", line)
                    }
                    lineBuffer = String(lineBuffer[lineBuffer.index(after: nl)...])
                }
            }
            source.setCancelHandler {
                close(fd)
            }
            self.logTailSource = source
            source.resume()
            NSLog("[VeloxLog] 开始实时监听日志: \(path)")
        }
    }

    /// 实时输出 Pipe（代理模式 stderr）到 NSLog。
    /// Pipe 的 read 端用 DispatchSourceRead 监听，每行一条 NSLog。
    private func startPipeLogTailing(pipe: Pipe) {
        stopLogTailing()
        let fd = pipe.fileHandleForReading.fileDescriptor
        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: .global())
        var lineBuffer = ""
        source.setEventHandler {
            let data = pipe.fileHandleForReading.availableData
            guard !data.isEmpty, let chunk = String(data: data, encoding: .utf8) else { return }
            lineBuffer += chunk
            while let nl = lineBuffer.firstIndex(of: "\n") {
                let line = String(lineBuffer[lineBuffer.startIndex..<nl])
                if !line.trimmingCharacters(in: .whitespaces).isEmpty {
                    NSLog("[Mihomo] %@", line)
                }
                lineBuffer = String(lineBuffer[lineBuffer.index(after: nl)...])
            }
        }
        logTailSource = source
        source.resume()
        NSLog("[VeloxLog] 开始实时监听 stderr pipe")
    }

    /// 停止日志实时输出。
    private func stopLogTailing() {
        logTailSource?.cancel()
        logTailSource = nil
        logTailHandle = nil
    }

    // MARK: - TUN 热重载（不重启进程）

    /// TUN 模式热重载：写入新配置 → PUT /configs?force=true → 处理 DNS/系统代理。
    /// 成功返回 true；失败返回 false（调用方回退到完整重连）。
    ///
    /// 性能关键点：
    /// - 整个流程不能阻塞主线程
    /// - 接受任何 2xx 响应为成功（不只是 204）
    /// - 失败时日志里打印 response body 以便定位
    /// - DNS/proxy 设置在后台线程跑（networksetup 子进程耗时 0.2-1s）
    /// - 用户看到的"连接成功"不等待后台的 DNS/proxy 设置，立刻返回 result(true)
    private func patchTunMode(config: String, enabled: Bool,
                               selectedProxyName: String, result: @escaping FlutterResult) {
        let configPath = getConfigFilePath()
        do {
            try config.write(toFile: configPath, atomically: true, encoding: .utf8)
            // 备份 TUN 配置供调试（每次 enabled=true 时覆盖）
            if enabled {
                try? config.write(toFile: "/tmp/velox_mihomo_last_tun.yaml", atomically: true, encoding: .utf8)
            }
        } catch {
            vlog("patchTunMode write config FAILED: \(error)")
            result(false)
            return
        }

        guard let url = URL(string: "http://127.0.0.1:\(clashApiPort)/configs?force=true") else {
            result(false)
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = "{\"path\":\"\(configPath)\"}".data(using: .utf8)
        request.timeoutInterval = 5

        vlog(">>> patchTunMode PUT /configs?force=true enabled=\(enabled) configSize=\(config.count)")
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            let http = response as? HTTPURLResponse
            let status = http?.statusCode ?? -1
            let ok = status >= 200 && status < 300 && error == nil

            if !ok {
                let body = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                self.vlog("<<< patchTunMode FAILED status=\(status) error=\(error?.localizedDescription ?? "nil") body=\(body.prefix(300))")
                DispatchQueue.main.async { result(false) }
                return
            }

            self.vlog("<<< patchTunMode SUCCESS status=\(status)")

            // 热重载后选择器被重置，重新切换到正确节点（异步，不阻塞）
            self.switchGlobalToNamedProxy(selectedProxyName)
            // 清掉旧连接，让 TUN 下切 规则↔全局 对已有 keep-alive 连接也立即生效
            self.flushAllConnections()

            // 立刻更新内部状态并返回 result(true) —— UI 马上显示"已连接"
            // DNS / 系统代理的修改放到后台跑（networksetup 子进程耗时会阻塞主线程）
            DispatchQueue.main.async {
                self.isTunMode = enabled
                result(true)
            }

            // 后台异步处理 DNS 和系统代理（不影响 UI 响应）
            DispatchQueue.global(qos: .userInitiated).async {
                if enabled {
                    self.setSystemDns("114.114.114.114")
                    self.applyProxySettings(enabled: false)
                    NSLog("SingboxFlutterPlugin: TUN mode on via hot-patch (DNS/proxy updated in bg)")
                } else {
                    self.restoreSystemDns()
                    self.applyProxySettings(enabled: true)
                    NSLog("SingboxFlutterPlugin: proxy mode on via hot-patch (DNS/proxy updated in bg)")
                }
            }
        }.resume()
    }

    // MARK: - DNS 管理（TUN 模式防 DNS 泄漏）

    /// TUN 启用时将系统 DNS 设为指定服务器（防止 DNS 绕过 fake-ip 泄漏）。
    private func setSystemDns(_ server: String) {
        markSystemDirty(true)
        NSLog("SingboxFlutterPlugin: setSystemDns \(server)")
        let interfaces = getActiveNetworkInterfaces()
        for iface in interfaces {
            let r = runCommand("/usr/sbin/networksetup",
                               arguments: ["-setdnsservers", iface, server])
            NSLog("SingboxFlutterPlugin: setdnsservers '\(iface)' → status=\(r.status)")
        }
    }

    /// TUN 禁用时恢复系统 DNS（清除强制设置，还原为 DHCP 自动获取）。
    private func restoreSystemDns() {
        NSLog("SingboxFlutterPlugin: restoreSystemDns")
        let interfaces = getActiveNetworkInterfaces()
        for iface in interfaces {
            let r = runCommand("/usr/sbin/networksetup",
                               arguments: ["-setdnsservers", iface, "Empty"])
            NSLog("SingboxFlutterPlugin: setdnsservers '\(iface)' Empty → status=\(r.status)")
        }
    }

    /// 获取当前活跃的网络接口列表（Wi-Fi、Ethernet 等）。
    private func getActiveNetworkInterfaces() -> [String] {
        let output = runCommand("/usr/sbin/networksetup", arguments: ["-listallnetworkservices"])
        guard output.status == 0 else { return ["Wi-Fi", "Ethernet"] }
        return output.stdout
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("*") && !$0.hasPrefix("An") }
    }

    private func stopMihomo() {
        stopLogTailing()
        // ✅ 行业主流：mihomo 是 helper 的 child process，stop_tun 命令做 SIGTERM+wait+SIGKILL
        // 兜底。helper 同步等子进程死透才返回，所以这里调完即可。
        if tunPid > 0 {
            NSLog("SingboxFlutterPlugin: stopMihomo: stop_tun tunPid=\(tunPid)")
            _ = sendHelperCommand(["cmd": "stop_tun", "pid": Int(tunPid)])
            tunPid = -1
        }
        // 兜底：清理用户态 Process 遗留（旧代码路径，理论上现在不会进来）
        if let process = mihomoProcess {
            if process.isRunning { process.terminate() }
            let deadline = Date().addingTimeInterval(2)
            while process.isRunning && Date() < deadline { Thread.sleep(forTimeInterval: 0.1) }
            if process.isRunning { kill(process.processIdentifier, SIGKILL) }
            mihomoProcess = nil
        }
    }

    private func handleUnexpectedTermination() {
        if isConnected {
            isConnected = false
            tunPid = -1
            stopStatsMonitoring()
            sendStatus("disconnected")
            sendError("Connection terminated unexpectedly")
        }
    }

    // MARK: - Clash API: 切换 GLOBAL 选择器

    /// 向指定 proxy group（GLOBAL 或 PROXY）发送切换请求。
    /// 内部辅助方法，fire-and-forget。
    private func putProxyGroup(_ group: String, name: String) {
        let safeName = name.replacingOccurrences(of: "\"", with: "\\\"")
        guard let url = URL(string: "http://127.0.0.1:\(clashApiPort)/proxies/\(group)") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = "{\"name\":\"\(safeName)\"}".data(using: .utf8)
        request.timeoutInterval = 3
        URLSession.shared.dataTask(with: request) { _, response, _ in
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            NSLog("SingboxFlutterPlugin: PUT /proxies/\(group) '\(name)' → \(code)")
        }.resume()
    }

    /// 连接/热重载后将正确节点同时设置到 GLOBAL 和 PROXY group。
    ///
    /// 为什么要同时设置两个：
    ///   mode: global → GLOBAL selector 控制所有流量，PROXY group 无效
    ///   mode: rule   → rules 里 MATCH,PROXY 走 PROXY group，GLOBAL 无效
    /// 同时设置两个，无论当前模式均正确工作，不需要知道 clashMode。
    ///
    /// 性能关键：API 就绪后立即切换（不再写死 1.5s 延迟）：
    ///   - 冷启动：轮询 /version，mihomo API 一就绪就切换（通常 200-500ms）
    ///   - 热重载：API 本来就在 listen，首次轮询即命中 → 立即切换
    private func switchGlobalToNamedProxy(_ proxyName: String) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            // 轮询 API 就绪（最多 3 秒），热重载场景下第一次就命中
            let deadline = Date().addingTimeInterval(3)
            var ready = false
            while Date() < deadline {
                if self.isClashApiReady() {
                    ready = true
                    break
                }
                Thread.sleep(forTimeInterval: 0.1)
            }
            if !ready {
                NSLog("SingboxFlutterPlugin: switchGlobalToNamedProxy: API not ready after 3s, firing anyway")
            }
            self.putProxyGroup("GLOBAL", name: proxyName)
            self.putProxyGroup("PROXY",  name: proxyName)
        }
    }

    /// 通过 Clash API 零停顿切换节点（由 Flutter switchProxy MethodChannel 调用）。
    ///
    /// 同时切换 GLOBAL selector 和 PROXY group：
    ///   • mode: global → GLOBAL 生效
    ///   • mode: rule   → PROXY group 生效
    /// 任一返回 204 即视为成功。
    private func switchProxyByName(name: String, result: @escaping FlutterResult) {
        let groups = ["GLOBAL", "PROXY"]
        let safeName = name.replacingOccurrences(of: "\"", with: "\\\"")
        let lock = NSLock()
        var doneCount = 0
        var anySuccess = false

        for group in groups {
            guard let url = URL(string: "http://127.0.0.1:\(clashApiPort)/proxies/\(group)") else {
                lock.lock(); doneCount += 1; lock.unlock()
                if doneCount == groups.count {
                    DispatchQueue.main.async { result(anySuccess) }
                }
                continue
            }
            var req = URLRequest(url: url)
            req.httpMethod = "PUT"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = "{\"name\":\"\(safeName)\"}".data(using: .utf8)
            req.timeoutInterval = 3

            URLSession.shared.dataTask(with: req) { data, response, error in
                let status = (response as? HTTPURLResponse)?.statusCode ?? -1
                // 接受任何 2xx（mihomo 实际返回 204 No Content）
                let ok = status >= 200 && status < 300 && error == nil
                if ok {
                    NSLog("SingboxFlutterPlugin: switchProxy /proxies/\(group) '\(name)' → OK (\(status))")
                } else {
                    let body = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                    NSLog("SingboxFlutterPlugin: switchProxy /proxies/\(group) '\(name)' → FAIL status=\(status) error=\(error?.localizedDescription ?? "nil") body=\(body.prefix(200))")
                }
                lock.lock()
                if ok { anySuccess = true }
                doneCount += 1
                let allDone = doneCount == groups.count
                let success = anySuccess
                lock.unlock()
                if allDone {
                    if success {
                        // 关闭所有存活的代理隧道，强制流量通过新节点重建连接
                        // 否则旧连接池（HK→SG切换时）会继续走旧节点，IP 不会立刻变
                        self.closeAllConnections()
                    }
                    DispatchQueue.main.async { result(success) }
                }
            }.resume()
        }
    }

    /// 关闭 Mihomo 所有存活的代理连接（DELETE /connections）。
    /// 切换节点后调用，迫使所有流量通过新节点重建，IP 立即生效。
    private func closeAllConnections() {
        guard let url = URL(string: "http://127.0.0.1:\(clashApiPort)/connections") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.timeoutInterval = 3
        URLSession.shared.dataTask(with: request) { _, response, _ in
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            NSLog("SingboxFlutterPlugin: DELETE /connections → \(code)")
        }.resume()
    }

    // MARK: - System Proxy (via networksetup — no root required)

    /// 获取所有活跃网络服务名（用于 networksetup 命令）
    private func getNetworkServices() -> [String] {
        let result = runCommand("/usr/sbin/networksetup", arguments: ["-listallnetworkservices"])
        return result.stdout
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("An asterisk") && !$0.hasPrefix("*") }
            .dropFirst() // 第一行是提示文字
            .map { String($0) }
    }

    /// 标记"已修改系统状态（代理/DNS）"。崩溃/强退后下次启动据此判断是否需要清理。
    /// 只在干净退出路径（disconnect / cleanupOnExit）里清成 false；任何系统改动都置 true。
    private let systemDirtyKey = "velox_system_dirty"
    private func markSystemDirty(_ dirty: Bool) {
        UserDefaults.standard.set(dirty, forKey: systemDirtyKey)
    }

    /// 开启或关闭系统代理（HTTP + HTTPS + SOCKS5），使用 networksetup 直接设置，无需 root。
    private func applyProxySettings(enabled: Bool) {
        if enabled { markSystemDirty(true) }
        // 优先通过 Helper（SCPreferences）设置，但仅当 helper 版本匹配时才用：
        // 旧版 helper 的 set_proxy 不含 bypass 例外列表，此时应跳过它、退回
        // networksetup 兜底（无需 root，且同样写入 bypass）。否则升级用户在纯代理
        // 模式下会被残留的旧 helper 拦截，bypass 失效。
        let helperCmd: [String: Any] = enabled
            ? ["cmd": "set_proxy", "port": proxyPort]
            : ["cmd": "clear_proxy"]
        if isHelperAvailable(),
           let resp = sendHelperCommand(helperCmd), resp["ok"] as? Bool == true {
            NSLog("SingboxFlutterPlugin: proxy \(enabled ? "enabled" : "disabled") via helper (v\(requiredHelperVersion))")
            return
        }

        // Fallback：直接调用 networksetup（不需要 root，ClashX 也是这样做的）
        let services = getNetworkServices()
        NSLog("SingboxFlutterPlugin: applying proxy via networksetup, services=\(services), enabled=\(enabled)")
        for service in services {
            if enabled {
                _ = runCommand("/usr/sbin/networksetup", arguments: ["-setwebproxy", service, "127.0.0.1", "\(proxyPort)"])
                _ = runCommand("/usr/sbin/networksetup", arguments: ["-setsecurewebproxy", service, "127.0.0.1", "\(proxyPort)"])
                _ = runCommand("/usr/sbin/networksetup", arguments: ["-setsocksfirewallproxy", service, "127.0.0.1", "\(proxyPort)"])
                // LAN / 回环 / 链路本地 / 本地域名 直连例外（对标 Clash Verge / ClashX）
                _ = runCommand("/usr/sbin/networksetup", arguments: [
                    "-setproxybypassdomains", service,
                    "127.0.0.1", "192.168.0.0/16", "10.0.0.0/8", "172.16.0.0/12",
                    "169.254.0.0/16", "localhost", "*.local",
                ])
                _ = runCommand("/usr/sbin/networksetup", arguments: ["-setwebproxystate", service, "on"])
                _ = runCommand("/usr/sbin/networksetup", arguments: ["-setsecurewebproxystate", service, "on"])
                _ = runCommand("/usr/sbin/networksetup", arguments: ["-setsocksfirewallproxystate", service, "on"])
                NSLog("SingboxFlutterPlugin: proxy set on service '\(service)' → 127.0.0.1:\(proxyPort)")
            } else {
                _ = runCommand("/usr/sbin/networksetup", arguments: ["-setwebproxystate", service, "off"])
                _ = runCommand("/usr/sbin/networksetup", arguments: ["-setsecurewebproxystate", service, "off"])
                _ = runCommand("/usr/sbin/networksetup", arguments: ["-setsocksfirewallproxystate", service, "off"])
                NSLog("SingboxFlutterPlugin: proxy cleared on service '\(service)'")
            }
        }
    }

    private func clearProxySettings() {
        applyProxySettings(enabled: false)
    }

    // MARK: - Privileged Helper IPC

    /// 当前 app 要求的 helper 版本号。与 VeloxHelper.c 里 version 命令的返回值一致。
    /// 每次新增 helper 命令时必须同步递增。
    private let requiredHelperVersion = "10"

    /// 检查 helper 是否已安装、可达且版本匹配。
    /// 返回 false 时 ensureHelperAvailable 会触发重新安装（更新旧版本）。
    private func isHelperAvailable() -> Bool {
        guard FileManager.default.fileExists(atPath: helperInstalledAt),
              FileManager.default.fileExists(atPath: helperPlistAt) else { return false }
        // 先 ping 确认进程存活
        guard let pingResp = sendHelperCommand(["cmd": "ping"]),
              pingResp["ok"] as? Bool == true else { return false }
        // 再查版本：旧 helper 不认识 version 命令会返回 error → 触发重装
        guard let verResp = sendHelperCommand(["cmd": "version"]),
              verResp["ok"] as? Bool == true,
              verResp["version"] as? String == requiredHelperVersion else {
            NSLog("SingboxFlutterPlugin: helper version mismatch, will reinstall")
            return false
        }
        return true
    }

    /// 确保 helper 可用且版本正确。首次安装或版本不匹配时弹一次密码授权。
    @discardableResult
    private func ensureHelperAvailable() -> Bool {
        if isHelperAvailable() {
            NSLog("SingboxFlutterPlugin: helper already available (v\(requiredHelperVersion))")
            return true
        }
        NSLog("SingboxFlutterPlugin: helper not found or outdated, installing…")
        return installHelper()
    }

    /// 安装 helper（仅需授权一次）
    private func installHelper() -> Bool {
        guard let resourcePath = Bundle.main.resourcePath else {
            NSLog("SingboxFlutterPlugin: can't find Bundle.main.resourcePath")
            return false
        }

        let helperSrc  = "\(resourcePath)/com.velox.app.helper"
        let plistSrc   = "\(resourcePath)/com.velox.app.helper.plist"
        let scriptSrc  = "\(resourcePath)/install_helper.sh"

        guard FileManager.default.isExecutableFile(atPath: helperSrc) else {
            NSLog("SingboxFlutterPlugin: bundled helper not found at \(helperSrc)")
            return false
        }
        guard FileManager.default.fileExists(atPath: plistSrc) else {
            NSLog("SingboxFlutterPlugin: bundled plist not found at \(plistSrc)")
            return false
        }
        guard FileManager.default.isExecutableFile(atPath: scriptSrc) else {
            NSLog("SingboxFlutterPlugin: install script not found at \(scriptSrc)")
            return false
        }

        // 申请管理员授权（只弹一次）
        guard let auth = acquireAuthorization() else {
            NSLog("SingboxFlutterPlugin: authorization cancelled by user")
            return false
        }

        let status = runAsRoot(tool: scriptSrc,
                               args: [helperSrc, plistSrc],
                               auth: auth)
        guard status == errAuthorizationSuccess else {
            NSLog("SingboxFlutterPlugin: install_helper.sh failed, status=\(status)")
            return false
        }

        // 等待 launchd 启动 helper
        for _ in 0..<20 {
            Thread.sleep(forTimeInterval: 0.25)
            if let resp = sendHelperCommand(["cmd": "ping"]),
               resp["ok"] as? Bool == true {
                NSLog("SingboxFlutterPlugin: helper installed and running")
                return true
            }
        }

        NSLog("SingboxFlutterPlugin: helper installed but not responding in time")
        return false
    }

    /// 卸载 helper（用于应用卸载场景）
    @discardableResult
    private func uninstallHelper() -> Bool {
        guard let resourcePath = Bundle.main.resourcePath else { return false }
        let scriptSrc = "\(resourcePath)/uninstall_helper.sh"
        guard FileManager.default.isExecutableFile(atPath: scriptSrc) else { return false }
        guard let auth = acquireAuthorization() else { return false }
        let status = runAsRoot(tool: scriptSrc, args: [], auth: auth)
        return status == errAuthorizationSuccess
    }

    /// 通过 Unix socket 向 helper 发送 JSON 命令，返回解析后的响应
    /// 通过 Unix socket 向 helper 发命令。
    /// `timeoutSec` 默认 2s 够快命令用；install_mihomo_svc 这类含 launchctl bootout
    /// 轮询(最多 3s)+800ms+bootstrap 的慢命令必须传更长超时（建议 20s），否则
    /// Swift 端 recv 提前超时收到 nil → 误判失败，可服务端其实已经成功。
    private func sendHelperCommand(_ command: [String: Any], timeoutSec: Int = 2) -> [String: Any]? {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: command, options: .withoutEscapingSlashes),
              let jsonStr = String(data: jsonData, encoding: .utf8) else { return nil }

        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return nil }
        defer { Darwin.close(fd) }

        var tv = timeval(tv_sec: timeoutSec, tv_usec: 0)
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
        setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))

        // 连接 Unix socket
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        addr.sun_len    = UInt8(MemoryLayout<sockaddr_un>.size)
        // 将 socket 路径写入 sun_path（UnsafeMutableBytes 避免 Swift 独占访问错误）
        let pathBytes = [UInt8](helperSocketPath.utf8) + [0]
        withUnsafeMutableBytes(of: &addr.sun_path) { sunPathBytes in
            sunPathBytes.copyBytes(from: pathBytes.prefix(sunPathBytes.count))
        }

        let connectRC = withUnsafePointer(to: addr) { addrPtr in
            addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { saPtr in
                Darwin.connect(fd, saPtr, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard connectRC == 0 else { return nil }

        // 发送命令（追加换行符作为分隔符）
        let message = jsonStr + "\n"
        let sent = message.withCString { Darwin.send(fd, $0, strlen($0), 0) }
        guard sent > 0 else { return nil }

        // 读取响应（直到换行或连接关闭）
        var responseBytes = [UInt8]()
        var oneByte = [UInt8](repeating: 0, count: 1)
        while true {
            let n = Darwin.recv(fd, &oneByte, 1, 0)
            if n <= 0 { break }
            if oneByte[0] == UInt8(ascii: "\n") { break }
            responseBytes.append(oneByte[0])
        }

        guard !responseBytes.isEmpty,
              let responseStr = String(bytes: responseBytes, encoding: .utf8),
              let responseData = responseStr.data(using: .utf8),
              let response = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any] else {
            return nil
        }

        return response
    }

    // MARK: - Legacy Authorization (fallback only)

    /// 申请管理员授权。整个 App 生命周期内缓存以减少弹框频率。
    private func acquireAuthorization() -> AuthorizationRef? {
        if let auth = cachedAuth { return auth }

        let rightName = "system.preferences.network"
        var auth: AuthorizationRef?
        let status: OSStatus = rightName.withCString { namePtr in
            var item = AuthorizationItem(name: namePtr, valueLength: 0, value: nil, flags: 0)
            return withUnsafeMutablePointer(to: &item) { itemPtr in
                var rights = AuthorizationRights(count: 1, items: itemPtr)
                let flags: AuthorizationFlags = [.interactionAllowed, .extendRights, .preAuthorize]
                return AuthorizationCreate(&rights, nil, flags, &auth)
            }
        }

        if status == errAuthorizationSuccess {
            cachedAuth = auth
            NSLog("SingboxFlutterPlugin: 管理员授权成功（已缓存，仅首次显示）")
            return auth
        }
        NSLog("SingboxFlutterPlugin: 授权失败 status=\(status)")
        return nil
    }

    /// Legacy SCPreferences proxy setter（回退路径，helper 可用后不再调用）
    @discardableResult
    private func applyProxySettingsLegacy(enabled: Bool, auth: AuthorizationRef) -> Bool {
        guard let prefs = SCPreferencesCreateWithAuthorization(
            nil, "Velox VPN" as CFString, nil, auth
        ) else { return false }

        guard let networkSet = SCNetworkSetCopyCurrent(prefs),
              let services = SCNetworkSetCopyServices(networkSet) as? [SCNetworkService] else {
            return false
        }

        let proxySettings: CFDictionary
        if enabled {
            proxySettings = [
                kCFNetworkProxiesHTTPEnable:  1,
                kCFNetworkProxiesHTTPProxy:   "127.0.0.1",
                kCFNetworkProxiesHTTPPort:    proxyPort,
                kCFNetworkProxiesHTTPSEnable: 1,
                kCFNetworkProxiesHTTPSProxy:  "127.0.0.1",
                kCFNetworkProxiesHTTPSPort:   proxyPort,
                kCFNetworkProxiesSOCKSEnable: 1,
                kCFNetworkProxiesSOCKSProxy:  "127.0.0.1",
                kCFNetworkProxiesSOCKSPort:   proxyPort,
            ] as CFDictionary
        } else {
            proxySettings = [
                kCFNetworkProxiesHTTPEnable:  0,
                kCFNetworkProxiesHTTPSEnable: 0,
                kCFNetworkProxiesSOCKSEnable: 0,
            ] as CFDictionary
        }

        for service in services {
            if let proto = SCNetworkServiceCopyProtocol(service, kSCNetworkProtocolTypeProxies) {
                SCNetworkProtocolSetConfiguration(proto, proxySettings)
            }
        }

        let committed = SCPreferencesCommitChanges(prefs)
        let applied   = SCPreferencesApplyChanges(prefs)
        SCPreferencesUnlock(prefs)
        return committed && applied
    }

    /// 以 root 权限执行工具（通过 ObjC PrivilegedExecutor）
    @discardableResult
    private func runAsRoot(tool: String, args: [String], auth: AuthorizationRef) -> OSStatus {
        return PrivilegedExecutor.execute(withPrivileges: auth, tool: tool, arguments: args)
    }

    // MARK: - Local Port Cleanup

    private func preparePortsForNewConnection() -> String? {
        for port in [proxyPort, clashApiPort] {
            if let error = releaseManagedPortIfNeeded(port) { return error }
        }
        return nil
    }

    private func releaseManagedPortIfNeeded(_ port: Int) -> String? {
        let pids = listeningPids(on: port)
        if pids.isEmpty { return nil }

        NSLog("SingboxFlutterPlugin: port \(port) is occupied by PIDs \(pids)")
        for pid in pids {
            if pid == mihomoProcess?.processIdentifier { continue }
            let name = processName(for: pid) ?? "unknown"
            let nameLower = name.lowercased()
            if !nameLower.contains("mihomo") && !nameLower.contains("sing-box") {
                return "Local port \(port) is in use by \(name) (PID \(pid)). Please close that app and retry."
            }
            terminateProcess(pid: pid)
        }

        if !listeningPids(on: port).isEmpty {
            return "Local port \(port) is still busy after cleanup. Please retry."
        }
        return nil
    }

    private func listeningPids(on port: Int) -> [Int32] {
        let output = runCommand("/usr/sbin/lsof", arguments: [
            "-nP", "-t", "-iTCP:\(port)", "-sTCP:LISTEN"
        ])
        if output.status != 0 && output.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return []
        }
        return output.stdout
            .split(whereSeparator: { $0.isNewline })
            .compactMap { Int32(String($0).trimmingCharacters(in: .whitespacesAndNewlines)) }
    }

    private func processName(for pid: Int32) -> String? {
        let output = runCommand("/bin/ps", arguments: ["-p", "\(pid)", "-o", "comm="])
        let name = output.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? nil : name
    }

    private func terminateProcess(pid: Int32) {
        NSLog("SingboxFlutterPlugin: terminating stale process PID=\(pid)")
        _ = runCommand("/bin/kill", arguments: ["-TERM", "\(pid)"])
        let deadline = Date().addingTimeInterval(1.0)
        while Date() < deadline {
            if !isProcessAlive(pid: pid) { return }
            Thread.sleep(forTimeInterval: 0.1)
        }
        _ = runCommand("/bin/kill", arguments: ["-KILL", "\(pid)"])
    }

    private func isProcessAlive(pid: Int32) -> Bool {
        return runCommand("/bin/kill", arguments: ["-0", "\(pid)"]).status == 0
    }

    /// 试探性 bind 127.0.0.1:port，看 mihomo 起来时能否成功 bind。
    /// 比 lsof 可靠：不受"对方进程属于哪个用户（root/user）"权限影响，纯靠内核端口表判定。
    ///
    /// ⚠️ 必须设 SO_REUSEADDR：macOS 上 LISTEN socket 关闭后，残留的 TIME_WAIT 连接会让
    /// 没设 SO_REUSEADDR 的 bind 失败 ~60s（端口被"保留"）。mihomo 启动时设了
    /// SO_REUSEADDR 能立刻绑成功；如果我们的探测不设，就会把"只剩 TIME_WAIT、其实
    /// mihomo 能绑"的端口误判为 busy，导致等 3s 还报 warning（而 mihomo 在 warning
    /// 之后启动反而成功 bind）。设上后行为对齐 mihomo。
    private func isPortFree(_ port: Int) -> Bool {
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        if fd < 0 { return false }
        defer { Darwin.close(fd) }
        var yes: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &yes, socklen_t(MemoryLayout<Int32>.size))
        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = UInt16(port).bigEndian   // htons
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")
        let rc = withUnsafePointer(to: &addr) { p -> Int32 in
            p.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                Darwin.bind(fd, sa, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        return rc == 0
    }

    /// 轮询等端口被释放（旧核心退出后内核回收监听 socket 有延迟）。
    /// 返回是否在超时内变空闲；超时返回 false（调用方可仅 log warning，不致命）。
    @discardableResult
    private func waitForPortFree(_ port: Int, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if isPortFree(port) { return true }
            Thread.sleep(forTimeInterval: 0.1)
        }
        return false
    }

    private func runCommand(_ launchPath: String, arguments: [String])
        -> (status: Int32, stdout: String, stderr: String) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: launchPath)
        task.arguments = arguments
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        task.standardOutput = stdoutPipe
        task.standardError  = stderrPipe
        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            return (1, "", error.localizedDescription)
        }
        let stdout = String(data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return (task.terminationStatus, stdout, stderr)
    }

    // MARK: - Paths

    private func getMihomoPath() -> String {
        if let resourcePath = Bundle.main.resourcePath {
            let p = "\(resourcePath)/mihomo"
            if FileManager.default.fileExists(atPath: p) { return p }
        }
        if let execURL = Bundle.main.executableURL {
            let p = execURL.deletingLastPathComponent().appendingPathComponent("mihomo").path
            if FileManager.default.fileExists(atPath: p) { return p }
        }
        for p in ["/opt/homebrew/bin/mihomo",
                  "/usr/local/bin/mihomo",
                  "\(NSHomeDirectory())/.local/bin/mihomo"] {
            if FileManager.default.fileExists(atPath: p) { return p }
        }
        return "/usr/local/bin/mihomo"
    }

    /// Fixed config path: world-writable /tmp so the app can write without root,
    /// and the mihomo LaunchDaemon (root) can read it.
    /// Must match MIHOMO_CONFIG_PATH in VeloxHelper.c and the plist ProgramArguments.
    private func getConfigFilePath() -> String {
        return "/tmp/velox_mihomo.yaml"
    }

    /// Persistent work directory for GeoIP/GeoSite databases.
    /// Created by install_mihomo_svc in VeloxHelper (requires root).
    /// Must match MIHOMO_INSTALL_DIR in VeloxHelper.c and the plist ProgramArguments.
    private func getMihomoWorkDir() -> String {
        return "/Library/Application Support/Velox"
    }

    /// 非 TUN 子进程的工作目录：用户可写（~/Library/Application Support/Velox）。
    private func getUserWorkDir() -> String {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        return base?.appendingPathComponent("Velox").path
            ?? (NSTemporaryDirectory() as NSString).appendingPathComponent("Velox")
    }

    /// 把 App bundle 内置的 geo 数据库拷到 [dir]（缺失或大小不一致才覆盖）。免 root。
    /// 镜像 helper 给 TUN/svc 安装 geo 的逻辑，让纯代理模式也能用 GEOSITE/GEOIP 分流。
    private func provisionGeoFiles(to dir: String) {
        let fm = FileManager.default
        try? fm.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let flutterAssets = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Frameworks/App.framework/Resources/flutter_assets")
        for name in ["geoip.metadb", "geosite.dat"] {
            let srcPath = flutterAssets.appendingPathComponent("assets/geo/\(name)").path
            let dstPath = (dir as NSString).appendingPathComponent(name)
            guard fm.fileExists(atPath: srcPath) else {
                NSLog("SingboxFlutterPlugin: bundled \(name) not found at \(srcPath)")
                continue
            }
            let srcSize = (try? fm.attributesOfItem(atPath: srcPath))?[.size] as? Int
            let dstSize = (try? fm.attributesOfItem(atPath: dstPath))?[.size] as? Int
            if fm.fileExists(atPath: dstPath), let s = srcSize, s == dstSize {
                continue  // 已是同一份，跳过拷贝
            }
            try? fm.removeItem(atPath: dstPath)
            do {
                try fm.copyItem(atPath: srcPath, toPath: dstPath)
                NSLog("SingboxFlutterPlugin: provisioned \(name) → \(dstPath)")
            } catch {
                NSLog("SingboxFlutterPlugin: copy \(name) failed: \(error)")
            }
        }
    }

    // MARK: - Stats Monitoring

    private func startStatsMonitoring() {
        stopStatsMonitoring()
        statsTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateStats()
        }
    }

    private func stopStatsMonitoring() {
        statsTimer?.invalidate()
        statsTimer = nil
    }

    private func updateStats() {
        fetchClashStats { [weak self] upload, download in
            guard let self = self else { return }
            let uploadSpeed   = upload   - self.lastUpload
            let downloadSpeed = download - self.lastDownload
            self.lastUpload    = self.totalUpload
            self.lastDownload  = self.totalDownload
            self.totalUpload   = upload
            self.totalDownload = download

            let connectionTime: Int
            if let startTime = self.connectionStartTime {
                connectionTime = Int(Date().timeIntervalSince(startTime))
            } else {
                connectionTime = 0
            }

            DispatchQueue.main.async {
                self.eventSink?([
                    "type":          "stats",
                    "uploadSpeed":   Int(uploadSpeed),
                    "downloadSpeed": Int(downloadSpeed),
                    "totalUpload":   Int(self.totalUpload),
                    "totalDownload": Int(self.totalDownload),
                    "connectionTime": connectionTime
                ])
            }
        }
    }

    private func fetchClashStats(completion: @escaping (Int64, Int64) -> Void) {
        let url = URL(string: "http://127.0.0.1:\(clashApiPort)/connections")!
        let task = URLSession.shared.dataTask(with: url) { [self] data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                completion(self.totalUpload, self.totalDownload)
                return
            }
            let upload   = json["uploadTotal"]   as? Int64 ?? 0
            let download = json["downloadTotal"] as? Int64 ?? 0
            completion(upload, download)
        }
        task.resume()
    }

    private func resetStats() {
        lastUpload = 0; lastDownload = 0
        totalUpload = 0; totalDownload = 0
    }

    // MARK: - Event Sink

    private func sendStatus(_ status: String) {
        NSLog("SingboxFlutterPlugin: sendStatus \(status)")
        DispatchQueue.main.async { [weak self] in
            self?.eventSink?(["type": "statusChanged", "status": status])
        }
    }

    private func sendError(_ message: String) {
        DispatchQueue.main.async { [weak self] in
            self?.eventSink?(["type": "error", "message": message])
        }
    }

    // MARK: - App Exit Cleanup

    /// App 退出时调用（由 AppDelegate.applicationWillTerminate 触发）
    public func cleanupOnExit() {
        if isTunMode {
            // TUN 退出：恢复系统 DNS（与 disconnect 一致；之前漏了 → DNS 卡在 114.114.114.114）
            restoreSystemDns()
            NSLog("SingboxFlutterPlugin: cleanupOnExit — system DNS restored (TUN)")
        } else {
            clearProxySettings()
            NSLog("SingboxFlutterPlugin: cleanupOnExit — system proxy cleared")
        }
        markSystemDirty(false)  // 干净退出，系统状态已还原
        stopMihomo()
        NSLog("SingboxFlutterPlugin: cleanupOnExit — Mihomo stopped")
    }
}

// MARK: - FlutterStreamHandler

extension SingboxFlutterPlugin: FlutterStreamHandler {
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
}
