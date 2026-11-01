//  WHAT: One field a record's content fills, as the content writer is asked for it.

import Foundation

/// One field a record's content fills: its name, what it is, and what the model is told about it.
struct AskField: Sendable, Equatable {
    enum Kind: Sendable, Equatable {
        case string
        case integer
        case number
        /// One of these values, as the API writes it.
        case choice([String])
        /// A list of short strings.
        case strings
    }

    /// The Swift name: the key the answer gives it under.
    var name: String
    var kind: Kind
    var optional: Bool
    var role: FieldRole
    /// What it is, in a few words: "the post's title, 20 to 90 characters".
    var note: String
}
