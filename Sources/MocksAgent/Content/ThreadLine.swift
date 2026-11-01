//  WHAT: One reply as the content writer answers it.

import Foundation

/// One reply: the earlier reply it answers (its place in the thread, from 0), and what it says.
struct ThreadLine: Sendable, Equatable {
    var replyTo: Int?
    var text: String
}
