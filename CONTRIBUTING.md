How you can Contribute
======================

- [Contribute to the GRDB codebase]
- [Answer issues and contribute to discussions]
- [Financial support and sponsoring]

## Contribute to the GRDB codebase

1. **Install** the following tools:

    - For running tests:
        - Ruby
        - [CocoaPods](https://cocoapods.org) (gem)
        - [xcpretty](https://github.com/xcpretty/xcpretty) (gem)
    - For contributing code:
        - [Swiftlint](https://github.com/realm/SwiftLint) (present in the `$PATH` or in `/opt/homebrew/bin/`)

2. **Clone the `development` branch on your machine.**

3. **Run `make SQLiteCustom` in the terminal**, at the root of the repository.
    
    This step is not strictly necessary if you do not plan to work on custom SQLite builds. But it will avoid a lot of warnings in Xcode.

4. **Open `GRDB.xcworkspace`.** This workspace contains six projects:
    
    - `GRDB.xcodeproj`: the project which contains the GRDB framework and test targets. The sources are organized in two groups:
        - `GRDB`: GRDB sources
        - `Tests`: GRDB tests
    - `GRDBCustom.xcodeproj`: the project which builds GRDB with a custom SQLite build.
    - `GRDBProfiling.xcodeproj`: a project which helps profiling GRDB with Instruments. No code here is really precious.
    - `GRDBDemoiOS.xcodeproj`, `GRDBCombineDemo.xcodeproj`, `GRDBAsyncDemo.xcodeproj`: the demo apps.
    
    To work with `GRDBCustom.xcodeproj`:
    
    - Make sure Xcode is installed in `/Applications`.
    - Run `make SQLiteCustom` in the terminal so that SQLite sources are present.

5. **Run tests**
    
    You can run tests from `GRDB.xcworkspace`, after selecting your scheme (`GRDB` from `GRDB.xcodeproj` or `GRDBCustom` from `GRDBCustom.xcodeproj`).
    
    Before submitting a pull request, please run in the terminal:
    
    ```sh
    make smokeTest
    ```
    
    The "smoke tests" perform minimal testing of the system SQLite, SQLCipher, custom SQLite builds, as well as SPM integration.
    
    Before a release, the full test suite must pass:
    
    ```sh
    make test
    ```
    
    The full test suite performs many more checks, such as the ability to archive an XCFramework, various installation methods, the demo apps, etc.
    
6. **Please respect the existing coding style**
    
    - Get familiar with the [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/).
    - Spaces, not tabs.
    - Whitespace-only lines are not trimmed.
    - Documentation comments are hard-wrapped at column 76 (Xcode > Preferences > Text Editing > Display > [X] Page guide at column: 76).
    - No Swiftlint warning after a build.


7. **Please provide documentation for your changes**

    GRDB documentation is provided as a DocC reference, and guides ([README.md](README.md) and the [Documentation](Documentation) folder).
    
    Please keep the reference and the guides up-to-date. To control the quality of your DocC reference documentation, close the workspace, open `Package.swift` in Xcode, and use Product > Build Documentation.
    
    GRDB is "documentation-driven", which means that nothing ships until it is supported by documentation that makes sense. Documentation makes sense when someone who is not you is able to figure out what is the purpose of your contribution, how to use it, and what are its eventual caveats and corner cases. When the documentation is hard to write, or reveals too many caveats, it is the sign that the api needs to be fixed.
    
8. **Open a pull request with your changes (targeting the `development` branch)!**

9. **If you are granted a push access to the repository**, check [ReleaseProcess.md](Documentation/ReleaseProcess.md) in order to publish a new GRDB version.


## Answer issues and contribute to discussions

Answering [issues](https://github.com/groue/GRDB.swift/issues), participating in [discussions](https://github.com/groue/GRDB.swift/discussions) and in the [forum](https://forums.swift.org/c/related-projects/grdb/36) is a great way to help, get familiar with the library, and shape its direction.


## Financial support and sponsoring

GRDB is free, and openly developed by its contributors, on their free time, according to their will, needs, and availability. It is not controlled by any company.

Support is free as well, as long as it happens publicly, and is available to everyone as well as internet search engines. This excludes the private channels of social networks, closed environments such as Slack, etc.

When you have specific development or support needs, please send an email to [Gwendal Roué](mailto:gr@pierlis.com) so that we can enter a regular business relationship through the [Pierlis](http://pierlis.com/) company, based in Paris, France.

You can also [sponsor @groue via GitHub](https://github.com/sponsors/groue).


[Contribute to the GRDB codebase]: #contribute-to-the-grdb-codebase
[Answer issues and contribute to discussions]: #answer-issues-and-contribute-to-discussions
[Financial support and sponsoring]: #financial-support-and-sponsoring
