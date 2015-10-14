GRDBDemoiOS7
============

This application runs an application that displays an editable list of persons and targets iOS7.

**To integrate GRDB in your iOS7 application:**

1. Drag all Swift files contained in the [GRDB folder](../../GRDB/) in your project.

2. In the **Build Phase** tab of your target, add `libsqlite3.tbd` in the **Link Binary With Libraries** section.

3. [Add a Bridging header to your project](https://developer.apple.com/library/ios/documentation/Swift/Conceptual/BuildingCocoaApps/MixandMatch.html) in which you add:
    
    ```objc
    #import "sqlite3.h"
    ```

4. Run
