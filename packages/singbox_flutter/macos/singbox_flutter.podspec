Pod::Spec.new do |s|
  s.name             = 'singbox_flutter'
  s.version          = '0.1.0'
  s.summary          = 'Flutter plugin for sing-box VPN core integration'
  s.description      = <<-DESC
Flutter plugin for sing-box VPN core integration supporting macOS system proxy.
                       DESC
  s.homepage         = 'https://github.com/velox/singbox_flutter'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Velox' => 'support@velox.app' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'FlutterMacOS'
  s.platform         = :osx, '10.14'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version    = '5.0'
end
