import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController

    // 高度 540 给 220 圆按钮 + 顶部 36 titlebar padding 留出舒适空间；
    // 宽度 720 仍是紧凑感（侧栏 96 + 主区 ~600）
    let defaultSize = NSSize(width: 720, height: 540)
    self.setContentSize(defaultSize)
    self.contentMinSize = NSSize(width: 640, height: 500)
    self.contentMaxSize = NSSize(width: 960, height: 720)
    self.center()

    // 让 Flutter 深色背景延伸到标题栏下方（避免浅色 titlebar 露出）
    self.titlebarAppearsTransparent = true
    self.styleMask.insert(.fullSizeContentView)
    // 用深色实色匹配 Flutter 主题（不能用 clear，否则 macOS 默认浅色
    // layer 会从 Flutter 渲染区域之外的边缘露出来）
    self.backgroundColor = NSColor(
      red: 6.0 / 255.0,
      green: 18.0 / 255.0,
      blue: 38.0 / 255.0,
      alpha: 1.0
    )
    // 标题文字隐藏，纯靠 Flutter 渲染
    self.titleVisibility = .hidden
    // titlebar 工具栏区域也用深色（Sequoia 上有时会单独渲染）
    self.appearance = NSAppearance(named: .darkAqua)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }

  override var isRestorable: Bool {
    get { return false }
    set {}
  }
}
