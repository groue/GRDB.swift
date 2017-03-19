.PHONY: doc
doc:
	jazzy \
	  --clean \
	  --author 'Gwendal Roué' \
	  --author_url https://github.com/groue \
	  --github_url https://github.com/groue/GRDB.swift \
	  --github-file-prefix https://github.com/groue/GRDB.swift/tree/v0.102.0 \
	  --module-version 0.102.0 \
	  --module GRDB \
	  --root-url http://groue.github.io/GRDB.swift/docs/0.102.0/ \
	  --output Documentation/Reference \
	  --podspec GRDB.swift.podspec