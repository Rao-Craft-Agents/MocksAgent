//  WHAT: How one endpoint of the mock backend answers, as the agent planned it: a fixture as it is, a list cut into
//        pages, an item found by a value of the request, a body echoed into what it made, bytes, or nothing. What the
//        package's `<Client>+Mock.swift` says, in the agent's terms, with the fixtures it needs.

import Foundation

enum RoutePlan: Sendable {
    case nothing
    /// A picture's bytes.
    case picture
    /// Text, as it is.
    case text(String)
    case fixture(JSONValue, type: TypeRef)
    case list(List)
    case lookup(Lookup)
    case echo(Echo)

    struct List: Sendable {
        var pages: [JSONValue]
        /// The answer's type, and the type of one item.
        var type: TypeRef
        var item: TypeRef
        var itemsKey: String?
        var paging: Paging
        var limit: String?
        var size: Int
        /// Query parameters that narrow the list, with the path of the value each must equal, and a value that
        /// narrows it to some of its items (for the package's tests).
        var filters: [Filter]
        var search: [String]
        var sort: Sort?
        var totals: [String]
        /// How many items all the pages hold.
        var count: Int {
            pages.reduce(0) { total, page in
                let list = itemsKey.flatMap { page[$0] } ?? page
                if case .array(let items) = list { return total + items.count }
                return total
            }
        }
    }

    struct Filter: Sendable {
        var parameter: String
        var path: [String]
        /// A value some items hold at `path`, and how many do.
        var sample: JSONValue?
        var matches: Int
    }

    enum Paging: Sendable, Equatable {
        case none
        case page(String)
        case cursor(String, id: [String], next: String?)
    }

    struct Sort: Sendable {
        var parameter: String
        /// A value of the parameter, the path it orders by, and whether the most comes first.
        var orders: [(value: String, path: [String], descending: Bool)]
    }

    struct Lookup: Sendable {
        var key: Key
        var items: Items
        var match: [String]
        /// The response the item goes into (nil: the item is the response), its type, and where the item goes.
        var response: JSONValue?
        var type: TypeRef
        var place: [String]
        var related: [Related]
        /// A value that finds an item, for the package's tests.
        var sample: JSONValue
    }

    enum Key: Sendable, Equatable {
        case path(String)
        case query(String)
        case body(String)
    }

    enum Items: Sendable {
        /// Another route's list (its method and path), or the value at `at` in each of its items.
        case route(String, String, at: [String]?)
        /// Items of its own, and their type.
        case own([JSONValue], type: TypeRef)
    }

    struct Related: Sendable {
        var place: [String]
        var items: Items
        var match: [String]
        var to: [String]
        var limit: Int?
    }

    struct Echo: Sendable {
        var response: JSONValue
        var type: TypeRef
        var place: [String]
        var id: String?
        var dates: [String]
        var joins: [Join]
    }

    struct Join: Sendable {
        var body: String
        var items: Items
        var match: [String]
        var place: [String]
    }
}
