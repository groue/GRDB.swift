Pod::Spec.new do |s|
  s.name     = 'GRDB.swift'
  s.version  = '6.24.1'
  
  s.license  = { :type => 'MIT', :file => 'LICENSE' }
  s.summary  = 'A toolkit for SQLite databases, with a focus on application development.'
  s.homepage = 'https://github.com/groue/GRDB.swift'
  s.author   = { 'Gwendal Roué' => 'gr@pierlis.com' }
  s.source   = { :git => 'https://github.com/groue/GRDB.swift.git', :tag => "v#{s.version}" }
  s.module_name = 'GRDB'
  
  s.swift_versions = ['5.7']
  s.ios.deployment_target = '11.0'
  s.osx.deployment_target = '10.13'
  s.watchos.deployment_target = '4.0'
  s.tvos.deployment_target = '11.0'
  s.default_subspec  = 'standard'
  
  s.subspec 'standard' do |ss|
    ss.source_files = 'GRDB/**/*.swift', 'Support/grdb_config.h'
    ss.framework = 'Foundation'
    ss.library = 'sqlite3'
    ss.xcconfig = {
      'OTHER_SWIFT_FLAGS' => '$(inherited) -D SQLITE_ENABLE_FTS5',
    }
  end
  
  s.subspec 'SQLCipher' do |ss|
    ss.source_files = 'GRDB/**/*.swift', 'Support/SQLCipher_config.h'
    ss.framework = 'Foundation'
    ss.dependency 'SQLCipher', '>= 3.4.2'
    ss.xcconfig = {
      'OTHER_SWIFT_FLAGS' => '$(inherited) -D SQLITE_HAS_CODEC -D GRDBCIPHER -D SQLITE_ENABLE_FTS5',
      'OTHER_CFLAGS' => '$(inherited) -DSQLITE_HAS_CODEC -DGRDBCIPHER -DSQLITE_ENABLE_FTS5',
      'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) SQLITE_HAS_CODEC=1 GRDBCIPHER=1 SQLITE_ENABLE_FTS5=1'
    }
  end
end
