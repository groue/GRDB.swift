import GRDB

try! print(DatabaseQueue().read { try String.fetchOne($0, sql: "SELECT 'Hello world!'")! })
