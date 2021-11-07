Demo Applications
=================

- [GRDBDemoiOS]: a storyboard-based UIKit application.
- [GRDBCombineDemo]: a Combine + SwiftUI application.
- [GRDBAsyncDemo]: a Async/Await + SwiftUI application.

Both [GRDBCombineDemo] and [GRDBAsyncDemo] use the same `@Query` property wrapper, that lets SwiftUI views automatically update their content when the database changes. It is defined in the shared [Query] package. You can copy and embed this package into your application, or just the `Query.swift` file.

[GRDBDemoiOS]: GRDBDemoiOS
[GRDBCombineDemo]: GRDBCombineDemo
[GRDBAsyncDemo]: GRDBAsyncDemo
[Query]: Query
