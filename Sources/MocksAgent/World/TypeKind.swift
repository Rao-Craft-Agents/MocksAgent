//  WHAT: What one of an API's types is to the mock backend.

import Foundation

enum TypeKind: Equatable, Sendable {
    /// String, Int, Date, URL and the other values a field holds as they are.
    case primitive
    /// A struct with an `id`: the world holds many of it.
    case record
    /// A struct without an `id` that holds records: put together from the world (`PostView`, `GetPostsResponse`).
    case view
    /// A struct without an `id` that holds values only: made from what it sits in (`PostAggregates`, `Session`).
    case value
    /// An enum whose cases carry nothing.
    case choice
    /// An enum whose cases carry values.
    case carrier
    /// A name no line declares.
    case unknown
}
