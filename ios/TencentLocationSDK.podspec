Pod::Spec.new do |spec|
  spec.name = 'TencentLocationSDK'
  spec.version = '4.3.1'
  spec.summary = 'Tencent Location SDK with an arm64 iOS Simulator slice.'
  spec.homepage = 'https://lbs.qq.com/mobile/iosLocationSDK/iosGeoGuide/iosGeoOverview'
  spec.license = { :type => 'Copyright', :text => 'Copyright © 1998-2026 Tencent All Rights Reserved' }
  spec.author = 'Tencent'
  spec.source = {
    :http => 'https://mapapi.qq.com/sdk/locationSDK/iOS/TencentLBS_4.3.1.zip',
    :sha256 => 'a0eb5b51778175ff1749c009a3dd5d99730ac4a700941132246857f9176863e9',
  }
  spec.ios.deployment_target = '13.0'
  spec.vendored_frameworks = 'TencentLBS_4.3.1/sdk/TencentLBS.xcframework'
  spec.libraries = 'c++'
end
