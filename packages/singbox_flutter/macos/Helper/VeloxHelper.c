/*
 * VeloxHelper.c
 * Privileged LaunchDaemon for com.velox.app
 *
 * Runs as root, listens on a Unix domain socket, and executes privileged
 * operations on behalf of the main app:
 *   - start_tun          : launch mihomo as root for TUN mode (legacy/fallback)
 *   - stop_tun           : kill the mihomo root process (legacy/fallback)
 *   - install_mihomo_svc : install mihomo as a standalone LaunchDaemon system service
 *   - start_mihomo_svc   : kickstart the mihomo LaunchDaemon service
 *   - stop_mihomo_svc    : stop the mihomo LaunchDaemon service (SIGTERM)
 *   - kill_all_mihomo    : force-kill every mihomo process (cleanup / orphan removal)
 *   - set_proxy          : write system HTTP/HTTPS/SOCKS proxy via SCPreferences
 *   - clear_proxy        : remove system proxy settings
 *   - ping               : health-check
 *
 * Protocol: newline-terminated JSON, one command per connection.
 *   Request:  {"cmd":"ping"}\n
 *   Response: {"ok":true}\n  or  {"ok":false,"error":"reason"}\n
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <signal.h>
#include <errno.h>
#include <fcntl.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <sys/stat.h>
#include <sys/wait.h>

#include <CoreFoundation/CoreFoundation.h>
#include <SystemConfiguration/SystemConfiguration.h>

#define SOCKET_PATH       "/var/run/com.velox.app.helper.sock"
#define MAX_BUF           65536

/* ── Mihomo standalone LaunchDaemon paths ───────────────────────────── */
#define MIHOMO_SVC_LABEL  "com.velox.app.mihomo"
#define MIHOMO_SVC_PLIST  "/Library/LaunchDaemons/com.velox.app.mihomo.plist"
#define MIHOMO_INSTALL_DIR "/Library/Application Support/Velox"
#define MIHOMO_BIN_PATH   "/Library/Application Support/Velox/mihomo"
/* Config written by the app (world-writable /tmp, readable by root daemon) */
#define MIHOMO_CONFIG_PATH "/tmp/velox_mihomo.yaml"
/* Log file for the LaunchDaemon service */
#define MIHOMO_SVC_LOG    "/tmp/velox_mihomo_svc.log"

static int    g_server_fd = -1;
static pid_t  g_tun_pid   = -1;   /* 当前由 Helper 管理的 TUN mihomo PID，Helper 进程内持久 */

/* ------------------------------------------------------------------ */
/* SIGCHLD：感知子进程退出，避免僵尸进程                                */
/* ------------------------------------------------------------------ */

static void on_child_exit(int sig) {
    (void)sig;
    int status;
    pid_t dead;
    /* 循环收割所有已退出的子进程 */
    while ((dead = waitpid(-1, &status, WNOHANG)) > 0) {
        if (dead == g_tun_pid) {
            fprintf(stderr, "VeloxHelper: mihomo PID=%d exited (status=%d)\n",
                    (int)dead, WEXITSTATUS(status));
            g_tun_pid = -1;
        }
    }
}

/* ------------------------------------------------------------------ */
/* Cleanup                                                             */
/* ------------------------------------------------------------------ */

static void cleanup_and_exit(int sig) {
    (void)sig;
    if (g_server_fd >= 0) {
        close(g_server_fd);
        g_server_fd = -1;
    }
    unlink(SOCKET_PATH);
    _exit(0);
}

/* ------------------------------------------------------------------ */
/* Minimal JSON helpers (no external dependencies)                     */
/* ------------------------------------------------------------------ */

/* Extract string value for "key":"value" — returns 0 on success */
static int json_get_string(const char *json, const char *key,
                            char *out, size_t out_size) {
    char search[256];
    snprintf(search, sizeof(search), "\"%s\":\"", key);
    const char *p = strstr(json, search);
    if (!p) return -1;
    p += strlen(search);
    const char *end = strchr(p, '"');
    if (!end) return -1;
    size_t len = (size_t)(end - p);
    if (len >= out_size) len = out_size - 1;
    memcpy(out, p, len);
    out[len] = '\0';
    return 0;
}

/* Extract integer value for "key":number */
static int json_get_int(const char *json, const char *key, int *out) {
    char search[256];
    snprintf(search, sizeof(search), "\"%s\":", key);
    const char *p = strstr(json, search);
    if (!p) return -1;
    p += strlen(search);
    *out = atoi(p);
    return 0;
}

/* ------------------------------------------------------------------ */
/* Run a command synchronously (safe: no shell, no injection risk)     */
/* Returns exit code, or -1 on fork/exec error.                       */
/* ------------------------------------------------------------------ */

static int run_cmd(const char *path, char *const argv[]) {
    /* Block SIGCHLD while we wait for this specific child, to prevent
     * on_child_exit() from reaping it before our own waitpid() call. */
    sigset_t block_chld, old_mask;
    sigemptyset(&block_chld);
    sigaddset(&block_chld, SIGCHLD);
    sigprocmask(SIG_BLOCK, &block_chld, &old_mask);

    pid_t pid = fork();
    if (pid < 0) {
        sigprocmask(SIG_SETMASK, &old_mask, NULL);
        return -1;
    }
    if (pid == 0) {
        /* Child: redirect stdout/stderr to /dev/null, then exec */
        int devnull = open("/dev/null", O_WRONLY);
        if (devnull >= 0) {
            dup2(devnull, STDOUT_FILENO);
            dup2(devnull, STDERR_FILENO);
            close(devnull);
        }
        /* Restore default SIGCHLD in child so execv'd process is not affected */
        signal(SIGCHLD, SIG_DFL);
        sigprocmask(SIG_SETMASK, &old_mask, NULL);
        execv(path, argv);
        _exit(127);
    }

    /* Parent: wait for this specific child while SIGCHLD is blocked */
    int status = 0;
    waitpid(pid, &status, 0);
    sigprocmask(SIG_SETMASK, &old_mask, NULL);
    return WIFEXITED(status) ? WEXITSTATUS(status) : -1;
}

/* ------------------------------------------------------------------ */
/* 安全：校验要以 root 执行/安装的二进制路径，防止调用方让我们跑任意程序。   */
/* 要求：绝对路径、basename 为 "mihomo"、是普通文件、且 group/other 不可写   */
/* （否则低权限进程可植入恶意二进制）。                                      */
/* ------------------------------------------------------------------ */
static int is_trusted_binary(const char *path) {
    if (!path || path[0] != '/') return 0;
    const char *slash = strrchr(path, '/');
    const char *base = slash ? slash + 1 : path;
    if (strcmp(base, "mihomo") != 0) return 0;
    struct stat st;
    if (stat(path, &st) != 0) return 0;
    if (!S_ISREG(st.st_mode)) return 0;
    if (st.st_mode & (S_IWGRP | S_IWOTH)) return 0;  /* 组/他人可写 → 拒绝 */
    return 1;
}

/* ------------------------------------------------------------------ */
/* System proxy via SCPreferences (works from root without auth)       */
/* ------------------------------------------------------------------ */

static int set_system_proxy(int enabled, int port) {
    SCPreferencesRef prefs = SCPreferencesCreate(kCFAllocatorDefault,
                                                 CFSTR("VeloxHelper"), NULL);
    if (!prefs) {
        fprintf(stderr, "VeloxHelper: SCPreferencesCreate failed\n");
        return -1;
    }

    /* Acquire exclusive lock (blocks up to ~5 s) to avoid commit conflicts */
    if (!SCPreferencesLock(prefs, TRUE)) {
        fprintf(stderr, "VeloxHelper: SCPreferencesLock failed, proceeding anyway\n");
    }

    SCNetworkSetRef netSet = SCNetworkSetCopyCurrent(prefs);
    if (!netSet) {
        CFRelease(prefs);
        fprintf(stderr, "VeloxHelper: SCNetworkSetCopyCurrent failed\n");
        return -1;
    }

    CFArrayRef services = SCNetworkSetCopyServices(netSet);
    CFRelease(netSet);
    if (!services) {
        CFRelease(prefs);
        return -1;
    }

    CFDictionaryRef proxyDict = NULL;

    if (enabled) {
        CFStringRef host  = CFSTR("127.0.0.1");
        int one = 1;
        CFNumberRef cfOne  = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &one);
        CFNumberRef cfPort = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &port);

        /* Bypass（例外）列表：LAN / 回环 / 链路本地 / 本地域名一律直连，不进代理。
         * 对标 Clash Verge / ClashX 的 macOS 默认例外列表。
         * ExcludeSimpleHostnames=1 等价于 Windows 的 <local>（无点的简单主机名直连）。*/
        const void *bypassItems[] = {
            CFSTR("127.0.0.1"),
            CFSTR("192.168.0.0/16"),
            CFSTR("10.0.0.0/8"),
            CFSTR("172.16.0.0/12"),
            CFSTR("169.254.0.0/16"),
            CFSTR("localhost"),
            CFSTR("*.local"),
        };
        CFArrayRef bypassList = CFArrayCreate(kCFAllocatorDefault, bypassItems,
                                              7, &kCFTypeArrayCallBacks);

        const void *keys[] = {
            kSCPropNetProxiesHTTPEnable,
            kSCPropNetProxiesHTTPProxy,
            kSCPropNetProxiesHTTPPort,
            kSCPropNetProxiesHTTPSEnable,
            kSCPropNetProxiesHTTPSProxy,
            kSCPropNetProxiesHTTPSPort,
            kSCPropNetProxiesSOCKSEnable,
            kSCPropNetProxiesSOCKSProxy,
            kSCPropNetProxiesSOCKSPort,
            kSCPropNetProxiesExceptionsList,
            kSCPropNetProxiesExcludeSimpleHostnames,
        };
        const void *vals[] = {
            cfOne, host, cfPort,
            cfOne, host, cfPort,
            cfOne, host, cfPort,
            bypassList, cfOne,
        };
        proxyDict = CFDictionaryCreate(kCFAllocatorDefault,
                                       keys, vals, 11,
                                       &kCFTypeDictionaryKeyCallBacks,
                                       &kCFTypeDictionaryValueCallBacks);
        CFRelease(cfOne);
        CFRelease(cfPort);
        CFRelease(bypassList);
    } else {
        int zero = 0;
        CFNumberRef cfZero = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &zero);
        const void *keys[] = {
            kSCPropNetProxiesHTTPEnable,
            kSCPropNetProxiesHTTPSEnable,
            kSCPropNetProxiesSOCKSEnable,
        };
        const void *vals[] = { cfZero, cfZero, cfZero };
        proxyDict = CFDictionaryCreate(kCFAllocatorDefault,
                                       keys, vals, 3,
                                       &kCFTypeDictionaryKeyCallBacks,
                                       &kCFTypeDictionaryValueCallBacks);
        CFRelease(cfZero);
    }

    CFIndex count = CFArrayGetCount(services);
    for (CFIndex i = 0; i < count; i++) {
        SCNetworkServiceRef svc =
            (SCNetworkServiceRef)CFArrayGetValueAtIndex(services, i);
        SCNetworkProtocolRef proto =
            SCNetworkServiceCopyProtocol(svc, kSCNetworkProtocolTypeProxies);
        if (proto) {
            SCNetworkProtocolSetConfiguration(proto, proxyDict);
            CFRelease(proto);
        }
    }

    CFRelease(services);
    CFRelease(proxyDict);

    Boolean committed = SCPreferencesCommitChanges(prefs);
    Boolean applied   = SCPreferencesApplyChanges(prefs);
    SCPreferencesUnlock(prefs);
    CFRelease(prefs);

    if (!committed || !applied) {
        fprintf(stderr, "VeloxHelper: SCPreferences commit/apply failed "
                "(committed=%d applied=%d)\n", committed, applied);
        return -1;
    }
    return 0;
}


/* ------------------------------------------------------------------ */
/* Command dispatcher                                                   */
/* ------------------------------------------------------------------ */

static void handle_command(const char *json, char *resp, size_t resp_size) {
    char cmd[64] = {0};
    json_get_string(json, "cmd", cmd, sizeof(cmd));

    /* ---------- ping ---------- */
    if (strcmp(cmd, "ping") == 0) {
        snprintf(resp, resp_size, "{\"ok\":true}");
        return;
    }

    /* ---------- version ---------- */
    /* Bump this string every time new commands are added.
     * The Swift plugin checks this before using new commands;
     * if the version doesn't match, it force-reinstalls the helper. */
    if (strcmp(cmd, "version") == 0) {
        snprintf(resp, resp_size, "{\"ok\":true,\"version\":\"10\"}");
        return;
    }

    /* ---------- start_tun ---------- */
    if (strcmp(cmd, "start_tun") == 0) {
        char singbox[1024] = {0};
        char config[1024]  = {0};
        char workdir[1024] = {0};
        char pid_file[512] = {0};
        char log_file[512] = {0};

        if (json_get_string(json, "singbox",   singbox,   sizeof(singbox))   < 0 ||
            json_get_string(json, "config",    config,    sizeof(config))    < 0 ||
            json_get_string(json, "pid_file",  pid_file,  sizeof(pid_file))  < 0 ||
            json_get_string(json, "log_file",  log_file,  sizeof(log_file))  < 0) {
            snprintf(resp, resp_size,
                     "{\"ok\":false,\"error\":\"start_tun: missing required args\"}");
            return;
        }
        /* 安全：只允许以 root 跑可信的 mihomo 二进制，拒绝任意路径 */
        if (!is_trusted_binary(singbox)) {
            snprintf(resp, resp_size,
                     "{\"ok\":false,\"error\":\"start_tun: untrusted binary path\"}");
            return;
        }
        /* workdir is optional; fall back to /tmp/mihomo if absent */
        if (json_get_string(json, "workdir", workdir, sizeof(workdir)) < 0) {
            strncpy(workdir, "/tmp/mihomo", sizeof(workdir) - 1);
        }

        /* ── 注入内置 geo 数据库到 workdir（缺失/更新时覆盖）──────────────
         * 活跃 TUN 走 child process 架构（start_tun，非 LaunchDaemon），不经过
         * install_mihomo_svc，所以 geo 必须在这里拷。否则 mihomo 找不到
         * geoip.metadb/geosite.dat → 尝试从 GitHub 下载（国内失败）→ 规则模式
         * GEOSITE/GEOIP 分流失效。helper 以 root 运行，可写入 workdir。 */
        {
            char src_geoip[1024]   = {0};
            char src_geosite[1024] = {0};
            json_get_string(json, "geoip",   src_geoip,   sizeof(src_geoip));
            json_get_string(json, "geosite", src_geosite, sizeof(src_geosite));
            mkdir(workdir, 0755);
            if (src_geoip[0] != '\0') {
                char dst[1100];
                snprintf(dst, sizeof(dst), "%s/geoip.metadb", workdir);
                char *cp_args[] = { "/bin/cp", "-f", src_geoip, dst, NULL };
                if (run_cmd("/bin/cp", cp_args) == 0) chmod(dst, 0644);
                else fprintf(stderr, "VeloxHelper: start_tun: copy geoip failed\n");
            }
            if (src_geosite[0] != '\0') {
                char dst[1100];
                snprintf(dst, sizeof(dst), "%s/geosite.dat", workdir);
                char *cp_args[] = { "/bin/cp", "-f", src_geosite, dst, NULL };
                if (run_cmd("/bin/cp", cp_args) == 0) chmod(dst, 0644);
                else fprintf(stderr, "VeloxHelper: start_tun: copy geosite failed\n");
            }
        }

        /* ── 第一步：停止已知的旧 TUN 进程（g_tun_pid，原子替换）──────────── */
        if (g_tun_pid > 0) {
            fprintf(stderr, "VeloxHelper: start_tun: stopping previous TUN PID=%d\n", (int)g_tun_pid);
            kill(g_tun_pid, SIGTERM);
            for (int i = 0; i < 20; i++) {
                if (kill(g_tun_pid, 0) != 0) break;
                usleep(100000);
            }
            if (kill(g_tun_pid, 0) == 0) kill(g_tun_pid, SIGKILL);
            waitpid(g_tun_pid, NULL, WNOHANG);
            g_tun_pid = -1;
        }

        /* ── 第二步：清理进程名匹配的孤立进程（跨 Helper 重启的残留）──────── */
        {
            FILE *kfp = popen("/usr/bin/pgrep -f velox_mihomo", "r");
            if (kfp) {
                char kline[32];
                int kany = 0;
                while (fgets(kline, sizeof(kline), kfp)) {
                    int kp = atoi(kline);
                    if (kp > 0) { kill((pid_t)kp, SIGTERM); kany++; }
                }
                pclose(kfp);
                if (kany > 0) {
                    usleep(700000);
                    kfp = popen("/usr/bin/pgrep -f velox_mihomo", "r");
                    if (kfp) {
                        while (fgets(kline, sizeof(kline), kfp)) {
                            int kp = atoi(kline);
                            if (kp > 0) kill((pid_t)kp, SIGKILL);
                        }
                        pclose(kfp);
                    }
                    usleep(200000);
                }
            }
        }

        /* Remove stale PID file */
        unlink(pid_file);

        pid_t pid = fork();
        if (pid < 0) {
            snprintf(resp, resp_size,
                     "{\"ok\":false,\"error\":\"fork failed: %d\"}", errno);
            return;
        }

        if (pid == 0) {
            /* Child: redirect output to log, detach, exec mihomo */
            int log_fd = open(log_file,
                              O_WRONLY | O_CREAT | O_TRUNC, 0644);
            if (log_fd >= 0) {
                dup2(log_fd, STDOUT_FILENO);
                dup2(log_fd, STDERR_FILENO);
                close(log_fd);
            }
            setsid(); /* detach from parent session */

            /* ── 关键：设置 SAFE_PATHS 允许 mihomo 通过 PUT /configs 热重载 /tmp 下的配置 ──
             * mihomo 1.18+ 有安全机制：PUT /configs { "path": "..." } 只允许
             * 加载 HOME 目录或 SAFE_PATHS 指定路径下的文件。默认会拒绝 /tmp 下的文件，
             * 返回 400 "path is not subpath of home directory or SAFE_PATHS"。
             *
             * 我们的 config 写在 /tmp/velox_mihomo.yaml，所以必须明确允许。
             * 不加这个，热重载会失败，BLoC 回退到完整重启 → 切节点/切 TUN 每次都
             * kill+fork mihomo → "不丝滑"。
             */
            setenv("SAFE_PATHS", "/tmp", 1);
            /*
             * Correct Mihomo invocation: mihomo -f <config> -d <workdir>
             * (Mihomo has no "run" subcommand — that is sing-box syntax.)
             * -f : config file path
             * -d : working directory for GeoSite/GeoIP database files
             */
            char *args[] = { singbox, "-f", config, "-d", workdir, NULL };
            execv(singbox, args);
            _exit(127);
        }

        /* Parent: record PID in global var (primary) and file (compat) */
        g_tun_pid = pid;
        FILE *pf = fopen(pid_file, "w");
        if (pf) {
            fprintf(pf, "%d\n", (int)pid);
            fclose(pf);
        }
        fprintf(stderr, "VeloxHelper: started mihomo TUN PID=%d\n", (int)pid);

        snprintf(resp, resp_size, "{\"ok\":true,\"pid\":%d}", (int)pid);
        return;
    }

    /* ---------- stop_tun ---------- */
    if (strcmp(cmd, "stop_tun") == 0) {
        int param_pid = 0;
        json_get_int(json, "pid", &param_pid);

        /* 优先使用 g_tun_pid（Helper 内部跟踪，最可靠），否则用参数 PID 兜底 */
        pid_t target = (g_tun_pid > 0) ? g_tun_pid : (pid_t)param_pid;

        if (target > 0) {
            fprintf(stderr, "VeloxHelper: stop_tun PID=%d\n", (int)target);
            kill(target, SIGTERM);

            /* Wait up to 2 s for graceful exit */
            for (int i = 0; i < 20; i++) {
                if (kill(target, 0) != 0) break;
                usleep(100000);
            }
            if (kill(target, 0) == 0) {
                kill(target, SIGKILL);
            }
            waitpid(target, NULL, WNOHANG);
            if (g_tun_pid == target) g_tun_pid = -1;
        }

        snprintf(resp, resp_size, "{\"ok\":true}");
        return;
    }

    /* ---------- kill_all_mihomo ---------- */
    /* Kill every running mihomo process by name (handles orphaned root processes). */
    if (strcmp(cmd, "kill_all_mihomo") == 0) {
        int killed = 0;

        /* First pass: SIGTERM */
        FILE *fp = popen("/usr/bin/pgrep -f velox_mihomo", "r");
        if (fp) {
            char line[32];
            while (fgets(line, sizeof(line), fp)) {
                int p = atoi(line);
                if (p > 0) {
                    kill((pid_t)p, SIGTERM);
                    killed++;
                    fprintf(stderr, "VeloxHelper: kill_all_mihomo SIGTERM pid=%d\n", p);
                }
            }
            pclose(fp);
        }

        if (killed > 0) {
            /* Wait up to 2 s for graceful exit */
            for (int i = 0; i < 20; i++) {
                usleep(100000);
                FILE *chk = popen("/usr/bin/pgrep -f velox_mihomo", "r");
                int any = 0;
                if (chk) {
                    char tmp[32];
                    if (fgets(tmp, sizeof(tmp), chk)) any = 1;
                    pclose(chk);
                }
                if (!any) break;
            }
            /* Second pass: SIGKILL any survivors */
            FILE *fp2 = popen("/usr/bin/pgrep -f velox_mihomo", "r");
            if (fp2) {
                char line2[32];
                while (fgets(line2, sizeof(line2), fp2)) {
                    int p = atoi(line2);
                    if (p > 0) {
                        kill((pid_t)p, SIGKILL);
                        fprintf(stderr, "VeloxHelper: kill_all_mihomo SIGKILL pid=%d\n", p);
                    }
                }
                pclose(fp2);
            }
            usleep(200000); /* Let OS release ports */
        }

        /* ── 清理【我们自己的】TUN 残留路由 ──
         * mihomo TUN auto-route 会加这 8 条 CIDR（覆盖全部公网 IPv4）+ 我们的 TUN 段。
         * 但 sing-box / ClashX 等其他 VPN 用的是【完全相同】的 CIDR，只是网关不同。
         * 之前无差别 `route delete <CIDR>` 会连别人的路由一起删 → 一打开我们的 app
         * 就把正在运行的其他 VPN 搞断网（已实测：误删 sing-box 的 1.0.0.0/8 等）。
         * 现在：删之前先用 `route -n get` 查该目标当前的网关，只有指向【我们的 TUN
         * 网关 172.29.201.x】才删；别人的（如 sing-box gw 172.18.x、或物理网关）一律跳过。
         */
        const char *stale_routes[] = {
            "1.0.0.0/8",    "2.0.0.0/7",    "4.0.0.0/6",    "8.0.0.0/5",
            "16.0.0.0/4",   "32.0.0.0/3",   "64.0.0.0/2",   "128.0.0.0/1",
            "198.18.0.0/15",   /* mihomo legacy default TUN subnet */
            "172.29.201.0/30", /* Velox custom TUN subnet */
            NULL
        };
        int cleaned_routes = 0;
        for (int i = 0; stale_routes[i] != NULL; i++) {
            /* 取网络基址（去掉 /prefix）用于 route get 查当前网关 */
            char dest_host[64];
            strncpy(dest_host, stale_routes[i], sizeof(dest_host) - 1);
            dest_host[sizeof(dest_host) - 1] = '\0';
            char *slash = strchr(dest_host, '/');
            if (slash) *slash = '\0';

            char getcmd[256];
            snprintf(getcmd, sizeof(getcmd),
                     "/sbin/route -n get %s 2>/dev/null | "
                     "/usr/bin/awk '/gateway:/{print $2; exit}'", dest_host);
            FILE *gp = popen(getcmd, "r");
            char gw[64] = {0};
            if (gp) { if (fgets(gw, sizeof(gw), gp)) { /* read gw */ } pclose(gp); }
            gw[strcspn(gw, "\r\n")] = '\0';

            /* 只删网关指向我们 TUN(172.29.201.x) 的路由；其它一律不碰 */
            if (strncmp(gw, "172.29.201.", 11) != 0) continue;

            char *route_args[] = {
                "/sbin/route", "-q", "delete", "-net",
                (char *)stale_routes[i], NULL
            };
            if (run_cmd("/sbin/route", route_args) == 0) {
                cleaned_routes++;
                fprintf(stderr, "VeloxHelper: deleted OUR stale route %s (gw %s)\n",
                        stale_routes[i], gw);
            }
        }
        if (cleaned_routes > 0) {
            usleep(300000); /* let routing table settle */
        }

        snprintf(resp, resp_size, "{\"ok\":true,\"killed\":%d,\"routes_cleaned\":%d}",
                 killed, cleaned_routes);
        return;
    }

    /* ---------- set_proxy ---------- */
    if (strcmp(cmd, "set_proxy") == 0) {
        int port = 10808;
        json_get_int(json, "port", &port);

        if (set_system_proxy(1, port) == 0) {
            snprintf(resp, resp_size, "{\"ok\":true}");
        } else {
            snprintf(resp, resp_size,
                     "{\"ok\":false,\"error\":\"SCPreferences set failed\"}");
        }
        return;
    }

    /* ---------- clear_proxy ---------- */
    if (strcmp(cmd, "clear_proxy") == 0) {
        if (set_system_proxy(0, 0) == 0) {
            snprintf(resp, resp_size, "{\"ok\":true}");
        } else {
            snprintf(resp, resp_size,
                     "{\"ok\":false,\"error\":\"SCPreferences clear failed\"}");
        }
        return;
    }

    /* ================================================================
     * Mihomo standalone LaunchDaemon service management
     * ================================================================ */

    /* ---------- install_mihomo_svc ---------- */
    /*
     * Installs mihomo as a persistent LaunchDaemon (com.velox.app.mihomo).
     * Steps:
     *   1. Create /Library/Application Support/Velox/
     *   2. Copy mihomo binary from app bundle path to MIHOMO_BIN_PATH
     *   3. Write the LaunchDaemon plist to MIHOMO_SVC_PLIST
     *   4. Bootstrap the service (launchctl bootstrap system <plist>)
     *
     * Params: {"cmd":"install_mihomo_svc","binary":"/path/to/app/mihomo"}
     */
    if (strcmp(cmd, "install_mihomo_svc") == 0) {
        char src_binary[1024]  = {0};
        char src_geoip[1024]   = {0};
        char src_geosite[1024] = {0};
        json_get_string(json, "binary",  src_binary,  sizeof(src_binary));
        json_get_string(json, "geoip",   src_geoip,   sizeof(src_geoip));
        json_get_string(json, "geosite", src_geosite, sizeof(src_geosite));

        /* 安全：若指定了二进制，必须是可信的 mihomo，拒绝任意路径 */
        if (src_binary[0] != '\0' && !is_trusted_binary(src_binary)) {
            snprintf(resp, resp_size,
                     "{\"ok\":false,\"error\":\"install_mihomo_svc: untrusted binary path\"}");
            return;
        }

        /* Create install directory */
        mkdir(MIHOMO_INSTALL_DIR, 0755);

        /* Copy binary from app bundle if source provided */
        if (src_binary[0] != '\0') {
            char *cp_args[] = { "/bin/cp", "-f", src_binary, MIHOMO_BIN_PATH, NULL };
            int r = run_cmd("/bin/cp", cp_args);
            if (r != 0) {
                snprintf(resp, resp_size,
                         "{\"ok\":false,\"error\":\"copy binary failed (cp ret=%d)\"}", r);
                return;
            }
            chmod(MIHOMO_BIN_PATH, 0755);
        }

        /* Install GeoIP / GeoSite databases alongside binary (mihomo -d
         * reads geoip.metadb + geosite.dat from this workdir). Files come
         * from app bundle's flutter_assets. Idempotent — overwrites every
         * install_mihomo_svc call so app upgrades pick up newer databases. */
        if (src_geoip[0] != '\0') {
            char dst_geoip[1024];
            snprintf(dst_geoip, sizeof(dst_geoip),
                     "%s/geoip.metadb", MIHOMO_INSTALL_DIR);
            char *cp_args[] = { "/bin/cp", "-f", src_geoip, dst_geoip, NULL };
            if (run_cmd("/bin/cp", cp_args) == 0) {
                chmod(dst_geoip, 0644);
            } else {
                fprintf(stderr, "VeloxHelper: warning: copy geoip failed\n");
            }
        }
        if (src_geosite[0] != '\0') {
            char dst_geosite[1024];
            snprintf(dst_geosite, sizeof(dst_geosite),
                     "%s/geosite.dat", MIHOMO_INSTALL_DIR);
            char *cp_args[] = { "/bin/cp", "-f", src_geosite, dst_geosite, NULL };
            if (run_cmd("/bin/cp", cp_args) == 0) {
                chmod(dst_geosite, 0644);
            } else {
                fprintf(stderr, "VeloxHelper: warning: copy geosite failed\n");
            }
        }

        /* Verify binary is executable */
        if (access(MIHOMO_BIN_PATH, X_OK) != 0) {
            snprintf(resp, resp_size,
                     "{\"ok\":false,\"error\":\"mihomo binary not executable at "
                     MIHOMO_BIN_PATH "\"}");
            return;
        }

        /* Write LaunchDaemon plist */
        FILE *pf = fopen(MIHOMO_SVC_PLIST, "w");
        if (!pf) {
            snprintf(resp, resp_size,
                     "{\"ok\":false,\"error\":\"cannot write plist to "
                     MIHOMO_SVC_PLIST " (errno=%d)\"}", errno);
            return;
        }
        fprintf(pf,
            "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
            "<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\"\n"
            "  \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n"
            "<plist version=\"1.0\">\n"
            "<dict>\n"
            "    <key>Label</key>\n"
            "    <string>" MIHOMO_SVC_LABEL "</string>\n"
            "    <key>ProgramArguments</key>\n"
            "    <array>\n"
            "        <string>" MIHOMO_BIN_PATH "</string>\n"
            "        <string>-f</string>\n"
            "        <string>" MIHOMO_CONFIG_PATH "</string>\n"
            "        <string>-d</string>\n"
            "        <string>" MIHOMO_INSTALL_DIR "</string>\n"
            "    </array>\n"
            "    <key>RunAtLoad</key>\n"
            "    <false/>\n"
            "    <key>KeepAlive</key>\n"
            "    <dict>\n"
            "        <key>SuccessfulExit</key>\n"
            "        <false/>\n"
            "    </dict>\n"
            "    <key>StandardOutPath</key>\n"
            "    <string>" MIHOMO_SVC_LOG "</string>\n"
            "    <key>StandardErrorPath</key>\n"
            "    <string>" MIHOMO_SVC_LOG "</string>\n"
            "</dict>\n"
            "</plist>\n");
        fclose(pf);
        chmod(MIHOMO_SVC_PLIST, 0644);

        /* Bootout first — this sends SIGTERM to the running mihomo service.
         * We must wait until mihomo fully exits (port 10808 released, TUN routes
         * removed) before bootstrapping + kickstarting the new instance. */
        char *bootout_args[] = {
            "/bin/launchctl", "bootout", "system/" MIHOMO_SVC_LABEL, NULL
        };
        run_cmd("/bin/launchctl", bootout_args);

        /* Poll for mihomo process exit (up to 3 s after SIGTERM) */
        for (int i = 0; i < 30; i++) {
            FILE *fp = popen("/usr/bin/pgrep -f velox_mihomo", "r");
            int any = 0;
            if (fp) {
                char tmp[32];
                if (fgets(tmp, sizeof(tmp), fp)) any = 1;
                pclose(fp);
            }
            if (!any) break;
            usleep(100000); /* 100 ms per check */
        }
        /* Extra pause for kernel to release port 10808 and remove TUN routes */
        usleep(800000); /* 800 ms */

        /* Bootstrap the service into the system domain */
        char *bootstrap_args[] = {
            "/bin/launchctl", "bootstrap", "system", MIHOMO_SVC_PLIST, NULL
        };
        int r = run_cmd("/bin/launchctl", bootstrap_args);
        if (r != 0) {
            snprintf(resp, resp_size,
                     "{\"ok\":false,\"error\":\"launchctl bootstrap failed (ret=%d)\"}", r);
            return;
        }

        fprintf(stderr, "VeloxHelper: install_mihomo_svc: service bootstrapped OK\n");
        snprintf(resp, resp_size, "{\"ok\":true}");
        return;
    }

    /* ---------- start_mihomo_svc ---------- */
    /*
     * Kickstart the mihomo LaunchDaemon (kill existing instance, start fresh).
     * Params: {"cmd":"start_mihomo_svc"}
     */
    if (strcmp(cmd, "start_mihomo_svc") == 0) {
        /* Truncate / create fresh log file so the app can tail it */
        int lfd = open(MIHOMO_SVC_LOG, O_WRONLY | O_CREAT | O_TRUNC, 0644);
        if (lfd >= 0) close(lfd);

        char *args[] = {
            "/bin/launchctl", "kickstart", "-k",
            "system/" MIHOMO_SVC_LABEL, NULL
        };
        int r = run_cmd("/bin/launchctl", args);
        if (r == 0) {
            fprintf(stderr, "VeloxHelper: start_mihomo_svc: kickstart OK\n");
            snprintf(resp, resp_size, "{\"ok\":true}");
        } else {
            snprintf(resp, resp_size,
                     "{\"ok\":false,\"error\":\"kickstart failed (ret=%d)\"}", r);
        }
        return;
    }

    /* ---------- stop_mihomo_svc ---------- */
    /*
     * Send SIGTERM to the mihomo LaunchDaemon service.
     * launchd will NOT restart it because we send via 'kill', not 'stop'.
     * Params: {"cmd":"stop_mihomo_svc"}
     */
    if (strcmp(cmd, "stop_mihomo_svc") == 0) {
        char *args[] = {
            "/bin/launchctl", "kill", "TERM",
            "system/" MIHOMO_SVC_LABEL, NULL
        };
        run_cmd("/bin/launchctl", args); /* ignore return; service may already be stopped */
        fprintf(stderr, "VeloxHelper: stop_mihomo_svc: SIGTERM sent\n");
        snprintf(resp, resp_size, "{\"ok\":true}");
        return;
    }

    /* ---------- uninstall_mihomo_svc ---------- */
    /*
     * Completely remove the mihomo LaunchDaemon from the system:
     *   1. bootout the service from launchd (kills any running instance)
     *   2. delete /Library/LaunchDaemons/com.velox.app.mihomo.plist
     *
     * Used on app startup to clean up from previous architecture (v1/v2) that
     * installed mihomo as a standalone service. We're now using child-process
     * architecture (start_tun), so the service is no longer needed.
     * Idempotent: safe to call even if service isn't installed.
     * Params: {"cmd":"uninstall_mihomo_svc"}
     */
    if (strcmp(cmd, "uninstall_mihomo_svc") == 0) {
        char *bootout_args[] = {
            "/bin/launchctl", "bootout", "system/" MIHOMO_SVC_LABEL, NULL
        };
        run_cmd("/bin/launchctl", bootout_args); /* ignore failure — may not be loaded */
        unlink(MIHOMO_SVC_PLIST); /* ignore failure — may not exist */
        fprintf(stderr, "VeloxHelper: uninstall_mihomo_svc: bootout + rm done\n");
        snprintf(resp, resp_size, "{\"ok\":true}");
        return;
    }

    /* Unknown */
    snprintf(resp, resp_size,
             "{\"ok\":false,\"error\":\"unknown command: %.32s\"}", cmd);
}

/* ------------------------------------------------------------------ */
/* Main                                                                 */
/* ------------------------------------------------------------------ */

int main(void) {
    signal(SIGTERM, cleanup_and_exit);
    signal(SIGINT,  cleanup_and_exit);
    signal(SIGPIPE, SIG_IGN);
    /* 监听子进程退出：感知 mihomo 崩溃并清除 g_tun_pid，同时回收僵尸进程 */
    signal(SIGCHLD, on_child_exit);

    g_server_fd = socket(AF_UNIX, SOCK_STREAM, 0);
    if (g_server_fd < 0) {
        perror("VeloxHelper: socket");
        return 1;
    }

    /* Remove stale socket file if present */
    unlink(SOCKET_PATH);

    struct sockaddr_un addr;
    memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    strncpy(addr.sun_path, SOCKET_PATH, sizeof(addr.sun_path) - 1);

    if (bind(g_server_fd, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
        perror("VeloxHelper: bind");
        return 1;
    }

    /* Allow any user (including the non-root app) to connect */
    chmod(SOCKET_PATH, 0777);

    if (listen(g_server_fd, 16) < 0) {
        perror("VeloxHelper: listen");
        return 1;
    }

    fprintf(stdout, "VeloxHelper listening on %s (pid %d)\n",
            SOCKET_PATH, (int)getpid());
    fflush(stdout);

    static char buf[MAX_BUF];
    static char resp[MAX_BUF];

    for (;;) {
        int client_fd = accept(g_server_fd, NULL, NULL);
        if (client_fd < 0) {
            if (errno == EINTR) continue;
            perror("VeloxHelper: accept");
            continue;
        }

        /* ── 鉴权：socket 是 0777（任何本地进程都能连），所以这里必须校验调用方身份，
         * 否则任意低权限进程都能让我们以 root 干活 → 本地提权。
         * 只放行 root 和当前 GUI 登录用户；登录用户不可知时退而求其次挡掉系统/守护账号(<500)。*/
        {
            uid_t peer_uid = (uid_t)-1; gid_t peer_gid = (gid_t)-1;
            if (getpeereid(client_fd, &peer_uid, &peer_gid) != 0) {
                close(client_fd); continue;
            }
            if (peer_uid != 0) {  /* root 始终放行 */
                uid_t console_uid = (uid_t)-1;
                CFStringRef cu = SCDynamicStoreCopyConsoleUser(NULL, &console_uid, NULL);
                if (cu) CFRelease(cu);
                int allowed = (console_uid != (uid_t)-1 && console_uid != 0)
                                  ? (peer_uid == console_uid)   /* 正常：只认 GUI 登录用户 */
                                  : (peer_uid >= 500);          /* 兜底：挡掉系统/守护账号 */
                if (!allowed) {
                    fprintf(stderr, "VeloxHelper: rejected uid=%d (console=%d)\n",
                            (int)peer_uid, (int)console_uid);
                    const char *deny = "{\"ok\":false,\"error\":\"unauthorized caller\"}\n";
                    send(client_fd, deny, strlen(deny), 0);
                    close(client_fd);
                    continue;
                }
            }
        }

        /* Read until newline delimiter or buffer full */
        memset(buf, 0, sizeof(buf));
        ssize_t total = 0;
        while (total < (ssize_t)(sizeof(buf) - 1)) {
            ssize_t n = recv(client_fd, buf + total, 1, 0);
            if (n <= 0) break;
            total += n;
            if (buf[total - 1] == '\n') {
                buf[total - 1] = '\0'; /* strip newline */
                break;
            }
        }

        memset(resp, 0, sizeof(resp));
        handle_command(buf, resp, sizeof(resp) - 2);

        /* Append newline and send */
        size_t rlen = strlen(resp);
        resp[rlen]   = '\n';
        resp[rlen+1] = '\0';
        send(client_fd, resp, rlen + 1, 0);
        close(client_fd);
    }

    return 0;
}
