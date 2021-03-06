Pod::Spec.new do |spec|
  spec.name         = 'Romo'
  spec.summary      = 'Romo iOS SDK'
  spec.homepage     = 'https://github.com/Navideck/Romo-iOS-SDK'
  spec.version      = '0.5.3'
  spec.authors      = { 'Navideck' => 'team@navideck.com' }
  spec.source       = { :git => 'https://github.com/Navideck/Romo-iOS-SDK', :tag => "Romo_v#{spec.version}" }
  spec.ios.deployment_target = '6.0'
  spec.requires_arc = true
  spec.static_framework = true
  spec.license = { :file => 'LICENSE.md' }

  spec.subspec 'RMShared' do |sp|
    sp.source_files = 'RMShared/Classes/**/*.{h,m,mm,pch}'
    sp.dependency 'CocoaLumberjack'
    sp.dependency 'SocketRocket'
  end

  spec.subspec 'RMCore' do |sp|
    sp.source_files = 'RMCore/Classes/**/*.{h,m,mm,pch}'
    sp.dependency 'Romo/RMShared'
  end
  
  spec.subspec 'RMCharacter' do |sp|
    sp.source_files = 'RMCharacter/Classes/**/*.{h,m,mm,pch}'
    # sp.resource_bundle = { 'RMCharacter' => ['RMCharacter/Assets/**/*.xcassets'] }
    sp.resources = 'RMCharacter/Assets/**/*.*'
    sp.dependency 'Romo/RMShared'
  end

  spec.subspec 'RMVision' do |sp|
    sp.source_files = 'RMVision/Classes/**/*.{h,m,mm,pch}'
    sp.exclude_files = ['RMVisionSample','RMVisionSampleTests']
    sp.resource_bundle = { 'RMVision' => ['RMVision/Assets/**/*.*'] }
    sp.dependency 'Romo/RMShared'
    sp.dependency 'CocoaLumberjack'
    sp.dependency 'GPUImage'
    # spec.dependency 'NMSSH', '>=2.2.8'
    sp.dependency 'OpenCV', '~> 2.0'
  end

  spec.default_subspec = "RMCore"

  # Fix for "building for iOS Simulator, but linking in object file built for iOS" when doing pod trunk push
  spec.pod_target_xcconfig = {
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64'
  }
  spec.user_target_xcconfig = { 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64' }
end
