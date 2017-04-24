// Generated using Sourcery 0.6.0 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT


import XCTest
@testable import GRDBTests
extension AdapterRowTests {
  static var allTests: [(String, (AdapterRowTests) -> () throws -> Void)] = [
    ("testRowAsSequence", testRowAsSequence),
    ("testRowValueAtIndex", testRowValueAtIndex),
    ("testRowValueNamed", testRowValueNamed),
    ("testRowValueFromColumn", testRowValueFromColumn),
    ("testDataNoCopy", testDataNoCopy),
    ("testRowDatabaseValueAtIndex", testRowDatabaseValueAtIndex),
    ("testRowDatabaseValueNamed", testRowDatabaseValueNamed),
    ("testRowCount", testRowCount),
    ("testRowColumnNames", testRowColumnNames),
    ("testRowDatabaseValues", testRowDatabaseValues),
    ("testRowIsCaseInsensitive", testRowIsCaseInsensitive),
    ("testRowIsCaseInsensitiveAndReturnsLeftmostMatchingColumn", testRowIsCaseInsensitiveAndReturnsLeftmostMatchingColumn),
    ("testRowAdapterIsCaseInsensitiveAndPicksLeftmostBaseColumn", testRowAdapterIsCaseInsensitiveAndPicksLeftmostBaseColumn),
    ("testMissingColumn", testMissingColumn),
    ("testRowHasColumnIsCaseInsensitive", testRowHasColumnIsCaseInsensitive),
    ("testScopes", testScopes),
    ("testScopesWithMainMapping", testScopesWithMainMapping),
    ("testMergeScopes", testMergeScopes),
    ("testThreeLevelScopes", testThreeLevelScopes),
    ("testSuffixAdapter", testSuffixAdapter),
    ("testSuffixAdapterIndexesAreIndependentFromScopes", testSuffixAdapterIndexesAreIndependentFromScopes),
    ("testRangeAdapterWithCountableRange", testRangeAdapterWithCountableRange),
    ("testRangeAdapterWithCountableClosedRange", testRangeAdapterWithCountableClosedRange),
    ("testRangeAdapterIndexesAreIndependentFromScopes", testRangeAdapterIndexesAreIndependentFromScopes),
    ("testCopy", testCopy),
    ("testEqualityWithCopy", testEqualityWithCopy),
    ("testEqualityComparesScopes", testEqualityComparesScopes),
    ("testEqualityWithNonMappedRow", testEqualityWithNonMappedRow),
    ("testEmptyMapping", testEmptyMapping),
    ("testRequestAdapter", testRequestAdapter),
    ("testTypedRequestAdapter", testTypedRequestAdapter),
  ]
}
extension AnyCursorTests {
  static var allTests: [(String, (AnyCursorTests) -> () throws -> Void)] = [
    ("testAnyCursorFromClosure", testAnyCursorFromClosure),
    ("testAnyCursorFromThrowingClosure", testAnyCursorFromThrowingClosure),
    ("testAnyCursorFromCursor", testAnyCursorFromCursor),
    ("testAnyCursorFromThrowingCursor", testAnyCursorFromThrowingCursor),
  ]
}
extension CGFloatTests {
  static var allTests: [(String, (CGFloatTests) -> () throws -> Void)] = [
    ("testCGFLoat", testCGFLoat),
  ]
}
extension ConcurrencyTests {
  static var allTests: [(String, (ConcurrencyTests) -> () throws -> Void)] = [
    ("testWrappedReadWrite", testWrappedReadWrite),
    ("testDeferredTransactionConcurrency", testDeferredTransactionConcurrency),
    ("testExclusiveTransactionConcurrency", testExclusiveTransactionConcurrency),
    ("testImmediateTransactionConcurrency", testImmediateTransactionConcurrency),
    ("testBusyCallback", testBusyCallback),
    ("testReaderDuringDefaultTransaction", testReaderDuringDefaultTransaction),
    ("testReaderInDeferredTransactionDuringDefaultTransaction", testReaderInDeferredTransactionDuringDefaultTransaction),
  ]
}
extension CursorTests {
  static var allTests: [(String, (CursorTests) -> () throws -> Void)] = [
    ("testContainsEquatable", testContainsEquatable),
    ("testContainsClosure", testContainsClosure),
    ("testContainsIsLazy", testContainsIsLazy),
    ("testFirst", testFirst),
    ("testFirstIsLazy", testFirstIsLazy),
    ("testFlatMapOfOptional", testFlatMapOfOptional),
    ("testForEach", testForEach),
    ("testThrowingForEach", testThrowingForEach),
    ("testReduce", testReduce),
  ]
}
extension DataMemoryTests {
  static var allTests: [(String, (DataMemoryTests) -> () throws -> Void)] = [
    ("testMemoryBehavior", testMemoryBehavior),
  ]
}
extension DatabaseCoderTests {
  static var allTests: [(String, (DatabaseCoderTests) -> () throws -> Void)] = [
    ("testDatabaseCoder", testDatabaseCoder),
    ("testDatabaseCoderInitNilFailure", testDatabaseCoderInitNilFailure),
    ("testDatabaseCoderFromDatabaseValueFailure", testDatabaseCoderFromDatabaseValueFailure),
  ]
}
extension DatabaseCollationTests {
  static var allTests: [(String, (DatabaseCollationTests) -> () throws -> Void)] = [
    ("testDefaultCollations", testDefaultCollations),
    ("testCollation", testCollation),
  ]
}
extension DatabaseCursorTests {
  static var allTests: [(String, (DatabaseCursorTests) -> () throws -> Void)] = [
    ("testNextReturnsNilAfterExhaustion", testNextReturnsNilAfterExhaustion),
    ("testStepError", testStepError),
    ("testStepDatabaseError", testStepDatabaseError),
  ]
}
extension DatabaseErrorTests {
  static var allTests: [(String, (DatabaseErrorTests) -> () throws -> Void)] = [
    ("testDatabaseErrorInTransaction", testDatabaseErrorInTransaction),
    ("testDatabaseErrorInTopLevelSavepoint", testDatabaseErrorInTopLevelSavepoint),
    ("testDatabaseErrorThrownByUpdateStatementContainSQLAndArguments", testDatabaseErrorThrownByUpdateStatementContainSQLAndArguments),
    ("testDatabaseErrorThrownByExecuteMultiStatementContainSQL", testDatabaseErrorThrownByExecuteMultiStatementContainSQL),
    ("testExtendedResultCodesAreActivated", testExtendedResultCodesAreActivated),
    ("testNSErrorBridging", testNSErrorBridging),
  ]
}
extension DatabaseFunctionTests {
  static var allTests: [(String, (DatabaseFunctionTests) -> () throws -> Void)] = [
    ("testDefaultFunctions", testDefaultFunctions),
    ("testFunctionReturningNull", testFunctionReturningNull),
    ("testFunctionReturningInt64", testFunctionReturningInt64),
    ("testFunctionReturningDouble", testFunctionReturningDouble),
    ("testFunctionReturningString", testFunctionReturningString),
    ("testFunctionReturningData", testFunctionReturningData),
    ("testFunctionReturningCustomValueType", testFunctionReturningCustomValueType),
    ("testFunctionArgumentNil", testFunctionArgumentNil),
    ("testFunctionArgumentInt64", testFunctionArgumentInt64),
    ("testFunctionArgumentDouble", testFunctionArgumentDouble),
    ("testFunctionArgumentString", testFunctionArgumentString),
    ("testFunctionArgumentBlob", testFunctionArgumentBlob),
    ("testFunctionArgumentCustomValueType", testFunctionArgumentCustomValueType),
    ("testFunctionWithoutArgument", testFunctionWithoutArgument),
    ("testFunctionOfOneArgument", testFunctionOfOneArgument),
    ("testFunctionOfTwoArguments", testFunctionOfTwoArguments),
    ("testVariadicFunction", testVariadicFunction),
    ("testFunctionThrowingDatabaseErrorWithMessage", testFunctionThrowingDatabaseErrorWithMessage),
    ("testFunctionThrowingDatabaseErrorWithCode", testFunctionThrowingDatabaseErrorWithCode),
    ("testFunctionThrowingDatabaseErrorWithMessageAndCode", testFunctionThrowingDatabaseErrorWithMessageAndCode),
    ("testFunctionThrowingCustomError", testFunctionThrowingCustomError),
    ("testFunctionsAreClosures", testFunctionsAreClosures),
  ]
}
extension DatabaseLogErrorTests {
  static var allTests: [(String, (DatabaseLogErrorTests) -> () throws -> Void)] = [
    ("testErrorLog", testErrorLog),
  ]
}
extension DatabaseMigratorTests {
  static var allTests: [(String, (DatabaseMigratorTests) -> () throws -> Void)] = [
    ("testMigratorDatabaseQueue", testMigratorDatabaseQueue),
    ("testMigratorDatabasePool", testMigratorDatabasePool),
    ("testMigrationFailureTriggersRollback", testMigrationFailureTriggersRollback),
    ("testMigrationWithoutForeignKeyChecks", testMigrationWithoutForeignKeyChecks),
  ]
}
extension DatabasePoolBackupTests {
  static var allTests: [(String, (DatabasePoolBackupTests) -> () throws -> Void)] = [
    ("testBackup", testBackup),
  ]
}
extension DatabasePoolCollationTests {
  static var allTests: [(String, (DatabasePoolCollationTests) -> () throws -> Void)] = [
    ("testCollationIsSharedBetweenWriterAndReaders", testCollationIsSharedBetweenWriterAndReaders),
  ]
}
extension DatabasePoolConcurrencyTests {
  static var allTests: [(String, (DatabasePoolConcurrencyTests) -> () throws -> Void)] = [
    ("testDatabasePoolFundamental1", testDatabasePoolFundamental1),
    ("testDatabasePoolFundamental2", testDatabasePoolFundamental2),
    ("testDatabasePoolFundamental3", testDatabasePoolFundamental3),
    ("testWrappedReadWrite", testWrappedReadWrite),
    ("testReadFromPreviousNonWALDatabase", testReadFromPreviousNonWALDatabase),
    ("testReadOpensATransaction", testReadOpensATransaction),
    ("testReadError", testReadError),
    ("testConcurrentRead", testConcurrentRead),
    ("testReadMethodIsolationOfStatement", testReadMethodIsolationOfStatement),
    ("testReadMethodIsolationOfStatementWithCheckpoint", testReadMethodIsolationOfStatementWithCheckpoint),
    ("testReadBlockIsolationStartingWithRead", testReadBlockIsolationStartingWithRead),
    ("testReadBlockIsolationStartingWithSelect", testReadBlockIsolationStartingWithSelect),
    ("testReadBlockIsolationStartingWithWrite", testReadBlockIsolationStartingWithWrite),
    ("testReadBlockIsolationStartingWithWriteTransaction", testReadBlockIsolationStartingWithWriteTransaction),
    ("testUnsafeReadMethodIsolationOfStatement", testUnsafeReadMethodIsolationOfStatement),
    ("testUnsafeReadMethodIsolationOfStatementWithCheckpoint", testUnsafeReadMethodIsolationOfStatementWithCheckpoint),
    ("testUnsafeReadMethodIsolationOfBlock", testUnsafeReadMethodIsolationOfBlock),
    ("testReadFromCurrentStateOpensATransaction", testReadFromCurrentStateOpensATransaction),
    ("testReadFromCurrentStateOutsideOfTransaction", testReadFromCurrentStateOutsideOfTransaction),
    ("testReadFromCurrentStateError", testReadFromCurrentStateError),
    ("testIssue80", testIssue80),
  ]
}
extension DatabasePoolFunctionTests {
  static var allTests: [(String, (DatabasePoolFunctionTests) -> () throws -> Void)] = [
    ("testFunctionIsSharedBetweenWriterAndReaders", testFunctionIsSharedBetweenWriterAndReaders),
  ]
}
extension DatabasePoolReadOnlyTests {
  static var allTests: [(String, (DatabasePoolReadOnlyTests) -> () throws -> Void)] = [
    ("testConcurrentRead", testConcurrentRead),
  ]
}
extension DatabasePoolReleaseMemoryTests {
  static var allTests: [(String, (DatabasePoolReleaseMemoryTests) -> () throws -> Void)] = [
    ("testDatabasePoolDeinitClosesAllConnections", testDatabasePoolDeinitClosesAllConnections),
    ("testDatabasePoolReleaseMemoryClosesReaderConnections", testDatabasePoolReleaseMemoryClosesReaderConnections),
    ("testBlocksRetainConnection", testBlocksRetainConnection),
    ("testDatabaseIteratorRetainConnection", testDatabaseIteratorRetainConnection),
    ("testStatementDoNotRetainDatabaseConnection", testStatementDoNotRetainDatabaseConnection),
  ]
}
extension DatabasePoolSchemaCacheTests {
  static var allTests: [(String, (DatabasePoolSchemaCacheTests) -> () throws -> Void)] = [
    ("testCache", testCache),
    ("testCachedStatementsAreNotShared", testCachedStatementsAreNotShared),
  ]
}
extension DatabaseQueueBackupTests {
  static var allTests: [(String, (DatabaseQueueBackupTests) -> () throws -> Void)] = [
    ("testBackup", testBackup),
  ]
}
extension DatabaseQueueInMemoryTests {
  static var allTests: [(String, (DatabaseQueueInMemoryTests) -> () throws -> Void)] = [
    ("testInMemoryDatabase", testInMemoryDatabase),
  ]
}
extension DatabaseQueueReadOnlyTests {
  static var allTests: [(String, (DatabaseQueueReadOnlyTests) -> () throws -> Void)] = [
    ("testReadOnlyDatabaseCanNotBeModified", testReadOnlyDatabaseCanNotBeModified),
  ]
}
extension DatabaseQueueSchemaCacheTests {
  static var allTests: [(String, (DatabaseQueueSchemaCacheTests) -> () throws -> Void)] = [
    ("testCache", testCache),
  ]
}
extension DatabaseQueueTests {
  static var allTests: [(String, (DatabaseQueueTests) -> () throws -> Void)] = [
    ("testInvalidFileFormat", testInvalidFileFormat),
    ("testAddRemoveFunction", testAddRemoveFunction),
    ("testAddRemoveCollation", testAddRemoveCollation),
  ]
}
extension DatabaseQueueuReleaseMemoryTests {
  static var allTests: [(String, (DatabaseQueueuReleaseMemoryTests) -> () throws -> Void)] = [
    ("testDatabaseQueueuDeinitClosesConnection", testDatabaseQueueuDeinitClosesConnection),
    ("testBlocksRetainConnection", testBlocksRetainConnection),
    ("testDatabaseIteratorRetainConnection", testDatabaseIteratorRetainConnection),
    ("testStatementDoNotRetainDatabaseConnection", testStatementDoNotRetainDatabaseConnection),
  ]
}
extension DatabaseReaderTests {
  static var allTests: [(String, (DatabaseReaderTests) -> () throws -> Void)] = [
    ("testDatabaseQueueReadPreventsDatabaseModification", testDatabaseQueueReadPreventsDatabaseModification),
    ("testDatabasePoolReadPreventsDatabaseModification", testDatabasePoolReadPreventsDatabaseModification),
  ]
}
extension DatabaseSavepointTests {
  static var allTests: [(String, (DatabaseSavepointTests) -> () throws -> Void)] = [
    ("testIsInsideTransaction", testIsInsideTransaction),
    ("testIsInsideTransactionWithImplicitRollback", testIsInsideTransactionWithImplicitRollback),
    ("testReleaseTopLevelSavepointFromDatabaseWithDefaultDeferredTransactions", testReleaseTopLevelSavepointFromDatabaseWithDefaultDeferredTransactions),
    ("testRollbackTopLevelSavepointFromDatabaseWithDefaultDeferredTransactions", testRollbackTopLevelSavepointFromDatabaseWithDefaultDeferredTransactions),
    ("testNestedSavepointFromDatabaseWithDefaultDeferredTransactions", testNestedSavepointFromDatabaseWithDefaultDeferredTransactions),
    ("testReleaseTopLevelSavepointFromDatabaseWithDefaultImmediateTransactions", testReleaseTopLevelSavepointFromDatabaseWithDefaultImmediateTransactions),
    ("testRollbackTopLevelSavepointFromDatabaseWithDefaultImmediateTransactions", testRollbackTopLevelSavepointFromDatabaseWithDefaultImmediateTransactions),
    ("testNestedSavepointFromDatabaseWithDefaultImmediateTransactions", testNestedSavepointFromDatabaseWithDefaultImmediateTransactions),
    ("testSubsequentSavepoints", testSubsequentSavepoints),
    ("testSubsequentSavepointsWithErrors", testSubsequentSavepointsWithErrors),
  ]
}
extension DatabaseTests {
  static var allTests: [(String, (DatabaseTests) -> () throws -> Void)] = [
    ("testCreateTable", testCreateTable),
    ("testCreateTemporaryTable", testCreateTemporaryTable),
    ("testMultipleStatementsWithoutArguments", testMultipleStatementsWithoutArguments),
    ("testUpdateStatement", testUpdateStatement),
    ("testUpdateStatementWithArrayBinding", testUpdateStatementWithArrayBinding),
    ("testUpdateStatementWithDictionaryBinding", testUpdateStatementWithDictionaryBinding),
    ("testDatabaseExecute", testDatabaseExecute),
    ("testDatabaseExecuteChanges", testDatabaseExecuteChanges),
    ("testDatabaseExecuteWithArrayBinding", testDatabaseExecuteWithArrayBinding),
    ("testDatabaseExecuteWithDictionaryBinding", testDatabaseExecuteWithDictionaryBinding),
    ("testSelectStatement", testSelectStatement),
    ("testSelectStatementWithArrayBinding", testSelectStatementWithArrayBinding),
    ("testSelectStatementWithDictionaryBinding", testSelectStatementWithDictionaryBinding),
    ("testRowValueAtIndex", testRowValueAtIndex),
    ("testRowValueNamed", testRowValueNamed),
    ("testDatabaseCanBeUsedOutsideOfDatabaseQueueBlockAsLongAsTheQueueIsCorrect", testDatabaseCanBeUsedOutsideOfDatabaseQueueBlockAsLongAsTheQueueIsCorrect),
    ("testFailedCommitIsRollbacked", testFailedCommitIsRollbacked),
  ]
}
extension DatabaseTimestampTests {
  static var allTests: [(String, (DatabaseTimestampTests) -> () throws -> Void)] = [
    ("testDatabaseTimestamp", testDatabaseTimestamp),
  ]
}
extension DatabaseValueConversionTests {
  static var allTests: [(String, (DatabaseValueConversionTests) -> () throws -> Void)] = [
    ("testTextAffinity", testTextAffinity),
    ("testNumericAffinity", testNumericAffinity),
    ("testIntegerAffinity", testIntegerAffinity),
    ("testRealAffinity", testRealAffinity),
    ("testNoneAffinity", testNoneAffinity),
  ]
}
extension DatabaseValueConvertibleEscapingTests {
  static var allTests: [(String, (DatabaseValueConvertibleEscapingTests) -> () throws -> Void)] = [
    ("testText", testText),
    ("testInteger", testInteger),
    ("testDouble", testDouble),
    ("testBlob", testBlob),
  ]
}
extension DatabaseValueConvertibleFetchTests {
  static var allTests: [(String, (DatabaseValueConvertibleFetchTests) -> () throws -> Void)] = [
    ("testFetchCursor", testFetchCursor),
    ("testFetchCursorConversionFailure", testFetchCursorConversionFailure),
    ("testFetchCursorStepFailure", testFetchCursorStepFailure),
    ("testFetchCursorCompilationFailure", testFetchCursorCompilationFailure),
    ("testFetchAll", testFetchAll),
    ("testFetchAllConversionFailure", testFetchAllConversionFailure),
    ("testFetchAllStepFailure", testFetchAllStepFailure),
    ("testFetchAllCompilationFailure", testFetchAllCompilationFailure),
    ("testFetchOne", testFetchOne),
    ("testFetchOneConversionFailure", testFetchOneConversionFailure),
    ("testFetchOneStepFailure", testFetchOneStepFailure),
    ("testFetchOneCompilationFailure", testFetchOneCompilationFailure),
    ("testOptionalFetchCursor", testOptionalFetchCursor),
    ("testOptionalFetchCursorConversionFailure", testOptionalFetchCursorConversionFailure),
    ("testOptionalFetchCursorStepFailure", testOptionalFetchCursorStepFailure),
    ("testOptionalFetchCursorCompilationFailure", testOptionalFetchCursorCompilationFailure),
    ("testOptionalFetchAll", testOptionalFetchAll),
    ("testOptionalFetchAllConversionFailure", testOptionalFetchAllConversionFailure),
    ("testOptionalFetchAllStepFailure", testOptionalFetchAllStepFailure),
    ("testOptionalFetchAllCompilationFailure", testOptionalFetchAllCompilationFailure),
  ]
}
extension DatabaseValueConvertibleSubclassTests {
  static var allTests: [(String, (DatabaseValueConvertibleSubclassTests) -> () throws -> Void)] = [
    ("testParent", testParent),
    ("testChild", testChild),
  ]
}
extension DatabaseValueTests {
  static var allTests: [(String, (DatabaseValueTests) -> () throws -> Void)] = [
    ("testDatabaseValueAsDatabaseValueConvertible", testDatabaseValueAsDatabaseValueConvertible),
    ("testDatabaseValueCanBeUsedAsStatementArgument", testDatabaseValueCanBeUsedAsStatementArgument),
    ("testDatabaseValueEquatable", testDatabaseValueEquatable),
    ("testDatabaseValueHash", testDatabaseValueHash),
    ("testDatabaseValueDescription", testDatabaseValueDescription),
  ]
}
extension DatabaseWriterTests {
  static var allTests: [(String, (DatabaseWriterTests) -> () throws -> Void)] = [
    ("testDatabaseQueueAvailableDatabaseConnection", testDatabaseQueueAvailableDatabaseConnection),
    ("testDatabasePoolAvailableDatabaseConnection", testDatabasePoolAvailableDatabaseConnection),
  ]
}
extension EnumeratedCursorTests {
  static var allTests: [(String, (EnumeratedCursorTests) -> () throws -> Void)] = [
    ("testEnumeratedCursorFromCursor", testEnumeratedCursorFromCursor),
    ("testEnumeratedCursorFromThrowingCursor", testEnumeratedCursorFromThrowingCursor),
  ]
}
extension FTS3PatternTests {
  static var allTests: [(String, (FTS3PatternTests) -> () throws -> Void)] = [
    ("testValidFTS3Pattern", testValidFTS3Pattern),
    ("testInvalidFTS3Pattern", testInvalidFTS3Pattern),
    ("testFTS3PatternWithAnyToken", testFTS3PatternWithAnyToken),
    ("testFTS3PatternWithAllTokens", testFTS3PatternWithAllTokens),
    ("testFTS3PatternWithPhrase", testFTS3PatternWithPhrase),
  ]
}
extension FTS3RecordTests {
  static var allTests: [(String, (FTS3RecordTests) -> () throws -> Void)] = [
    ("testRowIdIsSelectedByDefault", testRowIdIsSelectedByDefault),
    ("testMatch", testMatch),
    ("testMatchNil", testMatchNil),
    ("testFetchCount", testFetchCount),
  ]
}
extension FTS3TableBuilderTests {
  static var allTests: [(String, (FTS3TableBuilderTests) -> () throws -> Void)] = [
    ("testWithoutBody", testWithoutBody),
    ("testOptions", testOptions),
    ("testSimpleTokenizer", testSimpleTokenizer),
    ("testPorterTokenizer", testPorterTokenizer),
    ("testUnicode61Tokenizer", testUnicode61Tokenizer),
    ("testUnicode61TokenizerRemoveDiacritics", testUnicode61TokenizerRemoveDiacritics),
    ("testUnicode61TokenizerSeparators", testUnicode61TokenizerSeparators),
    ("testUnicode61TokenizerTokenCharacters", testUnicode61TokenizerTokenCharacters),
    ("testColumns", testColumns),
  ]
}
extension FTS3TokenizerTests {
  static var allTests: [(String, (FTS3TokenizerTests) -> () throws -> Void)] = [
    ("testSimpleTokenizer", testSimpleTokenizer),
    ("testPorterTokenizer", testPorterTokenizer),
    ("testUnicode61Tokenizer", testUnicode61Tokenizer),
    ("testUnicode61TokenizerRemoveDiacritics", testUnicode61TokenizerRemoveDiacritics),
    ("testUnicode61TokenizerSeparators", testUnicode61TokenizerSeparators),
    ("testUnicode61TokenizerTokenCharacters", testUnicode61TokenizerTokenCharacters),
  ]
}
extension FTS4RecordTests {
  static var allTests: [(String, (FTS4RecordTests) -> () throws -> Void)] = [
    ("testRowIdIsSelectedByDefault", testRowIdIsSelectedByDefault),
    ("testMatch", testMatch),
    ("testMatchNil", testMatchNil),
    ("testFetchCount", testFetchCount),
  ]
}
extension FTS4TableBuilderTests {
  static var allTests: [(String, (FTS4TableBuilderTests) -> () throws -> Void)] = [
    ("testWithoutBody", testWithoutBody),
    ("testOptions", testOptions),
    ("testSimpleTokenizer", testSimpleTokenizer),
    ("testPorterTokenizer", testPorterTokenizer),
    ("testUnicode61Tokenizer", testUnicode61Tokenizer),
    ("testUnicode61TokenizerRemoveDiacritics", testUnicode61TokenizerRemoveDiacritics),
    ("testUnicode61TokenizerSeparators", testUnicode61TokenizerSeparators),
    ("testUnicode61TokenizerTokenCharacters", testUnicode61TokenizerTokenCharacters),
    ("testColumns", testColumns),
    ("testNotIndexedColumns", testNotIndexedColumns),
    ("testFTS4Options", testFTS4Options),
    ("testFTS4Synchronization", testFTS4Synchronization),
  ]
}
extension FetchedRecordsControllerTests {
  static var allTests: [(String, (FetchedRecordsControllerTests) -> () throws -> Void)] = [
    ("testControllerFromSQL", testControllerFromSQL),
    ("testControllerFromSQLWithAdapter", testControllerFromSQLWithAdapter),
    ("testControllerFromRequest", testControllerFromRequest),
    ("testSections", testSections),
    ("testEmptyRequestGivesOneSection", testEmptyRequestGivesOneSection),
    ("testDatabaseChangesAreNotReReflectedUntilPerformFetchAndDelegateIsSet", testDatabaseChangesAreNotReReflectedUntilPerformFetchAndDelegateIsSet),
    ("testSimpleInsert", testSimpleInsert),
    ("testSimpleUpdate", testSimpleUpdate),
    ("testSimpleDelete", testSimpleDelete),
    ("testSimpleMove", testSimpleMove),
    ("testSideTableChange", testSideTableChange),
    ("testComplexChanges", testComplexChanges),
    ("testExternalTableChange", testExternalTableChange),
    ("testCustomRecordIdentity", testCustomRecordIdentity),
    ("testRequestChange", testRequestChange),
    ("testSetCallbacksAfterUpdate", testSetCallbacksAfterUpdate),
    ("testTrailingClosureCallback", testTrailingClosureCallback),
    ("testFetchAlongside", testFetchAlongside),
    ("testFetchErrors", testFetchErrors),
  ]
}
extension FilterCursorTests {
  static var allTests: [(String, (FilterCursorTests) -> () throws -> Void)] = [
    ("testFilterCursorFromCursor", testFilterCursorFromCursor),
    ("testFilterCursorFromThrowingCursor", testFilterCursorFromThrowingCursor),
    ("testThrowingFilterCursorFromCursor", testThrowingFilterCursorFromCursor),
  ]
}
extension FlattenCursorTests {
  static var allTests: [(String, (FlattenCursorTests) -> () throws -> Void)] = [
    ("testFlatMapOfSequence", testFlatMapOfSequence),
    ("testFlatMapOfCursor", testFlatMapOfCursor),
    ("testSequenceFlatMapOfCursor", testSequenceFlatMapOfCursor),
    ("testJoinedSequences", testJoinedSequences),
    ("testJoinedCursors", testJoinedCursors),
  ]
}
extension FoundationDataTests {
  static var allTests: [(String, (FoundationDataTests) -> () throws -> Void)] = [
    ("testDatabaseValueCanNotStoreEmptyData", testDatabaseValueCanNotStoreEmptyData),
    ("testDataDatabaseValueRoundTrip", testDataDatabaseValueRoundTrip),
    ("testDataFromDatabaseValueFailure", testDataFromDatabaseValueFailure),
  ]
}
extension FoundationDateComponentsTests {
  static var allTests: [(String, (FoundationDateComponentsTests) -> () throws -> Void)] = [
    ("testDatabaseDateComponentsFormatHM", testDatabaseDateComponentsFormatHM),
    ("testDatabaseDateComponentsFormatHMS", testDatabaseDateComponentsFormatHMS),
    ("testDatabaseDateComponentsFormatHMSS", testDatabaseDateComponentsFormatHMSS),
    ("testDatabaseDateComponentsFormatYMD", testDatabaseDateComponentsFormatYMD),
    ("testDatabaseDateComponentsFormatYMD_HM", testDatabaseDateComponentsFormatYMD_HM),
    ("testDatabaseDateComponentsFormatYMD_HMS", testDatabaseDateComponentsFormatYMD_HMS),
    ("testDatabaseDateComponentsFormatYMD_HMSS", testDatabaseDateComponentsFormatYMD_HMSS),
    ("testUndefinedDatabaseDateComponentsFormatYMD_HMSS", testUndefinedDatabaseDateComponentsFormatYMD_HMSS),
    ("testDatabaseDateComponentsFormatIso8601YMD_HM", testDatabaseDateComponentsFormatIso8601YMD_HM),
    ("testDatabaseDateComponentsFormatIso8601YMD_HMS", testDatabaseDateComponentsFormatIso8601YMD_HMS),
    ("testDatabaseDateComponentsFormatIso8601YMD_HMSS", testDatabaseDateComponentsFormatIso8601YMD_HMSS),
    ("testFormatYMD_HMSIsLexicallyComparableToCURRENT_TIMESTAMP", testFormatYMD_HMSIsLexicallyComparableToCURRENT_TIMESTAMP),
    ("testDatabaseDateComponentsFromUnparsableString", testDatabaseDateComponentsFromUnparsableString),
    ("testDatabaseDateComponentsFailureFromNilDateComponents", testDatabaseDateComponentsFailureFromNilDateComponents),
  ]
}
extension FoundationDateTests {
  static var allTests: [(String, (FoundationDateTests) -> () throws -> Void)] = [
    ("testDate", testDate),
    ("testDateIsLexicallyComparableToCURRENT_TIMESTAMP", testDateIsLexicallyComparableToCURRENT_TIMESTAMP),
    ("testDateFromUnparsableString", testDateFromUnparsableString),
    ("testDateDoesNotAcceptFormatHM", testDateDoesNotAcceptFormatHM),
    ("testDateDoesNotAcceptFormatHMS", testDateDoesNotAcceptFormatHMS),
    ("testDateDoesNotAcceptFormatHMSS", testDateDoesNotAcceptFormatHMSS),
    ("testDateAcceptsFormatYMD", testDateAcceptsFormatYMD),
    ("testDateAcceptsFormatYMD_HM", testDateAcceptsFormatYMD_HM),
    ("testDateAcceptsFormatYMD_HMS", testDateAcceptsFormatYMD_HMS),
    ("testDateAcceptsFormatYMD_HMSS", testDateAcceptsFormatYMD_HMSS),
    ("testDateAcceptsJulianDayNumber", testDateAcceptsJulianDayNumber),
    ("testDateAcceptsFormatIso8601YMD_HM", testDateAcceptsFormatIso8601YMD_HM),
    ("testDateAcceptsFormatIso8601YMD_HMS", testDateAcceptsFormatIso8601YMD_HMS),
    ("testDateAcceptsFormatIso8601YMD_HMSS", testDateAcceptsFormatIso8601YMD_HMSS),
  ]
}
extension FoundationNSDataTests {
  static var allTests: [(String, (FoundationNSDataTests) -> () throws -> Void)] = [
    ("testDatabaseValueCanNotStoreEmptyData", testDatabaseValueCanNotStoreEmptyData),
    ("testNSDataDatabaseValueRoundTrip", testNSDataDatabaseValueRoundTrip),
    ("testNSDataFromDatabaseValueFailure", testNSDataFromDatabaseValueFailure),
  ]
}
extension FoundationNSDateTests {
  static var allTests: [(String, (FoundationNSDateTests) -> () throws -> Void)] = [
    ("testNSDate", testNSDate),
    ("testNSDateIsLexicallyComparableToCURRENT_TIMESTAMP", testNSDateIsLexicallyComparableToCURRENT_TIMESTAMP),
    ("testNSDateFromUnparsableString", testNSDateFromUnparsableString),
    ("testNSDateDoesNotAcceptFormatHM", testNSDateDoesNotAcceptFormatHM),
    ("testNSDateDoesNotAcceptFormatHMS", testNSDateDoesNotAcceptFormatHMS),
    ("testNSDateDoesNotAcceptFormatHMSS", testNSDateDoesNotAcceptFormatHMSS),
    ("testNSDateAcceptsFormatYMD", testNSDateAcceptsFormatYMD),
    ("testNSDateAcceptsFormatYMD_HM", testNSDateAcceptsFormatYMD_HM),
    ("testNSDateAcceptsFormatYMD_HMS", testNSDateAcceptsFormatYMD_HMS),
    ("testNSDateAcceptsFormatYMD_HMSS", testNSDateAcceptsFormatYMD_HMSS),
    ("testNSDateAcceptsJulianDayNumber", testNSDateAcceptsJulianDayNumber),
    ("testNSDateAcceptsFormatIso8601YMD_HM", testNSDateAcceptsFormatIso8601YMD_HM),
    ("testNSDateAcceptsFormatIso8601YMD_HMS", testNSDateAcceptsFormatIso8601YMD_HMS),
    ("testNSDateAcceptsFormatIso8601YMD_HMSS", testNSDateAcceptsFormatIso8601YMD_HMSS),
  ]
}
extension FoundationNSDecimalNumberTests {
  static var allTests: [(String, (FoundationNSDecimalNumberTests) -> () throws -> Void)] = [
    ("testNSDecimalNumberPreservesIntegerValues", testNSDecimalNumberPreservesIntegerValues),
  ]
}
extension FoundationNSNullTests {
  static var allTests: [(String, (FoundationNSNullTests) -> () throws -> Void)] = [
    ("testNSNullFromDatabaseValue", testNSNullFromDatabaseValue),
    ("testNSNullFromDatabaseValueFailure", testNSNullFromDatabaseValueFailure),
  ]
}
extension FoundationNSNumberTests {
  static var allTests: [(String, (FoundationNSNumberTests) -> () throws -> Void)] = [
    ("testNSNumberDatabaseValueToSwiftType", testNSNumberDatabaseValueToSwiftType),
    ("testNSNumberDatabaseValueRoundTrip", testNSNumberDatabaseValueRoundTrip),
    ("testNSNumberFromDatabaseValueFailure", testNSNumberFromDatabaseValueFailure),
  ]
}
extension FoundationNSStringTests {
  static var allTests: [(String, (FoundationNSStringTests) -> () throws -> Void)] = [
    ("testNSStringDatabaseValueRoundTrip", testNSStringDatabaseValueRoundTrip),
    ("testNSStringFromStringDatabaseValueSuccess", testNSStringFromStringDatabaseValueSuccess),
    ("testNSNumberFromDatabaseValueFailure", testNSNumberFromDatabaseValueFailure),
  ]
}
extension FoundationNSURLTests {
  static var allTests: [(String, (FoundationNSURLTests) -> () throws -> Void)] = [
    ("testNSURLDatabaseValueRoundTrip", testNSURLDatabaseValueRoundTrip),
    ("testNSURLFromDatabaseValueFailure", testNSURLFromDatabaseValueFailure),
  ]
}
extension FoundationNSUUIDTests {
  static var allTests: [(String, (FoundationNSUUIDTests) -> () throws -> Void)] = [
    ("testNSUUIDDatabaseValueRoundTrip", testNSUUIDDatabaseValueRoundTrip),
    ("testNSUUIDFromDatabaseValueFailure", testNSUUIDFromDatabaseValueFailure),
  ]
}
extension FoundationURLTests {
  static var allTests: [(String, (FoundationURLTests) -> () throws -> Void)] = [
    ("testURLDatabaseValueRoundTrip", testURLDatabaseValueRoundTrip),
    ("testURLFromDatabaseValueFailure", testURLFromDatabaseValueFailure),
  ]
}
extension FoundationUUIDTests {
  static var allTests: [(String, (FoundationUUIDTests) -> () throws -> Void)] = [
    ("testUUIDDatabaseValueRoundTrip", testUUIDDatabaseValueRoundTrip),
    ("testUUIDFromDatabaseValueFailure", testUUIDFromDatabaseValueFailure),
  ]
}
extension IndexInfoTests {
  static var allTests: [(String, (IndexInfoTests) -> () throws -> Void)] = [
    ("testIndexes", testIndexes),
    ("testColumnsThatUniquelyIdentityRows", testColumnsThatUniquelyIdentityRows),
  ]
}
extension IteratorCursorTests {
  static var allTests: [(String, (IteratorCursorTests) -> () throws -> Void)] = [
    ("testIteratorCursorFromIterator", testIteratorCursorFromIterator),
    ("testIteratorCursorFromSequence", testIteratorCursorFromSequence),
  ]
}
extension MapCursorTests {
  static var allTests: [(String, (MapCursorTests) -> () throws -> Void)] = [
    ("testMap", testMap),
    ("testMapThrowingCursor", testMapThrowingCursor),
  ]
}
extension MutablePersistablePersistenceConflictPolicyTests {
  static var allTests: [(String, (MutablePersistablePersistenceConflictPolicyTests) -> () throws -> Void)] = [
    ("testPolicyDefaultArguments", testPolicyDefaultArguments),
    ("testDefaultPolicy", testDefaultPolicy),
    ("testMixedPolicy", testMixedPolicy),
    ("testReplacePolicy", testReplacePolicy),
    ("testIgnorePolicy", testIgnorePolicy),
    ("testFailPolicy", testFailPolicy),
    ("testAbortPolicy", testAbortPolicy),
    ("testRollbackPolicy", testRollbackPolicy),
  ]
}
extension MutablePersistableTests {
  static var allTests: [(String, (MutablePersistableTests) -> () throws -> Void)] = [
    ("testInsertMutablePersistablePerson", testInsertMutablePersistablePerson),
    ("testUpdateMutablePersistablePerson", testUpdateMutablePersistablePerson),
    ("testPartialUpdateMutablePersistablePerson", testPartialUpdateMutablePersistablePerson),
    ("testSaveMutablePersistablePerson", testSaveMutablePersistablePerson),
    ("testDeleteMutablePersistablePerson", testDeleteMutablePersistablePerson),
    ("testExistsMutablePersistablePerson", testExistsMutablePersistablePerson),
    ("testInsertMutablePersistableCountry", testInsertMutablePersistableCountry),
    ("testUpdateMutablePersistableCountry", testUpdateMutablePersistableCountry),
    ("testSaveMutablePersistableCountry", testSaveMutablePersistableCountry),
    ("testDeleteMutablePersistableCountry", testDeleteMutablePersistableCountry),
    ("testExistsMutablePersistableCountry", testExistsMutablePersistableCountry),
    ("testInsertMutablePersistableCustomizedCountry", testInsertMutablePersistableCustomizedCountry),
    ("testUpdateMutablePersistableCustomizedCountry", testUpdateMutablePersistableCustomizedCountry),
    ("testSaveMutablePersistableCustomizedCountry", testSaveMutablePersistableCustomizedCountry),
    ("testDeleteMutablePersistableCustomizedCountry", testDeleteMutablePersistableCustomizedCountry),
    ("testExistsMutablePersistableCustomizedCountry", testExistsMutablePersistableCustomizedCountry),
  ]
}
extension NumericOverflowTests {
  static var allTests: [(String, (NumericOverflowTests) -> () throws -> Void)] = [
    ("testHighInt64FromDoubleOverflows", testHighInt64FromDoubleOverflows),
    ("testLowInt64FromDoubleOverflows", testLowInt64FromDoubleOverflows),
    ("testHighInt32FromDoubleOverflows", testHighInt32FromDoubleOverflows),
    ("testLowInt32FromDoubleOverflows", testLowInt32FromDoubleOverflows),
    ("testHighIntFromDoubleOverflows", testHighIntFromDoubleOverflows),
    ("testLowIntFromDoubleOverflows", testLowIntFromDoubleOverflows),
  ]
}
extension PersistableTests {
  static var allTests: [(String, (PersistableTests) -> () throws -> Void)] = [
    ("testInsertPersistablePerson", testInsertPersistablePerson),
    ("testSavePersistablePerson", testSavePersistablePerson),
    ("testInsertPersistablePersonClass", testInsertPersistablePersonClass),
    ("testUpdatePersistablePersonClass", testUpdatePersistablePersonClass),
    ("testPartialUpdatePersistablePersonClass", testPartialUpdatePersistablePersonClass),
    ("testSavePersistablePersonClass", testSavePersistablePersonClass),
    ("testDeletePersistablePersonClass", testDeletePersistablePersonClass),
    ("testExistsPersistablePersonClass", testExistsPersistablePersonClass),
    ("testInsertPersistableCountry", testInsertPersistableCountry),
    ("testUpdatePersistableCountry", testUpdatePersistableCountry),
    ("testPartialUpdatePersistableCountry", testPartialUpdatePersistableCountry),
    ("testSavePersistableCountry", testSavePersistableCountry),
    ("testDeletePersistableCountry", testDeletePersistableCountry),
    ("testExistsPersistableCountry", testExistsPersistableCountry),
    ("testInsertPersistableCustomizedCountry", testInsertPersistableCustomizedCountry),
    ("testUpdatePersistableCustomizedCountry", testUpdatePersistableCustomizedCountry),
    ("testPartialUpdatePersistableCustomizedCountry", testPartialUpdatePersistableCustomizedCountry),
    ("testSavePersistableCustomizedCountry", testSavePersistableCustomizedCountry),
    ("testDeletePersistableCustomizedCountry", testDeletePersistableCustomizedCountry),
    ("testExistsPersistableCustomizedCountry", testExistsPersistableCustomizedCountry),
    ("testInsertErrorDoesNotPreventSubsequentInserts", testInsertErrorDoesNotPreventSubsequentInserts),
  ]
}
extension QueryInterfaceExpressionsTests {
  static var allTests: [(String, (QueryInterfaceExpressionsTests) -> () throws -> Void)] = [
    ("testContains", testContains),
    ("testContainsWithCollation", testContainsWithCollation),
    ("testGreaterThan", testGreaterThan),
    ("testGreaterThanWithCollation", testGreaterThanWithCollation),
    ("testGreaterThanOrEqual", testGreaterThanOrEqual),
    ("testGreaterThanOrEqualWithCollation", testGreaterThanOrEqualWithCollation),
    ("testLessThan", testLessThan),
    ("testLessThanWithCollation", testLessThanWithCollation),
    ("testLessThanOrEqual", testLessThanOrEqual),
    ("testLessThanOrEqualWithCollation", testLessThanOrEqualWithCollation),
    ("testEqual", testEqual),
    ("testEqualWithCollation", testEqualWithCollation),
    ("testNotEqual", testNotEqual),
    ("testNotEqualWithCollation", testNotEqualWithCollation),
    ("testNotEqualWithSwiftNotOperator", testNotEqualWithSwiftNotOperator),
    ("testIs", testIs),
    ("testIsWithCollation", testIsWithCollation),
    ("testIsNot", testIsNot),
    ("testIsNotWithCollation", testIsNotWithCollation),
    ("testIsNotWithSwiftNotOperator", testIsNotWithSwiftNotOperator),
    ("testExists", testExists),
    ("testLogicalOperators", testLogicalOperators),
    ("testStringFunctions", testStringFunctions),
    ("testPrefixMinusOperator", testPrefixMinusOperator),
    ("testInfixMinusOperator", testInfixMinusOperator),
    ("testInfixPlusOperator", testInfixPlusOperator),
    ("testInfixMultiplyOperator", testInfixMultiplyOperator),
    ("testInfixDivideOperator", testInfixDivideOperator),
    ("testCompoundArithmeticExpression", testCompoundArithmeticExpression),
    ("testIfNull", testIfNull),
    ("testCountExpression", testCountExpression),
    ("testAvgExpression", testAvgExpression),
    ("testLengthExpression", testLengthExpression),
    ("testMinExpression", testMinExpression),
    ("testMaxExpression", testMaxExpression),
    ("testSumExpression", testSumExpression),
    ("testLikeOperator", testLikeOperator),
    ("testCustomFunction", testCustomFunction),
  ]
}
extension QueryInterfaceExtensibilityTests {
  static var allTests: [(String, (QueryInterfaceExtensibilityTests) -> () throws -> Void)] = [
    ("testStrftime", testStrftime),
    ("testMatch", testMatch),
    ("testCast", testCast),
  ]
}
extension QueryInterfaceRequestTests {
  static var allTests: [(String, (QueryInterfaceRequestTests) -> () throws -> Void)] = [
    ("testFetchRowFromRequest", testFetchRowFromRequest),
    ("testFetchCount", testFetchCount),
    ("testSelectLiteral", testSelectLiteral),
    ("testSelectLiteralWithPositionalArguments", testSelectLiteralWithPositionalArguments),
    ("testSelectLiteralWithNamedArguments", testSelectLiteralWithNamedArguments),
    ("testSelect", testSelect),
    ("testSelectAliased", testSelectAliased),
    ("testMultipleSelect", testMultipleSelect),
    ("testDistinct", testDistinct),
    ("testFilterLiteral", testFilterLiteral),
    ("testFilterLiteralWithPositionalArguments", testFilterLiteralWithPositionalArguments),
    ("testFilterLiteralWithNamedArguments", testFilterLiteralWithNamedArguments),
    ("testFilter", testFilter),
    ("testMultipleFilter", testMultipleFilter),
    ("testGroupLiteral", testGroupLiteral),
    ("testGroupLiteralWithPositionalArguments", testGroupLiteralWithPositionalArguments),
    ("testGroupLiteralWithNamedArguments", testGroupLiteralWithNamedArguments),
    ("testGroup", testGroup),
    ("testMultipleGroup", testMultipleGroup),
    ("testHavingLiteral", testHavingLiteral),
    ("testHavingLiteralWithPositionalArguments", testHavingLiteralWithPositionalArguments),
    ("testHavingLiteralWithNamedArguments", testHavingLiteralWithNamedArguments),
    ("testHaving", testHaving),
    ("testMultipleHaving", testMultipleHaving),
    ("testSortLiteral", testSortLiteral),
    ("testSortLiteralWithPositionalArguments", testSortLiteralWithPositionalArguments),
    ("testSortLiteralWithNamedArguments", testSortLiteralWithNamedArguments),
    ("testSort", testSort),
    ("testSortWithCollation", testSortWithCollation),
    ("testMultipleSort", testMultipleSort),
    ("testReverse", testReverse),
    ("testReverseWithCollation", testReverseWithCollation),
    ("testMultipleReverse", testMultipleReverse),
    ("testLimit", testLimit),
    ("testMultipleLimit", testMultipleLimit),
    ("testDelete", testDelete),
  ]
}
extension RawRepresentableDatabaseValueConvertibleTests {
  static var allTests: [(String, (RawRepresentableDatabaseValueConvertibleTests) -> () throws -> Void)] = [
    ("testColor32", testColor32),
    ("testColor64", testColor64),
    ("testColor", testColor),
    ("testGrape", testGrape),
  ]
}
extension RecordCopyTests {
  static var allTests: [(String, (RecordCopyTests) -> () throws -> Void)] = [
    ("testRecordCopy", testRecordCopy),
  ]
}
extension RecordEditedTests {
  static var allTests: [(String, (RecordEditedTests) -> () throws -> Void)] = [
    ("testRecordIsEditedAfterInit", testRecordIsEditedAfterInit),
    ("testRecordIsEditedAfterInitFromRow", testRecordIsEditedAfterInitFromRow),
    ("testRecordIsNotEditedAfterFullFetch", testRecordIsNotEditedAfterFullFetch),
    ("testRecordIsNotEditedAfterFullFetchWithIntegerPropertyOnRealAffinityColumn", testRecordIsNotEditedAfterFullFetchWithIntegerPropertyOnRealAffinityColumn),
    ("testRecordIsNotEditedAfterWiderThanFullFetch", testRecordIsNotEditedAfterWiderThanFullFetch),
    ("testRecordIsEditedAfterPartialFetch", testRecordIsEditedAfterPartialFetch),
    ("testRecordIsNotEditedAfterInsert", testRecordIsNotEditedAfterInsert),
    ("testRecordIsEditedAfterValueChange", testRecordIsEditedAfterValueChange),
    ("testRecordIsNotEditedAfterSameValueChange", testRecordIsNotEditedAfterSameValueChange),
    ("testRecordIsNotEditedAfterUpdate", testRecordIsNotEditedAfterUpdate),
    ("testRecordIsNotEditedAfterSave", testRecordIsNotEditedAfterSave),
    ("testRecordIsEditedAfterPrimaryKeyChange", testRecordIsEditedAfterPrimaryKeyChange),
    ("testCopyTransfersEditedFlag", testCopyTransfersEditedFlag),
    ("testChangesAfterInit", testChangesAfterInit),
    ("testChangesAfterInitFromRow", testChangesAfterInitFromRow),
    ("testChangesAfterFullFetch", testChangesAfterFullFetch),
    ("testChangesAfterPartialFetch", testChangesAfterPartialFetch),
    ("testChangesAfterInsert", testChangesAfterInsert),
    ("testChangesAfterValueChange", testChangesAfterValueChange),
    ("testChangesAfterUpdate", testChangesAfterUpdate),
    ("testChangesAfterSave", testChangesAfterSave),
    ("testChangesAfterPrimaryKeyChange", testChangesAfterPrimaryKeyChange),
    ("testCopyTransfersChanges", testCopyTransfersChanges),
    ("testChangesOfWrappedRecordAfterFullFetch", testChangesOfWrappedRecordAfterFullFetch),
  ]
}
extension RecordEventsTests {
  static var allTests: [(String, (RecordEventsTests) -> () throws -> Void)] = [
    ("testAwakeFromFetchIsNotTriggeredByInit", testAwakeFromFetchIsNotTriggeredByInit),
    ("testAwakeFromFetchIsNotTriggeredByInitFromRow", testAwakeFromFetchIsNotTriggeredByInitFromRow),
    ("testAwakeFromFetchIsTriggeredFetch", testAwakeFromFetchIsTriggeredFetch),
  ]
}
extension RecordInitializersTests {
  static var allTests: [(String, (RecordInitializersTests) -> () throws -> Void)] = [
    ("testFetchedRecordAreInitializedFromRow", testFetchedRecordAreInitializedFromRow),
  ]
}
extension RecordMinimalPrimaryKeyRowIDTests {
  static var allTests: [(String, (RecordMinimalPrimaryKeyRowIDTests) -> () throws -> Void)] = [
    ("testInsertWithNilPrimaryKeyInsertsARowAndSetsPrimaryKey", testInsertWithNilPrimaryKeyInsertsARowAndSetsPrimaryKey),
    ("testInsertWithNotNilPrimaryKeyThatDoesNotMatchAnyRowInsertsARow", testInsertWithNotNilPrimaryKeyThatDoesNotMatchAnyRowInsertsARow),
    ("testInsertWithNotNilPrimaryKeyThatMatchesARowThrowsDatabaseError", testInsertWithNotNilPrimaryKeyThatMatchesARowThrowsDatabaseError),
    ("testInsertAfterDeleteInsertsARow", testInsertAfterDeleteInsertsARow),
    ("testUpdateWithNotNilPrimaryKeyThatDoesNotMatchAnyRowThrowsRecordNotFound", testUpdateWithNotNilPrimaryKeyThatDoesNotMatchAnyRowThrowsRecordNotFound),
    ("testUpdateWithNotNilPrimaryKeyThatMatchesARowUpdatesThatRow", testUpdateWithNotNilPrimaryKeyThatMatchesARowUpdatesThatRow),
    ("testUpdateAfterDeleteThrowsRecordNotFound", testUpdateAfterDeleteThrowsRecordNotFound),
    ("testSaveWithNilPrimaryKeyInsertsARowAndSetsPrimaryKey", testSaveWithNilPrimaryKeyInsertsARowAndSetsPrimaryKey),
    ("testSaveWithNotNilPrimaryKeyThatDoesNotMatchAnyRowInsertsARow", testSaveWithNotNilPrimaryKeyThatDoesNotMatchAnyRowInsertsARow),
    ("testSaveWithNotNilPrimaryKeyThatMatchesARowUpdatesThatRow", testSaveWithNotNilPrimaryKeyThatMatchesARowUpdatesThatRow),
    ("testSaveAfterDeleteInsertsARow", testSaveAfterDeleteInsertsARow),
    ("testDeleteWithNotNilPrimaryKeyThatDoesNotMatchAnyRowDoesNothing", testDeleteWithNotNilPrimaryKeyThatDoesNotMatchAnyRowDoesNothing),
    ("testDeleteWithNotNilPrimaryKeyThatMatchesARowDeletesThatRow", testDeleteWithNotNilPrimaryKeyThatMatchesARowDeletesThatRow),
    ("testDeleteAfterDeleteDoesNothing", testDeleteAfterDeleteDoesNothing),
    ("testFetchCursorWithKeys", testFetchCursorWithKeys),
    ("testFetchAllWithKeys", testFetchAllWithKeys),
    ("testFetchOneWithKey", testFetchOneWithKey),
    ("testFetchCursorWithPrimaryKeys", testFetchCursorWithPrimaryKeys),
    ("testFetchAllWithPrimaryKeys", testFetchAllWithPrimaryKeys),
    ("testFetchOneWithPrimaryKey", testFetchOneWithPrimaryKey),
    ("testExistsWithNotNilPrimaryKeyThatDoesNotMatchAnyRowReturnsFalse", testExistsWithNotNilPrimaryKeyThatDoesNotMatchAnyRowReturnsFalse),
    ("testExistsWithNotNilPrimaryKeyThatMatchesARowReturnsTrue", testExistsWithNotNilPrimaryKeyThatMatchesARowReturnsTrue),
    ("testExistsAfterDeleteReturnsTrue", testExistsAfterDeleteReturnsTrue),
  ]
}
extension RecordMinimalPrimaryKeySingleTests {
  static var allTests: [(String, (RecordMinimalPrimaryKeySingleTests) -> () throws -> Void)] = [
    ("testInsertWithNilPrimaryKeyThrowsDatabaseError", testInsertWithNilPrimaryKeyThrowsDatabaseError),
    ("testInsertWithNotNilPrimaryKeyThatDoesNotMatchAnyRowInsertsARow", testInsertWithNotNilPrimaryKeyThatDoesNotMatchAnyRowInsertsARow),
    ("testInsertWithNotNilPrimaryKeyThatMatchesARowThrowsDatabaseError", testInsertWithNotNilPrimaryKeyThatMatchesARowThrowsDatabaseError),
    ("testInsertAfterDeleteInsertsARow", testInsertAfterDeleteInsertsARow),
    ("testUpdateWithNotNilPrimaryKeyThatDoesNotMatchAnyRowThrowsRecordNotFound", testUpdateWithNotNilPrimaryKeyThatDoesNotMatchAnyRowThrowsRecordNotFound),
    ("testUpdateWithNotNilPrimaryKeyThatMatchesARowUpdatesThatRow", testUpdateWithNotNilPrimaryKeyThatMatchesARowUpdatesThatRow),
    ("testUpdateAfterDeleteThrowsRecordNotFound", testUpdateAfterDeleteThrowsRecordNotFound),
    ("testSaveWithNilPrimaryKeyThrowsDatabaseError", testSaveWithNilPrimaryKeyThrowsDatabaseError),
    ("testSaveWithNotNilPrimaryKeyThatDoesNotMatchAnyRowInsertsARow", testSaveWithNotNilPrimaryKeyThatDoesNotMatchAnyRowInsertsARow),
    ("testSaveWithNotNilPrimaryKeyThatMatchesARowUpdatesThatRow", testSaveWithNotNilPrimaryKeyThatMatchesARowUpdatesThatRow),
    ("testSaveAfterDeleteInsertsARow", testSaveAfterDeleteInsertsARow),
    ("testDeleteWithNotNilPrimaryKeyThatDoesNotMatchAnyRowDoesNothing", testDeleteWithNotNilPrimaryKeyThatDoesNotMatchAnyRowDoesNothing),
    ("testDeleteWithNotNilPrimaryKeyThatMatchesARowDeletesThatRow", testDeleteWithNotNilPrimaryKeyThatMatchesARowDeletesThatRow),
    ("testDeleteAfterDeleteDoesNothing", testDeleteAfterDeleteDoesNothing),
    ("testFetchCursorWithKeys", testFetchCursorWithKeys),
    ("testFetchAllWithKeys", testFetchAllWithKeys),
    ("testFetchOneWithKey", testFetchOneWithKey),
    ("testFetchCursorWithPrimaryKeys", testFetchCursorWithPrimaryKeys),
    ("testFetchAllWithPrimaryKeys", testFetchAllWithPrimaryKeys),
    ("testFetchOneWithPrimaryKey", testFetchOneWithPrimaryKey),
    ("testExistsWithNotNilPrimaryKeyThatDoesNotMatchAnyRowReturnsFalse", testExistsWithNotNilPrimaryKeyThatDoesNotMatchAnyRowReturnsFalse),
    ("testExistsWithNotNilPrimaryKeyThatMatchesARowReturnsTrue", testExistsWithNotNilPrimaryKeyThatMatchesARowReturnsTrue),
    ("testExistsAfterDeleteReturnsTrue", testExistsAfterDeleteReturnsTrue),
  ]
}
extension RecordPersistenceConflictPolicyTests {
  static var allTests: [(String, (RecordPersistenceConflictPolicyTests) -> () throws -> Void)] = [
    ("testDefaultPersistenceConflictPolicy", testDefaultPersistenceConflictPolicy),
    ("testConfigurablePersistenceConflictPolicy", testConfigurablePersistenceConflictPolicy),
  ]
}
extension RecordPrimaryKeyHiddenRowIDTests {
  static var allTests: [(String, (RecordPrimaryKeyHiddenRowIDTests) -> () throws -> Void)] = [
    ("testInsertWithNilPrimaryKeyInsertsARowAndSetsPrimaryKey", testInsertWithNilPrimaryKeyInsertsARowAndSetsPrimaryKey),
    ("testRollbackedInsertWithNilPrimaryKeyDoesNotResetPrimaryKey", testRollbackedInsertWithNilPrimaryKeyDoesNotResetPrimaryKey),
    ("testInsertWithNotNilPrimaryKeyThatDoesNotMatchAnyRowInsertsARow", testInsertWithNotNilPrimaryKeyThatDoesNotMatchAnyRowInsertsARow),
    ("testRollbackedInsertWithNotNilPrimaryKeyDoeNotResetPrimaryKey", testRollbackedInsertWithNotNilPrimaryKeyDoeNotResetPrimaryKey),
    ("testInsertWithNotNilPrimaryKeyThatMatchesARowThrowsDatabaseError", testInsertWithNotNilPrimaryKeyThatMatchesARowThrowsDatabaseError),
    ("testInsertAfterDeleteInsertsARow", testInsertAfterDeleteInsertsARow),
    ("testUpdateWithNilPrimaryKeyThrowsRecordNotFound", testUpdateWithNilPrimaryKeyThrowsRecordNotFound),
    ("testUpdateWithNotNilPrimaryKeyThatDoesNotMatchAnyRowThrowsRecordNotFound", testUpdateWithNotNilPrimaryKeyThatDoesNotMatchAnyRowThrowsRecordNotFound),
    ("testUpdateWithNotNilPrimaryKeyThatMatchesARowUpdatesThatRow", testUpdateWithNotNilPrimaryKeyThatMatchesARowUpdatesThatRow),
    ("testUpdateAfterDeleteThrowsRecordNotFound", testUpdateAfterDeleteThrowsRecordNotFound),
    ("testSaveWithNilPrimaryKeyInsertsARowAndSetsPrimaryKey", testSaveWithNilPrimaryKeyInsertsARowAndSetsPrimaryKey),
    ("testSaveWithNotNilPrimaryKeyThatDoesNotMatchAnyRowInsertsARow", testSaveWithNotNilPrimaryKeyThatDoesNotMatchAnyRowInsertsARow),
    ("testSaveWithNotNilPrimaryKeyThatMatchesARowUpdatesThatRow", testSaveWithNotNilPrimaryKeyThatMatchesARowUpdatesThatRow),
    ("testSaveAfterDeleteInsertsARow", testSaveAfterDeleteInsertsARow),
    ("testDeleteWithNilPrimaryKey", testDeleteWithNilPrimaryKey),
    ("testDeleteWithNotNilPrimaryKeyThatDoesNotMatchAnyRowDoesNothing", testDeleteWithNotNilPrimaryKeyThatDoesNotMatchAnyRowDoesNothing),
    ("testDeleteWithNotNilPrimaryKeyThatMatchesARowDeletesThatRow", testDeleteWithNotNilPrimaryKeyThatMatchesARowDeletesThatRow),
    ("testDeleteAfterDeleteDoesNothing", testDeleteAfterDeleteDoesNothing),
    ("testFetchCursorWithKeys", testFetchCursorWithKeys),
    ("testFetchAllWithKeys", testFetchAllWithKeys),
    ("testFetchOneWithKey", testFetchOneWithKey),
    ("testFetchCursorWithPrimaryKeys", testFetchCursorWithPrimaryKeys),
    ("testFetchAllWithPrimaryKeys", testFetchAllWithPrimaryKeys),
    ("testFetchOneWithPrimaryKey", testFetchOneWithPrimaryKey),
    ("testExistsWithNilPrimaryKeyReturnsFalse", testExistsWithNilPrimaryKeyReturnsFalse),
    ("testExistsWithNotNilPrimaryKeyThatDoesNotMatchAnyRowReturnsFalse", testExistsWithNotNilPrimaryKeyThatDoesNotMatchAnyRowReturnsFalse),
    ("testExistsWithNotNilPrimaryKeyThatMatchesARowReturnsTrue", testExistsWithNotNilPrimaryKeyThatMatchesARowReturnsTrue),
    ("testExistsAfterDeleteReturnsTrue", testExistsAfterDeleteReturnsTrue),
    ("testRowIdIsSelectedByDefault", testRowIdIsSelectedByDefault),
    ("testFetchedRecordsController", testFetchedRecordsController),
  ]
}
extension RecordPrimaryKeyMultipleTests {
  static var allTests: [(String, (RecordPrimaryKeyMultipleTests) -> () throws -> Void)] = [
    ("testInsertWithNilPrimaryKeyThrowsDatabaseError", testInsertWithNilPrimaryKeyThrowsDatabaseError),
    ("testInsertWithNotNilPrimaryKeyThatDoesNotMatchAnyRowInsertsARow", testInsertWithNotNilPrimaryKeyThatDoesNotMatchAnyRowInsertsARow),
    ("testInsertWithNotNilPrimaryKeyThatMatchesARowThrowsDatabaseError", testInsertWithNotNilPrimaryKeyThatMatchesARowThrowsDatabaseError),
    ("testInsertAfterDeleteInsertsARow", testInsertAfterDeleteInsertsARow),
    ("testUpdateWithNilPrimaryKeyThrowsRecordNotFound", testUpdateWithNilPrimaryKeyThrowsRecordNotFound),
    ("testUpdateWithNotNilPrimaryKeyThatDoesNotMatchAnyRowThrowsRecordNotFound", testUpdateWithNotNilPrimaryKeyThatDoesNotMatchAnyRowThrowsRecordNotFound),
    ("testUpdateWithNotNilPrimaryKeyThatMatchesARowUpdatesThatRow", testUpdateWithNotNilPrimaryKeyThatMatchesARowUpdatesThatRow),
    ("testUpdateAfterDeleteThrowsRecordNotFound", testUpdateAfterDeleteThrowsRecordNotFound),
    ("testSaveWithNilPrimaryKeyThrowsDatabaseError", testSaveWithNilPrimaryKeyThrowsDatabaseError),
    ("testSaveWithNotNilPrimaryKeyThatDoesNotMatchAnyRowInsertsARow", testSaveWithNotNilPrimaryKeyThatDoesNotMatchAnyRowInsertsARow),
    ("testSaveWithNotNilPrimaryKeyThatMatchesARowUpdatesThatRow", testSaveWithNotNilPrimaryKeyThatMatchesARowUpdatesThatRow),
    ("testSaveAfterDeleteInsertsARow", testSaveAfterDeleteInsertsARow),
    ("testDeleteWithNilPrimaryKey", testDeleteWithNilPrimaryKey),
    ("testDeleteWithNotNilPrimaryKeyThatDoesNotMatchAnyRowDoesNothing", testDeleteWithNotNilPrimaryKeyThatDoesNotMatchAnyRowDoesNothing),
    ("testDeleteWithNotNilPrimaryKeyThatMatchesARowDeletesThatRow", testDeleteWithNotNilPrimaryKeyThatMatchesARowDeletesThatRow),
    ("testDeleteAfterDeleteDoesNothing", testDeleteAfterDeleteDoesNothing),
    ("testFetchCursorWithKeys", testFetchCursorWithKeys),
    ("testFetchAllWithKeys", testFetchAllWithKeys),
    ("testFetchOneWithKey", testFetchOneWithKey),
    ("testExistsWithNilPrimaryKeyReturnsFalse", testExistsWithNilPrimaryKeyReturnsFalse),
    ("testExistsWithNotNilPrimaryKeyThatDoesNotMatchAnyRowReturnsFalse", testExistsWithNotNilPrimaryKeyThatDoesNotMatchAnyRowReturnsFalse),
    ("testExistsWithNotNilPrimaryKeyThatMatchesARowReturnsTrue", testExistsWithNotNilPrimaryKeyThatMatchesARowReturnsTrue),
    ("testExistsAfterDeleteReturnsTrue", testExistsAfterDeleteReturnsTrue),
  ]
}
extension RecordPrimaryKeyNoneTests {
  static var allTests: [(String, (RecordPrimaryKeyNoneTests) -> () throws -> Void)] = [
    ("testInsertInsertsARow", testInsertInsertsARow),
    ("testSaveInsertsARow", testSaveInsertsARow),
    ("testFetchOneWithKey", testFetchOneWithKey),
    ("testFetchCursorWithPrimaryKeys", testFetchCursorWithPrimaryKeys),
    ("testFetchAllWithPrimaryKeys", testFetchAllWithPrimaryKeys),
    ("testFetchOneWithPrimaryKey", testFetchOneWithPrimaryKey),
  ]
}
extension RecordPrimaryKeyRowIDTests {
  static var allTests: [(String, (RecordPrimaryKeyRowIDTests) -> () throws -> Void)] = [
    ("testInsertWithNilPrimaryKeyInsertsARowAndSetsPrimaryKey", testInsertWithNilPrimaryKeyInsertsARowAndSetsPrimaryKey),
    ("testRollbackedInsertWithNilPrimaryKeyDoesNotResetPrimaryKey", testRollbackedInsertWithNilPrimaryKeyDoesNotResetPrimaryKey),
    ("testInsertWithNotNilPrimaryKeyThatDoesNotMatchAnyRowInsertsARow", testInsertWithNotNilPrimaryKeyThatDoesNotMatchAnyRowInsertsARow),
    ("testRollbackedInsertWithNotNilPrimaryKeyDoeNotResetPrimaryKey", testRollbackedInsertWithNotNilPrimaryKeyDoeNotResetPrimaryKey),
    ("testInsertWithNotNilPrimaryKeyThatMatchesARowThrowsDatabaseError", testInsertWithNotNilPrimaryKeyThatMatchesARowThrowsDatabaseError),
    ("testInsertAfterDeleteInsertsARow", testInsertAfterDeleteInsertsARow),
    ("testUpdateWithNilPrimaryKeyThrowsRecordNotFound", testUpdateWithNilPrimaryKeyThrowsRecordNotFound),
    ("testUpdateWithNotNilPrimaryKeyThatDoesNotMatchAnyRowThrowsRecordNotFound", testUpdateWithNotNilPrimaryKeyThatDoesNotMatchAnyRowThrowsRecordNotFound),
    ("testUpdateWithNotNilPrimaryKeyThatMatchesARowUpdatesThatRow", testUpdateWithNotNilPrimaryKeyThatMatchesARowUpdatesThatRow),
    ("testUpdateAfterDeleteThrowsRecordNotFound", testUpdateAfterDeleteThrowsRecordNotFound),
    ("testSaveWithNilPrimaryKeyInsertsARowAndSetsPrimaryKey", testSaveWithNilPrimaryKeyInsertsARowAndSetsPrimaryKey),
    ("testSaveWithNotNilPrimaryKeyThatDoesNotMatchAnyRowInsertsARow", testSaveWithNotNilPrimaryKeyThatDoesNotMatchAnyRowInsertsARow),
    ("testSaveWithNotNilPrimaryKeyThatMatchesARowUpdatesThatRow", testSaveWithNotNilPrimaryKeyThatMatchesARowUpdatesThatRow),
    ("testSaveAfterDeleteInsertsARow", testSaveAfterDeleteInsertsARow),
    ("testDeleteWithNilPrimaryKey", testDeleteWithNilPrimaryKey),
    ("testDeleteWithNotNilPrimaryKeyThatDoesNotMatchAnyRowDoesNothing", testDeleteWithNotNilPrimaryKeyThatDoesNotMatchAnyRowDoesNothing),
    ("testDeleteWithNotNilPrimaryKeyThatMatchesARowDeletesThatRow", testDeleteWithNotNilPrimaryKeyThatMatchesARowDeletesThatRow),
    ("testDeleteAfterDeleteDoesNothing", testDeleteAfterDeleteDoesNothing),
    ("testFetchCursorWithKeys", testFetchCursorWithKeys),
    ("testFetchAllWithKeys", testFetchAllWithKeys),
    ("testFetchOneWithKey", testFetchOneWithKey),
    ("testFetchCursorWithPrimaryKeys", testFetchCursorWithPrimaryKeys),
    ("testFetchAllWithPrimaryKeys", testFetchAllWithPrimaryKeys),
    ("testFetchOneWithPrimaryKey", testFetchOneWithPrimaryKey),
    ("testExistsWithNilPrimaryKeyReturnsFalse", testExistsWithNilPrimaryKeyReturnsFalse),
    ("testExistsWithNotNilPrimaryKeyThatDoesNotMatchAnyRowReturnsFalse", testExistsWithNotNilPrimaryKeyThatDoesNotMatchAnyRowReturnsFalse),
    ("testExistsWithNotNilPrimaryKeyThatMatchesARowReturnsTrue", testExistsWithNotNilPrimaryKeyThatMatchesARowReturnsTrue),
    ("testExistsAfterDeleteReturnsTrue", testExistsAfterDeleteReturnsTrue),
  ]
}
extension RecordPrimaryKeySingleTests {
  static var allTests: [(String, (RecordPrimaryKeySingleTests) -> () throws -> Void)] = [
    ("testInsertWithNilPrimaryKeyThrowsDatabaseError", testInsertWithNilPrimaryKeyThrowsDatabaseError),
    ("testInsertWithNotNilPrimaryKeyThatDoesNotMatchAnyRowInsertsARow", testInsertWithNotNilPrimaryKeyThatDoesNotMatchAnyRowInsertsARow),
    ("testInsertWithNotNilPrimaryKeyThatMatchesARowThrowsDatabaseError", testInsertWithNotNilPrimaryKeyThatMatchesARowThrowsDatabaseError),
    ("testInsertAfterDeleteInsertsARow", testInsertAfterDeleteInsertsARow),
    ("testUpdateWithNilPrimaryKeyThrowsRecordNotFound", testUpdateWithNilPrimaryKeyThrowsRecordNotFound),
    ("testUpdateWithNotNilPrimaryKeyThatDoesNotMatchAnyRowThrowsRecordNotFound", testUpdateWithNotNilPrimaryKeyThatDoesNotMatchAnyRowThrowsRecordNotFound),
    ("testUpdateWithNotNilPrimaryKeyThatMatchesARowUpdatesThatRow", testUpdateWithNotNilPrimaryKeyThatMatchesARowUpdatesThatRow),
    ("testUpdateAfterDeleteThrowsRecordNotFound", testUpdateAfterDeleteThrowsRecordNotFound),
    ("testSaveWithNilPrimaryKeyThrowsDatabaseError", testSaveWithNilPrimaryKeyThrowsDatabaseError),
    ("testSaveWithNotNilPrimaryKeyThatDoesNotMatchAnyRowInsertsARow", testSaveWithNotNilPrimaryKeyThatDoesNotMatchAnyRowInsertsARow),
    ("testSaveWithNotNilPrimaryKeyThatMatchesARowUpdatesThatRow", testSaveWithNotNilPrimaryKeyThatMatchesARowUpdatesThatRow),
    ("testSaveAfterDeleteInsertsARow", testSaveAfterDeleteInsertsARow),
    ("testDeleteWithNilPrimaryKey", testDeleteWithNilPrimaryKey),
    ("testDeleteWithNotNilPrimaryKeyThatDoesNotMatchAnyRowDoesNothing", testDeleteWithNotNilPrimaryKeyThatDoesNotMatchAnyRowDoesNothing),
    ("testDeleteWithNotNilPrimaryKeyThatMatchesARowDeletesThatRow", testDeleteWithNotNilPrimaryKeyThatMatchesARowDeletesThatRow),
    ("testDeleteAfterDeleteDoesNothing", testDeleteAfterDeleteDoesNothing),
    ("testFetchCursorWithKeys", testFetchCursorWithKeys),
    ("testFetchAllWithKeys", testFetchAllWithKeys),
    ("testFetchOneWithKey", testFetchOneWithKey),
    ("testFetchCursorWithPrimaryKeys", testFetchCursorWithPrimaryKeys),
    ("testFetchAllWithPrimaryKeys", testFetchAllWithPrimaryKeys),
    ("testFetchOneWithPrimaryKey", testFetchOneWithPrimaryKey),
    ("testExistsWithNilPrimaryKeyReturnsFalse", testExistsWithNilPrimaryKeyReturnsFalse),
    ("testExistsWithNotNilPrimaryKeyThatDoesNotMatchAnyRowReturnsFalse", testExistsWithNotNilPrimaryKeyThatDoesNotMatchAnyRowReturnsFalse),
    ("testExistsWithNotNilPrimaryKeyThatMatchesARowReturnsTrue", testExistsWithNotNilPrimaryKeyThatMatchesARowReturnsTrue),
    ("testExistsAfterDeleteReturnsTrue", testExistsAfterDeleteReturnsTrue),
  ]
}
extension RecordPrimaryKeySingleWithReplaceConflictResolutionTests {
  static var allTests: [(String, (RecordPrimaryKeySingleWithReplaceConflictResolutionTests) -> () throws -> Void)] = [
    ("testInsertWithNilPrimaryKeyThrowsDatabaseError", testInsertWithNilPrimaryKeyThrowsDatabaseError),
    ("testInsertWithNotNilPrimaryKeyThatDoesNotMatchAnyRowInsertsARow", testInsertWithNotNilPrimaryKeyThatDoesNotMatchAnyRowInsertsARow),
    ("testInsertWithNotNilPrimaryKeyThatMatchesARowReplacesARow", testInsertWithNotNilPrimaryKeyThatMatchesARowReplacesARow),
    ("testInsertAfterDeleteInsertsARow", testInsertAfterDeleteInsertsARow),
    ("testUpdateWithNotNilPrimaryKeyThatDoesNotMatchAnyRowThrowsRecordNotFound", testUpdateWithNotNilPrimaryKeyThatDoesNotMatchAnyRowThrowsRecordNotFound),
    ("testUpdateWithNotNilPrimaryKeyThatMatchesARowUpdatesThatRow", testUpdateWithNotNilPrimaryKeyThatMatchesARowUpdatesThatRow),
    ("testUpdateAfterDeleteThrowsRecordNotFound", testUpdateAfterDeleteThrowsRecordNotFound),
    ("testSaveWithNilPrimaryKeyThrowsDatabaseError", testSaveWithNilPrimaryKeyThrowsDatabaseError),
    ("testSaveWithNotNilPrimaryKeyThatDoesNotMatchAnyRowInsertsARow", testSaveWithNotNilPrimaryKeyThatDoesNotMatchAnyRowInsertsARow),
    ("testSaveWithNotNilPrimaryKeyThatMatchesARowUpdatesThatRow", testSaveWithNotNilPrimaryKeyThatMatchesARowUpdatesThatRow),
    ("testSaveAfterDeleteInsertsARow", testSaveAfterDeleteInsertsARow),
    ("testDeleteWithNotNilPrimaryKeyThatDoesNotMatchAnyRowDoesNothing", testDeleteWithNotNilPrimaryKeyThatDoesNotMatchAnyRowDoesNothing),
    ("testDeleteWithNotNilPrimaryKeyThatMatchesARowDeletesThatRow", testDeleteWithNotNilPrimaryKeyThatMatchesARowDeletesThatRow),
    ("testDeleteAfterDeleteDoesNothing", testDeleteAfterDeleteDoesNothing),
    ("testFetchCursorWithKeys", testFetchCursorWithKeys),
    ("testFetchAllWithKeys", testFetchAllWithKeys),
    ("testFetchOneWithKey", testFetchOneWithKey),
    ("testFetchCursorWithPrimaryKeys", testFetchCursorWithPrimaryKeys),
    ("testFetchAllWithPrimaryKeys", testFetchAllWithPrimaryKeys),
    ("testFetchOneWithPrimaryKey", testFetchOneWithPrimaryKey),
    ("testExistsWithNotNilPrimaryKeyThatDoesNotMatchAnyRowReturnsFalse", testExistsWithNotNilPrimaryKeyThatDoesNotMatchAnyRowReturnsFalse),
    ("testExistsWithNotNilPrimaryKeyThatMatchesARowReturnsTrue", testExistsWithNotNilPrimaryKeyThatMatchesARowReturnsTrue),
    ("testExistsAfterDeleteReturnsTrue", testExistsAfterDeleteReturnsTrue),
  ]
}
extension RecordQueryInterfaceRequestTests {
  static var allTests: [(String, (RecordQueryInterfaceRequestTests) -> () throws -> Void)] = [
    ("testFetch", testFetch),
  ]
}
extension RecordSubClassTests {
  static var allTests: [(String, (RecordSubClassTests) -> () throws -> Void)] = [
    ("testSaveWithNilPrimaryKeyCallsInsertMethod", testSaveWithNilPrimaryKeyCallsInsertMethod),
    ("testSaveWithNotNilPrimaryKeyThatDoesNotMatchAnyRowCallsInsertMethod", testSaveWithNotNilPrimaryKeyThatDoesNotMatchAnyRowCallsInsertMethod),
    ("testSaveWithNotNilPrimaryKeyThatMatchesARowCallsUpdateMethod", testSaveWithNotNilPrimaryKeyThatMatchesARowCallsUpdateMethod),
    ("testSaveAfterDeleteCallsInsertMethod", testSaveAfterDeleteCallsInsertMethod),
    ("testSelect", testSelect),
  ]
}
extension RecordUniqueIndexTests {
  static var allTests: [(String, (RecordUniqueIndexTests) -> () throws -> Void)] = [
    ("testFetchOneRequiresUniqueIndex", testFetchOneRequiresUniqueIndex),
    ("testDeleteOneRequiresUniqueIndex", testDeleteOneRequiresUniqueIndex),
  ]
}
extension RecordWithColumnNameManglingTests {
  static var allTests: [(String, (RecordWithColumnNameManglingTests) -> () throws -> Void)] = [
    ("testBadlyMangledStuff", testBadlyMangledStuff),
  ]
}
extension RequestTests {
  static var allTests: [(String, (RequestTests) -> () throws -> Void)] = [
    ("testRequestFetch", testRequestFetch),
    ("testRequestFetchCount", testRequestFetchCount),
    ("testRequestCustomizedFetchCount", testRequestCustomizedFetchCount),
  ]
}
extension ResultCodeTests {
  static var allTests: [(String, (ResultCodeTests) -> () throws -> Void)] = [
    ("testResultCodeEquatable", testResultCodeEquatable),
    ("testResultCodeMatch", testResultCodeMatch),
    ("testResultCodeSwitch", testResultCodeSwitch),
  ]
}
extension RowConvertibleQueryInterfaceRequestTests {
  static var allTests: [(String, (RowConvertibleQueryInterfaceRequestTests) -> () throws -> Void)] = [
    ("testAll", testAll),
    ("testFetch", testFetch),
    ("testAlternativeFetch", testAlternativeFetch),
  ]
}
extension RowConvertibleTests {
  static var allTests: [(String, (RowConvertibleTests) -> () throws -> Void)] = [
    ("testRowInitializer", testRowInitializer),
    ("testFetchCursor", testFetchCursor),
    ("testFetchCursorStepFailure", testFetchCursorStepFailure),
    ("testFetchCursorCompilationFailure", testFetchCursorCompilationFailure),
    ("testFetchAll", testFetchAll),
    ("testFetchAllStepFailure", testFetchAllStepFailure),
    ("testFetchAllCompilationFailure", testFetchAllCompilationFailure),
    ("testFetchOne", testFetchOne),
    ("testFetchOneStepFailure", testFetchOneStepFailure),
    ("testFetchOneCompilationFailure", testFetchOneCompilationFailure),
  ]
}
extension RowCopiedFromStatementTests {
  static var allTests: [(String, (RowCopiedFromStatementTests) -> () throws -> Void)] = [
    ("testRowAsSequence", testRowAsSequence),
    ("testRowValueAtIndex", testRowValueAtIndex),
    ("testRowValueNamed", testRowValueNamed),
    ("testRowValueFromColumn", testRowValueFromColumn),
    ("testDataNoCopy", testDataNoCopy),
    ("testRowDatabaseValueAtIndex", testRowDatabaseValueAtIndex),
    ("testRowDatabaseValueNamed", testRowDatabaseValueNamed),
    ("testRowCount", testRowCount),
    ("testRowColumnNames", testRowColumnNames),
    ("testRowDatabaseValues", testRowDatabaseValues),
    ("testRowIsCaseInsensitive", testRowIsCaseInsensitive),
    ("testRowIsCaseInsensitiveAndReturnsLeftmostMatchingColumn", testRowIsCaseInsensitiveAndReturnsLeftmostMatchingColumn),
    ("testMissingColumn", testMissingColumn),
    ("testRowHasColumnIsCaseInsensitive", testRowHasColumnIsCaseInsensitive),
    ("testVariants", testVariants),
    ("testCopy", testCopy),
    ("testEqualityWithCopy", testEqualityWithCopy),
  ]
}
extension RowFetchTests {
  static var allTests: [(String, (RowFetchTests) -> () throws -> Void)] = [
    ("testFetchCursor", testFetchCursor),
    ("testFetchCursorStepFailure", testFetchCursorStepFailure),
    ("testFetchCursorCompilationFailure", testFetchCursorCompilationFailure),
    ("testFetchAll", testFetchAll),
    ("testFetchAllStepFailure", testFetchAllStepFailure),
    ("testFetchAllCompilationFailure", testFetchAllCompilationFailure),
    ("testFetchOne", testFetchOne),
    ("testFetchOneStepFailure", testFetchOneStepFailure),
    ("testFetchOneCompilationFailure", testFetchOneCompilationFailure),
  ]
}
extension RowFoundationTests {
  static var allTests: [(String, (RowFoundationTests) -> () throws -> Void)] = [
    ("testRowFromInvalidDictionary", testRowFromInvalidDictionary),
    ("testRowFromDictionary", testRowFromDictionary),
  ]
}
extension RowFromDictionaryLiteralTests {
  static var allTests: [(String, (RowFromDictionaryLiteralTests) -> () throws -> Void)] = [
    ("testRowAsSequence", testRowAsSequence),
    ("testColumnOrderIsPreserved", testColumnOrderIsPreserved),
    ("testDuplicateColumnNames", testDuplicateColumnNames),
    ("testRowValueAtIndex", testRowValueAtIndex),
    ("testRowValueNamed", testRowValueNamed),
    ("testRowValueFromColumn", testRowValueFromColumn),
    ("testDataNoCopy", testDataNoCopy),
    ("testRowDatabaseValueAtIndex", testRowDatabaseValueAtIndex),
    ("testRowDatabaseValueNamed", testRowDatabaseValueNamed),
    ("testRowCount", testRowCount),
    ("testRowColumnNames", testRowColumnNames),
    ("testRowDatabaseValues", testRowDatabaseValues),
    ("testRowIsCaseInsensitive", testRowIsCaseInsensitive),
    ("testMissingColumn", testMissingColumn),
    ("testRowHasColumnIsCaseInsensitive", testRowHasColumnIsCaseInsensitive),
    ("testSubRows", testSubRows),
    ("testCopy", testCopy),
    ("testEqualityWithCopy", testEqualityWithCopy),
  ]
}
extension RowFromDictionaryTests {
  static var allTests: [(String, (RowFromDictionaryTests) -> () throws -> Void)] = [
    ("testRowAsSequence", testRowAsSequence),
    ("testRowValueAtIndex", testRowValueAtIndex),
    ("testRowValueNamed", testRowValueNamed),
    ("testRowValueFromColumn", testRowValueFromColumn),
    ("testDataNoCopy", testDataNoCopy),
    ("testRowDatabaseValueAtIndex", testRowDatabaseValueAtIndex),
    ("testRowDatabaseValueNamed", testRowDatabaseValueNamed),
    ("testRowCount", testRowCount),
    ("testRowColumnNames", testRowColumnNames),
    ("testRowDatabaseValues", testRowDatabaseValues),
    ("testRowIsCaseInsensitive", testRowIsCaseInsensitive),
    ("testMissingColumn", testMissingColumn),
    ("testRowHasColumnIsCaseInsensitive", testRowHasColumnIsCaseInsensitive),
    ("testSubRows", testSubRows),
    ("testCopy", testCopy),
    ("testEqualityWithCopy", testEqualityWithCopy),
  ]
}
extension RowFromStatementTests {
  static var allTests: [(String, (RowFromStatementTests) -> () throws -> Void)] = [
    ("testRowAsSequence", testRowAsSequence),
    ("testRowValueAtIndex", testRowValueAtIndex),
    ("testRowValueNamed", testRowValueNamed),
    ("testRowValueFromColumn", testRowValueFromColumn),
    ("testDataNoCopy", testDataNoCopy),
    ("testRowDatabaseValueAtIndex", testRowDatabaseValueAtIndex),
    ("testRowDatabaseValueNamed", testRowDatabaseValueNamed),
    ("testRowCount", testRowCount),
    ("testRowColumnNames", testRowColumnNames),
    ("testRowDatabaseValues", testRowDatabaseValues),
    ("testRowIsCaseInsensitive", testRowIsCaseInsensitive),
    ("testRowIsCaseInsensitiveAndReturnsLeftmostMatchingColumn", testRowIsCaseInsensitiveAndReturnsLeftmostMatchingColumn),
    ("testMissingColumn", testMissingColumn),
    ("testRowHasColumnIsCaseInsensitive", testRowHasColumnIsCaseInsensitive),
    ("testVariants", testVariants),
    ("testCopy", testCopy),
    ("testEqualityWithCopy", testEqualityWithCopy),
    ("testDatabaseCursorMap", testDatabaseCursorMap),
  ]
}
extension SQLExpressionLiteralTests {
  static var allTests: [(String, (SQLExpressionLiteralTests) -> () throws -> Void)] = [
    ("testWithArguments", testWithArguments),
    ("testWithoutArguments", testWithoutArguments),
  ]
}
extension SchedulingWatchdogTests {
  static var allTests: [(String, (SchedulingWatchdogTests) -> () throws -> Void)] = [
    ("testSchedulingWatchdog", testSchedulingWatchdog),
    ("testDatabaseQueueFromDatabaseQueue", testDatabaseQueueFromDatabaseQueue),
    ("testDatabaseQueueFromDatabasePool", testDatabaseQueueFromDatabasePool),
    ("testDatabasePoolFromDatabaseQueue", testDatabasePoolFromDatabaseQueue),
    ("testDatabasePoolFromDatabasePool", testDatabasePoolFromDatabasePool),
  ]
}
extension SelectStatementTests {
  static var allTests: [(String, (SelectStatementTests) -> () throws -> Void)] = [
    ("testArrayStatementArguments", testArrayStatementArguments),
    ("testStatementArgumentsSetterWithArray", testStatementArgumentsSetterWithArray),
    ("testDictionaryStatementArguments", testDictionaryStatementArguments),
    ("testStatementArgumentsSetterWithDictionary", testStatementArgumentsSetterWithDictionary),
    ("testDatabaseErrorThrownBySelectStatementContainSQL", testDatabaseErrorThrownBySelectStatementContainSQL),
    ("testCachedSelectStatementStepFailure", testCachedSelectStatementStepFailure),
    ("testSelectionInfo", testSelectionInfo),
  ]
}
extension StatementArgumentsFoundationTests {
  static var allTests: [(String, (StatementArgumentsFoundationTests) -> () throws -> Void)] = [
    ("testStatementArgumentsArrayInitializer", testStatementArgumentsArrayInitializer),
    ("testStatementArgumentsNSArrayInitializerFromInvalidNSArray", testStatementArgumentsNSArrayInitializerFromInvalidNSArray),
    ("testStatementArgumentsDictionaryInitializer", testStatementArgumentsDictionaryInitializer),
    ("testStatementArgumentsNSDictionaryInitializerFromInvalidNSDictionary", testStatementArgumentsNSDictionaryInitializerFromInvalidNSDictionary),
  ]
}
extension StatementArgumentsTests {
  static var allTests: [(String, (StatementArgumentsTests) -> () throws -> Void)] = [
    ("testPositionalStatementArgumentsValidation", testPositionalStatementArgumentsValidation),
    ("testPositionalStatementArguments", testPositionalStatementArguments),
    ("testUnsafePositionalStatementArguments", testUnsafePositionalStatementArguments),
    ("testNamedStatementArgumentsValidation", testNamedStatementArgumentsValidation),
    ("testNamedStatementArguments", testNamedStatementArguments),
    ("testUnsafeNamedStatementArguments", testUnsafeNamedStatementArguments),
    ("testReusedNamedStatementArgumentsValidation", testReusedNamedStatementArgumentsValidation),
    ("testReusedNamedStatementArguments", testReusedNamedStatementArguments),
    ("testUnsafeReusedNamedStatementArguments", testUnsafeReusedNamedStatementArguments),
    ("testMixedArguments", testMixedArguments),
    ("testAppendContentsOf", testAppendContentsOf),
    ("testPlusOperator", testPlusOperator),
    ("testOverflowPlusOperator", testOverflowPlusOperator),
    ("testPlusEqualOperator", testPlusEqualOperator),
  ]
}
extension StatementColumnConvertibleFetchTests {
  static var allTests: [(String, (StatementColumnConvertibleFetchTests) -> () throws -> Void)] = [
    ("testSlowConversion", testSlowConversion),
    ("testRowExtraction", testRowExtraction),
    ("testFetchCursor", testFetchCursor),
    ("testFetchCursorConversionFailure", testFetchCursorConversionFailure),
    ("testFetchCursorStepFailure", testFetchCursorStepFailure),
    ("testFetchCursorCompilationFailure", testFetchCursorCompilationFailure),
    ("testFetchAll", testFetchAll),
    ("testFetchAllConversionFailure", testFetchAllConversionFailure),
    ("testFetchAllStepFailure", testFetchAllStepFailure),
    ("testFetchAllCompilationFailure", testFetchAllCompilationFailure),
    ("testFetchOne", testFetchOne),
    ("testFetchOneStepFailure", testFetchOneStepFailure),
    ("testFetchOneCompilationFailure", testFetchOneCompilationFailure),
    ("testOptionalFetchCursor", testOptionalFetchCursor),
    ("testOptionalFetchCursorConversionFailure", testOptionalFetchCursorConversionFailure),
    ("testOptionalFetchCursorCompilationFailure", testOptionalFetchCursorCompilationFailure),
    ("testOptionalFetchAll", testOptionalFetchAll),
    ("testOptionalFetchAllConversionFailure", testOptionalFetchAllConversionFailure),
    ("testOptionalFetchAllStepFailure", testOptionalFetchAllStepFailure),
    ("testOptionalFetchAllCompilationFailure", testOptionalFetchAllCompilationFailure),
  ]
}
extension StatementColumnConvertibleTests {
  static var allTests: [(String, (StatementColumnConvertibleTests) -> () throws -> Void)] = [
    ("testTextAffinity", testTextAffinity),
    ("testNumericAffinity", testNumericAffinity),
    ("testIntegerAffinity", testIntegerAffinity),
    ("testRealAffinity", testRealAffinity),
    ("testNoneAffinity", testNoneAffinity),
  ]
}
extension StatementSelectionInfoTests {
  static var allTests: [(String, (StatementSelectionInfoTests) -> () throws -> Void)] = [
    ("testSelectStatement", testSelectStatement),
    ("testUpdateStatement", testUpdateStatement),
    ("testInsertStatement", testInsertStatement),
    ("testDeleteStatement", testDeleteStatement),
    ("testUpdateStatementInvalidatesDatabaseSchemaCache", testUpdateStatementInvalidatesDatabaseSchemaCache),
  ]
}
extension TableDefinitionTests {
  static var allTests: [(String, (TableDefinitionTests) -> () throws -> Void)] = [
    ("testCreateTable", testCreateTable),
    ("testTableCreationOptions", testTableCreationOptions),
    ("testColumnPrimaryKeyOptions", testColumnPrimaryKeyOptions),
    ("testColumnNotNull", testColumnNotNull),
    ("testColumnUnique", testColumnUnique),
    ("testColumnCheck", testColumnCheck),
    ("testColumnDefault", testColumnDefault),
    ("testColumnCollation", testColumnCollation),
    ("testColumnReference", testColumnReference),
    ("testTablePrimaryKey", testTablePrimaryKey),
    ("testTableUniqueKey", testTableUniqueKey),
    ("testTableForeignKey", testTableForeignKey),
    ("testTableCheck", testTableCheck),
    ("testAutoReferences", testAutoReferences),
    ("testRenameTable", testRenameTable),
    ("testAlterTable", testAlterTable),
    ("testDropTable", testDropTable),
    ("testCreateIndex", testCreateIndex),
    ("testCreatePartialIndex", testCreatePartialIndex),
    ("testDropIndex", testDropIndex),
  ]
}
extension TableMappingDeleteByKeyTests {
  static var allTests: [(String, (TableMappingDeleteByKeyTests) -> () throws -> Void)] = [
    ("testImplicitRowIDPrimaryKey", testImplicitRowIDPrimaryKey),
    ("testSingleColumnPrimaryKey", testSingleColumnPrimaryKey),
    ("testMultipleColumnPrimaryKey", testMultipleColumnPrimaryKey),
    ("testUniqueIndex", testUniqueIndex),
    ("testImplicitUniqueIndexOnSingleColumnPrimaryKey", testImplicitUniqueIndexOnSingleColumnPrimaryKey),
  ]
}
extension TableMappingQueryInterfaceRequestTests {
  static var allTests: [(String, (TableMappingQueryInterfaceRequestTests) -> () throws -> Void)] = [
    ("testFetchCount", testFetchCount),
    ("testSelectLiteral", testSelectLiteral),
    ("testSelectLiteralWithPositionalArguments", testSelectLiteralWithPositionalArguments),
    ("testSelectLiteralWithNamedArguments", testSelectLiteralWithNamedArguments),
    ("testSelect", testSelect),
    ("testMultipleSelect", testMultipleSelect),
    ("testFilterLiteral", testFilterLiteral),
    ("testFilterLiteralWithPositionalArguments", testFilterLiteralWithPositionalArguments),
    ("testFilterLiteralWithNamedArguments", testFilterLiteralWithNamedArguments),
    ("testFilter", testFilter),
    ("testMultipleFilter", testMultipleFilter),
    ("testSortLiteral", testSortLiteral),
    ("testSortLiteralWithPositionalArguments", testSortLiteralWithPositionalArguments),
    ("testSortLiteralWithNamedArguments", testSortLiteralWithNamedArguments),
    ("testSort", testSort),
    ("testMultipleSort", testMultipleSort),
    ("testLimit", testLimit),
    ("testMultipleLimit", testMultipleLimit),
    ("testDelete", testDelete),
  ]
}
extension TableMappingTests {
  static var allTests: [(String, (TableMappingTests) -> () throws -> Void)] = [
    ("testPrimaryKeyRowComparatorWithIntegerPrimaryKey", testPrimaryKeyRowComparatorWithIntegerPrimaryKey),
    ("testPrimaryKeyRowComparatorWithHiddenRowIDPrimaryKey", testPrimaryKeyRowComparatorWithHiddenRowIDPrimaryKey),
  ]
}
extension TransactionObserverSavepointsTests {
  static var allTests: [(String, (TransactionObserverSavepointsTests) -> () throws -> Void)] = [
    ("testSavepointAsTransaction", testSavepointAsTransaction),
    ("testSavepointInsideTransaction", testSavepointInsideTransaction),
    ("testSavepointWithIdenticalName", testSavepointWithIdenticalName),
    ("testMultipleRollbackOfSavepoint", testMultipleRollbackOfSavepoint),
    ("testReleaseSavepoint", testReleaseSavepoint),
    ("testRollbackNonNestedSavepointInsideTransaction", testRollbackNonNestedSavepointInsideTransaction),
  ]
}
extension TransactionObserverTests {
  static var allTests: [(String, (TransactionObserverTests) -> () throws -> Void)] = [
    ("testInsertEvent", testInsertEvent),
    ("testUpdateEvent", testUpdateEvent),
    ("testDeleteEvent", testDeleteEvent),
    ("testTruncateOptimization", testTruncateOptimization),
    ("testCascadingDeleteEvents", testCascadingDeleteEvents),
    ("testImplicitTransactionCommit", testImplicitTransactionCommit),
    ("testCascadeWithImplicitTransactionCommit", testCascadeWithImplicitTransactionCommit),
    ("testExplicitTransactionCommit", testExplicitTransactionCommit),
    ("testCascadeWithExplicitTransactionCommit", testCascadeWithExplicitTransactionCommit),
    ("testExplicitTransactionRollback", testExplicitTransactionRollback),
    ("testImplicitTransactionRollbackCausedByDatabaseError", testImplicitTransactionRollbackCausedByDatabaseError),
    ("testExplicitTransactionRollbackCausedByDatabaseError", testExplicitTransactionRollbackCausedByDatabaseError),
    ("testImplicitTransactionRollbackCausedByTransactionObserver", testImplicitTransactionRollbackCausedByTransactionObserver),
    ("testExplicitTransactionRollbackCausedByTransactionObserver", testExplicitTransactionRollbackCausedByTransactionObserver),
    ("testImplicitTransactionRollbackCausedByDatabaseErrorSuperseedTransactionObserver", testImplicitTransactionRollbackCausedByDatabaseErrorSuperseedTransactionObserver),
    ("testExplicitTransactionRollbackCausedByDatabaseErrorSuperseedTransactionObserver", testExplicitTransactionRollbackCausedByDatabaseErrorSuperseedTransactionObserver),
    ("testMinimalRowIDUpdateObservation", testMinimalRowIDUpdateObservation),
    ("testInsertEventIsNotifiedToAllObservers", testInsertEventIsNotifiedToAllObservers),
    ("testExplicitTransactionRollbackCausedBySecondTransactionObserverOutOfThree", testExplicitTransactionRollbackCausedBySecondTransactionObserverOutOfThree),
    ("testTransactionObserverIsNotRetained", testTransactionObserverIsNotRetained),
    ("testTransactionObserverAddAndRemove", testTransactionObserverAddAndRemove),
    ("testFilterDatabaseEvents", testFilterDatabaseEvents),
  ]
}
extension UpdateStatementTests {
  static var allTests: [(String, (UpdateStatementTests) -> () throws -> Void)] = [
    ("testTrailingSemicolonAndWhiteSpaceIsAcceptedAndOptional", testTrailingSemicolonAndWhiteSpaceIsAcceptedAndOptional),
    ("testArrayStatementArguments", testArrayStatementArguments),
    ("testStatementArgumentsSetterWithArray", testStatementArgumentsSetterWithArray),
    ("testDictionaryStatementArguments", testDictionaryStatementArguments),
    ("testStatementArgumentsSetterWithDictionary", testStatementArgumentsSetterWithDictionary),
    ("testUpdateStatementAcceptsSelectQueries", testUpdateStatementAcceptsSelectQueries),
    ("testUpdateStatementAcceptsSelectQueriesAndConsumeAllRows", testUpdateStatementAcceptsSelectQueriesAndConsumeAllRows),
    ("testExecuteMultipleStatement", testExecuteMultipleStatement),
    ("testExecuteMultipleStatementWithTrailingWhiteSpace", testExecuteMultipleStatementWithTrailingWhiteSpace),
    ("testExecuteMultipleStatementWithTrailingSemicolonAndWhiteSpace", testExecuteMultipleStatementWithTrailingSemicolonAndWhiteSpace),
    ("testExecuteMultipleStatementWithNamedArguments", testExecuteMultipleStatementWithNamedArguments),
    ("testExecuteMultipleStatementWithReusedNamedArguments", testExecuteMultipleStatementWithReusedNamedArguments),
    ("testExecuteMultipleStatementWithPositionalArguments", testExecuteMultipleStatementWithPositionalArguments),
    ("testDatabaseErrorThrownByUpdateStatementContainSQL", testDatabaseErrorThrownByUpdateStatementContainSQL),
    ("testMultipleValidStatementsError", testMultipleValidStatementsError),
    ("testMultipleStatementsWithSecondOneInvalidError", testMultipleStatementsWithSecondOneInvalidError),
  ]
}
extension VirtualTableModuleTests {
  static var allTests: [(String, (VirtualTableModuleTests) -> () throws -> Void)] = [
    ("testCustomVirtualTableModule", testCustomVirtualTableModule),
    ("testThrowingCustomVirtualTableModule", testThrowingCustomVirtualTableModule),
  ]
}

XCTMain([
  testCase(AdapterRowTests.allTests),
  testCase(AnyCursorTests.allTests),
  testCase(CGFloatTests.allTests),
  testCase(ConcurrencyTests.allTests),
  testCase(CursorTests.allTests),
  testCase(DataMemoryTests.allTests),
  testCase(DatabaseCoderTests.allTests),
  testCase(DatabaseCollationTests.allTests),
  testCase(DatabaseCursorTests.allTests),
  testCase(DatabaseErrorTests.allTests),
  testCase(DatabaseFunctionTests.allTests),
  testCase(DatabaseLogErrorTests.allTests),
  testCase(DatabaseMigratorTests.allTests),
  testCase(DatabasePoolBackupTests.allTests),
  testCase(DatabasePoolCollationTests.allTests),
  testCase(DatabasePoolConcurrencyTests.allTests),
  testCase(DatabasePoolFunctionTests.allTests),
  testCase(DatabasePoolReadOnlyTests.allTests),
  testCase(DatabasePoolReleaseMemoryTests.allTests),
  testCase(DatabasePoolSchemaCacheTests.allTests),
  testCase(DatabaseQueueBackupTests.allTests),
  testCase(DatabaseQueueInMemoryTests.allTests),
  testCase(DatabaseQueueReadOnlyTests.allTests),
  testCase(DatabaseQueueSchemaCacheTests.allTests),
  testCase(DatabaseQueueTests.allTests),
  testCase(DatabaseQueueuReleaseMemoryTests.allTests),
  testCase(DatabaseReaderTests.allTests),
  testCase(DatabaseSavepointTests.allTests),
  testCase(DatabaseTests.allTests),
  testCase(DatabaseTimestampTests.allTests),
  testCase(DatabaseValueConversionTests.allTests),
  testCase(DatabaseValueConvertibleEscapingTests.allTests),
  testCase(DatabaseValueConvertibleFetchTests.allTests),
  testCase(DatabaseValueConvertibleSubclassTests.allTests),
  testCase(DatabaseValueTests.allTests),
  testCase(DatabaseWriterTests.allTests),
  testCase(EnumeratedCursorTests.allTests),
  testCase(FTS3PatternTests.allTests),
  testCase(FTS3RecordTests.allTests),
  testCase(FTS3TableBuilderTests.allTests),
  testCase(FTS3TokenizerTests.allTests),
  testCase(FTS4RecordTests.allTests),
  testCase(FTS4TableBuilderTests.allTests),
  testCase(FetchedRecordsControllerTests.allTests),
  testCase(FilterCursorTests.allTests),
  testCase(FlattenCursorTests.allTests),
  testCase(FoundationDataTests.allTests),
  testCase(FoundationDateComponentsTests.allTests),
  testCase(FoundationDateTests.allTests),
  testCase(FoundationNSDataTests.allTests),
  testCase(FoundationNSDateTests.allTests),
  testCase(FoundationNSDecimalNumberTests.allTests),
  testCase(FoundationNSNullTests.allTests),
  testCase(FoundationNSNumberTests.allTests),
  testCase(FoundationNSStringTests.allTests),
  testCase(FoundationNSURLTests.allTests),
  testCase(FoundationNSUUIDTests.allTests),
  testCase(FoundationURLTests.allTests),
  testCase(FoundationUUIDTests.allTests),
  testCase(IndexInfoTests.allTests),
  testCase(IteratorCursorTests.allTests),
  testCase(MapCursorTests.allTests),
  testCase(MutablePersistablePersistenceConflictPolicyTests.allTests),
  testCase(MutablePersistableTests.allTests),
  testCase(NumericOverflowTests.allTests),
  testCase(PersistableTests.allTests),
  testCase(QueryInterfaceExpressionsTests.allTests),
  testCase(QueryInterfaceExtensibilityTests.allTests),
  testCase(QueryInterfaceRequestTests.allTests),
  testCase(RawRepresentableDatabaseValueConvertibleTests.allTests),
  testCase(RecordCopyTests.allTests),
  testCase(RecordEditedTests.allTests),
  testCase(RecordEventsTests.allTests),
  testCase(RecordInitializersTests.allTests),
  testCase(RecordMinimalPrimaryKeyRowIDTests.allTests),
  testCase(RecordMinimalPrimaryKeySingleTests.allTests),
  testCase(RecordPersistenceConflictPolicyTests.allTests),
  testCase(RecordPrimaryKeyHiddenRowIDTests.allTests),
  testCase(RecordPrimaryKeyMultipleTests.allTests),
  testCase(RecordPrimaryKeyNoneTests.allTests),
  testCase(RecordPrimaryKeyRowIDTests.allTests),
  testCase(RecordPrimaryKeySingleTests.allTests),
  testCase(RecordPrimaryKeySingleWithReplaceConflictResolutionTests.allTests),
  testCase(RecordQueryInterfaceRequestTests.allTests),
  testCase(RecordSubClassTests.allTests),
  testCase(RecordUniqueIndexTests.allTests),
  testCase(RecordWithColumnNameManglingTests.allTests),
  testCase(RequestTests.allTests),
  testCase(ResultCodeTests.allTests),
  testCase(RowConvertibleQueryInterfaceRequestTests.allTests),
  testCase(RowConvertibleTests.allTests),
  testCase(RowCopiedFromStatementTests.allTests),
  testCase(RowFetchTests.allTests),
  testCase(RowFoundationTests.allTests),
  testCase(RowFromDictionaryLiteralTests.allTests),
  testCase(RowFromDictionaryTests.allTests),
  testCase(RowFromStatementTests.allTests),
  testCase(SQLExpressionLiteralTests.allTests),
  testCase(SchedulingWatchdogTests.allTests),
  testCase(SelectStatementTests.allTests),
  testCase(StatementArgumentsFoundationTests.allTests),
  testCase(StatementArgumentsTests.allTests),
  testCase(StatementColumnConvertibleFetchTests.allTests),
  testCase(StatementColumnConvertibleTests.allTests),
  testCase(StatementSelectionInfoTests.allTests),
  testCase(TableDefinitionTests.allTests),
  testCase(TableMappingDeleteByKeyTests.allTests),
  testCase(TableMappingQueryInterfaceRequestTests.allTests),
  testCase(TableMappingTests.allTests),
  testCase(TransactionObserverSavepointsTests.allTests),
  testCase(TransactionObserverTests.allTests),
  testCase(UpdateStatementTests.allTests),
  testCase(VirtualTableModuleTests.allTests),
])

