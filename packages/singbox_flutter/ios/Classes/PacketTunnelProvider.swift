import NetworkExtension
import Foundation

/// Network Extension Packet Tunnel Provider for sing-box.
///
/// This file should be added to a separate Network Extension target in the main app.
/// Steps to set up:
/// 1. Create a new target: File > New > Target > Network Extension
/// 2. Select "Packet Tunnel Provider"
/// 3. Copy this file to the new target
/// 4. Add Libbox.xcframework to the target
/// 5. Configure App Groups for IPC between main app and extension
/// 6. Update entitlements for both targets
class PacketTunnelProvider: NEPacketTunnelProvider {

    private var singboxStarted = false
    private let appGroupId: String = {
        // Get app group ID from parent bundle
        let bundleId = Bundle.main.bundleIdentifier ?? ""
        let parentBundleId = bundleId.replacingOccurrences(of: ".PacketTunnel", with: "")
        return "group.\(parentBundleId)"
    }()

    // Stats tracking
    private var statsTimer: Timer?
    private var lastUpload: Int64 = 0
    private var lastDownload: Int64 = 0

    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        // Get configuration from provider configuration
        guard let providerConfig = (protocolConfiguration as? NETunnelProviderProtocol)?.providerConfiguration,
              let configString = providerConfig["config"] as? String else {
            completionHandler(NSError(domain: "PacketTunnelProvider", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Missing configuration"
            ]))
            return
        }

        // Write config to file
        let configPath = getConfigFilePath()
        do {
            try configString.write(toFile: configPath, atomically: true, encoding: .utf8)
        } catch {
            completionHandler(error)
            return
        }

        // Configure TUN settings
        let tunnelSettings = createTunnelSettings()

        setTunnelNetworkSettings(tunnelSettings) { [weak self] error in
            if let error = error {
                completionHandler(error)
                return
            }

            // Start sing-box
            do {
                try self?.startSingbox(configPath: configPath)
                self?.startStatsMonitoring()
                completionHandler(nil)
            } catch {
                completionHandler(error)
            }
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        stopStatsMonitoring()
        stopSingbox()
        completionHandler()
    }

    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        // Handle messages from the main app
        // Can be used for stats queries or configuration updates
        guard let message = try? JSONSerialization.jsonObject(with: messageData) as? [String: Any],
              let command = message["command"] as? String else {
            completionHandler?(nil)
            return
        }

        switch command {
        case "getStats":
            let stats: [String: Any] = [
                "uploadSpeed": getUploadSpeed(),
                "downloadSpeed": getDownloadSpeed(),
                "totalUpload": getTotalUpload(),
                "totalDownload": getTotalDownload()
            ]
            if let data = try? JSONSerialization.data(withJSONObject: stats) {
                completionHandler?(data)
            } else {
                completionHandler?(nil)
            }

        default:
            completionHandler?(nil)
        }
    }

    // MARK: - TUN Settings

    private func createTunnelSettings() -> NEPacketTunnelNetworkSettings {
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "172.19.0.1")

        // IPv4 settings
        let ipv4Settings = NEIPv4Settings(addresses: ["172.19.0.2"], subnetMasks: ["255.255.255.252"])
        ipv4Settings.includedRoutes = [NEIPv4Route.default()]
        settings.ipv4Settings = ipv4Settings

        // DNS settings
        let dnsSettings = NEDNSSettings(servers: ["8.8.8.8", "1.1.1.1"])
        dnsSettings.matchDomains = [""]
        settings.dnsSettings = dnsSettings

        // MTU
        settings.mtu = 9000

        return settings
    }

    // MARK: - sing-box Core

    private func startSingbox(configPath: String) throws {
        // Note: This is a placeholder. In actual implementation,
        // you would use the Libbox framework's API.
        //
        // Example with Libbox:
        // let boxService = LibboxNewService(configPath)
        // try boxService.start()

        singboxStarted = true
        NSLog("PacketTunnelProvider: sing-box started with config at \(configPath)")
    }

    private func stopSingbox() {
        if singboxStarted {
            // Note: Stop the libbox service here
            // boxService?.stop()
            singboxStarted = false
            NSLog("PacketTunnelProvider: sing-box stopped")
        }
    }

    private func getConfigFilePath() -> String {
        let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupId
        ) ?? FileManager.default.temporaryDirectory

        return containerURL.appendingPathComponent("config.json").path
    }

    // MARK: - Stats

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
        // Get current stats from sing-box
        let currentUpload = getTotalUpload()
        let currentDownload = getTotalDownload()

        // Calculate speed
        let uploadSpeed = currentUpload - lastUpload
        let downloadSpeed = currentDownload - lastDownload

        lastUpload = currentUpload
        lastDownload = currentDownload

        // Save to App Groups for main app to read
        if let defaults = UserDefaults(suiteName: appGroupId) {
            defaults.set(Int(uploadSpeed), forKey: "uploadSpeed")
            defaults.set(Int(downloadSpeed), forKey: "downloadSpeed")
            defaults.set(Int(currentUpload), forKey: "totalUpload")
            defaults.set(Int(currentDownload), forKey: "totalDownload")
            defaults.synchronize()
        }
    }

    private func getUploadSpeed() -> Int64 {
        // Get from sing-box stats API
        // return LibboxGetUploadSpeed()
        return 0
    }

    private func getDownloadSpeed() -> Int64 {
        // Get from sing-box stats API
        // return LibboxGetDownloadSpeed()
        return 0
    }

    private func getTotalUpload() -> Int64 {
        // Get from sing-box stats API
        // return LibboxGetTotalUpload()
        return 0
    }

    private func getTotalDownload() -> Int64 {
        // Get from sing-box stats API
        // return LibboxGetTotalDownload()
        return 0
    }
}
