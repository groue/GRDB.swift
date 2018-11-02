Pod::Spec.new do |s|
  s.name     = 'GRDBPlus'
  s.version  = '3.5.0'
  
  s.license  = { :type => 'MIT', :file => 'LICENSE' }
  s.summary  = 'A toolkit for SQLite databases, with a focus on application development.'
  s.homepage = 'https://github.com/groue/GRDB.swift'
  s.author   = { 'Gwendal Roué' => 'gr@pierlis.com' }
  s.source   = { :git => 'https://github.com/groue/GRDB.swift.git', :tag => "v#{s.version}" }
  s.module_name = 'GRDB'
  
  s.ios.deployment_target = '11.4'
  s.osx.deployment_target = '10.13'
  s.watchos.deployment_target = '4.3'
  
  s.source_files = 'GRDB/**/*.swift', 'Support/*.h'
  s.module_map = 'Support/module.modulemap'
  s.framework = 'Foundation'
  s.library = 'sqlite3'
  
  s.xcconfig = {
    'OTHER_SWIFT_FLAGS' => '$(inherited) -D SQLITE_ENABLE_FTS5',
  }
end
