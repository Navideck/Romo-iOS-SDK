Pod::Spec.new do |spec|
  spec.name         = 'Romo'
  spec.summary      = 'Romo iOS SDK'
  spec.homepage     = 'https://github.com/Navideck/Romo-iOS-SDK'
  spec.version      = '0.6.0'
  spec.authors      = { 'Navideck' => 'team@navideck.com' }
  spec.source       = { :git => 'https://github.com/Navideck/Romo-iOS-SDK', :tag => "Romo_v#{spec.version}" }
  spec.ios.deployment_target = '15.5'
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

  # RMVision is now the RomoVision pod (https://github.com/bwake2012/Romo-iOS-SDK-Vision)

  spec.default_subspec = "RMCore"
end
