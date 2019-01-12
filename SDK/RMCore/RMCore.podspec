Pod::Spec.new do |spec|
  spec.name         = 'RMCore'
  spec.summary      = 'RMCore'
  spec.homepage     = 'https://github.com/fotiDim/Romo'
  spec.version      = '0.1.0'
  spec.authors      = { 'Foti Dim' => 'foti@navideck.com' }
  spec.source       = { :git => 'https://github.com/fotiDim/Romo', :tag => "RMCore_v#{spec.version}" }
  spec.source_files = '**/*.{h,m,mm,pch}'
  spec.ios.deployment_target = '6.0'
  spec.requires_arc = true
  spec.dependency 'RMShared'
end