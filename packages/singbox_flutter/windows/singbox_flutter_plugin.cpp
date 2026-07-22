// Velox Windows plugin — mihomo (Clash Meta) proxy 模式 + TUN 模式 (Plan C)
//
// 代理模式：CreateProcessA 直接起 mihomo.exe，stdout/stderr 重定向到 log 文件。
// TUN 模式 (Plan C)：ShellExecuteEx + lpVerb="runas" 弹一次 UAC 提权 mihomo 子进程。
//   - wintun.dll 已在 CMakeLists.txt 里 bundle 到 exe 同目录，mihomo 会自动加载。
//   - 提权后 stdout/stderr 无法重定向（ShellExecuteEx 没有 STARTUPINFO；
//     且非管理员父进程不能把 pipe handle 继承给管理员子进程），故 TUN 分支只保留
//     进程句柄用于 wait/kill，日志走 mihomo 自己的 file logging + Clash API。
//   - 用户点 UAC "否" → GetLastError()==ERROR_CANCELLED (1223)，StartMihomo 返回 false。
//
// 架构对齐：
//   - 使用 mihomo.exe 作为内核（和 macOS 一致）
//   - 读取 Dart 生成的 mihomo YAML 配置
//   - 端口 17890 (mixed-port) / 19090 (Clash API)，和 macOS 一致
//   - 节点切换通过 Clash API PUT /proxies/GLOBAL（热切换，零停顿）

#include "include/singbox_flutter/singbox_flutter_plugin_c_api.h"

#include <flutter/method_channel.h>
#include <flutter/event_channel.h>
#include <flutter/event_stream_handler_functions.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <windows.h>
#include <wininet.h>
#include <shlobj.h>
#include <shellapi.h>

#include <memory>
#include <string>
#include <sstream>
#include <thread>
#include <chrono>
#include <atomic>
#include <fstream>
#include <filesystem>
#include <mutex>

#pragma comment(lib, "wininet.lib")
#pragma comment(lib, "shell32.lib")

namespace singbox_flutter {

class SingboxFlutterPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  SingboxFlutterPlugin();
  virtual ~SingboxFlutterPlugin();

  SingboxFlutterPlugin(const SingboxFlutterPlugin&) = delete;
  SingboxFlutterPlugin& operator=(const SingboxFlutterPlugin&) = delete;

 private:
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  void Connect(const std::string& config,
               const std::string& selectedProxyName,
               bool tunEnabled,
               std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void Disconnect(std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  flutter::EncodableMap GetStats();
  std::string GetVersion();

  // Proxy switching via Clash API (no process restart)
  bool SwitchProxyByName(const std::string& name);

  // tunEnabled=true → ShellExecuteEx runas 提权（Plan C）;false → CreateProcessA 常规启动
  bool StartMihomo(const std::string& configPath, bool tunEnabled);
  void StopMihomo();
  bool SetSystemProxy(bool enabled);
  void StartStatsMonitoring();
  void StopStatsMonitoring();
  void SendStatus(const std::string& status);
  void SendStats();

  // Paths
  std::string GetConfigFilePath();
  std::string GetMihomoPath();
  std::string GetWorkDir();
  std::string GetLogDir();
  void NativeLog(const std::string& msg);

  // Clash API helpers
  std::string HttpRequest(const std::string& method, const std::string& path,
                          const std::string& body, int timeoutMs = 3000);

  std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> event_sink_;
  HANDLE mihomo_process_ = nullptr;
  // 记录当前 mihomo 是否以提权方式启动。切换 TUN <-> proxy 时,
  // 若期望的提权状态与当前不符,必须重启 mihomo(热重载不能改进程 token)。
  std::atomic<bool> mihomo_is_elevated_{false};
  std::atomic<bool> is_connected_{false};
  std::atomic<bool> monitoring_stats_{false};
  std::thread stats_thread_;
  std::chrono::steady_clock::time_point connection_start_time_;

  int64_t total_upload_ = 0;
  int64_t total_download_ = 0;
  int64_t last_upload_ = 0;
  int64_t last_download_ = 0;

  // 和 macOS 对齐：17890 代理 + 19090 API（避开 Clash Verge 的 7890 / 9090）
  static constexpr int kProxyPort = 17890;
  static constexpr int kClashApiPort = 19090;
};

void SingboxFlutterPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  auto plugin = std::make_unique<SingboxFlutterPlugin>();

  auto method_channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "com.velox.singbox_flutter/method",
          &flutter::StandardMethodCodec::GetInstance());

  auto event_channel =
      std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
          registrar->messenger(), "com.velox.singbox_flutter/events",
          &flutter::StandardMethodCodec::GetInstance());

  auto* plugin_ptr = plugin.get();

  method_channel->SetMethodCallHandler(
      [plugin_ptr](const auto &call, auto result) {
        plugin_ptr->HandleMethodCall(call, std::move(result));
      });

  auto stream_handler = std::make_unique<flutter::StreamHandlerFunctions<flutter::EncodableValue>>(
      [plugin_ptr](const flutter::EncodableValue* arguments,
                   std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& events)
          -> std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> {
        plugin_ptr->event_sink_ = std::move(events);
        return nullptr;
      },
      [plugin_ptr](const flutter::EncodableValue* arguments)
          -> std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> {
        plugin_ptr->event_sink_ = nullptr;
        return nullptr;
      });

  event_channel->SetStreamHandler(std::move(stream_handler));

  registrar->AddPlugin(std::move(plugin));
}

SingboxFlutterPlugin::SingboxFlutterPlugin() {}

SingboxFlutterPlugin::~SingboxFlutterPlugin() {
  StopStatsMonitoring();
  StopMihomo();
  SetSystemProxy(false);
}

void SingboxFlutterPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const std::string& method = method_call.method_name();

  if (method == "connect") {
    const auto* args = std::get_if<flutter::EncodableMap>(method_call.arguments());
    if (args) {
      auto config_it = args->find(flutter::EncodableValue("config"));
      auto name_it = args->find(flutter::EncodableValue("selectedProxyName"));
      auto tun_it = args->find(flutter::EncodableValue("tun_enabled"));
      std::string config;
      std::string selectedProxyName = "proxy";
      bool tunEnabled = false;
      if (config_it != args->end()) {
        const auto* c = std::get_if<std::string>(&config_it->second);
        if (c) config = *c;
      }
      if (name_it != args->end()) {
        const auto* n = std::get_if<std::string>(&name_it->second);
        if (n) selectedProxyName = *n;
      }
      // Dart 端 mihomo_service.dart 会传 'tun_enabled' bool（Plan C）
      // 缺省视为 false → 走非提权 CreateProcessA 分支
      if (tun_it != args->end()) {
        const auto* b = std::get_if<bool>(&tun_it->second);
        if (b) tunEnabled = *b;
      }
      if (!config.empty()) {
        Connect(config, selectedProxyName, tunEnabled, std::move(result));
        return;
      }
    }
    result->Error("INVALID_ARGUMENT", "Config is required");
  } else if (method == "disconnect") {
    Disconnect(std::move(result));
  } else if (method == "getStats") {
    result->Success(flutter::EncodableValue(GetStats()));
  } else if (method == "hasVpnPermission") {
    // Windows proxy 模式不需要 VPN 权限
    result->Success(flutter::EncodableValue(true));
  } else if (method == "requestVpnPermission") {
    result->Success(flutter::EncodableValue(true));
  } else if (method == "getVersion") {
    result->Success(flutter::EncodableValue(GetVersion()));
  } else if (method == "warmupAuth") {
    // Windows 不需要 helper 预热
    result->Success(flutter::EncodableValue(true));
  } else if (method == "uninstallHelper") {
    // Windows 没有 helper
    result->Success(flutter::EncodableValue(true));
  } else if (method == "patchTunMode") {
    // Windows Plan C：TUN 开/关需要跨提权边界（普通↔管理员），
    // 无法用 Clash API PUT /configs 热重载完成 → 返回 false，
    // Dart 层 (MihomoService.patchTunMode) 收到 false 会走完整重连路径，
    // 重连时 Connect() 会根据新配置里的 tun.enable 决定是否走 runas 提权。
    NativeLog("patchTunMode: returning false; caller should full-reconnect");
    result->Success(flutter::EncodableValue(false));
  } else if (method == "switchProxy") {
    // 节点切换：通过 Clash API PUT /proxies/GLOBAL
    // Dart 端(mihomo_service.dart::switchProxy) 传 {'proxyName': ...}，
    // 键名必须严格对齐，之前误用 "name" → INVALID_ARGUMENT 死循环。
    const auto* args = std::get_if<flutter::EncodableMap>(method_call.arguments());
    if (args) {
      auto name_it = args->find(flutter::EncodableValue("proxyName"));
      if (name_it != args->end()) {
        const auto* name = std::get_if<std::string>(&name_it->second);
        if (name) {
          bool ok = SwitchProxyByName(*name);
          result->Success(flutter::EncodableValue(ok));
          return;
        }
      }
    }
    result->Error("INVALID_ARGUMENT", "proxyName is required");
  } else {
    result->NotImplemented();
  }
}

void SingboxFlutterPlugin::Connect(
    const std::string& config,
    const std::string& selectedProxyName,
    bool tunEnabled,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  NativeLog(std::string("Connect: tunEnabled=") + (tunEnabled ? "true" : "false") +
            " current_elevated=" + (mihomo_is_elevated_ ? "true" : "false"));
  // 已连接 且 提权状态匹配 → 尝试热重载（不重启 mihomo）
  // 提权状态不匹配（TUN <-> proxy 切换）时,必须重启 mihomo,因为进程 token 不能中途换。
  if (is_connected_ && mihomo_process_ != nullptr &&
      mihomo_is_elevated_ == tunEnabled) {
    SendStatus("connecting");

    std::string configPath = GetConfigFilePath();
    std::ofstream config_file(configPath);
    if (!config_file) {
      result->Error("CONFIG_ERROR", "Failed to write config file");
      return;
    }
    config_file << config;
    config_file.close();

    // 热重载
    std::string body = "{\"path\":\"" + configPath + "\"}";
    std::string resp = HttpRequest("PUT", "/configs?force=true", body);
    if (!resp.empty()) {
      // 热重载成功，切到正确的节点
      SwitchProxyByName(selectedProxyName);
      SendStatus("connected");
      result->Success(flutter::EncodableValue(true));
      return;
    }
    // 热重载失败，退回完整重启
    StopMihomo();
  } else if (is_connected_ && mihomo_process_ != nullptr) {
    // 提权状态切换 → 强制关掉旧 mihomo,让后面走 StartMihomo 重启
    NativeLog("Connect: elevation mismatch (was " +
              std::string(mihomo_is_elevated_ ? "elevated" : "normal") +
              ", need " + (tunEnabled ? "elevated" : "normal") +
              ") — forcing full restart");
    StopMihomo();
  }

  SendStatus("connecting");

  // 写入 config 文件（mihomo YAML）
  std::string configPath = GetConfigFilePath();
  std::ofstream config_file(configPath);
  if (!config_file) {
    SendStatus("error");
    result->Error("CONFIG_ERROR", "Failed to write config file");
    return;
  }
  config_file << config;
  config_file.close();

  // 启动 mihomo
  // Plan C：tunEnabled=true 时走 ShellExecuteEx runas 提权（会弹一次 UAC），
  // 用户拒绝 UAC → StartMihomo 返回 false，此处报 START_ERROR。
  if (!StartMihomo(configPath, tunEnabled)) {
    SendStatus("error");
    result->Error("START_ERROR",
                  tunEnabled
                      ? "Failed to spawn elevated mihomo process. "
                        "User may have declined UAC (ERROR_CANCELLED=1223). "
                        "See %LOCALAPPDATA%\\Velox\\Logs\\mihomo-native.log"
                      : "Failed to spawn mihomo process. See "
                        "%LOCALAPPDATA%\\Velox\\Logs\\mihomo-native.log");
    return;
  }

  // 轮询 Clash API `/version` 探测就绪（最多 5s）,并检测 mihomo 是否已崩
  bool ready = false;
  for (int i = 0; i < 25; ++i) {
    if (mihomo_process_) {
      DWORD ec = 0;
      if (GetExitCodeProcess(mihomo_process_, &ec) && ec != STILL_ACTIVE) {
        NativeLog("Connect: mihomo exited early code=" + std::to_string(ec));
        CloseHandle(mihomo_process_);
        mihomo_process_ = nullptr;
        mihomo_is_elevated_ = false;
        SendStatus("error");
        result->Error("MIHOMO_DIED",
                      "mihomo exited early (code=" + std::to_string(ec) +
                      "). See mihomo-child.log for stderr.");
        return;
      }
    }
    std::string v = HttpRequest("GET", "/version", "", 400);
    if (!v.empty()) {
      NativeLog("Connect: Clash API ready after " + std::to_string(i * 200) + "ms");
      ready = true;
      break;
    }
    std::this_thread::sleep_for(std::chrono::milliseconds(200));
  }

  if (!ready) {
    NativeLog("Connect: Clash API 127.0.0.1:" + std::to_string(kClashApiPort) +
              " never responded in 5s");
    StopMihomo();
    SendStatus("error");
    result->Error("API_TIMEOUT",
                  "Clash API 127.0.0.1:" + std::to_string(kClashApiPort) +
                  " never responded in 5s. mihomo may have failed to bind port. "
                  "See mihomo-child.log.");
    return;
  }

  // Clash API 起来了 — 切节点（切失败不算致命,GLOBAL 兜底）
  if (!SwitchProxyByName(selectedProxyName)) {
    NativeLog("Connect: SwitchProxyByName failed for '" + selectedProxyName + "', continuing");
  }

  // 设置系统代理
  if (SetSystemProxy(true)) {
    is_connected_ = true;
    connection_start_time_ = std::chrono::steady_clock::now();
    StartStatsMonitoring();
    SendStatus("connected");
    NativeLog("Connect: SUCCESS");
    result->Success(flutter::EncodableValue(true));
  } else {
    NativeLog("Connect: SetSystemProxy failed err=" + std::to_string(GetLastError()));
    StopMihomo();
    SendStatus("error");
    result->Error("PROXY_ERROR", "Failed to set system proxy");
  }
}

void SingboxFlutterPlugin::Disconnect(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  SendStatus("disconnecting");

  StopStatsMonitoring();
  SetSystemProxy(false);
  StopMihomo();

  is_connected_ = false;
  total_upload_ = 0;
  total_download_ = 0;
  last_upload_ = 0;
  last_download_ = 0;

  SendStatus("disconnected");
  result->Success(flutter::EncodableValue(true));
}

flutter::EncodableMap SingboxFlutterPlugin::GetStats() {
  int64_t connection_time = 0;
  if (is_connected_) {
    auto now = std::chrono::steady_clock::now();
    connection_time = std::chrono::duration_cast<std::chrono::seconds>(
        now - connection_start_time_).count();
  }

  flutter::EncodableMap stats;
  stats[flutter::EncodableValue("uploadSpeed")] =
      flutter::EncodableValue(total_upload_ - last_upload_);
  stats[flutter::EncodableValue("downloadSpeed")] =
      flutter::EncodableValue(total_download_ - last_download_);
  stats[flutter::EncodableValue("totalUpload")] =
      flutter::EncodableValue(total_upload_);
  stats[flutter::EncodableValue("totalDownload")] =
      flutter::EncodableValue(total_download_);
  stats[flutter::EncodableValue("connectionTime")] =
      flutter::EncodableValue(connection_time);

  return stats;
}

std::string SingboxFlutterPlugin::GetVersion() {
  // 调用 mihomo.exe -v 抓 stdout 首行；抓不到就 fallback 到 "mihomo-windows"。
  std::string mihomoPath = GetMihomoPath();
  if (mihomoPath.empty() || GetFileAttributesA(mihomoPath.c_str()) == INVALID_FILE_ATTRIBUTES) {
    return "mihomo-windows";
  }

  SECURITY_ATTRIBUTES sa;
  ZeroMemory(&sa, sizeof(sa));
  sa.nLength = sizeof(sa);
  sa.bInheritHandle = TRUE;
  sa.lpSecurityDescriptor = nullptr;

  HANDLE hReadPipe = nullptr;
  HANDLE hWritePipe = nullptr;
  if (!CreatePipe(&hReadPipe, &hWritePipe, &sa, 0)) {
    return "mihomo-windows";
  }
  // 关闭读端的继承，避免子进程持有
  SetHandleInformation(hReadPipe, HANDLE_FLAG_INHERIT, 0);

  STARTUPINFOA si;
  PROCESS_INFORMATION pi;
  ZeroMemory(&si, sizeof(si));
  si.cb = sizeof(si);
  si.dwFlags = STARTF_USESTDHANDLES | STARTF_USESHOWWINDOW;
  si.wShowWindow = SW_HIDE;
  si.hStdOutput = hWritePipe;
  si.hStdError = hWritePipe;
  si.hStdInput = nullptr;
  ZeroMemory(&pi, sizeof(pi));

  std::string command = "\"" + mihomoPath + "\" -v";
  BOOL ok = CreateProcessA(
      nullptr, const_cast<char*>(command.c_str()),
      nullptr, nullptr, TRUE, CREATE_NO_WINDOW,
      nullptr, nullptr, &si, &pi);

  // 无论 CreateProcess 是否成功都要关掉写端句柄，
  // 否则 ReadFile 永远等不到 EOF。
  CloseHandle(hWritePipe);

  if (!ok) {
    CloseHandle(hReadPipe);
    return "mihomo-windows";
  }

  // 给子进程 1 秒钟输出（-v 应该毫秒级返回）
  WaitForSingleObject(pi.hProcess, 1000);

  std::string output;
  char buffer[512];
  DWORD bytesRead = 0;
  while (ReadFile(hReadPipe, buffer, sizeof(buffer) - 1, &bytesRead, nullptr) && bytesRead > 0) {
    buffer[bytesRead] = '\0';
    output += buffer;
    if (output.size() > 2048) break;  // 保险
  }

  CloseHandle(hReadPipe);
  CloseHandle(pi.hThread);
  CloseHandle(pi.hProcess);

  // 取首行
  size_t nl = output.find_first_of("\r\n");
  if (nl != std::string::npos) output = output.substr(0, nl);
  // trim 尾部空白
  while (!output.empty() && (output.back() == ' ' || output.back() == '\t')) {
    output.pop_back();
  }
  if (output.empty()) return "mihomo-windows";
  return output;
}

bool SingboxFlutterPlugin::SwitchProxyByName(const std::string& name) {
  // 同时切换 GLOBAL 和 PROXY 组，和 macOS 逻辑一致
  std::string safeName = name;
  // 简单转义双引号
  size_t pos = 0;
  while ((pos = safeName.find('"', pos)) != std::string::npos) {
    safeName.replace(pos, 1, "\\\"");
    pos += 2;
  }
  std::string body = "{\"name\":\"" + safeName + "\"}";

  bool any = false;
  if (!HttpRequest("PUT", "/proxies/GLOBAL", body).empty()) any = true;
  if (!HttpRequest("PUT", "/proxies/PROXY", body).empty()) any = true;

  // 关闭所有连接，强制新流量走新节点
  if (any) {
    HttpRequest("DELETE", "/connections", "");
  }

  return any;
}

bool SingboxFlutterPlugin::StartMihomo(const std::string& configPath, bool tunEnabled) {
  // 防御：如果 mihomo_process_ 还持有旧 handle（异常路径漏关）,先释放
  if (mihomo_process_ != nullptr) {
    NativeLog("StartMihomo: WARN mihomo_process_ non-null at entry; closing stale handle");
    CloseHandle(mihomo_process_);
    mihomo_process_ = nullptr;
    mihomo_is_elevated_ = false;
  }

  std::string mihomoPath = GetMihomoPath();
  std::string workDir = GetWorkDir();
  std::string childLog = GetLogDir() + "\\mihomo-child.log";

  NativeLog("StartMihomo: exe=" + mihomoPath);
  NativeLog("StartMihomo: cfg=" + configPath);
  NativeLog("StartMihomo: workdir=" + workDir);
  NativeLog("StartMihomo: childlog=" + childLog);
  NativeLog(std::string("StartMihomo: elevation=") + (tunEnabled ? "runas (UAC)" : "normal"));

  if (GetFileAttributesA(mihomoPath.c_str()) == INVALID_FILE_ATTRIBUTES) {
    NativeLog("StartMihomo: FATAL mihomo.exe not found at " + mihomoPath);
    return false;
  }

  try {
    std::filesystem::create_directories(workDir);
  } catch (const std::exception& e) {
    NativeLog(std::string("StartMihomo: create_directories failed: ") + e.what());
  }

  // ===== Plan C：TUN 模式走 ShellExecuteEx runas 提权 =====
  // ShellExecuteEx 没有 STARTUPINFO → 无法传 stdout/stderr pipe；
  // 且非提权父进程 → 提权子进程的 handle 继承被 UIPI 阻断，日志只能靠 mihomo file logging。
  if (tunEnabled) {
    // 参数字符串（unicode 版本）：-f "cfg" -d "workdir"
    std::wstring wParams;
    {
      auto widen = [](const std::string& s) -> std::wstring {
        if (s.empty()) return L"";
        int n = MultiByteToWideChar(CP_UTF8, 0, s.c_str(), (int)s.size(), nullptr, 0);
        std::wstring w(n, L'\0');
        MultiByteToWideChar(CP_UTF8, 0, s.c_str(), (int)s.size(), w.data(), n);
        return w;
      };
      wParams = L"-f \"" + widen(configPath) + L"\" -d \"" + widen(workDir) + L"\"";
    }
    std::wstring wExe, wDir;
    {
      auto widen = [](const std::string& s) -> std::wstring {
        if (s.empty()) return L"";
        int n = MultiByteToWideChar(CP_UTF8, 0, s.c_str(), (int)s.size(), nullptr, 0);
        std::wstring w(n, L'\0');
        MultiByteToWideChar(CP_UTF8, 0, s.c_str(), (int)s.size(), w.data(), n);
        return w;
      };
      wExe = widen(mihomoPath);
      wDir = widen(workDir);
    }

    SHELLEXECUTEINFOW sei = { sizeof(sei) };
    sei.fMask       = SEE_MASK_NOCLOSEPROCESS | SEE_MASK_NOASYNC;
    sei.lpVerb      = L"runas";                  // 触发 UAC
    sei.lpFile      = wExe.c_str();
    sei.lpParameters= wParams.c_str();
    sei.lpDirectory = wDir.c_str();               // 明确 CWD，否则可能落到 %SYSTEMDIR%
    sei.nShow       = SW_HIDE;                    // 控制台窗口隐藏（console 子系统仍会一闪）

    NativeLog("StartMihomo(runas): invoking ShellExecuteExW ...");
    if (!ShellExecuteExW(&sei)) {
      DWORD err = GetLastError();
      if (err == ERROR_CANCELLED) {
        NativeLog("StartMihomo(runas): USER DECLINED UAC (ERROR_CANCELLED=1223)");
      } else {
        NativeLog("StartMihomo(runas): ShellExecuteExW FAILED err=" + std::to_string(err));
      }
      return false;
    }
    if (!sei.hProcess) {
      NativeLog("StartMihomo(runas): sei.hProcess is null despite success");
      return false;
    }
    mihomo_process_ = sei.hProcess;
    mihomo_is_elevated_ = true;
    NativeLog("StartMihomo(runas): elevated mihomo spawned (stdout/stderr NOT captured; "
              "check mihomo's own file log if configured)");
    return true;
  }

  // ===== 非 TUN：常规 CreateProcessA + stdout/stderr 重定向 =====
  // 打开 child log（重定向 mihomo stdout/stderr,让 YAML 错/端口冲突/缺 wintun 可见）
  SECURITY_ATTRIBUTES sa;
  ZeroMemory(&sa, sizeof(sa));
  sa.nLength = sizeof(sa);
  sa.bInheritHandle = TRUE;
  sa.lpSecurityDescriptor = nullptr;

  HANDLE hLog = CreateFileA(childLog.c_str(),
                            FILE_APPEND_DATA,
                            FILE_SHARE_READ | FILE_SHARE_WRITE,
                            &sa,
                            OPEN_ALWAYS,
                            FILE_ATTRIBUTE_NORMAL,
                            nullptr);
  if (hLog == INVALID_HANDLE_VALUE) {
    NativeLog("StartMihomo: WARN cannot open child log err=" + std::to_string(GetLastError()));
    hLog = nullptr;
  } else {
    const char* hdr = "\r\n===== mihomo child start =====\r\n";
    DWORD wr = 0;
    WriteFile(hLog, hdr, (DWORD)strlen(hdr), &wr, nullptr);
  }

  std::string command = "\"" + mihomoPath + "\" -f \"" + configPath + "\" -d \"" + workDir + "\"";
  NativeLog("StartMihomo: cmd=" + command);

  STARTUPINFOA si;
  PROCESS_INFORMATION pi;
  ZeroMemory(&si, sizeof(si));
  si.cb = sizeof(si);
  si.dwFlags = STARTF_USESHOWWINDOW;
  si.wShowWindow = SW_HIDE;
  if (hLog) {
    si.dwFlags |= STARTF_USESTDHANDLES;
    si.hStdOutput = hLog;
    si.hStdError = hLog;
    si.hStdInput = nullptr;
  }
  ZeroMemory(&pi, sizeof(pi));

  BOOL ok = CreateProcessA(
      nullptr,
      const_cast<char*>(command.c_str()),
      nullptr,
      nullptr,
      hLog ? TRUE : FALSE,
      CREATE_NO_WINDOW,
      nullptr,
      nullptr,
      &si,
      &pi);

  if (hLog) CloseHandle(hLog);

  if (!ok) {
    DWORD err = GetLastError();
    NativeLog("StartMihomo: CreateProcess FAILED err=" + std::to_string(err));
    return false;
  }

  mihomo_process_ = pi.hProcess;
  mihomo_is_elevated_ = false;
  CloseHandle(pi.hThread);
  NativeLog("StartMihomo: pid=" + std::to_string(pi.dwProcessId) + " spawned");
  return true;
}

void SingboxFlutterPlugin::StopMihomo() {
  if (mihomo_process_ != nullptr) {
    TerminateProcess(mihomo_process_, 0);
    CloseHandle(mihomo_process_);
    mihomo_process_ = nullptr;
  }
  mihomo_is_elevated_ = false;
}

bool SingboxFlutterPlugin::SetSystemProxy(bool enabled) {
  INTERNET_PER_CONN_OPTION_LISTA list;
  INTERNET_PER_CONN_OPTIONA options[3];
  DWORD size = sizeof(list);

  list.dwSize = sizeof(list);
  list.pszConnection = nullptr;
  list.dwOptionCount = 3;
  list.pOptions = options;

  if (enabled) {
    options[0].dwOption = INTERNET_PER_CONN_FLAGS;
    options[0].Value.dwValue = PROXY_TYPE_PROXY | PROXY_TYPE_DIRECT;

    std::string proxy_server = "127.0.0.1:" + std::to_string(kProxyPort);
    options[1].dwOption = INTERNET_PER_CONN_PROXY_SERVER;
    options[1].Value.pszValue = const_cast<char*>(proxy_server.c_str());

    options[2].dwOption = INTERNET_PER_CONN_PROXY_BYPASS;
    options[2].Value.pszValue = const_cast<char*>("localhost;127.*;10.*;172.16.*;172.17.*;172.18.*;172.19.*;172.20.*;172.21.*;172.22.*;172.23.*;172.24.*;172.25.*;172.26.*;172.27.*;172.28.*;172.29.*;172.30.*;172.31.*;192.168.*;<local>");
  } else {
    options[0].dwOption = INTERNET_PER_CONN_FLAGS;
    options[0].Value.dwValue = PROXY_TYPE_DIRECT;

    options[1].dwOption = INTERNET_PER_CONN_PROXY_SERVER;
    options[1].Value.pszValue = nullptr;

    options[2].dwOption = INTERNET_PER_CONN_PROXY_BYPASS;
    options[2].Value.pszValue = nullptr;
  }

  bool result = InternetSetOptionA(nullptr, INTERNET_OPTION_PER_CONNECTION_OPTION, &list, size);

  InternetSetOptionA(nullptr, INTERNET_OPTION_SETTINGS_CHANGED, nullptr, 0);
  InternetSetOptionA(nullptr, INTERNET_OPTION_REFRESH, nullptr, 0);

  return result;
}

void SingboxFlutterPlugin::StartStatsMonitoring() {
  if (monitoring_stats_) return;

  monitoring_stats_ = true;
  stats_thread_ = std::thread([this]() {
    while (monitoring_stats_) {
      SendStats();
      std::this_thread::sleep_for(std::chrono::seconds(1));
    }
  });
}

void SingboxFlutterPlugin::StopStatsMonitoring() {
  monitoring_stats_ = false;
  if (stats_thread_.joinable()) {
    stats_thread_.join();
  }
}

void SingboxFlutterPlugin::SendStatus(const std::string& status) {
  if (event_sink_) {
    flutter::EncodableMap event;
    event[flutter::EncodableValue("type")] = flutter::EncodableValue("statusChanged");
    event[flutter::EncodableValue("status")] = flutter::EncodableValue(status);
    event_sink_->Success(flutter::EncodableValue(event));
  }
}

void SingboxFlutterPlugin::SendStats() {
  if (!event_sink_) return;

  last_upload_ = total_upload_;
  last_download_ = total_download_;

  // 从 Clash API 拉流量
  std::string response = HttpRequest("GET", "/connections", "", 2000);
  if (!response.empty()) {
    size_t uploadPos = response.find("\"uploadTotal\":");
    size_t downloadPos = response.find("\"downloadTotal\":");
    try {
      if (uploadPos != std::string::npos) {
        total_upload_ = std::stoll(response.substr(uploadPos + 14));
      }
      if (downloadPos != std::string::npos) {
        total_download_ = std::stoll(response.substr(downloadPos + 16));
      }
    } catch (...) {}
  }

  int64_t connection_time = 0;
  if (is_connected_) {
    auto now = std::chrono::steady_clock::now();
    connection_time = std::chrono::duration_cast<std::chrono::seconds>(
        now - connection_start_time_).count();
  }

  flutter::EncodableMap event;
  event[flutter::EncodableValue("type")] = flutter::EncodableValue("stats");
  event[flutter::EncodableValue("uploadSpeed")] =
      flutter::EncodableValue(total_upload_ - last_upload_);
  event[flutter::EncodableValue("downloadSpeed")] =
      flutter::EncodableValue(total_download_ - last_download_);
  event[flutter::EncodableValue("totalUpload")] =
      flutter::EncodableValue(total_upload_);
  event[flutter::EncodableValue("totalDownload")] =
      flutter::EncodableValue(total_download_);
  event[flutter::EncodableValue("connectionTime")] =
      flutter::EncodableValue(connection_time);

  event_sink_->Success(flutter::EncodableValue(event));
}

std::string SingboxFlutterPlugin::GetConfigFilePath() {
  char temp_path[MAX_PATH];
  GetTempPathA(MAX_PATH, temp_path);
  return std::string(temp_path) + "velox_mihomo.yaml";
}

std::string SingboxFlutterPlugin::GetMihomoPath() {
  // 优先 exe 同目录下的 mihomo.exe（随 app 一起打包）
  char exe_path[MAX_PATH];
  if (GetModuleFileNameA(nullptr, exe_path, MAX_PATH) > 0) {
    std::filesystem::path p = std::filesystem::path(exe_path).parent_path() / "mihomo.exe";
    if (std::filesystem::exists(p)) {
      return p.string();
    }
  }

  // 常见备用位置
  const char* paths[] = {
    ".\\mihomo.exe",
    "C:\\Program Files\\mihomo\\mihomo.exe",
    "C:\\Program Files (x86)\\mihomo\\mihomo.exe",
  };

  for (const auto& path : paths) {
    if (GetFileAttributesA(path) != INVALID_FILE_ATTRIBUTES) {
      return path;
    }
  }

  return "mihomo.exe";
}

std::string SingboxFlutterPlugin::GetWorkDir() {
  // 使用 %LOCALAPPDATA%\Velox 作为 mihomo 工作目录（存 geosite / geoip 数据库）
  char appdata[MAX_PATH];
  if (SHGetFolderPathA(nullptr, CSIDL_LOCAL_APPDATA, nullptr, 0, appdata) == S_OK) {
    return std::string(appdata) + "\\Velox";
  }
  return ".";
}

std::string SingboxFlutterPlugin::GetLogDir() {
  std::string dir = GetWorkDir() + "\\Logs";
  try {
    std::filesystem::create_directories(dir);
  } catch (...) {}
  return dir;
}

void SingboxFlutterPlugin::NativeLog(const std::string& msg) {
  static std::mutex log_mu;
  std::lock_guard<std::mutex> lk(log_mu);
  std::string path = GetLogDir() + "\\mihomo-native.log";
  std::ofstream f(path, std::ios::app);
  if (!f) return;
  SYSTEMTIME st;
  GetLocalTime(&st);
  char ts[40];
  sprintf_s(ts, sizeof(ts), "%04d-%02d-%02dT%02d:%02d:%02d.%03d",
            st.wYear, st.wMonth, st.wDay,
            st.wHour, st.wMinute, st.wSecond, st.wMilliseconds);
  f << ts << " " << msg << "\n";
  OutputDebugStringA(("[velox] " + msg + "\n").c_str());
}

std::string SingboxFlutterPlugin::HttpRequest(
    const std::string& method, const std::string& path,
    const std::string& body, int timeoutMs) {
  std::string host = "127.0.0.1";
  std::string response;

  HINTERNET hSession = InternetOpenA("VeloxPlugin", INTERNET_OPEN_TYPE_DIRECT, nullptr, nullptr, 0);
  if (!hSession) return response;

  DWORD timeout = (DWORD)timeoutMs;
  InternetSetOptionA(hSession, INTERNET_OPTION_CONNECT_TIMEOUT, &timeout, sizeof(timeout));
  InternetSetOptionA(hSession, INTERNET_OPTION_SEND_TIMEOUT, &timeout, sizeof(timeout));
  InternetSetOptionA(hSession, INTERNET_OPTION_RECEIVE_TIMEOUT, &timeout, sizeof(timeout));

  HINTERNET hConnect = InternetConnectA(hSession, host.c_str(), (INTERNET_PORT)kClashApiPort,
                                        nullptr, nullptr, INTERNET_SERVICE_HTTP, 0, 0);
  if (!hConnect) {
    InternetCloseHandle(hSession);
    return response;
  }

  HINTERNET hRequest = HttpOpenRequestA(hConnect, method.c_str(), path.c_str(),
                                         nullptr, nullptr, nullptr,
                                         INTERNET_FLAG_RELOAD | INTERNET_FLAG_NO_CACHE_WRITE, 0);
  if (!hRequest) {
    InternetCloseHandle(hConnect);
    InternetCloseHandle(hSession);
    return response;
  }

  const char* headers = "Content-Type: application/json\r\n";
  BOOL sendOk = HttpSendRequestA(hRequest, headers, (DWORD)strlen(headers),
                                  (LPVOID)body.c_str(), (DWORD)body.size());

  if (sendOk) {
    // 检查 status code
    DWORD statusCode = 0;
    DWORD statusSize = sizeof(statusCode);
    if (HttpQueryInfoA(hRequest, HTTP_QUERY_STATUS_CODE | HTTP_QUERY_FLAG_NUMBER,
                       &statusCode, &statusSize, nullptr)) {
      if (statusCode >= 200 && statusCode < 300) {
        char buffer[4096];
        DWORD bytesRead;
        while (InternetReadFile(hRequest, buffer, sizeof(buffer) - 1, &bytesRead) && bytesRead > 0) {
          buffer[bytesRead] = '\0';
          response += buffer;
        }
        // 对于 204 No Content 等空响应，返回一个非空字符串表示成功
        if (response.empty()) response = "{}";
      }
    }
  }

  InternetCloseHandle(hRequest);
  InternetCloseHandle(hConnect);
  InternetCloseHandle(hSession);

  return response;
}

}  // namespace singbox_flutter

void SingboxFlutterPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  singbox_flutter::SingboxFlutterPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
