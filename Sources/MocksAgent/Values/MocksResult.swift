import Foundation

/// What a call answers: the files written, as absolute paths, and what the mock backend now holds.
public struct MocksResult: Codable, Sendable, Equatable {
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

    public init(path: String?, paths: [String], package: String, client: String, endpoints: [String], records: [String: Int],
                images: Int, written: Bool, notes: [String]) {
        self.path = path; self.paths = paths; self.package = package; self.client = client; self.endpoints = endpoints
        self.records = records; self.images = images; self.written = written; self.notes = notes
    }
}
