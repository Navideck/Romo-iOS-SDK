Pod::Spec.new do |spec|
  spec.name         = 'Romo'
  spec.summary      = 'Romo SDK'
  spec.homepage     = 'https://github.com/navideck/Romo'
  spec.version      = '0.3.1'
  spec.authors      = { 'Navideck' => 'team@navideck.com' }
  spec.source       = { :git => 'https://github.com/navideck/Romo', :tag => "Romo_v#{spec.version}" }
  spec.ios.deployment_target = '7.0'
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
    sp.resources = 'RMCharacter/Assets/**/*.*'
    # sp.resource_bundle = { 'RMCharacter' => ['RMCharacter/Assets/**/*.xcassets'] }  //Replace the above line for iOS 8
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
end
