import Dispatch

/// An actor that runs in a DispatchQueue.
///
/// Inspired by <https://forums.swift.org/t/using-dispatchqueue-as-actors-serial-executor-under-linux/75260/3>
actor DispatchQueueActor {
    private let executor: DispatchQueueExecutor
    
    /// - precondition: the queue is serial, or flags contains `.barrier`.
    init(queue: DispatchQueue, flags: DispatchWorkItemFlags = []) {
        self.executor = DispatchQueueExecutor(queue: queue, flags: flags)
    }
    
    nonisolated var unownedExecutor: UnownedSerialExecutor {
        executor.asUnownedSerialExecutor()
    }
    
    func execute<T>(_ work: () throws -> T) rethrows -> T {
        try work()
    }
}

private final class DispatchQueueExecutor: SerialExecutor {
    private let queue: DispatchQueue
    private let flags: DispatchWorkItemFlags
    
    init(queue: DispatchQueue, flags: DispatchWorkItemFlags) {
        self.queue = queue
        self.flags = flags
    }
    
    func enqueue(_ job: UnownedJob) {
        queue.async(flags: flags) {
            job.runSynchronously(on: self.asUnownedSerialExecutor())
        }
    }
    
    func asUnownedSerialExecutor() -> UnownedSerialExecutor {
        UnownedSerialExecutor(ordinary: self)
    }
    
    func checkIsolated() {
        dispatchPrecondition(condition: .onQueue(queue))
    }
}

#if os(Linux)
    extension DispatchQueueExecutor: @unchecked Sendable {}
#endif
