#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint tencent_location_flutter_plugin.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'tencent_location_flutter_plugin'
  s.version          = '0.2.0'
  s.summary          = 'iOS implementation of the tencent_location_flutter_plugin Flutter plugin.'
  s.description      = <<-DESC
iOS implementation of the tencent_location_flutter_plugin Flutter plugin,
wrapping the native Tencent Location SDK for iOS.
                       DESC
  s.homepage         = 'https://lbs.qq.com/location/'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Tencent' => 'lbs@tencent.com' }
  s.source           = { :path => '.' }
  s.source_files = 'tencent_location_flutter_plugin/Sources/**/*.{swift,h,m}'
  s.public_header_files = 'tencent_location_flutter_plugin/Sources/TLPGeofenceBridge/include/*.h'
  s.resource_bundles = {
    'tencent_location_flutter_plugin_privacy' => ['tencent_location_flutter_plugin/Sources/tencent_location_flutter_plugin/PrivacyInfo.xcprivacy'],
  }
  s.dependency 'Flutter'
  s.dependency 'TencentLocationSDK', '4.3.1'
  s.platform = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
