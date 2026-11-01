import XCTest
@testable import MocksAgent

/// What each type and field of an API is read as: the people, the groups, the content and its replies, and the
/// role of each field.
final class ShapeTests: XCTestCase {
    func testTheLemmyLikeAPIsParts() throws {
        let shape = Shape(try ClientAPI.resolve(Fixture.lemmy))
        XCTAssertEqual(shape.person, "Person")
        XCTAssertEqual(shape.groups, ["Community"])
        XCTAssertEqual(shape.contents, ["Post"])
        XCTAssertEqual(shape.children, ["Comment": "Post"])
        XCTAssertEqual(shape.kind(of: "PostView"), .view)
        XCTAssertEqual(shape.kind(of: "PostAggregates"), .value)
        XCTAssertEqual(shape.kind(of: "SortType"), .choice)
        XCTAssertEqual(shape.kind(of: "Post"), .record)
    }

    func testFieldRoles() throws {
        let shape = Shape(try ClientAPI.resolve(Fixture.lemmy))
        func role(_ field: String, _ type: String) -> FieldRole { shape.role(try! XCTUnwrap(shape.field(field, of: type)), of: type) }
        XCTAssertEqual(role("creatorID", "Post"), .reference("Person"), "a creator is the API's person")
        XCTAssertEqual(role("communityID", "Post"), .reference("Community"))
        XCTAssertEqual(role("postID", "Comment"), .reference("Post"))
        XCTAssertEqual(role("name", "Person"), .handle, "a name beside a display name is a handle")
        XCTAssertEqual(role("name", "Post"), .title, "a post's name is its title")
        XCTAssertEqual(role("name", "Community"), .handle)
        XCTAssertEqual(role("body", "Post"), .body(.markdown), "the doc says Markdown")
        XCTAssertEqual(role("avatar", "Person"), .image(.person))
        XCTAssertEqual(role("banner", "Community"), .image(.wide))
        XCTAssertEqual(role("thumbnailURL", "Post"), .image(.thing))
        XCTAssertEqual(role("url", "Post"), .link)
        XCTAssertEqual(role("actorID", "Person"), .page)
        XCTAssertEqual(role("published", "Post"), .created)
        XCTAssertEqual(role("updated", "Post"), .updated)
        XCTAssertEqual(role("comments", "PostAggregates"), .count("comments"))
        XCTAssertEqual(role("score", "PostAggregates"), .score)
        XCTAssertEqual(role("path", "Comment"), .path)
        XCTAssertEqual(role("jwt", "LoginResponse"), .secret)
        XCTAssertEqual(role("myVote", "PostView"), .vote)
        XCTAssertEqual(role("visibility", "Community"), .choice("CommunityVisibility"))
    }

    func testAMastodonLikeAPIsParts() throws {
        let shape = Shape(try ClientAPI.resolve(Fixture.mastodon))
        XCTAssertEqual(shape.person, "Account")
        XCTAssertEqual(shape.contents, ["Status"])
        XCTAssertEqual(shape.owned, ["MediaAttachment": "Status"], "a status owns its attachments")
        XCTAssertEqual(shape.role(try XCTUnwrap(shape.field("inReplyToID", of: "Status")), of: "Status"), .parent)
        XCTAssertEqual(shape.role(try XCTUnwrap(shape.field("account", of: "Status")), of: "Status"), .record("Account"))
        XCTAssertEqual(shape.role(try XCTUnwrap(shape.field("header", of: "Account")), of: "Account"), .image(.wide))
    }
}
