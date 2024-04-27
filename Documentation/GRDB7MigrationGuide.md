`TableRecord.databaseSelection` should be declared as a computed static property:

```diff
-static met databaseSelection: [any SQLSelectable] = [AllColumns(), Column.rowID]
+static var databaseSelection: [any SQLSelectable] { [AllColumns(), Column.rowID] }
```
