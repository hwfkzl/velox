import Flutter
import UIKit
import NetworkExtension

public class SingboxFlutterPlugin: NSObject, FlutterPlugin {
    private var channel: FlutterMethodChannel?
    private var eventChannel: FlutterEventChannel?
    private var eventSink: FlutterEventSink?
    private var vpnManager: NETunnelProviderManager?
    private var statsTimer: Timer?
    private var connectionStartTime: Date?
    private var isLoadingManager = false
    private var pendingConnectResult: FlutterResult?
    private var pendingConnectConfig: String?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = SingboxFlutterPlugin()

        let methodChannel = FlutterMethodChannel(
            name: "com.velox.singbox_flutter/method",
            binaryMessenger: registrar.messenger()
        )
        instance.channel = methodChannel
        registrar.addMethodCallDelegate(instance, channel: methodChannel)

        let eventChannel = FlutterEventChannel(
            name: "com.velox.singbox_flutter/events",
            binaryMessenger: registrar.messenger()
        )
        instance.eventChannel = eventChannel
        eventChannel.setStreamHandler(instance)

        // Load VPN configuration
        instance.loadVpnManager(completion: nil)

        // Observe VPN status changes
        NotificationCenter.default.addObserver(
            instance,
            selector: #selector(instance.vpnStatusDidChange(_:)),
            name: .NEVPNStatusDidChange,
            object: nil
        )
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "connect":
            guard let args = call.arguments as? [String: Any],
                  let config = args["config"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "Config is required", details: nil))
                return
            }
            connect(config: config, result: result)

        case "disconnect":
            disconnect(result: result)

        case "getStats":
            getStats(result: result)

        case "hasVpnPermission":
            hasVpnPermission(result: result)

        case "requestVpnPermission":
            requestVpnPermission(result: result)

        case "getVersion":
            result(getVersion())

        case "getExtensionStatus":
            result(getExtensionStatus())

        case "getAppGroupDir":
            // 返回 App Group 共享容器的绝对路径，供 Dart 层写入规则集文件。
            // Network Extension 进程的 sing-box 工作目录也指向同一路径，
            // 因此主 App 写入后 sing-box 可直接通过绝对路径读取规则集。
            let bundleId = Bundle.main.bundleIdentifier ?? ""
            let appGroupId = "group.\(bundleId)"
            if let url = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: appGroupId
            ) {
                result(url.path)
            } else {
                result(FlutterError(
                    code: "APP_GROUP_NOT_FOUND",
                    message: "App Group container unavailable for \(appGroupId)",
                    details: nil
                ))
            }

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func getExtensionStatus() -> [String: Any] {
        let bundleId = Bundle.main.bundleIdentifier ?? "unknown"
        let appGroupId = "group.\(bundleId)"
        let defaults = UserDefaults(suiteName: appGroupId)

        var result: [String: Any] = [
            "status": defaults?.string(forKey: "vpnStatus") ?? "unknown",
            "lastUpdate": defaults?.string(forKey: "vpnLastUpdate") ?? "",
            "appGroupId": appGroupId,
            "bundleId": bundleId,
            "providerBundleId": "\(bundleId).PacketTunnel",
            "vpnManagerLoaded": vpnManager != nil
        ]

        if let vpnManager = vpnManager {
            result["vpnEnabled"] = vpnManager.isEnabled
            result["connectionStatus"] = vpnManager.connection.status.rawValue
            result["localizedDescription"] = vpnManager.localizedDescription ?? ""

            if let proto = vpnManager.protocolConfiguration as? NETunnelProviderProtocol {
                result["configuredProviderBundleId"] = proto.providerBundleIdentifier ?? ""
                result["serverAddress"] = proto.serverAddress ?? ""
            }
        }

        return result
    }

    // MARK: - VPN Management

    private func loadVpnManager(completion: (() -> Void)?) {
        guard !isLoadingManager else {
            print("SingboxFlutterPlugin: Already loading VPN manager")
            return
        }
        isLoadingManager = true
        print("SingboxFlutterPlugin: Loading VPN managers...")

        NETunnelProviderManager.loadAllFromPreferences { [weak self] managers, error in
            guard let self = self else { return }
            self.isLoadingManager = false

            if let error = error {
                let nsError = error as NSError
                NSLog("SingboxFlutterPlugin: Error loading VPN managers: domain=%@ code=%ld desc=%@", nsError.domain, nsError.code, nsError.localizedDescription)
                self.vpnManager = NETunnelProviderManager()
                NSLog("SingboxFlutterPlugin: fallback — created new NETunnelProviderManager after load error")
                completion?()
                return
            }

            if let existingManager = managers?.first {
                NSLog("SingboxFlutterPlugin: Found existing VPN manager")
                self.vpnManager = existingManager
            } else {
                NSLog("SingboxFlutterPlugin: No existing VPN manager, creating new one")
                self.vpnManager = NETunnelProviderManager()
            }

            NSLog("SingboxFlutterPlugin: VPN manager loaded, isEnabled: %d", self.vpnManager?.isEnabled ?? false)
            completion?()
        }
    }

    private func connect(config: String, result: @escaping FlutterResult) {
        print("SingboxFlutterPlugin: connect() called")

        // If VPN manager is not ready, load it first
        if vpnManager == nil {
            print("SingboxFlutterPlugin: VPN manager not ready, loading first...")
            loadVpnManager { [weak self] in
                self?.doConnect(config: config, result: result)
            }
            return
        }

        doConnect(config: config, result: result)
    }

    private func doConnect(config: String, result: @escaping FlutterResult) {
        guard let vpnManager = vpnManager else {
            print("SingboxFlutterPlugin: VPN manager still nil after loading")
            result(FlutterError(code: "NO_VPN_MANAGER", message: "VPN manager not initialized", details: nil))
            return
        }

        sendStatus("connecting")

        // Get bundle identifier
        guard let bundleId = Bundle.main.bundleIdentifier else {
            print("SingboxFlutterPlugin: Bundle identifier is nil")
            result(FlutterError(code: "NO_BUNDLE_ID", message: "Bundle identifier not found", details: nil))
            return
        }

        let providerBundleId = "\(bundleId).PacketTunnel"
        print("SingboxFlutterPlugin: Provider bundle ID: \(providerBundleId)")

        // Configure VPN
        let tunnelProtocol = NETunnelProviderProtocol()
        tunnelProtocol.providerBundleIdentifier = providerBundleId
        tunnelProtocol.serverAddress = "Velox VPN"

        // Extract server host from config for routing exclusion
        var serverHost = ""
        if let configData = config.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: configData) as? [String: Any],
           let outbounds = json["outbounds"] as? [[String: Any]] {
            for outbound in outbounds {
                if let server = outbound["server"] as? String {
                    serverHost = server
                    break
                }
            }
        }
        print("SingboxFlutterPlugin: Server host for exclusion: \(serverHost)")
        print("SingboxFlutterPlugin: Config length: \(config.count)")

        tunnelProtocol.providerConfiguration = [
            "config": config,
            "serverHost": serverHost
        ]

        vpnManager.protocolConfiguration = tunnelProtocol
        vpnManager.localizedDescription = "Velox VPN"
        vpnManager.isEnabled = true

        print("SingboxFlutterPlugin: Saving VPN preferences...")

        // Save and connect
        vpnManager.saveToPreferences { [weak self] error in
            if let error = error {
                let ns = error as NSError
                NSLog("SingboxFlutterPlugin: SAVE ERR domain=%@ code=%ld desc=%@", ns.domain, ns.code, ns.localizedDescription)
                NSLog("SingboxFlutterPlugin: SAVE ERR userInfo=%@", String(describing: ns.userInfo))
                if let under = ns.userInfo[NSUnderlyingErrorKey] as? NSError {
                    NSLog("SingboxFlutterPlugin: SAVE UNDER domain=%@ code=%ld desc=%@ userInfo=%@", under.domain, under.code, under.localizedDescription, String(describing: under.userInfo))
                }
                NSLog("SingboxFlutterPlugin: providerBundleId=%@ cfgKeys=%@ cfgLen=%ld", providerBundleId, String(describing: (tunnelProtocol.providerConfiguration ?? [:]).keys.map { $0 }), config.count)
                let mainBundleId = Bundle.main.bundleIdentifier ?? "nil"
                NSLog("SingboxFlutterPlugin: mainBundleId=%@", mainBundleId)
                self?.sendStatus("error")
                let details = "\(ns.domain):\(ns.code) userInfo=\(ns.userInfo)"
                result(FlutterError(code: "SAVE_ERROR", message: error.localizedDescription, details: details))
                return
            }

            print("SingboxFlutterPlugin: VPN preferences saved, loading from preferences...")

            // Load again after saving - this is required by Apple
            vpnManager.loadFromPreferences { [weak self] error in
                if let error = error {
                    print("SingboxFlutterPlugin: Error loading VPN preferences: \(error)")
                    self?.sendStatus("error")
                    result(FlutterError(code: "LOAD_ERROR", message: error.localizedDescription, details: nil))
                    return
                }

                print("SingboxFlutterPlugin: VPN preferences loaded, isEnabled: \(vpnManager.isEnabled)")
                print("SingboxFlutterPlugin: Connection status: \(vpnManager.connection.status.rawValue)")
                print("SingboxFlutterPlugin: Starting VPN tunnel...")

                do {
                    try vpnManager.connection.startVPNTunnel()
                    print("SingboxFlutterPlugin: startVPNTunnel() called successfully")
                    self?.connectionStartTime = Date()
                    self?.startStatsMonitoring()
                    result(true)
                } catch {
                    print("SingboxFlutterPlugin: Error starting VPN: \(error)")
                    print("SingboxFlutterPlugin: Error domain: \((error as NSError).domain)")
                    print("SingboxFlutterPlugin: Error code: \((error as NSError).code)")
                    self?.sendStatus("error")
                    result(FlutterError(code: "START_ERROR", message: error.localizedDescription, details: "\((error as NSError).domain):\((error as NSError).code)"))
                }
            }
        }
    }

    private func disconnect(result: @escaping FlutterResult) {
        guard let vpnManager = vpnManager else {
            result(FlutterError(code: "NO_VPN_MANAGER", message: "VPN manager not initialized", details: nil))
            return
        }

        sendStatus("disconnecting")
        stopStatsMonitoring()
        vpnManager.connection.stopVPNTunnel()
        connectionStartTime = nil
        result(true)
    }

    private func getStats(result: @escaping FlutterResult) {
        // Get stats from Network Extension via App Groups
        let stats = getTrafficStats()
        result(stats)
    }

    private func hasVpnPermission(result: @escaping FlutterResult) {
        // iOS doesn't have explicit VPN permission like Android
        // Permission is requested when first configuring VPN
        result(true)
    }

    private func requestVpnPermission(result: @escaping FlutterResult) {
        // iOS handles this automatically
        result(true)
    }

    private func getVersion() -> String {
        // Return sing-box version
        // This would be implemented in the actual libbox framework
        return "1.8.0"
    }

    // MARK: - VPN Status

    @objc private func vpnStatusDidChange(_ notification: Notification) {
        guard let connection = notification.object as? NEVPNConnection else {
            print("SingboxFlutterPlugin: vpnStatusDidChange - not a NEVPNConnection")
            return
        }

        print("SingboxFlutterPlugin: VPN status changed to: \(connection.status.rawValue)")

        let status: String
        switch connection.status {
        case .invalid:
            print("SingboxFlutterPlugin: VPN status: invalid")
            status = "disconnected"
        case .disconnected:
            print("SingboxFlutterPlugin: VPN status: disconnected")
            status = "disconnected"
            stopStatsMonitoring()
        case .connecting:
            print("SingboxFlutterPlugin: VPN status: connecting")
            status = "connecting"
        case .connected:
            print("SingboxFlutterPlugin: VPN status: connected")
            status = "connected"
            if connectionStartTime == nil {
                connectionStartTime = Date()
            }
            startStatsMonitoring()
        case .reasserting:
            print("SingboxFlutterPlugin: VPN status: reasserting")
            status = "connecting"
        case .disconnecting:
            print("SingboxFlutterPlugin: VPN status: disconnecting")
            status = "disconnecting"
        @unknown default:
            print("SingboxFlutterPlugin: VPN status: unknown")
            status = "disconnected"
        }

        sendStatus(status)
    }

    private func sendStatus(_ status: String) {
        DispatchQueue.main.async { [weak self] in
            self?.eventSink?([
                "type": "statusChanged",
                "status": status
            ])
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
        let stats = getTrafficStats()

        DispatchQueue.main.async { [weak self] in
            var eventData = stats
            eventData["type"] = "stats"
            self?.eventSink?(eventData)
        }
    }

    private func getTrafficStats() -> [String: Any] {
        // Get stats from App Groups shared storage
        let appGroupId = "group.\(Bundle.main.bundleIdentifier!)"
        let defaults = UserDefaults(suiteName: appGroupId)

        let uploadSpeed = defaults?.integer(forKey: "uploadSpeed") ?? 0
        let downloadSpeed = defaults?.integer(forKey: "downloadSpeed") ?? 0
        let totalUpload = defaults?.integer(forKey: "totalUpload") ?? 0
        let totalDownload = defaults?.integer(forKey: "totalDownload") ?? 0

        // Get extension status for debugging
        let vpnStatus = defaults?.string(forKey: "vpnStatus") ?? "unknown"
        let vpnLastUpdate = defaults?.string(forKey: "vpnLastUpdate") ?? ""
        print("SingboxFlutterPlugin: Extension vpnStatus=\(vpnStatus), lastUpdate=\(vpnLastUpdate)")

        let connectionTime: Int
        if let startTime = connectionStartTime {
            connectionTime = Int(Date().timeIntervalSince(startTime))
        } else {
            connectionTime = 0
        }

        return [
            "uploadSpeed": uploadSpeed,
            "downloadSpeed": downloadSpeed,
            "totalUpload": totalUpload,
            "totalDownload": totalDownload,
            "connectionTime": connectionTime,
            "extensionStatus": vpnStatus,
            "extensionLastUpdate": vpnLastUpdate
        ]
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
