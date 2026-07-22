package com.velox.singbox_flutter

import android.app.Activity
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.net.VpnService
import android.os.IBinder
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.PluginRegistry

class SingboxFlutterPlugin : FlutterPlugin, MethodCallHandler, ActivityAware,
    PluginRegistry.ActivityResultListener {

    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var eventSink: EventChannel.EventSink? = null
    private var context: Context? = null
    private var activity: Activity? = null
    private var activityBinding: ActivityPluginBinding? = null

    private var vpnService: SingboxVpnService? = null
    private var vpnServiceBound = false
    private var pendingResult: MethodChannel.Result? = null

    companion object {
        private const val METHOD_CHANNEL = "com.velox.singbox_flutter/method"
        private const val EVENT_CHANNEL = "com.velox.singbox_flutter/events"
        private const val VPN_PERMISSION_REQUEST_CODE = 24601
    }

    private val serviceConnection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName?, service: IBinder?) {
            val binder = service as SingboxVpnService.LocalBinder
            vpnService = binder.getService()
            vpnServiceBound = true

            // Set up status listener
            vpnService?.setStatusListener(object : SingboxVpnService.StatusListener {
                override fun onStatusChanged(status: String) {
                    activity?.runOnUiThread {
                        eventSink?.success(mapOf(
                            "type" to "statusChanged",
                            "status" to status
                        ))
                    }
                }

                override fun onStatsUpdated(
                    uploadSpeed: Long,
                    downloadSpeed: Long,
                    totalUpload: Long,
                    totalDownload: Long
                ) {
                    activity?.runOnUiThread {
                        eventSink?.success(mapOf(
                            "type" to "stats",
                            "uploadSpeed" to uploadSpeed,
                            "downloadSpeed" to downloadSpeed,
                            "totalUpload" to totalUpload,
                            "totalDownload" to totalDownload,
                            "connectionTime" to (vpnService?.getConnectionDuration() ?: 0)
                        ))
                    }
                }

                override fun onError(message: String) {
                    activity?.runOnUiThread {
                        eventSink?.success(mapOf(
                            "type" to "error",
                            "message" to message
                        ))
                    }
                }
            })
        }

        override fun onServiceDisconnected(name: ComponentName?) {
            vpnService = null
            vpnServiceBound = false
        }
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext

        methodChannel = MethodChannel(binding.binaryMessenger, METHOD_CHANNEL)
        methodChannel.setMethodCallHandler(this)

        eventChannel = EventChannel(binding.binaryMessenger, EVENT_CHANNEL)
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        unbindVpnService()
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        activityBinding = binding
        binding.addActivityResultListener(this)
        bindVpnService()
    }

    override fun onDetachedFromActivity() {
        activityBinding?.removeActivityResultListener(this)
        activity = null
        activityBinding = null
        unbindVpnService()
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        onAttachedToActivity(binding)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        onDetachedFromActivity()
    }

    private fun bindVpnService() {
        context?.let { ctx ->
            val intent = Intent(ctx, SingboxVpnService::class.java)
            ctx.bindService(intent, serviceConnection, Context.BIND_AUTO_CREATE)
        }
    }

    private fun unbindVpnService() {
        if (vpnServiceBound) {
            context?.unbindService(serviceConnection)
            vpnServiceBound = false
            vpnService = null
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "connect" -> {
                val config = call.argument<String>("config")
                if (config == null) {
                    result.error("INVALID_ARGUMENT", "Config is required", null)
                    return
                }
                connect(config, result)
            }
            "disconnect" -> {
                disconnect(result)
            }
            "getStats" -> {
                getStats(result)
            }
            "hasVpnPermission" -> {
                hasVpnPermission(result)
            }
            "requestVpnPermission" -> {
                requestVpnPermission(result)
            }
            "getVersion" -> {
                result.success(MihomoCore.version())
            }
            "switchProxy" -> {
                // Fast switch:不重启 mihomo,直接 PUT /proxies/PROXY {"name": proxyName}
                // 毫秒级切换节点,tun/mihomo/socket 全程保持,用户无感知。
                val proxyName = call.argument<String>("proxyName")
                if (proxyName == null) {
                    result.error("INVALID_ARGUMENT", "proxyName is required", null)
                    return
                }
                switchProxy(proxyName, result)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun connect(config: String, result: MethodChannel.Result) {
        // First check VPN permission
        val prepareIntent = VpnService.prepare(context)
        if (prepareIntent != null) {
            // Need to request permission first
            pendingResult = result
            activity?.startActivityForResult(prepareIntent, VPN_PERMISSION_REQUEST_CODE)
            return
        }

        // Start VPN service
        context?.let { ctx ->
            val intent = Intent(ctx, SingboxVpnService::class.java).apply {
                action = SingboxVpnService.ACTION_CONNECT
                putExtra(SingboxVpnService.EXTRA_CONFIG, config)
            }

            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                ctx.startForegroundService(intent)
            } else {
                ctx.startService(intent)
            }

            result.success(true)
        } ?: result.error("NO_CONTEXT", "Context not available", null)
    }

    private fun disconnect(result: MethodChannel.Result) {
        // 用户主动点断开 → FULL_STOP:mihomo 停,tun 关,流量走系统直连。
        // Kill Switch(PROXY→REJECT 保留 tun)只在意外掉线/VpnService 被系统杀时
        // 才触发,防 IP 泄漏。之前默认 DISCONNECT 走 Kill Switch → UI 状态回读为
        // connected → 用户按几次断都断不开(现象:"为什么断开不了")。
        context?.let { ctx ->
            val intent = Intent(ctx, SingboxVpnService::class.java).apply {
                action = SingboxVpnService.ACTION_FULL_STOP
            }
            ctx.startService(intent)
            result.success(true)
        } ?: result.error("NO_CONTEXT", "Context not available", null)
    }

    /**
     * Fast switch:mihomo REST API PUT /proxies/PROXY {"name": proxyName}。
     * mihomo 依然运行,tun 依然在,只是 selector 指向新节点。<100ms。
     * 全靠首次连接时 config 就把所有节点写进了 PROXY selector 的 proxies 列表。
     */
    private fun switchProxy(proxyName: String, result: MethodChannel.Result) {
        Thread {
            // 用 raw Socket 而不是 HttpURLConnection:Android 9+ 后者对 http://127.0.0.1
            // 也拦(cleartext),需要 network_security_config 白名单。raw Socket 不受此限。
            val body = "{\"name\":\"$proxyName\"}".toByteArray(Charsets.UTF_8)
            val ok = try {
                java.net.Socket("127.0.0.1", 19090).use { sock ->
                    sock.soTimeout = 3000
                    // HTTP/1.0 匹配手动 nc 测试成功的格式;1.1 会引起 mihomo 400 Bad Request
                    val req = StringBuilder().apply {
                        append("PUT /proxies/PROXY HTTP/1.0\r\n")
                        append("Content-Type: application/json\r\n")
                        append("Content-Length: ").append(body.size).append("\r\n")
                        append("\r\n")
                    }.toString()
                    val out = sock.getOutputStream()
                    val reqBytes = req.toByteArray(Charsets.UTF_8)
                    // 全 dump 出:先构造完整 payload 一次写出,方便对比手动 nc
                    val fullPayload = reqBytes + body
                    android.util.Log.i(
                        "SingboxFlutterPlugin",
                        "switchProxy REQ (bytes=${fullPayload.size}): " +
                            String(fullPayload, Charsets.UTF_8).replace("\r", "\\r").replace("\n", "\\n|")
                    )
                    out.write(fullPayload)
                    out.flush()
                    val inp = sock.getInputStream()
                    val respBuf = StringBuilder()
                    val buf = ByteArray(512)
                    var total = 0
                    while (true) {
                        val n = inp.read(buf)
                        if (n <= 0) break
                        respBuf.append(String(buf, 0, n, Charsets.UTF_8))
                        total += n
                        if (total > 4096) break
                    }
                    val firstLine = respBuf.toString().lineSequence().firstOrNull() ?: ""
                    android.util.Log.i("SingboxFlutterPlugin", "switchProxy($proxyName): $firstLine (bytes=$total)")
                    // 400 时把 response 全 dump 出来看具体错误(限 800 字符防日志爆炸)
                    if (firstLine.contains(" 400 ") || firstLine.contains(" 5")) {
                        android.util.Log.w(
                            "SingboxFlutterPlugin",
                            "switchProxy full resp: " +
                                respBuf.toString().replace("\r", "\\r").replace("\n", "\\n|").take(1500)
                        )
                    }
                    // 2xx 全接受
                    Regex(""" (2\d\d) """).containsMatchIn(" $firstLine ")
                            || firstLine.contains(" 200 ")
                            || firstLine.contains(" 204 ")
                }
            } catch (e: Exception) {
                android.util.Log.w("SingboxFlutterPlugin", "switchProxy failed: $e")
                false
            }
            // 商业级 fast-switch:改 selector 后必须 DELETE /connections 杀掉旧 TCP。
            // mihomo 的 PUT /proxies/PROXY 只影响"下一次"选择,已存在的 keep-alive
            // 连接仍走旧节点 → 浏览器复用老连接 → whatismyip 显示旧节点 IP(用户
            // 抱怨:"切了香港,IP 还是日本")。DELETE /connections 强杀,下次请求
            // 被迫新开 TCP,立刻走新节点。~5ms 开销,值得。
            if (ok) {
                try {
                    java.net.Socket("127.0.0.1", 19090).use { sock ->
                        sock.soTimeout = 3000
                        val req = "DELETE /connections HTTP/1.0\r\n\r\n"
                        sock.getOutputStream().apply {
                            write(req.toByteArray(Charsets.UTF_8))
                            flush()
                        }
                        val firstLine = sock.getInputStream().bufferedReader()
                            .readLine() ?: ""
                        android.util.Log.i(
                            "SingboxFlutterPlugin",
                            "killAllConnections: $firstLine"
                        )
                    }
                } catch (e: Exception) {
                    android.util.Log.w("SingboxFlutterPlugin", "killAllConnections failed: $e")
                }
            }
            activity?.runOnUiThread { result.success(ok) } ?: result.success(ok)
        }.start()
    }

    private fun getStats(result: MethodChannel.Result) {
        vpnService?.let { service ->
            val stats = service.getStats()
            result.success(stats)
        } ?: result.success(mapOf(
            "uploadSpeed" to 0L,
            "downloadSpeed" to 0L,
            "totalUpload" to 0L,
            "totalDownload" to 0L,
            "connectionTime" to 0
        ))
    }

    private fun hasVpnPermission(result: MethodChannel.Result) {
        val prepareIntent = VpnService.prepare(context)
        result.success(prepareIntent == null)
    }

    private fun requestVpnPermission(result: MethodChannel.Result) {
        val prepareIntent = VpnService.prepare(context)
        if (prepareIntent == null) {
            result.success(true)
            return
        }

        pendingResult = result
        activity?.startActivityForResult(prepareIntent, VPN_PERMISSION_REQUEST_CODE)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode == VPN_PERMISSION_REQUEST_CODE) {
            val granted = resultCode == Activity.RESULT_OK
            pendingResult?.success(granted)
            pendingResult = null
            return true
        }
        return false
    }
}
