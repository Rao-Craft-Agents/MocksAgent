import XCTest
@testable import MocksAgent

/// What each endpoint answers: a list cut into pages and narrowed by the query, an item found by what the request
/// names, a body echoed into what it made, a sign-in's token.
final class RoutePlannerTests: XCTestCase {
    private func plans(_ record: APIRecord) async throws -> [String: RoutePlan] {
        let (shape, world, renderer) = try await Fixture.world(record)
        let plans = RoutePlanner(shape: shape, world: world, renderer: renderer).plans()
        return Dictionary(uniqueKeysWithValues: zip(shape.api.methods.map(\.name), plans))
    }

    func testAPagedListIsCutIntoPagesThatEnd() async throws {
        guard case .list(let list)? = try await plans(Fixture.lemmy)["posts"] else { return XCTFail("posts is a list") }
        XCTAssertEqual(list.pages.count, 3, "24 posts, 10 a page")
        XCTAssertEqual(list.count, 24)
        XCTAssertEqual(list.paging, .page("page"))
        XCTAssertEqual(list.limit, "limit")
        XCTAssertEqual(list.itemsKey, "posts")
        XCTAssertEqual(list.filters.map(\.parameter), ["community_id"])
        XCTAssertEqual(list.filters.first?.path, ["community", "id"])
        XCTAssertEqual(list.sort?.orders.map(\.value), ["New", "TopDay"])
        if case .array(let last)? = list.pages.last?["posts"] { XCTAssertEqual(last.count, 4, "the last page is short") }
    }

    func testAnItemIsFoundByWhatTheRequestNames() async throws {
        let plans = try await plans(Fixture.lemmy)
        guard case .lookup(let post)? = plans["post"] else { return XCTFail("post is a lookup") }
        XCTAssertEqual(post.key, .query("id"))
        XCTAssertEqual(post.match, ["post", "id"])
        XCTAssertEqual(post.place, ["post_view"])
        guard case .route("GET", "/api/v3/post/list", nil) = post.items else { return XCTFail("found among the posts list's items") }

        guard case .lookup(let person)? = plans["person"] else { return XCTFail("person is a lookup") }
        XCTAssertEqual(person.key, .query("username"))
        XCTAssertEqual(person.match, ["person", "name"], "a username is the person's handle")
        XCTAssertEqual(person.related.map(\.place), [["posts"], ["comments"]], "their posts and comments come with them")
        XCTAssertEqual(person.related.first?.match, ["creator", "id"])

        guard case .lookup(let like)? = plans["likePost"] else { return XCTFail("a vote finds the post it is on") }
        XCTAssertEqual(like.key, .body("post_id"))
    }

    func testABodyIsEchoedIntoWhatItMade() async throws {
        guard case .echo(let echo)? = try await plans(Fixture.lemmy)["createPost"] else { return XCTFail("createPost echoes") }
        XCTAssertEqual(echo.place, ["post_view", "post"])
        XCTAssertEqual(echo.id, "id")
        XCTAssertEqual(echo.dates, ["published"])
        XCTAssertEqual(echo.joins.map(\.body), ["community_id"])
        XCTAssertEqual(echo.joins.first?.place, ["post_view", "community"])
    }

    func testASignInAnswersTheToken() async throws {
        guard case .fixture(let json, _)? = try await plans(Fixture.lemmy)["login"] else { return XCTFail("login is a fixture") }
        XCTAssertEqual(json["jwt"], .string("token"))
        guard case .nothing? = try await plans(Fixture.lemmy)["deleteComment"] else { return XCTFail("a delete answers nothing") }
    }

    func testACursorListPagesByTheLastItemsID() async throws {
        let plans = try await plans(Fixture.mastodon)
        guard case .list(let timeline)? = plans["homeTimeline"] else { return XCTFail("the timeline is a list") }
        XCTAssertEqual(timeline.paging, .cursor("max_id", id: ["id"], next: nil), "the next cursor rides the Link header")
        XCTAssertNil(timeline.itemsKey, "the answer is the list")
        guard case .list(let statuses)? = plans["statuses"] else { return XCTFail("an account's statuses are a list") }
        XCTAssertEqual(statuses.filters.first?.parameter, "id")
        XCTAssertEqual(statuses.filters.first?.path, ["account", "id"], "the path's account narrows the list")
        guard case .fixture(let me, _)? = plans["me"] else { return XCTFail("me is a fixture") }
        XCTAssertNotNil(me["username"])
    }

    func testAPageEnvelopeCountsItsItems() async throws {
        guard case .list(let list)? = try await plans(Fixture.recipes)["recipes"] else { return XCTFail("recipes is a list") }
        XCTAssertEqual(list.totals, ["total"])
        XCTAssertEqual(list.pages.first?["total"], .int(list.count))
        XCTAssertEqual(list.filters.map(\.parameter), ["course"], "a field's name narrows by that field")
    }
}
