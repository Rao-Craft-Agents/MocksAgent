import XCTest
@testable import MocksAgent

/// A model's answer, checked before a word of it lands: every reason a record or a thread is refused, said so the
/// model can fix it.
final class ContentCheckTests: XCTestCase {
    private let ask: RecordAsk = {
        var ask = RecordAsk(type: "Post", plural: "posts", about: nil, fields: [
            AskField(name: "name", kind: .string, optional: false, role: .title, note: "its title"),
            AskField(name: "body", kind: .string, optional: true, role: .body(.markdown), note: "what it says"),
            AskField(name: "course", kind: .choice(["starter", "main", "dessert"]), optional: false, role: .choice("Course"), note: "one of"),
            AskField(name: "minutes", kind: .integer, optional: false, role: .number, note: "minutes"),
        ], count: 5, part: .content)
        ask.groups = [("baking", "Baking"), ("soups", "Soup Season")]
        ask.groupNoun = "community"
        return ask
    }()

    func testEveryProblemIsSaid() {
        let answer = #"""
        {"posts": [
          {"name": "Brown butter cookies", "body": "So good.", "course": "Dessert", "minutes": "25", "community": "baking"},
          {"body": "No title here", "course": "main", "minutes": 30, "community": "soups"},
          {"name": "Sample title", "course": "main", "minutes": 30, "community": "soups"},
          {"name": "Leek soup", "course": "brunch", "minutes": 20.5, "community": "bread"},
          {"name": "Brown butter cookies", "course": "main", "minutes": 10, "community": "Soup Season"}
        ]}
        """#
        let checked = ContentCheck.records(Data(answer.utf8), ask: ask, count: 5, taken: [])
        XCTAssertEqual(checked.good.count, 1)
        XCTAssertEqual(checked.good.first?["course"], .string("dessert"), "a choice is made exact")
        XCTAssertEqual(checked.good.first?["minutes"], .int(25), "digits read as a number")
        XCTAssertEqual(checked.good.first?["_group"], .string("baking"))
        let said = checked.problems.joined(separator: "\n")
        XCTAssertTrue(said.contains("2: `name` is missing"), said)
        XCTAssertTrue(said.contains("3: `name` reads as a placeholder"), said)
        XCTAssertTrue(said.contains("`course` \"brunch\" is not one of starter, main, dessert"), said)
        XCTAssertTrue(said.contains("`minutes` is not a whole number"), said)
        XCTAssertTrue(said.contains("`community` \"bread\""), said)
        XCTAssertTrue(said.contains("5: `name` \"Brown butter cookies\" is already taken"), said)
    }

    func testAHandleIsAHandleAndUnique() {
        let people = RecordAsk(type: "Person", plural: "people", about: nil, fields: [
            AskField(name: "name", kind: .string, optional: false, role: .handle, note: "handle"),
        ], count: 3, part: .person)
        let answer = #"{"people": [{"name": "Maya Bakes"}, {"name": "theo!"}, {"name": "maya_bakes"}]}"#
        let checked = ContentCheck.records(Data(answer.utf8), ask: people, count: 3, taken: ["theo"])
        XCTAssertEqual(checked.good.map { $0["name"] }, [.string("maya_bakes")], "a space becomes an underscore, in lowercase")
        XCTAssertTrue(checked.problems.contains { $0.contains("\"theo!\" is not a handle") }, "\(checked.problems)")
        XCTAssertTrue(checked.problems.contains { $0.contains("\"maya_bakes\" is already taken") }, "\(checked.problems)")
    }

    func testAThreadAnswersEarlierRepliesWithDepth() {
        let field = AskField(name: "content", kind: .string, optional: false, role: .body(.plain), note: "what it says")
        let parents = [ThreadAsk.Parent(number: 1, title: "Soup", body: nil, author: "maya", count: 4),
                       ThreadAsk.Parent(number: 2, title: "Bread", body: nil, author: "theo", count: 4),
                       ThreadAsk.Parent(number: 3, title: "Cake", body: nil, author: "ines", count: 3)]
        let ask = ThreadAsk(parents: parents, field: field, threaded: true, noun: "comment", parentNoun: "post")
        let answer = #"""
        {"threads": [
          {"post": 1, "comments": [{"id": 1, "replyTo": null, "text": "Lovely."}, {"id": 2, "replyTo": 1, "text": "Agreed!"},
                                   {"id": 3, "replyTo": 2, "text": "Same."}, {"id": 4, "replyTo": null, "text": "What stock?"}]},
          {"post": 2, "comments": [{"id": 1, "replyTo": null, "text": "Crumb!"}, {"id": 2, "replyTo": 1, "text": "Thanks."},
                                   {"id": 3, "replyTo": null, "text": "Flour?"}, {"id": 4, "replyTo": 3, "text": "Bread flour."}]},
          {"post": 3, "comments": [{"id": 1, "replyTo": 3, "text": "Yum."}, {"id": 2, "replyTo": null, "text": "Recipe?"}, {"id": 3, "replyTo": null, "text": "Saved."}]}
        ]}
        """#
        let threads = ContentCheck.threads(Data(answer.utf8), ask: ask, parents: parents)
        guard case .success(let first)? = threads[1] else { return XCTFail("thread 1 passes") }
        XCTAssertEqual(first.map(\.replyTo), [nil, 0, 1, nil])
        guard case .failure(let shallow)? = threads[2] else { return XCTFail("thread 2 has no depth") }
        XCTAssertTrue(shallow.reason.contains("give the thread depth"), shallow.reason)
        guard case .failure(let forward)? = threads[3] else { return XCTFail("thread 3 answers a later reply") }
        XCTAssertTrue(forward.reason.contains("not an earlier reply's id"), forward.reason)
    }

    func testAnAnswerThatIsNotJSONIsSaid() {
        let checked = ContentCheck.records(Data("Here are your posts!".utf8), ask: ask, count: 2, taken: [])
        XCTAssertEqual(checked.problems, ["the answer was not the JSON object asked for"])
    }
}
