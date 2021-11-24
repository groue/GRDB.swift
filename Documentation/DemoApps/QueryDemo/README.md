`@Query` Demo Application
=========================

<img align="right" src="https://github.com/groue/GRDB.swift/raw/dev/async/Documentation/DemoApps/QueryDemo/Screenshot.png" width="50%">

**`@Query`, defined in the [Query package], lets your SwiftUI views automatically update their content when the database changes.**

This demo application does not focus on the relationship between GRDB and SwiftUI. This topic is better explored in the [other demo apps](..).

Instead, you'll find here how to use `@Query` so that:

- The [main view](QueryDemo/Views/AppView.swift) of the app is kept up-to-date with the information stored in the database.
- [A sheet](QueryDemo/Views/PlayerPresenceView.swift) makes sure it gets dismissed as soon as the value it needs no longer exists in the database.

This demo app is also an opportunity to explore a few practices:

- _The database is the single source of truth._ All views feed from the database and only from the database. This is NOT a general rule, but it fits well this particular app.
- _The application is robust against surprising database changes._ Surprises usually happen as your application evolves and becomes more complex. In this demo application, all the purple buttons perform actions that might not be expected. How do we make the app robust against adversarial events? 

[Query package]: ../Query
