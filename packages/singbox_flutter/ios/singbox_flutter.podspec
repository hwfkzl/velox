Pod::Spec.new do |s|
  s.name             = 'singbox_flutter'
  s.version          = '0.1.0'
  s.summary          = 'Flutter plugin for sing-box VPN core integration'
  s.description      = <<-DESC
Flutter plugin for sing-box VPN core integration supporting iOS Network Extension.
                       DESC
  s.homepage         = 'https://github.com/velox/singbox_flutter'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Velox' => 'support@velox.app' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform         = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version    = '5.0'

  # sing-box framework (Libbox.xcframework should be added manually)
  # s.vendored_frameworks = 'Frameworks/Libbox.xcframework'
end
