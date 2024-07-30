`TableRecord.databaseSelection` should be declared as a computed static property:

```diff
-static met databaseSelection: [any SQLSelectable] = [AllColumns(), Column.rowID]
+static var databaseSelection: [any SQLSelectable] { [AllColumns(), Column.rowID] }
```

---

// Warning: Converting non-sendable function value to '@Sendable (Database) throws -> sending [Player]' may introduce data races
ValueObservation.tracking(Player.fetchAll())

-> Enable `SWIFT_UPCOMING_FEATURE_INFER_SENDABLE_FROM_CAPTURES` in Build Settings

---

Task cancellation is now honored (exclusively in async accesses)

---

CSQLite was renamed GRDBSQLite.

---

ValueObservation requires Sendable values

---

Strategies

- databaseDataEncodingStrategy(for:)
- databaseDateEncodingStrategy(for:)
- databaseUUIDEncodingStrategy(for:)
- databaseDataDecodingStrategy(for:)
- databaseDateDecodingStrategy(for:)
