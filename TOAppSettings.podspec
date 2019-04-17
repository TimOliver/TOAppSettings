Pod::Spec.new do |s|
  s.name     = 'TOAppSettings'
  s.version  = '0.0.1'
  s.license  =  { :type => 'MIT', :file => 'LICENSE' }
  s.summary  = 'A Realm-like object wrapper for NSUserDefaults.'
  s.homepage = 'https://github.com/TimOliver/TOAppSettings'
  s.author   = 'Tim Oliver'
  s.source   = { :git => 'https://github.com/TimOliver/TOAppSettings.git', :tag => s.version }
  s.platform = :ios, '8.0'
  s.source_files = 'TOAppSettings/**/*.{h,m}'
  s.requires_arc = true
end