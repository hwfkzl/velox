package com.velox.singbox_flutter

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.net.VpnService
import android.os.Binder
import android.os.Build
import android.os.IBinder
import android.os.ParcelFileDescriptor
import android.util.Log
import kotlinx.coroutines.*
import java.io.File
import java.util.concurrent.atomic.AtomicBoolean

class SingboxVpnService : VpnService() {

    companion object {
        private const val TAG = "SingboxVpnService"
        const val ACTION_CONNECT = "com.velox.singbox.CONNECT"
        const val ACTION_DISCONNECT = "com.velox.singbox.DISCONNECT"
        // Kill Switch:mihomo 保留但 PROXY→REJECT,tun 保留,流量被 mihomo 内部丢弃。
        // 用户真实 IP 不泄漏。用户明确开启才走这条路径(未来接 UI toggle)。
        const val ACTION_KILL_SWITCH = "com.velox.singbox.KILL_SWITCH"
        // 彻底关闭:mihomo 完全 stop、tun 关闭、网络恢复。用户点通知栏"彻底关闭"触发。
        const val ACTION_FULL_STOP = "com.velox.singbox.FULL_STOP"
        const val EXTRA_CONFIG = "config"

        private const val NOTIFICATION_ID = 1
        private const val NOTIFICATION_CHANNEL_ID = "singbox_vpn"
        private const val NOTIFICATION_CHANNEL_NAME = "VPN Service"

        // TUN interface configuration
        private const val TUN_MTU = 9000
        private const val TUN_ADDRESS = "172.19.0.1"
        private const val TUN_PREFIX = 30
        private const val TUN_DNS = "8.8.8.8"
    }

    private val binder = LocalBinder()
    private var tunInterface: ParcelFileDescriptor? = null
    private var statusListener: StatusListener? = null
    private var isRunning = AtomicBoolean(false)
    private var connectionStartTime: Long = 0
    private var scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private var statsJob: Job? = null

    // Traffic statistics
    private var lastUpload: Long = 0
    private var lastDownload: Long = 0
    private var totalUpload: Long = 0
    private var totalDownload: Long = 0
    private var uploadSpeed: Long = 0
    private var downloadSpeed: Long = 0

    interface StatusListener {
        fun onStatusChanged(status: String)
        fun onStatsUpdated(uploadSpeed: Long, downloadSpeed: Long, totalUpload: Long, totalDownload: Long)
        fun onError(message: String)
    }

    inner class LocalBinder : Binder() {
        fun getService(): SingboxVpnService = this@SingboxVpnService
    }

    override fun onBind(intent: Intent?): IBinder {
        return binder
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_CONNECT -> {
                val config = intent.getStringExtra(EXTRA_CONFIG)
                if (config != null) {
                    startVpn(config)
                }
            }
            ACTION_DISCONNECT -> {
                // 默认断开=Kill Switch(商业 VPN 标准:防真实 IP 泄漏)。
                // Flutter 侧把 kill_switch 状态映射成 "connected"(UI 显示"已保护"),
                // 用户通过通知栏"彻底关闭"才真断开。
                stopVpn(killSwitch = true)
            }
            ACTION_KILL_SWITCH -> {
                stopVpn(killSwitch = true)
            }
            ACTION_FULL_STOP -> {
                stopVpn(killSwitch = false)
            }
        }
        return START_STICKY
    }

    override fun onDestroy() {
        // Service 被销毁,一定要彻底停 mihomo 和释放 tun,防止孤儿进程/文件描述符泄漏
        stopVpn(killSwitch = false)
        scope.cancel()
        super.onDestroy()
    }

    override fun onRevoke() {
        // 系统撤销 VPN 权限(用户在系统设置里手动撤),没法阻断 tun 了 → 只能彻底停
        stopVpn(killSwitch = false)
        super.onRevoke()
    }

    fun setStatusListener(listener: StatusListener?) {
        statusListener = listener
    }

    fun getStats(): Map<String, Any> {
        return mapOf(
            "uploadSpeed" to uploadSpeed,
            "downloadSpeed" to downloadSpeed,
            "totalUpload" to totalUpload,
            "totalDownload" to totalDownload,
            "connectionTime" to getConnectionDuration()
        )
    }

    fun getConnectionDuration(): Int {
        if (!isRunning.get()) return 0
        return ((System.currentTimeMillis() - connectionStartTime) / 1000).toInt()
    }

    private fun startVpn(config: String) {
        // 允许从 Kill Switch 状态直接重连(isRunning=true 但需要新 config/新节点)。
        if (isRunning.get()) {
            Log.i(TAG, "startVpn while running: 视为从 Kill Switch 重连,先彻底清再启动")
            try {
                MihomoCore.stop()
                MihomoCore.setSocketProtect(null)
                tunInterface?.close()
                tunInterface = null
                isRunning.set(false)
            } catch (e: Exception) {
                Log.w(TAG, "预清理异常:$e")
            }
        }

        // P1-1 修复:Android API 26+ startForegroundService 有严格时限(5-10s)必须
        // 立刻 startForeground(),否则 ForegroundServiceDidNotStartInTimeException
        // 或系统静默 kill service → onDestroy → 用户看到 "已连接→断开中" 幽灵 600ms。
        // 一定要 SYNC 在 launch coroutine 之前完成,不能塞进 IO 线程。
        try {
            startForeground(NOTIFICATION_ID, createNotification("Connecting…"))
        } catch (e: Exception) {
            Log.e(TAG, "startForeground 失败(FGS 限制)", e)
            statusListener?.onError(e.message ?: "startForeground failed")
            statusListener?.onStatusChanged("disconnected")
            return
        }

        scope.launch {
            try {
                statusListener?.onStatusChanged("connecting")

                // 0) 落 geo 数据 + 告诉 mihomo 去哪找,这样 config 里的 GEOSITE/GEOIP CN
                //    规则能真正加载(否则 mihomo 试着 open("") 崩)。之前 Android 上跳过
                //    CN 分流就是因为这里没配好 → "规则代理" 跟 "全局代理" 结果一样。
                val geoHome = MihomoCore.ensureGeoData(applicationContext)
                MihomoCore.setHomeDir(geoHome)

                // 1) 用 VpnService.Builder 自己建 tun (mihomo 吃 fd 不自己建)
                val builder = Builder()
                    .setMtu(TUN_MTU)
                    .setSession("Velox")
                    .setBlocking(false)
                    .addAddress("198.18.0.1", 30)   // mihomo fake-ip range 头
                    .addRoute("0.0.0.0", 0)          // 全劫持
                    .addDnsServer(TUN_DNS)
                try { builder.addRoute("::", 0) } catch (e: Exception) { Log.w(TAG, "IPv6 route: $e") }
                // Android 13+ 排除私有段(避免 LAN 自循环)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    listOf("10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16").forEach { cidr ->
                        try {
                            val parts = cidr.split("/")
                            builder.excludeRoute(android.net.IpPrefix(
                                java.net.InetAddress.getByName(parts[0]),
                                parts[1].toInt(),
                            ))
                        } catch (e: Exception) { Log.w(TAG, "excludeRoute $cidr: $e") }
                    }
                }
                val pfd = builder.establish()
                    ?: throw IllegalStateException("VpnService.Builder.establish() returned null")
                tunInterface = pfd  // 暂存 pfd 引用(已 detach 后 close 是 no-op,安全)
                // 关键 pattern:detachFd 立刻把 fd 所有权交给 mihomo。mihomo Bind.stop
                // 内部会关 fd,pfd.close() 因为已 detach 变 no-op → 不会双关 → 不 SIGABRT。
                // 用 pfd.fd 保留所有权会跟 mihomo 争 → 停 VPN 时崩。
                val fd = pfd.detachFd()
                val yamlWithFd = injectTunFd(config, fd)

                // 装 socket protect 回调(防止 mihomo outbound socket 走回 tun)
                MihomoCore.setSocketProtect(object : bind.SocketProtector {
                    override fun protect(fd: Long): Boolean {
                        val ok = this@SingboxVpnService.protect(fd.toInt())
                        if (!ok) Log.w(TAG, "protect(fd=$fd) FAILED — mihomo outbound socket will loop back to tun")
                        else Log.d(TAG, "protect(fd=$fd) ok")
                        return ok
                    }
                })
                Log.i(TAG, "SocketProtect registered")

                try {
                    MihomoCore.start(yamlWithFd)
                } catch (e: Exception) {
                    // fd 已 detach,pfd.close() 关不掉。直接调 posix close 释放,防 tun 泄漏。
                    try { android.system.Os.close(java.io.FileDescriptor().apply {
                        val f = javaClass.getDeclaredField("descriptor")
                        f.isAccessible = true
                        f.setInt(this, fd)
                    }) } catch (_: Exception) {}
                    throw e
                }

                isRunning.set(true)
                connectionStartTime = System.currentTimeMillis()
                resetStats()

                // mihomo 起来了,通知改成 Connected(startForeground 已经在函数开头做过了)
                val nm = getSystemService(NotificationManager::class.java)
                nm?.notify(NOTIFICATION_ID, createNotification("Connected"))
                statusListener?.onStatusChanged("connected")
                startStatsMonitoring()

            } catch (e: Exception) {
                Log.e(TAG, "Failed to start VPN", e)
                // P1-2 修复:mihomo 起失败,fd 还在 pfd 里,close 释放内核 tun 防泄漏。
                try { tunInterface?.close() } catch (_: Exception) {}
                tunInterface = null
                MihomoCore.setSocketProtect(null)
                statusListener?.onError(e.message ?: "Unknown error")
                statusListener?.onStatusChanged("error")
                stopVpn(killSwitch = false)
            }
        }
    }

    /** 把 file-descriptor 塞到 YAML 的 tun: 段。找不到 tun: 就原样返回(mihomo 会报错)。 */
    private fun injectTunFd(yaml: String, fd: Int): String {
        val pattern = "tun:\n  enable: true"
        return if (yaml.contains(pattern)) {
            yaml.replace(pattern, "tun:\n  enable: true\n  file-descriptor: $fd")
        } else {
            Log.w(TAG, "YAML has no `tun:\n  enable: true` block — mihomo will likely fail to start")
            yaml
        }
    }

    /**
     * @param killSwitch true=Kill Switch 模式(默认):mihomo 保留、tun 保留、PROXY selector
     * 切到 REJECT,所有流量被 mihomo 丢弃,用户真实 IP 不泄漏。false=彻底停:mihomo stop、
     * tun close、系统网络恢复。onDestroy/onRevoke/startVpn 失败时必须 false。
     */
    private fun stopVpn(killSwitch: Boolean = true) {
        scope.launch {
            try {
                statusListener?.onStatusChanged("disconnecting")

                statsJob?.cancel()
                statsJob = null

                if (killSwitch && isRunning.get()) {
                    // Kill Switch:mihomo 保留,只把 PROXY selector 切到 REJECT
                    val ok = switchProxyToReject()
                    if (ok) {
                        startForeground(NOTIFICATION_ID, createNotification("🚫 已阻断(Kill Switch)"))
                        statusListener?.onStatusChanged("kill_switch")
                        Log.i(TAG, "Kill Switch ON:mihomo 保留,PROXY→REJECT,用户 IP 不泄漏。要彻底关闭走 ACTION_FULL_STOP。")
                        return@launch
                    }
                    // API 切换失败(mihomo 挂了?),fallback 到彻底停
                    Log.w(TAG, "Kill Switch API 切换失败,fallback 彻底停")
                }

                // 彻底停:mihomo 关、tun 关、网络恢复
                if (isRunning.get()) {
                    MihomoCore.stop()
                }
                MihomoCore.setSocketProtect(null)
                tunInterface?.close()
                tunInterface = null
                isRunning.set(false)

                stopForeground(STOP_FOREGROUND_REMOVE)
                statusListener?.onStatusChanged("disconnected")

            } catch (e: Exception) {
                Log.e(TAG, "Error stopping VPN", e)
                statusListener?.onError(e.message ?: "Unknown error")
            }
        }
    }

    // establishTun() 已废弃 — 新 libbox API 通过 PlatformInterfaceImpl.openTun() 自己建 TUN,
    // 从 sing-box JSON 配置的 inbounds[].type=tun 段读 mtu/address/route。

    private fun resetStats() {
        lastUpload = 0
        lastDownload = 0
        totalUpload = 0
        totalDownload = 0
        uploadSpeed = 0
        downloadSpeed = 0
    }

    private fun startStatsMonitoring() {
        // 新 libbox 没有简单 getTrafficStats() 同步接口,需要通过 CommandClient 走 unix socket
        // 取实时统计。第一版先提供 0 占位,UI 上仍显示"已连接",流量数字暂为 0。
        // 后续可补:CommandClient(libbox).setup(handler) → onWriteCommand 解析二进制流。
        statsJob?.cancel()
        statsJob = scope.launch {
            while (isActive && isRunning.get()) {
                statusListener?.onStatsUpdated(
                    uploadSpeed,
                    downloadSpeed,
                    totalUpload,
                    totalDownload,
                )
                updateNotification()
                delay(1000)
            }
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                NOTIFICATION_CHANNEL_NAME,
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "VPN connection status"
                setShowBadge(false)
            }

            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(status: String): Notification {
        val pendingIntent = packageManager.getLaunchIntentForPackage(packageName)?.let { intent ->
            PendingIntent.getActivity(
                this,
                0,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        }

        val disconnectIntent = Intent(this, SingboxVpnService::class.java).apply {
            action = ACTION_DISCONNECT
        }
        val disconnectPendingIntent = PendingIntent.getService(
            this,
            1,
            disconnectIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        // "彻底关闭" 按钮:onDestroy 走 killSwitch=false,释放 tun 让系统网络恢复。
        val fullStopIntent = Intent(this, SingboxVpnService::class.java).apply {
            action = ACTION_FULL_STOP
        }
        val fullStopPendingIntent = PendingIntent.getService(
            this,
            2,
            fullStopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // 品牌名读自 AndroidManifest 的 android:label（set-brand.sh 维护当前品牌）。
        val appName = packageManager.getApplicationLabel(applicationInfo)
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, NOTIFICATION_CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        return builder
            .setContentTitle("$appName")
            .setContentText(status)
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setOngoing(true)
            .setContentIntent(pendingIntent)
            .addAction(
                android.R.drawable.ic_menu_close_clear_cancel,
                "Disconnect",
                disconnectPendingIntent
            )
            .addAction(
                android.R.drawable.ic_menu_close_clear_cancel,
                "彻底关闭",
                fullStopPendingIntent
            )
            .build()
    }

    /**
     * Kill Switch 核心操作:调 mihomo REST API PUT /proxies/PROXY {"name":"REJECT"}。
     * 成功后所有流量在 mihomo 层被丢弃,tun 依然保留,系统流量出不去 → 用户 IP 不泄漏。
     * @return true=切换成功 kill switch 生效;false=API 出错 caller 走彻底停 fallback
     */
    private fun switchProxyToReject(): Boolean {
        val body = """{"name":"REJECT"}"""
        val bodyBytes = body.toByteArray(Charsets.UTF_8)
        return try {
            java.net.Socket("127.0.0.1", 19090).use { sock ->
                sock.soTimeout = 3000
                val req = "PUT /proxies/PROXY HTTP/1.0\r\n" +
                        "Host: 127.0.0.1\r\n" +
                        "Content-Type: application/json\r\n" +
                        "Content-Length: ${bodyBytes.size}\r\n" +
                        "Connection: close\r\n\r\n"
                sock.getOutputStream().apply {
                    write(req.toByteArray(Charsets.UTF_8))
                    write(bodyBytes)
                    flush()
                }
                val firstLine = sock.getInputStream().bufferedReader().readLine() ?: ""
                val ok = firstLine.contains(" 20") || firstLine.contains(" 204")
                Log.i(TAG, "switchProxyToReject: $firstLine (ok=$ok)")
                ok
            }
        } catch (e: Exception) {
            Log.w(TAG, "switchProxyToReject failed: $e")
            false
        }
    }

    private fun updateNotification() {
        if (!isRunning.get()) return

        val speedText = "↑ ${formatSpeed(uploadSpeed)} ↓ ${formatSpeed(downloadSpeed)}"
        val notification = createNotification(speedText)

        val notificationManager = getSystemService(NotificationManager::class.java)
        notificationManager.notify(NOTIFICATION_ID, notification)
    }

    private fun formatSpeed(bytesPerSecond: Long): String {
        return when {
            bytesPerSecond >= 1024 * 1024 -> String.format("%.1f MB/s", bytesPerSecond / (1024.0 * 1024.0))
            bytesPerSecond >= 1024 -> String.format("%.1f KB/s", bytesPerSecond / 1024.0)
            else -> "$bytesPerSecond B/s"
        }
    }
}
