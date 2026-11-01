//  WHAT: The replies under a few records the content writer is asked for: who answers whom, and what they say.

import Foundation

/// The replies under a few records.
struct ThreadAsk: Sendable {
    struct Parent: Sendable, Equatable {
        /// Its number in the ask: what the answer names it by.
        var number: Int
        var title: String
        var body: String?
        var author: String
        /// How many replies it gets.
        var count: Int
    }

    var parents: [Parent]
    /// The field a reply's text is.
    var field: AskField
    /// Whether replies answer each other, or only the record.
    var threaded: Bool
    /// What a reply and its record are called: `comment`, `post`.
    var noun: String
    var parentNoun: String
}
