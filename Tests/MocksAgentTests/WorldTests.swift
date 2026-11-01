import XCTest
@testable import MocksAgent

/// The world agrees with itself: references name records that exist, counts count, threads have depth, ids grow
/// with time, every date is in the last weeks.
final class WorldTests: XCTestCase {
    func testReferencesNameRecordsThatExist() async throws {
        let (_, world, _) = try await Fixture.world(Fixture.lemmy)
        let posts = Set(world.all("Post").map(\.id.compact)), people = Set(world.all("Person").map(\.id.compact)), communities = Set(world.all("Community").map(\.id.compact))
        XCTAssertEqual(world.count("Post"), 24)
        XCTAssertEqual(world.count("Comment"), 72)
        for comment in world.all("Comment") {
            XCTAssertTrue(posts.contains(comment.values["postID"]!.compact), "a comment's post id names a post")
            XCTAssertTrue(people.contains(comment.values["creatorID"]!.compact))
        }
        for post in world.all("Post") {
            XCTAssertTrue(communities.contains(post.values["communityID"]!.compact), "a post's community id names a community")
            XCTAssertTrue(people.contains(post.values["creatorID"]!.compact))
        }
    }

    func testThreadsHaveDepthAndPathsFollowThem() async throws {
        let (_, world, _) = try await Fixture.world(Fixture.lemmy)
        let comments = world.all("Comment")
        XCTAssertGreaterThanOrEqual(comments.map(\.depth).max() ?? 0, 2, "a reply to a reply")
        for comment in comments {
            guard case .string(let path)? = comment.values["path"] else { return XCTFail("a path") }
            XCTAssertTrue(path.hasPrefix("0."))
            XCTAssertTrue(path.hasSuffix(".\(comment.id.text!)"))
            XCTAssertEqual(path.split(separator: ".").count, comment.depth + 2)
            if let parent = comment.parent { XCTAssertGreaterThanOrEqual(comment.date, comments[parent].date, "a reply comes after what it answers") }
        }
    }

    func testIdsGrowWithTimeAndDatesAreRecent() async throws {
        let (_, world, _) = try await Fixture.world(Fixture.lemmy)
        let posts = world.all("Post")
        XCTAssertEqual(Set(posts.map(\.id.compact)).count, posts.count, "ids are unique")
        for (earlier, later) in zip(posts, posts.dropFirst()) {
            XCTAssertLessThanOrEqual(earlier.date, later.date)
            XCTAssertLessThan(earlier.id.text.flatMap { Int($0) }!, later.id.text.flatMap { Int($0) }!)
        }
        for post in posts {
            XCTAssertLessThanOrEqual(post.date, world.anchor)
            XCTAssertGreaterThan(post.date, world.anchor.addingTimeInterval(-22 * 86_400), "within the last three weeks")
        }
    }

    func testCountsCountTheWorld() async throws {
        let (_, world, renderer) = try await Fixture.world(Fixture.lemmy)
        for (index, post) in world.all("Post").enumerated() {
            let view = renderer.view("PostView", [("Post", index)])
            let comments = world.all("Comment").filter { $0.owner == index }.count
            XCTAssertEqual(view[path: ["counts", "comments"]], .int(comments), "a post's comment count is its comments")
            XCTAssertEqual(view[path: ["creator", "id"]], post.values["creatorID"], "the creator shown is the post's")
            XCTAssertEqual(view[path: ["community", "id"]], post.values["communityID"])
        }
        let person = renderer.view("PersonView", [("Person", world.me)])
        XCTAssertEqual(person[path: ["counts", "post_count"]], .int(world.all("Post").filter { $0.author == world.me }.count))
    }

    func testTheSameSeedMakesTheSameWorld() async throws {
        let (_, first, _) = try await Fixture.world(Fixture.lemmy, seed: 11)
        let (_, second, _) = try await Fixture.world(Fixture.lemmy, seed: 11)
        XCTAssertEqual(first.all("Post").map(\.id), second.all("Post").map(\.id))
        XCTAssertEqual(first.all("Comment").map(\.values), second.all("Comment").map(\.values))
    }
}
