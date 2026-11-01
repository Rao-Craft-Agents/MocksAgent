import Foundation
import GraniteAgents
import XCTest
@testable import MocksAgent

/// What the files say, what is refused, and what a later call keeps.
final class EmitTests: XCTestCase {
    private func run(_ input: MocksAgent.Input, in folder: URL) async throws -> MocksResult {
        var input = input
        input.directory = folder.path
        return try await MocksRun(input: input, host: AgentHost(directory: folder.path), yield: { _ in }).run()
    }

    private func text(_ result: MocksResult, _ suffix: String) throws -> String {
        try String(contentsOfFile: XCTUnwrap(result.paths.first { $0.hasSuffix("/" + suffix) }, suffix), encoding: .utf8)
    }

    func testTheRoutesSayHowEachEndpointAnswers() async throws {
        let folder = try Fixture.folder()
        try Fixture.package(Fixture.lemmy, in: folder)
        let result = try await run(.init(theme: Kitchen.theme), in: folder)
        let routes = try text(result, "LemmyClient+Mock.swift")
        XCTAssertTrue(routes.contains("public static func mock(_ scenario: MockScenario = .normal, latency: Duration = .milliseconds(250)) -> LemmyClient {"))
        XCTAssertTrue(routes.contains("MemoryTokenStore([hostKey(mockBaseURL): MockFixtures.sessionToken])"), "signed in, in memory")
        XCTAssertTrue(routes.contains("static let mockBaseURL = URL(string: \"https://lemmy.example\")!"))
        XCTAssertTrue(routes.contains("MockRoute(.post, \"/api/v3/user/login\", .fixture(MockFixtures.login)),"))
        XCTAssertTrue(routes.contains("paging: .page(\"page\"),"))
        XCTAssertTrue(routes.contains("filters: [\"post_id\": [\"post\", \"id\"]],"))
        XCTAssertTrue(routes.contains("key: .query(\"id\"),"))
        XCTAssertTrue(routes.contains(".init(place: [\"posts\"], items: .route(.get, \"/api/v3/post/list\"), match: [\"creator\", \"id\"], to: [\"person\", \"id\"], limit: 20),"))
        XCTAssertTrue(routes.contains("MockRoute(.delete, \"/api/v3/comment/{id}\", .nothing),"))
        let mode = try text(result, "MockMode.swift")
        XCTAssertTrue(mode.contains("public static var current: LemmyClient {"), "a test may replace the current client")
        XCTAssertTrue(mode.contains("let answer = try await LemmyClient.current.posts()"))
        let scenario = try text(result, "MockScenario.swift")
        for name in ["normal", "empty", "failing", "unauthorized", "slow"] { XCTAssertTrue(scenario.contains("case \(name)\n"), name) }
        let shared = try text(result, "MockFixtures.swift")
        XCTAssertTrue(shared.contains("written for a cozy recipe-sharing community"), shared)
        XCTAssertTrue(shared.contains(".object([\"error\": .string(message)])"))
        let fixture = try text(result, "PostFixture.swift")
        XCTAssertTrue(fixture.contains("static let post = #\"\"\""), "a fixture is a raw string literal")
        XCTAssertTrue(fixture.contains("\"post_view\": {"))
        let tests = try text(result, "MockFixtureTests.swift")
        for name in ["testEveryFixtureReadsAsItsType", "testEveryEndpointAnswers", "testEveryPagedListEnds", "testTheRequestNarrowsItsList",
                     "testEveryScenarioAnswersAsItShould", "testTheCurrentClientIsTheMockInATestAndCanBeReplaced", "testEveryPictureLoadsAsAnImage"] {
            XCTAssertTrue(tests.contains("func \(name)()"), name)
        }
    }

    func testOtherShapesOfAPIWriteFilesThatParse() async throws {
        for record in [Fixture.mastodon, Fixture.recipes] {
            let folder = try Fixture.folder()
            try Fixture.package(record, in: folder)
            let result = try await run(.init(theme: "a small social app"), in: folder)
            XCTAssertTrue(result.paths.contains { $0.hasSuffix("\(ClientAPI.stem(of: record.name))Client+Mock.swift") }, record.name)
        }
    }

    func testARefusedCallSaysEveryReasonAndWritesNothing() async throws {
        let empty = try Fixture.folder()
        do {
            _ = try await run(.init(), in: empty)
            XCTFail("no client package")
        } catch let error as MocksError {
            XCTAssertTrue("\(error)".contains("make the API's client with network first"), "\(error)")
        }
        let folder = try Fixture.folder()
        let package = try Fixture.package(Fixture.lemmy, in: folder)
        do {
            _ = try await run(.init(counts: ["recipes: 4", "posts forty"]), in: folder)
            XCTFail("counts that name nothing")
        } catch let error as MocksError {
            XCTAssertTrue("\(error)".contains("2 things in the call cannot be honoured"), "\(error)")
            XCTAssertTrue("\(error)".contains("`recipes: 4` names no record"), "\(error)")
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: package.appendingPathComponent("Sources/LemmyKit/Mocks").path), "nothing was written")
        try Fixture.package(Fixture.mastodon, in: folder)
        do {
            _ = try await run(.init(), in: folder)
            XCTFail("two packages")
        } catch let error as MocksError {
            XCTAssertTrue("\(error)".contains("name one in `package`"), "\(error)")
        }
    }

    func testALaterCallKeepsTheThemeAndSeedAndTakesAwayWhatIsGone() async throws {
        let folder = try Fixture.folder()
        let package = try Fixture.package(Fixture.lemmy, in: folder)
        let first = try await run(.init(theme: Kitchen.theme, seed: 42), in: folder)
        let settings = try XCTUnwrap(MocksSettings.read(in: package))
        XCTAssertEqual(settings.seed, 42)
        XCTAssertEqual(settings.theme, Kitchen.theme)
        // The API loses its vote endpoint; the next call's fixture of it is taken away.
        var smaller = Fixture.lemmy
        smaller.endpoints.removeAll { $0.contains("/post/like") }
        let encoder = JSONEncoder()
        try encoder.encode(smaller).write(to: package.appendingPathComponent("api.json"))
        let second = try await run(.init(), in: folder)
        XCTAssertTrue(second.notes.contains { $0.contains("removed Sources/LemmyKit/Mocks/Fixtures/LikePostFixture.swift") }, "\(second.notes)")
        XCTAssertFalse(second.notes.contains { $0.contains("no theme was given") }, "the theme is kept")
        let posts = { (result: MocksResult) in try String(contentsOfFile: result.paths.first { $0.hasSuffix("PostsFixture.swift") }!, encoding: .utf8) }
        let firstPosts = try posts(first), secondPosts = try posts(second)
        XCTAssertEqual(firstPosts.components(separatedBy: "\"name\"").count, secondPosts.components(separatedBy: "\"name\"").count)
    }
}

/// The pictures, the JSON and the literals the files are made of.
final class PartsTests: XCTestCase {
    func testThePicturesAreSmallPNGs() throws {
        XCTAssertEqual(MockArt.names.count, 18)
        for name in MockArt.names {
            let png = try XCTUnwrap(MockArt.png(name), name)
            XCTAssertEqual(Array(png.prefix(4)), [0x89, 0x50, 0x4E, 0x47], name)
            XCTAssertLessThan(png.count, 12_000, "\(name) is \(png.count) bytes")
        }
        XCTAssertNil(MockArt.png("food-7"))
    }

    func testJSONKeepsItsKeysInOrder() throws {
        let text = #"{"b": 1, "a": [true, null, 2.5, "x\"y"], "c": {"d": "é"}}"#
        let value = try XCTUnwrap(JSONValue.parse(Data(text.utf8)))
        XCTAssertEqual(value.compact, #"{"b": 1, "a": [true, null, 2.5, "x\"y"], "c": {"d": "é"}}"#)
        XCTAssertEqual(value[path: ["c", "d"]], .string("é"))
        XCTAssertNil(JSONValue.parse(Data("{\"a\": }".utf8)))
    }

    func testARawLiteralCannotBeEndedByItsJSON() {
        let tricky = JSONValue.object([("text", .string("a \"\"\"# and \\#(x)"))])
        let literal = SwiftLiteral.raw(tricky, indent: 4)
        XCTAssertTrue(literal.hasPrefix("##\"\"\""), literal)
        XCTAssertTrue(literal.hasSuffix("\"\"\"##"), literal)
    }
}
