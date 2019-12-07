let tests: [Test] =
    [
        {
            var promise: (() -> Void)?
            return Test(
                title: "Say hello to 0xDEAD10CC",
                instructions: """
                    0xDEAD10CC is an exception that crashes your application \
                    if a database stored in an App Group container is locked \
                    when the application gets suspended.
                    
                    The first test is asserting that this app can indeed \
                    crash with 0xDEAD10CC.
                    
                    1. Launch this app on a device
                    2. Launch the Console application on the Mac
                    3. Filter logs on AppGroupTest
                    4. Send the app to bacground
                    
                    EXPECTED: the Console contains "0xDEAD10CC"
                    
                    When the expectation is fulfilled, relanch the app and \
                    hit Done.
                    """,
                enter: {
                    try AppDatabase.shared.createDatabaseQueue()
                    AppDatabase.shared.openLongRunningTransaction(until: { promise = $0 }, completion: { _ in })
            },
                leave: {
                    promise?()
            })
        }(),
]
