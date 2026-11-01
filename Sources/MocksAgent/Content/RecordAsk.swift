//  WHAT: A batch of one type's records the content writer is asked for: what each says, by field.

import Foundation

/// A batch of one type's records.
struct RecordAsk: Sendable {
    /// What part the type plays, so word lists know what to write.
    enum Part: Sendable { case person, group, content, other }

    var type: String
    /// The key the answer's list is under: `posts`.
    var plural: String
    /// The entity line's doc.
    var about: String?
    var fields: [AskField]
    var count: Int
    var part: Part
    /// The groups a record is posted in, by handle, with their titles; empty when the type is in none.
    var groups: [(handle: String, title: String)] = []
    /// What a group is called: `community`.
    var groupNoun = "group"
    /// Handles and titles earlier batches took.
    var taken: [String] = []
    /// Where in the batches this is: the first record's number.
    var start = 0
}
