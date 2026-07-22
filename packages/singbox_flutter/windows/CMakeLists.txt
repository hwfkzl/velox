cmake_minimum_required(VERSION 3.14)
set(PROJECT_NAME "singbox_flutter")
project(${PROJECT_NAME} LANGUAGES CXX)

set(PLUGIN_NAME "singbox_flutter_plugin")

add_library(${PLUGIN_NAME} SHARED
  "singbox_flutter_plugin.cpp"
)

apply_standard_settings(${PLUGIN_NAME})

set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden)

target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)

target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")

target_link_libraries(${PLUGIN_NAME} PRIVATE flutter flutter_wrapper_plugin wininet)

# 随插件分发 mihomo.exe：flutter build windows 会自动把这里列出的文件
# copy 到 build/windows/x64/runner/Release/。
# 若目录里没放 mihomo.exe 则 fallback 到空列表，避免 flutter build 阶段报错；
# 运行时 GetMihomoPath() 会依次尝试 exe 同目录 / PATH / 常见安装路径。
set(_singbox_bundled "")
if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/bin/mihomo.exe")
  list(APPEND _singbox_bundled "${CMAKE_CURRENT_SOURCE_DIR}/bin/mihomo.exe")
else()
  message(WARNING
    "singbox_flutter: bin/mihomo.exe 未找到；构建后需手动放到 Release/ 目录，"
    "或从 https://github.com/MetaCubeX/mihomo/releases 下载后放到 "
    "packages/singbox_flutter/windows/bin/mihomo.exe。")
endif()
if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/bin/wintun.dll")
  list(APPEND _singbox_bundled "${CMAKE_CURRENT_SOURCE_DIR}/bin/wintun.dll")
else()
  message(WARNING
    "singbox_flutter: bin/wintun.dll 未找到；TUN 模式将不可用。"
    "从 https://www.wintun.net/ 下载后放到 packages/singbox_flutter/windows/bin/wintun.dll。")
endif()
set(singbox_flutter_bundled_libraries ${_singbox_bundled} PARENT_SCOPE)
