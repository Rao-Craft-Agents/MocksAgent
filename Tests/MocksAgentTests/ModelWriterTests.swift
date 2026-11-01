import Foundation
import GraniteAgents
import XCTest
@testable import MocksAgent

/// The host's model writes what the records say: asked in narrow batches with a schema built from the entity
/// lines, every answer checked, what fails asked for again with the reason, word lists after the rounds run out.
final class ModelWriterTests: XCTestCase {
    private let ask = RecordAsk(type: "Person", plural: "people", about: nil, fields: [
        AskField(name: "name", kind: .string, optional: false, role: .handle, note: "their handle"),
        AskField(name: "displayName", kind: .string, optional: true, role: .displayName, note: "their name"),
    ], count: 2, part: .person)

    func testABadAnswerIsAskedForAgainWithItsReason() async throws {
        let model = FakeHostModel(replies: [
            #"{"people": [{"name": "maya_bakes", "displayName": "Maya Okafor"}, {"displayName": "No Handle"}]}"#,
            #"{"people": [{"name": "theo.simmers", "displayName": "Theo Lindqvist"}]}"#,
        ])
        var writer = ModelWriter(model: model, theme: Theme(Kitchen.theme, package: "Lemmy"), rounds: 3, seed: 1, note: { _ in })
        let records = try await writer.records(ask)
        XCTAssertEqual(records.map { $0["name"] }, [.string("maya_bakes"), .string("theo.simmers")])
        XCTAssertEqual(writer.asks, 2)
        XCTAssertEqual(writer.retries, 1)
        XCTAssertTrue(writer.notes.isEmpty)
        let again = model.asked[1].user
        XCTAssertTrue(again.contains("`name` is missing"), "the second ask says what was wrong: \(again)")
        XCTAssertTrue(again.contains("Write 1 people again"), again)
        XCTAssertTrue(again.contains("maya_bakes"), "what is taken is said")
    }

    func testTheSchemaIsBuiltFromTheLinesAndTheExampleIsAnotherApps() async throws {
        let model = FakeHostModel(replies: [#"{"people": [{"name": "a1", "displayName": null}, {"name": "b2", "displayName": "Bo"}]}"#])
        var writer = ModelWriter(model: model, theme: Theme(Kitchen.theme, package: "Lemmy"), rounds: 3, seed: 1, note: { _ in })
        _ = try await writer.records(ask)
        let schema = try XCTUnwrap(JSONValue.parse(model.asked[0].schema))
        XCTAssertEqual(schema[path: ["properties", "people", "minItems"]], .int(2))
        XCTAssertEqual(schema[path: ["properties", "people", "items", "required"]], .array([.string("name"), .string("displayName")]))
        XCTAssertEqual(schema[path: ["properties", "people", "items", "properties", "displayName", "type"]], .array([.string("string"), .string("null")]))
        let system = model.asked[0].system
        XCTAssertTrue(system.contains("trail-running club"), "a food app is shown another app's example")
        XCTAssertFalse(system.contains("Kimchi") || system.contains("sourdough"), "never the app's own words")
    }

    /// Posts people discuss: each one an angle, a rule for titles, and only the handles taken are shown, never the
    /// titles (a model shown them writes variations: "…, Again", "#58"); a taken title is still refused.
    func testAPostsAskShowsAnglesAndHandlesButNeverTheTitlesTaken() async throws {
        var posts = RecordAsk(type: "Post", plural: "posts", about: nil, fields: [
            AskField(name: "name", kind: .string, optional: false, role: .title, note: "its title"),
        ], count: 2, part: .content)
        posts.groups = [("baking", "Baking")]
        posts.groupNoun = "community"
        posts.taken = ["maya_bakes", "Brown butter cookies"]
        posts.handles = ["maya_bakes"]
        posts.angles = Array(ContentPrompt.angles.prefix(2))
        let model = FakeHostModel(replies: [
            #"{"posts": [{"name": "Leek soup for a cold night", "community": "baking"}, {"name": "Brown butter cookies", "community": "baking"}]}"#,
            #"{"posts": [{"name": "Is a dutch oven worth it?", "community": "baking"}]}"#,
        ])
        var writer = ModelWriter(model: model, theme: Theme(Kitchen.theme, package: "Lemmy"), rounds: 3, seed: 1, note: { _ in })
        let records = try await writer.records(posts)
        XCTAssertEqual(records.map { $0["name"]?.text }, ["Leek soup for a cold night", "Is a dutch oven worth it?"])
        let first = model.asked[0].user
        XCTAssertTrue(first.contains("1. showing something they made or did") && first.contains("2. a question for the others"), first)
        XCTAssertTrue(first.contains("never the community's name, never numbered like a series"), first)
        XCTAssertTrue(first.contains("Handles already taken, never use again: maya_bakes"), first)
        XCTAssertFalse(first.contains("Brown butter cookies"), "a title taken is checked, never shown")
        let again = model.asked[1].user
        XCTAssertTrue(again.contains("1. a question for the others") && !again.contains("2. "), "the angle still wanted: \(again)")
        XCTAssertFalse(again.contains("Leek soup"), "nor a title this call took: \(again)")
    }

    func testWordListsWriteWhatTheRoundsCouldNot() async throws {
        let model = FakeHostModel(replies: [#"{"people": [{"name": "Sample name"}]}"#])
        var writer = ModelWriter(model: model, theme: Theme("a book club", package: "Books"), rounds: 2, seed: 1, note: { _ in })
        let records = try await writer.records(ask)
        XCTAssertEqual(records.count, 2)
        XCTAssertEqual(writer.asks, 2)
        XCTAssertTrue(writer.notes.first?.contains("came from word lists after 2 answers") == true, "\(writer.notes)")
        XCTAssertFalse(records.contains { $0["name"]?.text?.lowercased().contains("sample") == true })
    }

    /// The whole call on a scripted model of a recipe community: its first batch of posts is wrong twice over.
    func testACallOnTheHostsModelWritesTheCommunity() async throws {
        let folder = try Fixture.folder()
        let package = try Fixture.package(Fixture.lemmy, in: folder)
        let model = Kitchen.model()
        var input = MocksAgent.Input(theme: Kitchen.theme, counts: ["posts: 12", "comments: 30", "people: 10"])
        input.directory = folder.path
        let result = try await MocksRun(input: input, host: AgentHost(directory: folder.path, model: model), yield: { _ in }).run()
        XCTAssertTrue(result.written)
        XCTAssertTrue(result.notes.contains { $0.contains("asked again") }, "the bad batch was asked again: \(result.notes)")
        XCTAssertFalse(result.notes.contains { $0.contains("word lists") }, "everything passed in the end: \(result.notes)")
        let posts = try String(contentsOf: package.appendingPathComponent("Sources/LemmyKit/Mocks/Fixtures/PostsFixture.swift"), encoding: .utf8)
        XCTAssertTrue(posts.contains("My sourdough finally has an open crumb!"))
        XCTAssertFalse(posts.contains("\"bread\""), "a community that does not exist never lands")
        let comments = try String(contentsOf: package.appendingPathComponent("Sources/LemmyKit/Mocks/Fixtures/CommentsFixture.swift"), encoding: .utf8)
        XCTAssertTrue(comments.contains("Saving this for the weekend") || comments.contains("What temperature did you use?"))
        let postAsks = model.asked.filter { $0.user.contains("Answer {\"posts\"") }
        XCTAssertFalse(postAsks.isEmpty)
        XCTAssertTrue(postAsks.allSatisfy { $0.user.contains("What each one is, in order:") }, "posts people answer come with angles")
        XCTAssertFalse(model.asked.contains { $0.user.contains("Answer {\"people\"") && $0.user.contains("What each one is") }, "people do not")
        let retry = try XCTUnwrap(model.asked.first { $0.user.contains("came back wrong") })
        XCTAssertTrue(retry.user.contains("is missing") && retry.user.contains("\"bread\""), retry.user)
    }
}
