//  WHAT: One endpoint as the client `network` wrote calls it: its Swift name, its arguments by wire and Swift name,
//        what it sends and answers, how it pages, and where its token is. Read the way `network` resolves a line,
//        so the mock answers the method the client has.

import Foundation

struct ClientMethod: Sendable {
    /// A path or query parameter, as the method takes it.
    struct Argument: Sendable, Equatable {
        /// The name on the wire (`community_id`).
        var wire: String
        /// The name in Swift (`communityID`).
        var name: String
        var type: TypeRef
        var required: Bool
    }

    /// What the method answers.
    enum Answer: Sendable, Equatable {
        case nothing
        case json(TypeRef)
        case data
        case text
    }

    /// Where the marker of the page after this one comes from.
    enum Next: Sendable, Equatable {
        /// The page number, one up.
        case number
        /// A field of the response (`nextPage`), a String or an Int.
        case field(String, TypeRef)
        /// The `Link` header's `rel="next"` URL.
        case link
    }

    struct Paging: Sendable, Equatable {
        /// The type of one item.
        var item: TypeRef
        /// The response field that holds the items, by its Swift name; nil when the response is the array.
        var itemsField: String?
        /// The query argument the page or cursor goes in.
        var marker: Argument
        var next: Next
        /// The `limit` argument, if the endpoint takes one.
        var limit: Argument?
    }

    var endpoint: Endpoint
    var name: String
    var path: [Argument]
    var query: [Argument]
    var body: TypeRef?
    /// Whether the body is a multipart form.
    var multipart: Bool
    var answer: Answer
    var paging: Paging?
    /// The response field a `stores token` endpoint keeps the token from; `""` when the response is the token.
    var tokenField: String?

    /// `posts`, `post` → `Posts`, `Post`: the name a fixture of the method is filed under.
    var typeName: String { name.prefix(1).uppercased() + name.dropFirst() }
}
