Pod::Spec.new do |s|
  s.name             = 'flutter_dev_monitor'
  s.version          = '0.1.0'
  s.summary          = 'In-app developer monitor for Flutter apps.'
  s.description      = 'Tracks API calls, FPS, RAM, and disk usage with a floating overlay and full dashboard.'
  s.homepage         = 'https://github.com/yourusername/flutter_dev_monitor'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'SoftDreams' => 'dev@softdreams.vn' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '12.0'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
