import Foundation
import GraniteAgents
import XCTest
@testable import MocksAgent

/// The package as an app finds it: by its record, with the schema a model is shown and the guide a host prompts with.
final class MocksAgentTests: XCTestCase {
    func testTheRecordIsFoundWithNothingListed() throws {
        let mocks = try XCTUnwrap(GraniteRoster.discovered().package("mocks"), "the record is in this test binary")
        XCTAssertEqual(mocks.module, "MocksAgent")
        XCTAssertEqual(mocks.summary, MocksAgent.summary)
    }

    func testTheSchemaIsWhatAModelIsShown() {
        let mocks = AnyAgentPackage(MocksAgent.self)
        XCTAssertEqual(mocks.schema, .object([
            .init(name: "package", schema: .string, required: false),
            .init(name: "theme", schema: .string, required: false),
            .init(name: "counts", schema: .array(.string), required: false),
            .init(name: "scenarios", schema: .array(.choice(["normal", "empty", "failing", "unauthorized", "slow"])), required: false),
            .init(name: "endpoints", schema: .array(.string), required: false),
            .init(name: "entities", schema: .array(.string), required: false),
            .init(name: "seed", schema: .integer, required: false),
            .init(name: "rounds", schema: .integer, required: false),
            .init(name: "directory", schema: .string, required: false),
        ]))
        XCTAssertTrue(mocks.takesDirectory)
        XCTAssertEqual(Set(mocks.fields.keys), ["package", "theme", "counts", "scenarios", "endpoints", "entities", "seed", "rounds"],
                       "a note beside every field the model sees")
        XCTAssertEqual(MocksAgent.word, "mocks")
        XCTAssertNotNil(MocksAgent.word.range(of: #"^[a-z][a-z0-9]{1,31}$"#, options: .regularExpression))
    }

    func testTheGuideSaysHowToCallIt() {
        let guide = AnyAgentPackage(MocksAgent.self).guide
        for word in ["theme", "counts", "package", "scenarios", "network", "api.json", ".mock()", ".current", "-mock YES", "MOCK=1",
                     "data: URLs", "{\"theme\":", "{\"package\":"] {
            XCTAssertTrue(guide.contains(word), "the guide says \(word)")
        }
    }

    /// The call as a host makes it: JSON in, the host's folder filled, JSON out naming the files.
    func testACallThroughTheRosterWritesTheFilesItNames() async throws {
        let folder = try Fixture.folder()
        try Fixture.package(Fixture.lemmy, in: folder)
        let input = try JSONSerialization.data(withJSONObject: ["theme": Kitchen.theme, "counts": ["posts: 12", "comments: 30"], "directory": folder.path])
        let answer = try await AnyAgentPackage(MocksAgent.self).perform(input, host: AgentHost(directory: folder.path, ask: "mock data"))
        let result = try JSONDecoder().decode(MocksResult.self, from: answer)
        let package = folder.appendingPathComponent("Packages/LemmyKit")
        XCTAssertEqual(result.package, package.path)
        XCTAssertEqual(result.client, "LemmyClient")
        XCTAssertEqual(result.path, package.appendingPathComponent("Sources/LemmyKit/Mocks/LemmyClient+Mock.swift").path)
        XCTAssertEqual(result.records["Post"], 12)
        XCTAssertEqual(result.records["Comment"], 30)
        XCTAssertEqual(result.images, 18)
        XCTAssertFalse(result.written, "no model was offered")
        XCTAssertTrue(result.notes.contains { $0.contains("word lists") }, "\(result.notes)")
        let names = Set(result.paths.map { String($0.dropFirst(package.path.count + 1)) })
        for expected in ["Sources/LemmyKit/Mocks/MockServer.swift", "Sources/LemmyKit/Mocks/MockMode.swift", "Sources/LemmyKit/Mocks/MockScenario.swift",
                         "Sources/LemmyKit/Mocks/MockImages.swift", "Sources/LemmyKit/Mocks/MockFixtures.swift",
                         "Sources/LemmyKit/Mocks/Fixtures/PostsFixture.swift", "Sources/LemmyKit/Mocks/Fixtures/CommentsFixture.swift",
                         "Tests/LemmyKitTests/MockFixtureTests.swift", "mocks.json"] {
            XCTAssertTrue(names.contains(expected), expected)
        }
        for path in result.paths { XCTAssertTrue(FileManager.default.fileExists(atPath: path), path) }

        // The answer keeps granite-answer/1: the client's mock and each entity at its count, held against what was made.
        XCTAssertEqual((try JSONSerialization.jsonObject(with: answer) as? [String: Any])?["format"] as? String, AgentAnswerStandard.format)
        XCTAssertEqual(result.expected.first, AgentExpected(kind: "client", name: "LemmyClient+Mock"))
        XCTAssertTrue(result.expected.contains(AgentExpected(kind: "fixture", name: "Post")), "\(result.expected)")
        let made = Set(result.made.map { AgentExpected(kind: $0.kind, name: $0.name) })
        XCTAssertTrue(Set(result.expected).isSubset(of: made), "every entity at its count: \(result.made)")
        XCTAssertEqual(result.made.first { $0.name == "Post" }?.path, package.appendingPathComponent("Sources/LemmyKit/Mocks/Fixtures/PostsFixture.swift").path)
        XCTAssertEqual(result.problems.map(\.kind), ["model"], "no model was offered: the records are word lists'")
        XCTAssertNil(result.asks, "no model, no asks")
        XCTAssertEqual(MocksError.noPackage("no client package").refusal, AgentRefusal(.call, "no client package"))
    }
}

/// A host that names its folder only in `AgentHost`, as one calling over the wire may.
final class HostFolderTests: XCTestCase {
    func testTheHostsFolderIsUsedWhenTheInputHasNone() async throws {
        let folder = try Fixture.folder()
        try Fixture.package(Fixture.recipes, in: folder)
        let input = try JSONSerialization.data(withJSONObject: ["theme": "a weeknight cooking app", "counts": ["recipes: 6"]])
        let answer = try await AnyAgentPackage(MocksAgent.self).perform(input, host: AgentHost(directory: folder.path))
        let result = try JSONDecoder().decode(MocksResult.self, from: answer)
        XCTAssertEqual(result.package, folder.appendingPathComponent("Packages/RecipeKit").path)
        XCTAssertTrue(result.paths.allSatisfy { $0.hasPrefix(folder.path + "/") }, "\(result.paths)")
    }
}
