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

    /// A reply answers what the agent's shape says, whatever the model wrote; half the replies asked for are enough,
    /// never fewer; a reply that says nothing, reads as a placeholder or repeats another is refused.
    func testAThreadTakesItsShapeFromTheAgent() {
        let field = AskField(name: "content", kind: .string, optional: false, role: .body(.plain), note: "what it says")
        let parents = [ThreadAsk.Parent(number: 1, title: "Soup", body: nil, author: "maya", count: 4, shape: [nil, 0, 1, nil]),
                       ThreadAsk.Parent(number: 2, title: "Bread", body: nil, author: "theo", count: 5, shape: [nil, 0, 1, nil, 3]),
                       ThreadAsk.Parent(number: 3, title: "Cake", body: nil, author: "ines", count: 6, shape: [nil, nil, 1, 2, nil, 0]),
                       ThreadAsk.Parent(number: 4, title: "Kimchi", body: nil, author: "ruth", count: 2, shape: [nil, 0]),
                       ThreadAsk.Parent(number: 5, title: "Pie", body: nil, author: "sam", count: 2, shape: [nil, 0])]
        let ask = ThreadAsk(parents: parents, field: field, threaded: true, noun: "comment", parentNoun: "post")
        let answer = #"""
        {"threads": [
          {"post": 1, "comments": [{"id": 1, "replyTo": 3, "text": "Lovely."}, {"id": 2, "text": "Agreed!"},
                                   {"id": 3, "text": "Same."}, {"id": 4, "text": "What stock?"}]},
          {"post": 2, "comments": [{"id": 1, "text": "Crumb!"}, {"id": 2, "text": "Thanks."}, {"id": 3, "text": "Flour?"}]},
          {"post": 3, "comments": [{"id": 1, "text": "Yum."}, {"id": 2, "text": "Recipe?"}]},
          {"post": 4, "comments": [{"id": 1, "text": "Saved."}, {"id": 2, "text": "saved."}]},
          {"post": 5, "comments": [{"id": 1, "text": "Lorem ipsum dolor."}, {"id": 2, "text": "Nice."}]}
        ]}
        """#
        let threads = ContentCheck.threads(Data(answer.utf8), ask: ask, parents: parents)
        guard case .success(let first)? = threads[1] else { return XCTFail("thread 1 passes") }
        XCTAssertEqual(first.map(\.replyTo), [nil, 0, 1, nil], "the agent's shape, not the model's replyTo")
        guard case .success(let three)? = threads[2] else { return XCTFail("3 of 5 is enough") }
        XCTAssertEqual(three.map(\.replyTo), [nil, 0, 1])
        guard case .failure(let short)? = threads[3] else { return XCTFail("2 of 6 is fewer than half") }
        XCTAssertTrue(short.reason.contains("it has 2 replies, and 6 were asked for"), short.reason)
        guard case .failure(let twice)? = threads[4] else { return XCTFail("a reply said twice") }
        XCTAssertTrue(twice.reason.contains("two replies say the same thing"), twice.reason)
        guard case .failure(let filler)? = threads[5] else { return XCTFail("a placeholder") }
        XCTAssertTrue(filler.reason.contains("placeholder"), filler.reason)
    }

    /// The model is told who answers whom; a thread of four or more the agent shapes holds a reply to a reply to a reply.
    func testTheAgentShapesEveryThread() {
        var random = Seeded(7)
        for count in 1...12 {
            for _ in 0..<20 {
                let shape = WorldBuilder.thread(count, random: &random)
                XCTAssertEqual(shape.count, count)
                XCTAssertNil(shape.first ?? nil, "the first reply answers the record")
                for (index, answered) in shape.enumerated() { if let answered { XCTAssertLessThan(answered, index) } }
                if count >= 4 { XCTAssertTrue(shape.contains { $0.map { shape[$0] != nil } ?? false }, "depth in \(shape)") }
            }
        }
        XCTAssertEqual(ContentPrompt.answers([nil, 0, 1, nil], record: "post"), "1 answers the post, 2 answers 1, 3 answers 2, 4 answers the post")
    }

    func testAnAnswerThatIsNotJSONIsSaid() {
        let checked = ContentCheck.records(Data("Here are your posts!".utf8), ask: ask, count: 2, taken: [])
        XCTAssertEqual(checked.problems, ["the answer was not the JSON object asked for"])
    }
}
