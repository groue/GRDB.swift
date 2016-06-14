Pod::Spec.new do |s|
	s.name     = 'GRDB.swift'
	s.version  = '0.72.0'
	s.license  = { :type => 'MIT', :file => 'LICENSE' }
	s.summary  = 'A versatile SQLite toolkit for Swift, with WAL mode support.'
	s.homepage = 'https://github.com/groue/GRDB.swift'
	s.author   = { 'Gwendal Roué' => 'gr@pierlis.com' }
	s.source   = { :git => 'https://github.com/groue/GRDB.swift.git', :tag => "v#{s.version}" }
	s.source_files = 'GRDB/**/*.{h,m,swift}'
	s.module_name = 'GRDB'
	s.ios.deployment_target = '8.0'
	s.osx.deployment_target = '10.9'
	s.requires_arc = true
	s.module_map = 'Support/module.modulemap'
	s.framework = 'Foundation'
	s.library = 'sqlite3'
end
