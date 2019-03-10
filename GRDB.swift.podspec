Pod::Spec.new do |s|
  s.name     = 'GRDB.swift'
  s.version  = '3.7.0'
  
  s.license  = { :type => 'MIT', :file => 'LICENSE' }
  s.summary  = 'A toolkit for SQLite databases, with a focus on application development.'
  s.homepage = 'https://github.com/groue/GRDB.swift'
  s.author   = { 'Gwendal Roué' => 'gr@pierlis.com' }
  s.source   = { :git => 'https://github.com/groue/GRDB.swift.git', :tag => "v#{s.version}" }
  s.module_name = 'GRDB'
  
  s.ios.deployment_target = '9.0'
  s.osx.deployment_target = '10.9'
  s.watchos.deployment_target = '2.0'
  
  s.source_files = 'GRDB/**/*.swift', 'Support/*.h'
  s.module_map = 'Support/module.modulemap'
  s.framework = 'Foundation'
  s.library = 'sqlite3'
end
