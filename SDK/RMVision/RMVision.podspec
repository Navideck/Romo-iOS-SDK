Pod::Spec.new do |spec|
  spec.name         = 'RMVision'
  spec.summary      = 'RMVision'
  spec.homepage     = 'https://github.com/fotiDim/Romo'
  spec.version      = '0.1.0'
  spec.authors      = { 'Foti Dim' => 'foti@navideck.com' }
  spec.source       = { :git => 'https://github.com/fotiDim/Romo', :tag => "RMVision_v#{spec.version}" }
  spec.source_files = '**/*'
  spec.exclude_files = ['RMVisionSample','RMVisionSampleTests']
  spec.ios.deployment_target = '6.0'
  spec.requires_arc = true
  spec.dependency 'RMShared'
  spec.dependency 'CocoaLumberjack'
  spec.dependency 'GPUImage'
  # spec.dependency 'NMSSH', '>=2.2.8'
  spec.dependency 'OpenCV', '~> 2.0'
end 