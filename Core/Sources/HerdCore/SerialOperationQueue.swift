import Foundation

/// Enqueue synchronously on the UI actor, then await each operation including recovery.
@MainActor
public final class SerialOperationQueue {
    private var tail: Task<Void, Never>?
    public init() {}
    public func enqueue(_ operation: @escaping @MainActor () async throws -> Void) -> Task<Void, Error> {
        let previous = tail
        let next = Task {
            await previous?.value
            try Task.checkCancellation()
            try await operation()
        }
        tail = Task { _ = await next.result }
        return next
    }
}

public enum TabName {
    public static func changed(_ value: String, from original: String) -> String? {
        let name = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name != original.trimmingCharacters(in: .whitespacesAndNewlines),
              !name.contains(where: { $0.isNewline || $0 == "\0" }) else { return nil }
        return name
    }
}
