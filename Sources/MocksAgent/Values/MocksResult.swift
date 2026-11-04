import Foundation
import GraniteAgents

/// What a call answers, as `granite-answer/1`: the files written, as absolute paths, what the mock backend now holds,
/// and what it made of the records it was asked for.
public struct MocksResult: AgentAnswer, Equatable {
    /// The file with `mock(_:latency:)` and the routes.
    public var path: String?
    /// Every file written.
    public var paths: [String]
    /// The client package's folder.
    public var package: String
    /// The client the mock is made for: `RecipeClient`.
    public var client: String
    /// The endpoints that answer from fixtures, by their method names.
    public var endpoints: [String]
    /// How many records of each type the fixtures hold.
    public var records: [String: Int]
    /// How many pictures the fixtures show.
    public var images: Int
    /// Whether the host's model wrote what the records say; word lists did when it did not.
    public var written: Bool
    /// One sentence each: what the call did beside writing, or left out, and why.
    public var notes: [String]
    /// The client's mock and one fixture an entity that holds as many records as were asked; a file taken away.
    public var made: [AgentMade]
    /// The client's mock and one fixture an entity the answers hold.
    public var expected: [AgentExpected]
    /// What it could only do in part: records from word lists, an entity short of its count, no model offered.
    public var problems: [AgentProblem]
    /// How many times it asked the host's model, and how many of those asked again.
    public var asks: Asks?

    public struct Asks: Codable, Sendable, Equatable {
        public var asked: Int
        public var retried: Int
    }

    public init(path: String?, paths: [String], package: String, client: String, endpoints: [String], records: [String: Int],
                images: Int, written: Bool, notes: [String], made: [AgentMade] = [], expected: [AgentExpected] = [],
                problems: [AgentProblem] = [], asks: Asks? = nil) {
        self.path = path; self.paths = paths; self.package = package; self.client = client; self.endpoints = endpoints
        self.records = records; self.images = images; self.written = written; self.notes = notes
        self.made = made; self.expected = expected; self.problems = problems; self.asks = asks
    }
}
