Pod::Spec.new do |s|
	s.name     = 'GRDB.swift'
	s.version  = '0.107.0'
	
	s.license  = { :type => 'MIT', :file => 'LICENSE' }
	s.summary  = 'A Swift application toolkit for SQLite databases.'
	s.homepage = 'https://github.com/groue/GRDB.swift'
	s.author   = { 'Gwendal Roué' => 'gr@pierlis.com' }
	s.source   = { :git => 'https://github.com/groue/GRDB.swift.git', :tag => "v#{s.version}" }
	s.module_name = 'GRDB'
	
	s.ios.deployment_target = '8.0'
	s.osx.deployment_target = '10.9'
	s.watchos.deployment_target = '2.0'
	
	s.module_map = 'Support/module.modulemap'
	s.framework = 'Foundation'
	s.library = 'sqlite3'
	s.default_subspec = 'standard'

	s.subspec 'standard' do |ss|
		ss.source_files = 'GRDB/**/*.swift', 'Support/*.{c,h}'
	end

	s.subspec 'SQLCipher' do |ss|
		ss.source_files = 'GRDB/**/*.swift', 'Support/*.{c,h}'
		ss.exclude_files = 'Support/sqlite3.h'
		ss.xcconfig = {
			'OTHER_SWIFT_FLAGS' => '$(inherited) -DSQLITE_HAS_CODEC -DUSING_BUILTIN_SQLITE -DUSING_SQLCIPHER',
			'OTHER_CFLAGS' => '$(inherited) -DSQLITE_HAS_CODEC',
			'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) SQLITE_HAS_CODEC=1'
		}

		ss.dependency 'SQLCipher', '>= 3.4.0'
	end
end
