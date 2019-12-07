struct Test {
    let title: String
    let instructions: String
    let enter: () throws -> Void
    let leave: (@escaping (Error?) -> Void) -> Void
}
