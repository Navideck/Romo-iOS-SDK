Pod::Spec.new do |spec|
  spec.name         = 'RMCharacter'
  spec.summary      = 'RMCharacter'
  spec.homepage     = 'https://github.com/fotiDim/Romo'
  spec.version      = '0.1.0'
  spec.authors      = { 'Foti Dim' => 'foti@navideck.com' }
  spec.source       = { :git => 'https://github.com/fotiDim/Romo', :tag => "RMCharacter_v#{spec.version}" }
  spec.source_files = '**/*.{h,m,pch}'
  spec.ios.deployment_target = '6.0'
  spec.requires_arc = true
  spec.resources = 'RMCharacterResources/**/*'
  # spec.resource_bundle = {
  #     'RMCharacter' => [
  #       'RMCharacterResources/**/*',
  #     ]
  #   }  
end