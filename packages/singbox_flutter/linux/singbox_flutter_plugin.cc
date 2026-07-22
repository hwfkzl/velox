#include "include/singbox_flutter/singbox_flutter_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>

#include <cstring>
#include <string>
#include <fstream>
#include <thread>
#include <chrono>
#include <atomic>

#define SINGBOX_FLUTTER_PLUGIN(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), singbox_flutter_plugin_get_type(), \
                              SingboxFlutterPlugin))

struct _SingboxFlutterPlugin {
  GObject parent_instance;
  FlMethodChannel* method_channel;
  FlEventChannel* event_channel;
  FlEventSink* event_sink;

  GPid singbox_pid;
  gboolean is_connected;
  std::chrono::steady_clock::time_point connection_start_time;
  std::atomic<bool> monitoring_stats;
  std::thread* stats_thread;

  gint64 total_upload;
  gint64 total_download;
  gint64 last_upload;
  gint64 last_download;
};

G_DEFINE_TYPE(SingboxFlutterPlugin, singbox_flutter_plugin, g_object_get_type())

static constexpr int kProxyPort = 10808;
static constexpr int kClashApiPort = 19090;  // Use port 19090 to avoid conflicts with ClashX

// Forward declarations
static void send_status(SingboxFlutterPlugin* self, const gchar* status);
static void send_stats(SingboxFlutterPlugin* self);
static gboolean set_system_proxy(gboolean enabled);
static void start_singbox(SingboxFlutterPlugin* self, const gchar* config_path);
static void stop_singbox(SingboxFlutterPlugin* self);
static void start_stats_monitoring(SingboxFlutterPlugin* self);
static void stop_stats_monitoring(SingboxFlutterPlugin* self);
static gchar* get_config_file_path();
static gchar* get_singbox_path();

static void connect_vpn(SingboxFlutterPlugin* self, const gchar* config,
                        FlMethodCall* method_call) {
  if (self->is_connected) {
    g_autoptr(FlValue) error = fl_value_new_string("Already connected");
    fl_method_call_respond_error(method_call, "ALREADY_CONNECTED",
                                 "Already connected", error, nullptr);
    return;
  }

  send_status(self, "connecting");

  // Write config to file
  gchar* config_path = get_config_file_path();
  std::ofstream config_file(config_path);
  if (!config_file) {
    send_status(self, "error");
    g_autoptr(FlValue) error = fl_value_new_string("Failed to write config");
    fl_method_call_respond_error(method_call, "CONFIG_ERROR",
                                 "Failed to write config file", error, nullptr);
    g_free(config_path);
    return;
  }
  config_file << config;
  config_file.close();

  // Start sing-box
  start_singbox(self, config_path);
  g_free(config_path);

  // Wait for sing-box to start
  g_usleep(1000000);  // 1 second

  if (self->singbox_pid > 0) {
    // Set system proxy
    if (set_system_proxy(TRUE)) {
      self->is_connected = TRUE;
      self->connection_start_time = std::chrono::steady_clock::now();
      start_stats_monitoring(self);
      send_status(self, "connected");
      g_autoptr(FlValue) result = fl_value_new_bool(TRUE);
      fl_method_call_respond_success(method_call, result, nullptr);
    } else {
      stop_singbox(self);
      send_status(self, "error");
      g_autoptr(FlValue) error = fl_value_new_string("Failed to set proxy");
      fl_method_call_respond_error(method_call, "PROXY_ERROR",
                                   "Failed to set system proxy", error, nullptr);
    }
  } else {
    send_status(self, "error");
    g_autoptr(FlValue) error = fl_value_new_string("Failed to start");
    fl_method_call_respond_error(method_call, "START_ERROR",
                                 "Failed to start sing-box", error, nullptr);
  }
}

static void disconnect_vpn(SingboxFlutterPlugin* self, FlMethodCall* method_call) {
  send_status(self, "disconnecting");

  stop_stats_monitoring(self);
  set_system_proxy(FALSE);
  stop_singbox(self);

  self->is_connected = FALSE;
  self->total_upload = 0;
  self->total_download = 0;
  self->last_upload = 0;
  self->last_download = 0;

  send_status(self, "disconnected");

  g_autoptr(FlValue) result = fl_value_new_bool(TRUE);
  fl_method_call_respond_success(method_call, result, nullptr);
}

static FlValue* get_stats(SingboxFlutterPlugin* self) {
  gint64 connection_time = 0;
  if (self->is_connected) {
    auto now = std::chrono::steady_clock::now();
    connection_time = std::chrono::duration_cast<std::chrono::seconds>(
        now - self->connection_start_time).count();
  }

  g_autoptr(FlValue) stats = fl_value_new_map();
  fl_value_set_string_take(stats, "uploadSpeed",
                           fl_value_new_int(self->total_upload - self->last_upload));
  fl_value_set_string_take(stats, "downloadSpeed",
                           fl_value_new_int(self->total_download - self->last_download));
  fl_value_set_string_take(stats, "totalUpload",
                           fl_value_new_int(self->total_upload));
  fl_value_set_string_take(stats, "totalDownload",
                           fl_value_new_int(self->total_download));
  fl_value_set_string_take(stats, "connectionTime",
                           fl_value_new_int(connection_time));

  return fl_value_ref(stats);
}

static void method_call_cb(FlMethodChannel* channel, FlMethodCall* method_call,
                          gpointer user_data) {
  SingboxFlutterPlugin* self = SINGBOX_FLUTTER_PLUGIN(user_data);
  const gchar* method = fl_method_call_get_name(method_call);

  if (strcmp(method, "connect") == 0) {
    FlValue* args = fl_method_call_get_args(method_call);
    FlValue* config_value = fl_value_lookup_string(args, "config");
    if (config_value != nullptr) {
      const gchar* config = fl_value_get_string(config_value);
      connect_vpn(self, config, method_call);
    } else {
      g_autoptr(FlValue) error = fl_value_new_string("Config is required");
      fl_method_call_respond_error(method_call, "INVALID_ARGUMENT",
                                   "Config is required", error, nullptr);
    }
  } else if (strcmp(method, "disconnect") == 0) {
    disconnect_vpn(self, method_call);
  } else if (strcmp(method, "getStats") == 0) {
    g_autoptr(FlValue) stats = get_stats(self);
    fl_method_call_respond_success(method_call, stats, nullptr);
  } else if (strcmp(method, "hasVpnPermission") == 0) {
    g_autoptr(FlValue) result = fl_value_new_bool(TRUE);
    fl_method_call_respond_success(method_call, result, nullptr);
  } else if (strcmp(method, "requestVpnPermission") == 0) {
    g_autoptr(FlValue) result = fl_value_new_bool(TRUE);
    fl_method_call_respond_success(method_call, result, nullptr);
  } else if (strcmp(method, "getVersion") == 0) {
    g_autoptr(FlValue) result = fl_value_new_string("1.8.0");
    fl_method_call_respond_success(method_call, result, nullptr);
  } else {
    fl_method_call_respond_not_implemented(method_call, nullptr);
  }
}

static FlMethodErrorResponse* event_listen_cb(FlEventChannel* channel,
                                              FlValue* args,
                                              gpointer user_data) {
  SingboxFlutterPlugin* self = SINGBOX_FLUTTER_PLUGIN(user_data);
  self->event_sink = fl_event_channel_get_event_sink(channel);
  return nullptr;
}

static FlMethodErrorResponse* event_cancel_cb(FlEventChannel* channel,
                                              FlValue* args,
                                              gpointer user_data) {
  SingboxFlutterPlugin* self = SINGBOX_FLUTTER_PLUGIN(user_data);
  self->event_sink = nullptr;
  return nullptr;
}

static void send_status(SingboxFlutterPlugin* self, const gchar* status) {
  if (self->event_sink == nullptr) return;

  g_autoptr(FlValue) event = fl_value_new_map();
  fl_value_set_string_take(event, "type", fl_value_new_string("statusChanged"));
  fl_value_set_string_take(event, "status", fl_value_new_string(status));
  fl_event_sink_send(self->event_sink, event, nullptr);
}

static void send_stats(SingboxFlutterPlugin* self) {
  if (self->event_sink == nullptr) return;

  gint64 connection_time = 0;
  if (self->is_connected) {
    auto now = std::chrono::steady_clock::now();
    connection_time = std::chrono::duration_cast<std::chrono::seconds>(
        now - self->connection_start_time).count();
  }

  g_autoptr(FlValue) event = fl_value_new_map();
  fl_value_set_string_take(event, "type", fl_value_new_string("stats"));
  fl_value_set_string_take(event, "uploadSpeed",
                           fl_value_new_int(self->total_upload - self->last_upload));
  fl_value_set_string_take(event, "downloadSpeed",
                           fl_value_new_int(self->total_download - self->last_download));
  fl_value_set_string_take(event, "totalUpload",
                           fl_value_new_int(self->total_upload));
  fl_value_set_string_take(event, "totalDownload",
                           fl_value_new_int(self->total_download));
  fl_value_set_string_take(event, "connectionTime",
                           fl_value_new_int(connection_time));
  fl_event_sink_send(self->event_sink, event, nullptr);
}

static gboolean set_system_proxy(gboolean enabled) {
  gchar* command;

  if (enabled) {
    // Try GNOME gsettings first
    command = g_strdup_printf(
        "gsettings set org.gnome.system.proxy mode 'manual' && "
        "gsettings set org.gnome.system.proxy.http host '127.0.0.1' && "
        "gsettings set org.gnome.system.proxy.http port %d && "
        "gsettings set org.gnome.system.proxy.https host '127.0.0.1' && "
        "gsettings set org.gnome.system.proxy.https port %d && "
        "gsettings set org.gnome.system.proxy.socks host '127.0.0.1' && "
        "gsettings set org.gnome.system.proxy.socks port %d",
        kProxyPort, kProxyPort, kProxyPort);
  } else {
    command = g_strdup("gsettings set org.gnome.system.proxy mode 'none'");
  }

  gint exit_status;
  gboolean result = g_spawn_command_line_sync(command, nullptr, nullptr,
                                              &exit_status, nullptr);
  g_free(command);

  // If gsettings fails, try KDE's kwriteconfig
  if (!result || exit_status != 0) {
    if (enabled) {
      command = g_strdup_printf(
          "kwriteconfig5 --file kioslaverc --group 'Proxy Settings' --key ProxyType 1 && "
          "kwriteconfig5 --file kioslaverc --group 'Proxy Settings' --key httpProxy 'http://127.0.0.1:%d' && "
          "kwriteconfig5 --file kioslaverc --group 'Proxy Settings' --key httpsProxy 'http://127.0.0.1:%d' && "
          "kwriteconfig5 --file kioslaverc --group 'Proxy Settings' --key socksProxy 'socks://127.0.0.1:%d'",
          kProxyPort, kProxyPort, kProxyPort);
    } else {
      command = g_strdup(
          "kwriteconfig5 --file kioslaverc --group 'Proxy Settings' --key ProxyType 0");
    }

    result = g_spawn_command_line_sync(command, nullptr, nullptr,
                                       &exit_status, nullptr);
    g_free(command);
  }

  return result && exit_status == 0;
}

static void start_singbox(SingboxFlutterPlugin* self, const gchar* config_path) {
  gchar* singbox_path = get_singbox_path();
  gchar* argv[] = {singbox_path, (gchar*)"run", (gchar*)"-c", (gchar*)config_path, nullptr};

  GError* error = nullptr;
  gboolean result = g_spawn_async(
      nullptr,      // working_directory
      argv,         // argv
      nullptr,      // envp
      G_SPAWN_DO_NOT_REAP_CHILD,
      nullptr,      // child_setup
      nullptr,      // user_data
      &self->singbox_pid,
      &error);

  g_free(singbox_path);

  if (!result) {
    g_warning("Failed to start sing-box: %s", error->message);
    g_error_free(error);
    self->singbox_pid = 0;
  }
}

static void stop_singbox(SingboxFlutterPlugin* self) {
  if (self->singbox_pid > 0) {
    kill(self->singbox_pid, SIGTERM);
    g_spawn_close_pid(self->singbox_pid);
    self->singbox_pid = 0;
  }
}

static void fetch_clash_stats(SingboxFlutterPlugin* self) {
  // Fetch stats from Clash API using curl
  gchar* command = g_strdup_printf("curl -s http://127.0.0.1:%d/connections", kClashApiPort);
  gchar* output = nullptr;
  gint exit_status;

  if (g_spawn_command_line_sync(command, &output, nullptr, &exit_status, nullptr) && exit_status == 0 && output) {
    // Parse JSON response to extract uploadTotal and downloadTotal
    gchar* upload_pos = g_strstr_len(output, -1, "\"uploadTotal\":");
    gchar* download_pos = g_strstr_len(output, -1, "\"downloadTotal\":");

    if (upload_pos) {
      upload_pos += 14;  // length of "\"uploadTotal\":"
      self->total_upload = g_ascii_strtoll(upload_pos, nullptr, 10);
    }
    if (download_pos) {
      download_pos += 16;  // length of "\"downloadTotal\":"
      self->total_download = g_ascii_strtoll(download_pos, nullptr, 10);
    }
    g_free(output);
  }
  g_free(command);
}

static void start_stats_monitoring(SingboxFlutterPlugin* self) {
  if (self->monitoring_stats) return;

  self->monitoring_stats = true;
  self->stats_thread = new std::thread([self]() {
    while (self->monitoring_stats) {
      self->last_upload = self->total_upload;
      self->last_download = self->total_download;
      fetch_clash_stats(self);
      send_stats(self);
      std::this_thread::sleep_for(std::chrono::seconds(1));
    }
  });
}

static void stop_stats_monitoring(SingboxFlutterPlugin* self) {
  self->monitoring_stats = false;
  if (self->stats_thread != nullptr) {
    self->stats_thread->join();
    delete self->stats_thread;
    self->stats_thread = nullptr;
  }
}

static gchar* get_config_file_path() {
  return g_build_filename(g_get_tmp_dir(), "singbox_config.json", nullptr);
}

static gchar* get_singbox_path() {
  // Check common locations
  const gchar* paths[] = {
      "/usr/local/bin/sing-box",
      "/usr/bin/sing-box",
      "~/.local/bin/sing-box"
  };

  for (const gchar* path : paths) {
    gchar* expanded_path;
    if (path[0] == '~') {
      expanded_path = g_build_filename(g_get_home_dir(), path + 2, nullptr);
    } else {
      expanded_path = g_strdup(path);
    }

    if (g_file_test(expanded_path, G_FILE_TEST_EXISTS)) {
      return expanded_path;
    }
    g_free(expanded_path);
  }

  return g_strdup("sing-box");
}

static void singbox_flutter_plugin_dispose(GObject* object) {
  SingboxFlutterPlugin* self = SINGBOX_FLUTTER_PLUGIN(object);

  stop_stats_monitoring(self);
  stop_singbox(self);
  set_system_proxy(FALSE);

  g_clear_object(&self->method_channel);
  g_clear_object(&self->event_channel);

  G_OBJECT_CLASS(singbox_flutter_plugin_parent_class)->dispose(object);
}

static void singbox_flutter_plugin_class_init(SingboxFlutterPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = singbox_flutter_plugin_dispose;
}

static void singbox_flutter_plugin_init(SingboxFlutterPlugin* self) {
  self->singbox_pid = 0;
  self->is_connected = FALSE;
  self->monitoring_stats = false;
  self->stats_thread = nullptr;
  self->event_sink = nullptr;
  self->total_upload = 0;
  self->total_download = 0;
  self->last_upload = 0;
  self->last_download = 0;
}

void singbox_flutter_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  SingboxFlutterPlugin* plugin = SINGBOX_FLUTTER_PLUGIN(
      g_object_new(singbox_flutter_plugin_get_type(), nullptr));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();

  plugin->method_channel = fl_method_channel_new(
      fl_plugin_registrar_get_messenger(registrar),
      "com.velox.singbox_flutter/method",
      FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(
      plugin->method_channel, method_call_cb, g_object_ref(plugin),
      g_object_unref);

  plugin->event_channel = fl_event_channel_new(
      fl_plugin_registrar_get_messenger(registrar),
      "com.velox.singbox_flutter/events",
      FL_METHOD_CODEC(codec));
  fl_event_channel_set_stream_handlers(
      plugin->event_channel, event_listen_cb, event_cancel_cb,
      g_object_ref(plugin), g_object_unref);

  g_object_unref(plugin);
}
