import Dispatch

/// An actor that runs in a DispatchQueue.
///
/// Inspired by <https://forums.swift.org/t/using-dispatchqueue-as-actors-serial-executor-under-linux/75260/3>
actor DispatchQueueActor {
    private let executor: DispatchQueueExecutor
    
    /// - precondition: the queue is serial.
    init(queue: DispatchQueue) {
        self.executor = DispatchQueueExecutor(queue: queue)
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
    
    init(queue: DispatchQueue) {
        self.queue = queue
    }
    
    func enqueue(_ job: UnownedJob) {
        queue.async {
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
