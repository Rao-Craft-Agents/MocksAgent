//  WHAT: What writes what the records say: the host's model (`ModelWriter`), or word lists (`WordWriter`).

import Foundation

/// What writes the content: the host's model, or word lists.
protocol ContentWriter: Sendable {
    /// What each record says, by field name; the group it is in under `"_group"`, by handle.
    mutating func records(_ ask: RecordAsk) async throws -> [[String: JSONValue]]
    /// Each parent's replies, in the order of `ask.parents`.
    mutating func threads(_ ask: ThreadAsk) async throws -> [[ThreadLine]]
    /// How many asks of the model it took, and how many were asked again.
    var asks: Int { get }
    var retries: Int { get }
    /// What it could not write well, one sentence each.
    var notes: [String] { get }
}
