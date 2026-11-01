import Foundation

/// What a run says as it goes.
public enum MocksFrame: Sendable {
    /// The package's lines were read: how many endpoints and types.
    case read(endpoints: Int, types: Int)
    /// The records were made: how many of each type, and how many asks of the model it took.
    case made(records: [String: Int], asks: Int)
    /// The files are written.
    case written(MocksResult)

    public var result: MocksResult? {
        if case .written(let result) = self { return result }
        return nil
    }
}
