package com.velox.singbox_flutter

import android.content.Context
import android.util.Log
// gomobile-bind 输出的 Java 包名默认 `bind`;若装出来实际是 `mihomo.bind`,把下面
// 两行改成 import mihomo.bind.Bind / import mihomo.bind.SocketProtector
import bind.Bind
import bind.SocketProtector

/**
 * mihomo (Clash.Meta) Kotlin wrapper。
 *
 * 从 sing-box(libbox.aar)迁过来:sing-box 的 xtls-rprx-vision 客户端跟 xray 服务端
 * 在 splice 直传阶段兼容不完善,实测 Chrome ERR_CONNECTION_RESET。macOS 端一直
 * 用 mihomo,Android 同栈统一。
 *
 * TUN 由 Kotlin 侧 VpnService.Builder 建 → fd → 塞进 YAML tun.file-descriptor → Bind.start
 * outbound socket protect 通过 SocketProtector 接口:mihomo 建 socket 时回调我们的 Protect,
 * 我们调 VpnService.protect(fd) 让 socket 不进 tun。
 */
object MihomoCore {

    private const val TAG = "MihomoCore"
    private var running = false

    @Synchronized
    fun start(configYaml: String) {
        if (running) {
            Log.w(TAG, "already running, stopping first")
            stop()
        }
        try {
            Bind.start(configYaml)
            running = true
            Log.i(TAG, "started, version=${version()}")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start", e)
            throw e
        }
    }

    @Synchronized
    fun stop() {
        if (!running) return
        try {
            Bind.stop()
            Log.i(TAG, "stopped")
        } catch (e: Exception) {
            Log.e(TAG, "stop error", e)
        } finally {
            running = false
        }
    }

    fun isRunning(): Boolean = running

    fun version(): String = try { Bind.version() } catch (_: Exception) { "unknown" }

    /** 装/卸 socket protect 回调。传 null 卸载。传实例:mihomo 出站 socket 会调其 Protect(fd)。 */
    fun setSocketProtect(protector: SocketProtector?) {
        try {
            Bind.setSocketProtect(protector)
        } catch (e: Exception) {
            Log.w(TAG, "setSocketProtect failed", e)
        }
    }

    /**
     * 告诉 mihomo 在 [path] 里找 geosite.dat / geoip.metadb。
     * gomobile bind 下 $HOME 空,mihomo 默认 os.UserHomeDir() 拿不到路径 → 加载 geo
     * 数据崩溃 → 之前只能在 Android 上彻底关 GEOSITE/GEOIP 规则。
     * 现在 Kotlin 把 assets 里的 geo 数据 copy 到 filesDir,再调这个函数让 mihomo 找到,
     * 就能开启完整 CN 分流("规则代理" 才会真起效)。
     */
    fun setHomeDir(path: String) {
        try {
            Bind.setHomeDir(path)
            Log.i(TAG, "HomeDir set: $path")
        } catch (e: Exception) {
            Log.w(TAG, "setHomeDir failed", e)
        }
    }

    /**
     * 从 assets 抽 geosite.dat + geoip.metadb 到 filesDir(仅首次或 asset 更新时 copy)。
     * assets 里的文件 mihomo 读不了(是 zip 里),必须先落地。
     * 返回真实 filesDir 路径,给 setHomeDir 用。
     */
    fun ensureGeoData(ctx: Context): String {
        val homeDir = ctx.filesDir
        val geoFiles = listOf("geosite.dat", "geoip.metadb")
        for (name in geoFiles) {
            val dst = java.io.File(homeDir, name)
            // 只在文件不存在或 assets 比本地新时复制:APK 版本号变化时用 SharedPreferences 追踪
            val versionKey = "geo_asset_ver_${name}"
            val prefs = ctx.getSharedPreferences("mihomo_geo", Context.MODE_PRIVATE)
            val installedVer = prefs.getString(versionKey, null)
            val currentVer = try { ctx.packageManager.getPackageInfo(ctx.packageName, 0).longVersionCode.toString() } catch (_: Exception) { "0" }
            if (!dst.exists() || installedVer != currentVer) {
                try {
                    ctx.assets.open(name).use { input ->
                        dst.outputStream().use { output -> input.copyTo(output) }
                    }
                    prefs.edit().putString(versionKey, currentVer).apply()
                    Log.i(TAG, "geo asset copied: $name (${dst.length()} bytes)")
                } catch (e: Exception) {
                    Log.e(TAG, "copy $name failed", e)
                }
            }
        }
        return homeDir.absolutePath
    }
}
