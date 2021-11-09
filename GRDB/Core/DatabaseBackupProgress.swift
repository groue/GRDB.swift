public protocol DatabaseBackupProgress {
    var totalPages: Int { get }
    var completedPages: Int { get }
    var isFinished: Bool { get }
    
    func cancel()
}
