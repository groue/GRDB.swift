# Using or Avoiding the Main Thread 

Everything you have to known about GRDB and the main thread.

## Overview

**This guide describes the relationship between GRDB and the main thread.** It complements the <doc:Concurrency> guide, that you should read first.

Accessing the database from the main thread is handy. Graphical applications, for example, do not need to show a loading screen until values are fetched and ready for display. They do not need to spawn tasks or any other asynchronous constructs in response to user actions.

There are only two things one should think about when accessing the database from the main thread:
- How long does it take to start the database access?
- How long does it take to execute the database requests?

The first delay depends on *database contention* 
The first delay can be slowed down if the database is already busy

SQLite is very fast, and many database accesses are so fast that the user has no time to notice them. In a graphical application, performing fast database accesses from the main thread is handy, because the application does not need to show a loading screen until values are fetched and ready for display.

Other database accesses should be performed in a background thread, in order to avoid user interface freezes.

In the end, accessing the database on or off the main thread is a choice left to the application.

The database can be accessed from the main thread, or from a background thread, at the application convenience. In this guide we explain what you have to know when you intend to access the database from the main thread, or when you want to make sure a database access does not block the main thread. We will discuss plain database accesses (`read`, `write`), as well a database observation with ``ValueObservation``.

### Avoiding the Main Thread

To avoid performing database accesses from the main thread,  

<!--@START_MENU_TOKEN@-->Text<!--@END_MENU_TOKEN@-->
