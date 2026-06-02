Pod::Spec.new do |s|
  s.name             = 'MivaltaRustBridge'
  s.version          = '0.1.0'
  s.summary          = 'MiValta Rust Bridge - FFI bridge to gatc-ffi'
  s.description      = <<-DESC
Privacy-first AI fitness coaching engine. 100% on-device. No cloud.
                       DESC
  s.homepage         = 'https://github.com/Bartveldkamp/Mivalta-flutter'
  s.license          = { :type => 'Proprietary' }
  s.author           = { 'MiValta' => 'info@mivalta.com' }
  s.source           = { :path => '.' }
  s.platform         = :ios, '13.0'
  s.static_framework = true

  # The xcframework contains the static library for device and simulator
  s.vendored_frameworks = 'MivaltaRustBridge.xcframework'

  # Link against system frameworks required by the Rust code
  s.frameworks = 'Security', 'CoreFoundation'

  # These are needed for rusqlite and other native code
  s.libraries = 'c++', 'sqlite3'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
  }
end
