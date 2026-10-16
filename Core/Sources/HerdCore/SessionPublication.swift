import Foundation

/// Presentation ordering shared by full and post-mutation Space reads.
public struct SessionPublication {
    private var revision: UInt64 = 0
    public init() {}
    public mutating func apply(_ result: SessionReader.Snapshot, to current: Session?, workspace: String? = nil) throws -> Session? {
        guard result.revision >= revision else { return nil }
        let session: Session
        if let workspace {
            guard let current else { throw Failure("Missing session for scoped update") }
            session = try current.replacingWorkspace(workspace, with: result.session)
        } else { session = result.session }
        revision = result.revision
        return session
    }
}
