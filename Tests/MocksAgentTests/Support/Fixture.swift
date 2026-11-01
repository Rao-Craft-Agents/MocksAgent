import Foundation
@testable import MocksAgent

enum Fixture {
    /// A folder of its own for one test, removed with the process's temporary files.
    static func folder() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("mocks-\(UUID().uuidString.prefix(8))", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// A Lemmy-like API, as `network` keeps its lines: a login that stores a JWT, posts paged and narrowed by
    /// community, a post by its id, comments paged and narrowed by post, a person by name with their posts and
    /// comments, communities, a community by name with its moderators, a vote on a post.
    static let lemmyEndpoints = [
        #"POST /api/v3/user/login body(Login) -> LoginResponse as login stores token(jwt) "signs a person in""#,
        #"GET /api/v3/post/list?page,limit,sort:SortType,type_:ListingType,community_id:Int -> GetPostsResponse as posts paged "the posts of a community, or of the instance""#,
        "GET /api/v3/post?id:Int! -> PostResponse as post",
        "POST /api/v3/post body(CreatePost) -> PostResponse as createPost",
        "GET /api/v3/comment/list?post_id:Int,page,limit,sort:CommentSortType -> GetCommentsResponse as comments paged",
        "POST /api/v3/comment body(CreateComment) -> CommentResponse as createComment",
        "GET /api/v3/user?username!,page,limit -> GetPersonDetailsResponse as person",
        "GET /api/v3/community/list?page,limit,sort:SortType -> ListCommunitiesResponse as communities paged",
        "GET /api/v3/community?name! -> GetCommunityResponse as community",
        "POST /api/v3/post/like body(CreatePostLike) -> PostResponse as likePost",
        "DELETE /api/v3/comment/{id:Int} as deleteComment",
    ]

    static let lemmyEntities = [
        "Login: usernameOrEmail String, password String",
        "LoginResponse: jwt String?, registrationCreated Bool = false, verifyEmailSent Bool = false",
        "GetPostsResponse: posts [PostView]",
        "PostView: post Post, creator Person, community Community, counts PostAggregates, myVote Int?, saved Bool = false",
        #"Post "a link or text post in a community": id Int, name String, url URL?, body String? "markdown", thumbnailURL URL?, creatorID Int, communityID Int, published Date, updated Date?, nsfw Bool = false, locked Bool = false, featuredCommunity Bool = false"#,
        "Person: id Int, name String, displayName String?, avatar URL?, banner URL?, bio String?, actorID URL, local Bool, published Date",
        "Community: id Int, name String, title String, description String?, icon URL?, banner URL?, nsfw Bool = false, visibility CommunityVisibility = .public, published Date",
        #"CommunityVisibility: public = "Public" | localOnly = "LocalOnly""#,
        "PostAggregates: comments Int, score Int, upvotes Int, downvotes Int, newestCommentTime Date?",
        "PostResponse: postView PostView",
        "CreatePost: name String, communityID Int, url URL?, body String?, nsfw Bool?",
        "CreatePostLike: postID Int, score Int",
        "GetCommentsResponse: comments [CommentView]",
        "CommentView: comment Comment, creator Person, post Post, community Community, counts CommentAggregates, myVote Int?",
        "Comment: id Int, creatorID Int, postID Int, content String, path String, published Date, updated Date?, deleted Bool = false, distinguished Bool = false",
        "CommentAggregates: score Int, upvotes Int, downvotes Int, childCount Int",
        "CommentResponse: commentView CommentView",
        "CreateComment: content String, postID Int, parentID Int?",
        "GetPersonDetailsResponse: personView PersonView, posts [PostView], comments [CommentView]",
        "PersonView: person Person, counts PersonAggregates",
        "PersonAggregates: postCount Int, commentCount Int",
        "ListCommunitiesResponse: communities [CommunityView]",
        "CommunityView: community Community, subscribed SubscribedType, counts CommunityAggregates",
        #"SubscribedType: subscribed = "Subscribed" | notSubscribed = "NotSubscribed" | pending = "Pending""#,
        "CommunityAggregates: subscribers Int, posts Int, comments Int, usersActiveWeek Int",
        "GetCommunityResponse: communityView CommunityView, moderators [CommunityModeratorView]",
        "CommunityModeratorView: community Community, moderator Person",
        #"SortType: active = "Active" | hot = "Hot" | new = "New" | topDay = "TopDay""#,
        #"CommentSortType: hot = "Hot" | top = "Top" | new = "New" | old = "Old""#,
        #"ListingType: all = "All" | local = "Local" | subscribed = "Subscribed""#,
    ]

    static let lemmy = APIRecord(name: "LemmyKit", baseURL: "https://lemmy.example", auth: "bearer", paging: "page", coding: "snake",
                                 dates: ["yyyy-MM-dd HH:mm:ss"], endpoints: lemmyEndpoints, entities: lemmyEntities)

    /// A Mastodon-like API: string ids, an account in each status, attachments a status owns, a timeline paged by
    /// `max_id` and the `Link` header, exact keys.
    static let mastodon = APIRecord(
        name: "MastodonKit", baseURL: "https://mastodon.example", auth: "bearer", paging: "cursor", coding: "snake",
        endpoints: [
            "GET /api/v1/accounts/verify_credentials -> Account as me",
            "GET /api/v1/timelines/home?max_id,limit -> [Status] as homeTimeline paged",
            "GET /api/v1/accounts/{id}/statuses?max_id,limit -> [Status] as statuses paged",
            "GET /api/v1/statuses/{id} -> Status as status",
            "POST /api/v1/statuses body(NewStatus) -> Status as postStatus",
        ],
        entities: [
            "Account: id String, username String, acct String, displayName String, avatar URL, header URL?, note String, followersCount Int, followingCount Int, statusesCount Int, createdAt Date, bot Bool = false",
            "Status: id String, createdAt Date, account Account, content String, visibility Visibility, sensitive Bool, spoilerText String, mediaAttachments [MediaAttachment], repliesCount Int, reblogsCount Int, favouritesCount Int, inReplyToID String?, reblog Status?",
            "MediaAttachment: id String, type MediaType, url URL, description String?",
            "MediaType: image | video | gifv | audio",
            "Visibility: public | unlisted | private | direct",
            "NewStatus: status String, visibility Visibility = .public",
        ])

    /// A recipe API with exact keys, a page envelope with a total, and no people.
    static let recipes = APIRecord(
        name: "RecipeKit", baseURL: "https://api.recipes.example", auth: "bearer", paging: "page", coding: "exact",
        endpoints: [
            "POST /v1/session body(Credentials) -> Session as signIn stores token",
            "GET /v1/recipes?page,per_page,course:Course -> RecipePage as recipes paged",
            "GET /v1/recipes/{id:Int} -> Recipe as recipe",
            "POST /v1/recipes body(NewRecipe) -> Recipe as createRecipe",
            "DELETE /v1/recipes/{id:Int} as deleteRecipe",
        ],
        entities: [
            "Credentials: email String, password String",
            "Session: token String",
            "RecipePage: recipes [Recipe], total Int = 0",
            "Recipe: id Int, title String, minutes Int = 30, course Course?, added Date, photo URL?",
            "Course: starter | main | dessert",
            "NewRecipe: title String, minutes Int",
        ])

    /// A client package as `network` lays one out, in `folder`: its `api.json` and the files `mocks` looks for, the
    /// rest of the client left out (the unit tests only parse what `mocks` writes).
    @discardableResult
    static func package(_ record: APIRecord, in folder: URL) throws -> URL {
        let package = folder.appendingPathComponent("Packages/\(record.name)")
        let stem = ClientAPI.stem(of: record.name)
        let source = package.appendingPathComponent("Sources/\(record.name)")
        for (path, text) in [("\(stem)Client.swift", "public final class \(stem)Client {}\n"),
                             ("Transport/HTTPTransport.swift", "public protocol HTTPTransport {}\n"),
                             ("Auth/MemoryTokenStore.swift", "public final class MemoryTokenStore {}\n"),
                             ("Coding/\(stem)Coding.swift", "public enum \(stem)Coding {}\n")] {
            let url = source.appendingPathComponent(path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try text.write(to: url, atomically: true, encoding: .utf8)
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(record).write(to: package.appendingPathComponent("api.json"))
        return package
    }

    /// The world of `record`, made by word lists.
    static func world(_ record: APIRecord, counts: [String: Int] = [:], seed: Int = 7) async throws -> (Shape, World, Renderer) {
        let shape = Shape(try ClientAPI.resolve(record))
        let theme = Theme("a cozy recipe-sharing community", package: shape.api.stem)
        var builder = WorldBuilder(shape: shape, theme: theme, seed: seed, anchor: Date(timeIntervalSince1970: 1_790_000_000), counts: counts)
        var writer = WordWriter(theme: theme, seed: seed)
        let world = try await builder.build(&writer, note: { _ in })
        return (shape, world, Renderer(shape: shape, world: world, token: "token"))
    }
}
