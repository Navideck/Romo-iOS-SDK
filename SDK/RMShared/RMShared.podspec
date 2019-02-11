Pod::Spec.new do |spec|
  spec.name         = 'RMShared'
  spec.summary      = 'RMShared'
  spec.homepage     = 'https://github.com/fotiDim/Romo'
  spec.version      = '0.3.0'
  spec.authors      = { 'Foti Dim' => 'foti@navideck.com' }
  spec.source       = { :git => 'https://github.com/fotiDim/Romo', :tag => "RMShared_v#{spec.version}" }
  spec.source_files = 'Classes/**/*.{h,m,mm,pch}'
  spec.ios.deployment_target = '6.0'
  spec.requires_arc = true
  spec.dependency 'CocoaLumberjack'
  spec.dependency 'SocketRocket'
  spec.dependency 'UIDevice-Hardware'
end