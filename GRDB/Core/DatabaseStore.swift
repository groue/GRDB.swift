import Foundation

/// DatabaseStore is responsible for applying Configuration.fileAttributes to
/// all database files (db.sqlite, db.sqlite-wal, db.sqlite-shm,
/// db.sqlite-journal, etc.)
class DatabaseStore {
    private let source: dispatch_source_t?
    private let queue: dispatch_queue_t?
    
    convenience init(path: String, attributes: [String: AnyObject]?) throws {
        guard let attributes = attributes else {
            self.init()
            return
        }
        
        let databaseFileName = (path as NSString).lastPathComponent
        let directoryPath = (path as NSString).stringByDeletingLastPathComponent
        
        // We use a dispatch_source to monitor the contents of the database file
        // parent directory, and apply file attributes.
        //
        // This require a file descriptor on the directory.
        let directoryDescriptor = open(directoryPath, O_EVTONLY)
        guard directoryDescriptor != -1 else {
            // Let NSFileManager throw a nice NSError
            try NSFileManager.defaultManager().contentsOfDirectoryAtPath(directoryPath)
            // Come on, NSFileManager... OK just throw something that is somewhat relevant
            throw NSError(domain: NSCocoaErrorDomain, code: NSFileReadUnknownError, userInfo: nil)
        }
        
        // Call the non-throwing initializer
        self.init(directoryPath: directoryPath, databaseFileName: databaseFileName, directoryDescriptor: directoryDescriptor, attributes: attributes)
    }
    
    /// Block the current thread until all pending file operations are completed.
    func sync() {
        if let queue = queue {
            dispatch_sync(queue) { }
        }
    }
    
    private init() {
        self.queue = nil
        self.source = nil
    }
    
    private init(directoryPath: String, databaseFileName: String, directoryDescriptor: CInt, attributes: [String: AnyObject]) {
        let queue = dispatch_queue_create("com.groue.GRDB.DatabaseStore", nil)
        let source = dispatch_source_create(DISPATCH_SOURCE_TYPE_VNODE, UInt(directoryDescriptor), DISPATCH_VNODE_WRITE, queue)
        var processedFileNames: Set<String> = []
        
        // Configure dispatch source
        dispatch_source_set_event_handler(source) {
            // Directory has been modified: apply file attributes on unprocessed files
            DatabaseStore.setFileAttributes(
                directoryPath: directoryPath,
                databaseFileName: databaseFileName,
                attributes: attributes,
                processedFileNames: &processedFileNames)
        }
        dispatch_source_set_cancel_handler(source) {
            close(directoryDescriptor)
        }
        
        self.queue = queue
        self.source = source
        
        // Apply file attributes on existing files
        DatabaseStore.setFileAttributes(
            directoryPath: directoryPath,
            databaseFileName: databaseFileName,
            attributes: attributes,
            processedFileNames: &processedFileNames)
        
        // Wait for directory modifications
        dispatch_resume(source)
    }
    
    deinit {
        if let source = source {
            dispatch_source_cancel(source)
        }
    }
    
    private static func setFileAttributes(directoryPath directoryPath: String, databaseFileName: String, attributes: [String: AnyObject], inout processedFileNames: Set<String>) {
        let fm = NSFileManager.defaultManager()
        let fileNames = try! Set(fm.contentsOfDirectoryAtPath(directoryPath).filter { $0.hasPrefix(databaseFileName) })
        for fileName in fileNames.subtract(processedFileNames) {
            do {
                try fm.setAttributes(attributes, ofItemAtPath: (directoryPath as NSString).stringByAppendingPathComponent(fileName))
            } catch let error as NSError {
                guard error.domain == NSCocoaErrorDomain && error.code == NSFileNoSuchFileError else {
                    try! { throw error }()
                    preconditionFailure()
                }
            }
        }
        processedFileNames = fileNames
    }
}
