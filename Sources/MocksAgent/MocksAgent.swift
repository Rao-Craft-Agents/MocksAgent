//  WHAT: Realistic mock backend responses for an app's API, as a Granite agent package. A call names the client
//        package `network` made (or finds it) and the app's theme; the run writes into that package a mock backend
//        that answers every endpoint in the process with believable data (people, groups, posts, threads with depth,
//        pictures, pages that end), `.mock(_:latency:)` and its scenarios, `MockMode` and `.current`, and the tests
//        that prove it, and answers where.
//  IN:   Input: the package, the theme, how many records of a type, the scenarios to prove, lines over the package's,
//        the seed, the rounds a batch may be asked.
//  OUT:  MocksResult: the files written, the client, the endpoints answered, the records of each type, the pictures.
//  PIN:  THE MODEL WRITES WORDS; THE AGENT HOLDS THE DATA. The host's model writes what records say, in batches
//        checked against the entity lines; ids, references, dates, counts, pages and pictures are the agent's, so
//        every fixture decodes and agrees with the others. Nothing is written until every Swift file parses.

import Foundation
import GraniteAgents

public struct MocksAgent: GraniteAgentPackage {
    public struct Input: Codable, Sendable {
        /// The client package's folder, relative to the project: `Packages/RecipeKit`. Found by its `api.json` when
        /// left out.
        public var package: String?
        /// What the app is and how it sounds: "a cozy recipe-sharing community".
        public var theme: String?
        /// How many records of a type: `posts: 40`, `comments: 120`.
        public var counts: [String]?
        /// The scenarios the package's tests prove; every one when left out.
        public var scenarios: [MocksScenario]?
        /// Endpoint lines over the package's own, in `network`'s line.
        public var endpoints: [String]?
        /// Entity lines over the package's own, in the models line.
        public var entities: [String]?
        /// What the picks are made from: the same seed and the same words make the same fixtures.
        public var seed: Int?
        /// How many answers the model may give a batch; 3 when left out.
        public var rounds: Int?
        /// The host's folder.
        public var directory: String?

        public init(package: String? = nil, theme: String? = nil, counts: [String]? = nil, scenarios: [MocksScenario]? = nil,
                    endpoints: [String]? = nil, entities: [String]? = nil, seed: Int? = nil, rounds: Int? = nil, directory: String? = nil) {
            self.package = package; self.theme = theme; self.counts = counts; self.scenarios = scenarios; self.endpoints = endpoints
            self.entities = entities; self.seed = seed; self.rounds = rounds; self.directory = directory
        }
    }

    public typealias Event = MocksFrame
    public typealias Output = MocksResult
    public typealias Compute = Void

    public static let word = "mocks"
    public static let summary = "writes realistic mock backend responses into an app's API client package — believable people, posts, threads, pictures and pages, scenarios that fail on purpose, and `.mock()` — so screens, previews and tests run with no server."
    public static let fields = [
        "package": "the client package's folder, relative to the project (`Packages/RecipeKit`); found by its api.json when left out",
        "theme": "what the app is and how it sounds, which the records are written in: `a cozy recipe-sharing community: home cooks posting what they made`",
        "counts": "how many records of a type, one line each: `posts: 40`, `comments: 120`, `people: 20`; 24 posts, three replies a post, 16 people and 8 groups when left out",
        "scenarios": "the scenarios the package's tests prove: normal, empty, failing, unauthorized, slow; every one when left out",
        "endpoints": "endpoint lines over the package's own, in network's line, for an endpoint the package's api.json lacks",
        "entities": "entity lines over the package's own, in the models line",
        "seed": "a number the picks are made from; the same seed and words make the same fixtures",
        "rounds": "how many answers the model may give one batch; 3 when left out",
    ]
    public static let guide = """
        Tag mocks to make the app run on believable data with no server: its screens, previews, tests and screenshots. \
        It writes into the client package `network` made (`Packages/<Name>`, found by its api.json) a mock backend \
        that answers every endpoint in the process: people with handles and avatars, the groups they post in, posts \
        with titles and bodies in the app's voice, comment threads with depth, counts that agree, dates over the last \
        weeks, pictures drawn as soft gradients (served as data: URLs AsyncImage loads), lists that page and end, an \
        item found by the id asked for, a body echoed back. Call it before reading the package: it reads the \
        api.json, the models and the client itself and names every file it wrote, so a call needs only `theme`, what \
        the app is and how it sounds, which the host's model writes the records from in small checked batches. Example: {"theme": "a cozy \
        recipe-sharing community: home cooks posting weeknight dinners, bakes and ferments", "counts": ["posts: 40", \
        "comments: 120"]}. With two client packages, name one and the scenarios its tests prove: {"package": \
        "Packages/PantryKit", "theme": "a pantry tracker shared by housemates", "scenarios": ["normal", "empty", \
        "failing"]}. The app then uses `RecipeClient.mock()` in previews and tests (`.mock(.failing)`, `.empty`, \
        `.unauthorized`, `.slow` for the other states) and `RecipeClient.current` in its services: the mock when \
        launched with `-mock YES` or `MOCK=1`, in previews and in tests, the live API otherwise. A later call keeps \
        the theme and seed and rewrites the fixtures, so call it again after `network` changes the API. A call it \
        cannot honour (no client package, a count naming no record) is refused with every reason and nothing is \
        written. Not for the client itself (network), the app's own types (models) or views.
        """

    public static func output(from events: [MocksFrame]) -> MocksResult? { events.compactMap(\.result).last }

    public init() {}

    public func run(_ input: Input, context: Context) -> AsyncThrowingStream<MocksFrame, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let result = try await MocksRun(input: input, host: context.host) { continuation.yield($0) }.run()
                    continuation.yield(.written(result))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
