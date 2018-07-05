Pod::Spec.new do |s|
	s.name     = 'GRDBCipher'
	s.version  = '3.1.0'
	
	s.license  = { :type => 'MIT', :file => 'LICENSE' }
	s.summary  = 'A toolkit for SQLite databases, with a focus on application development.'
	s.homepage = 'https://github.com/groue/GRDB.swift'
	s.author   = { 'Gwendal Roué' => 'gr@pierlis.com' }
	s.source   = { :git => 'https://github.com/groue/GRDB.swift.git', :tag => "v#{s.version}" }
	s.module_name = 'GRDBCipher'
	
	s.ios.deployment_target = '8.0'
	s.osx.deployment_target = '10.9'
	s.watchos.deployment_target = '2.0'
	
	s.source_files = 'GRDB/**/*.swift', 'SQLCipher/*.h', 'Support/grdb_config.h'
	s.module_map = 'SQLCipher/module.modulemap'
	s.xcconfig = {
		'OTHER_SWIFT_FLAGS' => '$(inherited) -D SQLITE_HAS_CODEC -D GRDBCIPHER',
		'OTHER_CFLAGS' => '$(inherited) -DSQLITE_HAS_CODEC -DGRDBCIPHER',
		'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) SQLITE_HAS_CODEC=1 GRDBCIPHER=1'
	}
	s.framework = 'Foundation'
	s.dependency 'SQLCipher', '~> 3.4.1'
end
