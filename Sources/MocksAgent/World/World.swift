//  WHAT: The believable data the fixtures are cut from: every record of every type the API answers, each with its
//        id, what it says, who made it, where, when, how much it is loved, and what it answers; made to agree, so a
//        comment's post id names a post and a post's comment count is its comments.

import Foundation

struct World: Sendable {
    /// One record: its id, what its fields hold, and how it stands to the others.
    struct Record: Sendable {
        var type: String
        var index: Int
        var id: JSONValue = .null
        /// What its fields hold, by Swift name, as JSON. Counts are left out: they are counted when it is shown.
        var values: [String: JSONValue] = [:]
        /// The records it holds in place, by field: indices into the field type's records.
        var holds: [String: [Int]] = [:]
        var date: Date
        /// How much it is liked, from 0 to 1: its votes, its replies, its followers.
        var popularity: Double
        /// The person who made it.
        var author: Int?
        /// The group it is in.
        var group: Int?
        /// The record it belongs to: a comment's post, an attachment's status.
        var owner: Int?
        /// The record of its own type it answers, and how deep that puts it.
        var parent: Int?
        var depth = 0
        /// Its handle, and what a prompt calls it.
        var handle: String?
        var title: String?
        /// The picture it shows, when it shows one, and whether it links elsewhere.
        var picture: String?
        var link = false
        /// Its votes up and down.
        var upvotes = 0
        var downvotes = 0
    }

    var records: [String: [Record]] = [:]
    /// The person signed in: who the mock's new posts are by, and whose account `me` answers.
    var me = 0
    /// When the world was made: every date is before it.
    let anchor: Date
    /// The host the API's own links point to (`lemmy.example`).
    let host: String

    init(anchor: Date, host: String) {
        self.anchor = anchor
        self.host = host
    }

    func all(_ type: String) -> [Record] { records[type] ?? [] }

    func record(_ type: String, _ index: Int) -> Record? {
        guard let list = records[type], index >= 0, index < list.count else { return nil }
        return list[index]
    }

    /// How many records of `type` there are.
    func count(_ type: String) -> Int { records[type]?.count ?? 0 }

    /// The index of the record of `type` whose id or handle is `text`.
    func find(_ type: String, _ text: String) -> Int? {
        all(type).firstIndex { $0.id.text == text || $0.handle == text }
    }
}
