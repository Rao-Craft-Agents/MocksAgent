//  WHAT: What a picture field shows, so the right one of the drawn pictures is named for it.

import Foundation

/// What a picture shows.
enum ImageSubject: String, Equatable, Sendable {
    /// A face: an avatar.
    case person
    /// A thing: a post's thumbnail, a community's icon.
    case thing
    /// A wide view: a banner, a header.
    case wide
}
