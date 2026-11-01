//  WHAT: What the app is and how it sounds, as a call says it ("a cozy recipe-sharing community"), and the kind of
//        place it reads as: what the word lists write from when no model is offered, which pictures its posts show,
//        and which app the model's example comes from.

import Foundation

struct Theme: Sendable, Equatable {
    /// The kinds of place word lists can write for.
    enum Domain: String, Sendable, CaseIterable {
        case food, outdoors, tech, books, general
    }

    /// The call's words, or what was made of the package's name when it gave none.
    var text: String
    var domain: Domain

    init(_ text: String?, package: String) {
        let given = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        self.text = given.isEmpty ? "an online community, \(package)'s app: people posting, sharing links and pictures, and talking it over" : given
        let words = self.text.lowercased()
        func has(_ list: [String]) -> Bool { list.contains { words.contains($0) } }
        if has(["recipe", "food", "cook", "bak", "kitchen", "meal", "dinner", "restaurant", "coffee", "tea", "wine", "pantry", "chef", "ferment", "bread"]) {
            domain = .food
        } else if has(["hike", "hiking", "trail", "outdoor", "camp", "travel", "trip", "climb", "run", "cycl", "bike", "garden", "nature", "bird", "photo"]) {
            domain = .outdoors
        } else if has(["code", "coding", "dev", "program", "software", "swift", "tech", "computer", "linux", "open source", "engineer", "app"]) {
            domain = .tech
        } else if has(["book", "read", "novel", "librar", "poetry", "writing", "writer", "literature"]) {
            domain = .books
        } else {
            domain = .general
        }
    }

    /// The pictures a post shows: food for a kitchen, places otherwise.
    var thingPictures: String { domain == .food ? "food" : "place" }
}
