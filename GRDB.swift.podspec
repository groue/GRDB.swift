Pod::Spec.new do |s|
  s.name     = 'GRDB.swift'
  s.version  = '3.2.0'
  
  s.license  = { :type => 'MIT', :file => 'LICENSE' }
  s.summary  = 'A toolkit for SQLite databases, with a focus on application development.'
  s.homepage = 'https://github.com/groue/GRDB.swift'
  s.author   = { 'Gwendal Roué' => 'gr@pierlis.com' }
  s.source   = { :git => 'https://github.com/groue/GRDB.swift.git', :tag => "v#{s.version}" }
  s.module_name = 'GRDB'
  s.module_map = 'Support/module.modulemap'
  s.framework = 'Foundation'
  s.library = 'sqlite3'
  
  s.default_subspec = 'default'
  
  s.subspec 'default' do |ss|
    ss.source_files = 'GRDB/**/*.swift', 'Support/*.h'
    ss.ios.deployment_target = '8.0'
    ss.osx.deployment_target = '10.9'
    ss.watchos.deployment_target = '2.0'
  end
  
  # https://github.com/CocoaPods/CocoaPods/issues/7333
  s.subspec 'FTS5' do |ss|
    ss.source_files = 'GRDB/**/*.swift', 'Support/*.h'
    ss.ios.deployment_target = '11.4'
    ss.osx.deployment_target = '10.13'
    ss.watchos.deployment_target = '4.3'
    ss.xcconfig = {
      'OTHER_SWIFT_FLAGS' => '$(inherited) -D SQLITE_ENABLE_FTS5',
    }
  end
end
