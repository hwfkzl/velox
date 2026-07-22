#!/bin/bash

# Velox UI 自动化测试脚本
# 使用 cliclick 模拟鼠标点击

set -e

LOG_FILE="/tmp/velox_ui_test.log"
SCREENSHOT_DIR="/tmp/velox_screenshots"
FLUTTER_LOG="/tmp/flutter_output.log"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$LOG_FILE"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

# 初始化
init() {
    rm -f "$LOG_FILE"
    mkdir -p "$SCREENSHOT_DIR"
    log "=========================================="
    log "Velox UI 自动化测试开始"
    log "=========================================="
}

# 截图
screenshot() {
    local name=$1
    local file="$SCREENSHOT_DIR/${name}_$(date +%H%M%S).png"
    screencapture -x "$file"
    log "  📸 截图: $name"
}

# 等待
wait_ms() {
    sleep $(echo "scale=3; $1/1000" | bc)
}

wait_sec() {
    sleep $1
}

# 点击坐标
click() {
    local x=$1
    local y=$2
    cliclick c:$x,$y
    wait_ms 300
}

# 输入文本
type_text() {
    cliclick t:"$1"
    wait_ms 200
}

# 获取窗口信息
get_window_bounds() {
    local result=$(osascript -e 'tell application "System Events"
        tell process "velox"
            set win to first window
            set winPos to position of win
            set winSize to size of win
            return "" & (item 1 of winPos) & " " & (item 2 of winPos) & " " & (item 1 of winSize) & " " & (item 2 of winSize)
        end tell
    end tell' 2>/dev/null)
    echo "$result"
}

# 激活应用窗口
activate_app() {
    osascript -e 'tell application "velox" to activate' 2>/dev/null
    wait_sec 1
}

# 检查应用是否运行
check_app_running() {
    if pgrep -f "velox.app" > /dev/null; then
        log "✅ Velox 应用正在运行"
        return 0
    else
        error "❌ Velox 应用未运行！"
        return 1
    fi
}

# 检查 Flutter 日志中的错误
check_flutter_errors() {
    if [ -f "$FLUTTER_LOG" ]; then
        local errors=$(grep -i "error\|exception" "$FLUTTER_LOG" 2>/dev/null | tail -5)
        if [ -n "$errors" ]; then
            warn "检测到错误:"
            echo "$errors" | while read line; do
                echo "  $line" | tee -a "$LOG_FILE"
            done
        fi
    fi
}

# ==================== 测试用例 ====================

test_bottom_tabs() {
    log "📱 测试底部导航栏..."

    read wx wy ww wh <<< $(get_window_bounds)
    log "  窗口: x=$wx y=$wy w=$ww h=$wh"

    # 底部 Tab 栏 Y 坐标 (距离底部约 40px)
    local tab_y=$((wy + wh - 40))
    local tab_width=$((ww / 4))

    # Tab 1: 首页
    log "  点击 Tab 1: 首页"
    click $((wx + tab_width / 2)) $tab_y
    wait_sec 1
    screenshot "1_tab_home"

    # Tab 2: 订阅
    log "  点击 Tab 2: 订阅"
    click $((wx + tab_width + tab_width / 2)) $tab_y
    wait_sec 1
    screenshot "2_tab_subscription"

    # Tab 3: 设置
    log "  点击 Tab 3: 设置"
    click $((wx + tab_width * 2 + tab_width / 2)) $tab_y
    wait_sec 1
    screenshot "3_tab_settings"

    # Tab 4: 个人
    log "  点击 Tab 4: 个人"
    click $((wx + tab_width * 3 + tab_width / 2)) $tab_y
    wait_sec 1
    screenshot "4_tab_profile"

    log "✅ 底部导航栏测试完成"
    check_flutter_errors
}

test_home_page() {
    log "🏠 测试首页..."

    read wx wy ww wh <<< $(get_window_bounds)
    local tab_y=$((wy + wh - 40))
    local tab_width=$((ww / 4))

    # 回到首页
    click $((wx + tab_width / 2)) $tab_y
    wait_sec 1

    # 点击连接按钮 (页面中心偏上)
    log "  点击 VPN 连接按钮"
    click $((wx + ww / 2)) $((wy + wh / 2 - 80))
    wait_sec 2
    screenshot "5_vpn_connecting"

    # 等待连接状态变化
    wait_sec 2

    # 再次点击断开
    log "  点击断开 VPN"
    click $((wx + ww / 2)) $((wy + wh / 2 - 80))
    wait_sec 2
    screenshot "6_vpn_disconnected"

    # 点击服务器列表区域
    log "  点击服务器选择区域"
    click $((wx + ww / 2)) $((wy + wh - 150))
    wait_sec 1
    screenshot "7_server_list"

    log "✅ 首页测试完成"
    check_flutter_errors
}

test_subscription_page() {
    log "💳 测试订阅页面..."

    read wx wy ww wh <<< $(get_window_bounds)
    local tab_y=$((wy + wh - 40))
    local tab_width=$((ww / 4))

    # 点击订阅 Tab
    click $((wx + tab_width + tab_width / 2)) $tab_y
    wait_sec 2
    screenshot "8_subscription_page"

    # 点击购买/升级按钮 (假设在页面下方)
    log "  点击购买按钮"
    click $((wx + ww / 2)) $((wy + wh - 120))
    wait_sec 2
    screenshot "9_plan_purchase"

    # 如果进入了套餐选择页面
    # 选择第一个套餐
    log "  选择套餐"
    click $((wx + ww / 2)) $((wy + 180))
    wait_sec 1
    screenshot "10_plan_selected"

    # 选择周期 (月付)
    log "  选择周期"
    click $((wx + ww / 2)) $((wy + 380))
    wait_sec 1
    screenshot "11_cycle_selected"

    # 点击结账
    log "  点击结账"
    click $((wx + ww - 100)) $((wy + wh - 60))
    wait_sec 2
    screenshot "12_checkout_result"

    # 返回 (点击左上角)
    log "  返回"
    click $((wx + 50)) $((wy + 60))
    wait_sec 1

    log "✅ 订阅页面测试完成"
    check_flutter_errors
}

test_settings_page() {
    log "⚙️ 测试设置页面..."

    read wx wy ww wh <<< $(get_window_bounds)
    local tab_y=$((wy + wh - 40))
    local tab_width=$((ww / 4))

    # 点击设置 Tab
    click $((wx + tab_width * 2 + tab_width / 2)) $tab_y
    wait_sec 1
    screenshot "13_settings_page"

    # 测试语言切换 (右上角)
    log "  点击语言切换"
    click $((wx + ww - 60)) $((wy + 60))
    wait_sec 1
    screenshot "14_language_menu"

    # 点击空白处关闭菜单
    click $((wx + ww / 2)) $((wy + wh / 2))
    wait_sec 1

    # 点击设置项 (从上往下)
    local settings_y=$((wy + 150))
    local step=70

    log "  点击各设置项..."

    # DNS 设置
    click $((wx + ww / 2)) $((settings_y))
    wait_sec 1
    screenshot "15_dns_settings"
    click $((wx + 50)) $((wy + 60))  # 返回
    wait_sec 1

    # 代理模式
    click $((wx + ww / 2)) $((settings_y + step))
    wait_sec 1
    screenshot "16_proxy_mode"
    click $((wx + 50)) $((wy + 60))
    wait_sec 1

    # 隐私政策
    click $((wx + ww / 2)) $((settings_y + step * 2))
    wait_sec 1
    screenshot "17_privacy_policy"
    click $((wx + 50)) $((wy + 60))
    wait_sec 1

    # 服务条款
    click $((wx + ww / 2)) $((settings_y + step * 3))
    wait_sec 1
    screenshot "18_terms"
    click $((wx + 50)) $((wy + 60))
    wait_sec 1

    log "✅ 设置页面测试完成"
    check_flutter_errors
}

test_profile_page() {
    log "👤 测试个人页面..."

    read wx wy ww wh <<< $(get_window_bounds)
    local tab_y=$((wy + wh - 40))
    local tab_width=$((ww / 4))

    # 点击个人 Tab
    click $((wx + tab_width * 3 + tab_width / 2)) $tab_y
    wait_sec 1
    screenshot "19_profile_page"

    local profile_y=$((wy + 280))
    local step=60

    # 邀请好友
    log "  点击邀请好友"
    click $((wx + ww / 2)) $((profile_y))
    wait_sec 1
    screenshot "20_invite"
    click $((wx + 50)) $((wy + 60))
    wait_sec 1

    # 订单历史
    log "  点击订单历史"
    click $((wx + ww / 2)) $((profile_y + step))
    wait_sec 1
    screenshot "21_orders"
    click $((wx + 50)) $((wy + 60))
    wait_sec 1

    # 帮助支持
    log "  点击帮助支持"
    click $((wx + ww / 2)) $((profile_y + step * 2))
    wait_sec 1
    screenshot "22_support"
    click $((wx + 50)) $((wy + 60))
    wait_sec 1

    # 关于
    log "  点击关于"
    click $((wx + ww / 2)) $((profile_y + step * 3))
    wait_sec 1
    screenshot "23_about"
    click $((wx + 50)) $((wy + 60))
    wait_sec 1

    # 退出登录
    log "  点击退出登录"
    click $((wx + ww / 2)) $((profile_y + step * 4))
    wait_sec 1
    screenshot "24_logout_confirm"

    # 取消退出
    click $((wx + ww / 3)) $((wy + wh / 2 + 50))
    wait_sec 1

    log "✅ 个人页面测试完成"
    check_flutter_errors
}

# ==================== 主程序 ====================

main() {
    init

    # 检查应用是否运行
    if ! check_app_running; then
        error "请先运行: flutter run -d macos"
        exit 1
    fi

    # 激活应用窗口
    activate_app

    # 获取窗口信息
    local bounds=$(get_window_bounds)
    if [ -z "$bounds" ]; then
        error "无法获取窗口信息！"
        echo ""
        echo -e "${YELLOW}请按以下步骤授予权限:${NC}"
        echo "1. 打开 系统偏好设置 → 安全性与隐私 → 隐私 → 辅助功能"
        echo "2. 点击左下角🔒解锁"
        echo "3. 添加 '终端' 或你使用的终端应用"
        echo "4. 重新运行此脚本"
        exit 1
    fi

    log "窗口边界: $bounds"

    # 运行所有测试
    test_bottom_tabs
    test_home_page
    test_subscription_page
    test_settings_page
    test_profile_page

    log ""
    log "=========================================="
    log "🎉 所有测试完成！"
    log "=========================================="
    log "📸 截图保存在: $SCREENSHOT_DIR"
    log "📝 日志保存在: $LOG_FILE"

    # 显示检测到的错误
    echo ""
    info "检查 Flutter 日志中的错误..."
    if [ -f "$FLUTTER_LOG" ]; then
        local error_count=$(grep -c "ERROR\|Exception" "$FLUTTER_LOG" 2>/dev/null || echo "0")
        if [ "$error_count" -gt 0 ]; then
            warn "发现 $error_count 个错误，请查看日志"
        else
            log "✅ 没有发现错误"
        fi
    fi
}

# 显示帮助
if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
    echo "Velox UI 自动化测试脚本"
    echo ""
    echo "用法: $0"
    echo ""
    echo "前提条件:"
    echo "  1. Velox 应用正在运行 (flutter run -d macos)"
    echo "  2. 已授予终端辅助功能权限"
    echo ""
    echo "测试内容:"
    echo "  - 底部导航栏切换"
    echo "  - 首页 VPN 连接/断开"
    echo "  - 订阅页面购买流程"
    echo "  - 设置页面各选项"
    echo "  - 个人页面各选项"
    exit 0
fi

# 运行主程序
main "$@"
