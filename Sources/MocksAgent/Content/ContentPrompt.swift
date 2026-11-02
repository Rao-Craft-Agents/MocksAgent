//  WHAT: What the model is told: how a believable record reads, an example from another app to copy the shape of,
//        then the records of one batch (the fields, the groups they may be posted in, what is taken) or the threads
//        under a few records, and, when asking again, what was wrong.
//  PIN:  THE EXAMPLE IS ANOTHER APP'S. A local model copies the example it is shown; a recipe app's for most themes,
//        a running club's when the theme is about food, and never the app's own words.
//  PIN:  THE SCHEMA RIDES BEHIND. It is pasted as a reference; the last thing the model reads is the ask itself.

import Foundation

enum ContentPrompt {
    static let rules = """
    How the records read:
    - Real people wrote them, in the app's own voice: specific details (a dish, a place, a number, a time of day), varied lengths, some short and casual, some longer and careful. Each one different from the others: different openings, different topics.
    - Never "Sample", "Lorem ipsum", "Test", "Example", "User 1", "Post 2" or a placeholder of any kind, and never a word about the content being mock or generated.
    - A handle is lowercase letters, digits and underscores, 3 to 20 characters, never one already taken. A name is a person's name or a nickname.
    - Where a field says Markdown: short paragraphs, sometimes a list, **bold**, or a [link](https://example.com/...) to example.com, never to a real site.
    - A field that may be null is null now and then, as it would be.
    - A choice is one of the values listed, written exactly as listed.
    """

    static func recordsSystem(_ theme: Theme) -> String {
        let example = theme.domain == .food ? runningExample : recipeExample
        return """
        You write the content of an app's mock backend: the records its screens, previews and tests show, so the app looks like a real place with real people in it. You answer with one JSON object holding a list of exactly the records asked for, each with every field asked for, and nothing else.

        \(rules)

        An example from \(example.app): three of its members, each with a handle, a name and a bio, answered as {"members": [...]}:
        \(example.records)
        """
    }

    static func threadsSystem(_ theme: Theme, ask: ThreadAsk) -> String {
        let example = theme.domain == .food ? runningExample : recipeExample
        let answers = ask.threaded ? "what it is said to answer, the record or an earlier reply by its number" : "the record"
        return """
        You write the replies under a few records of an app's mock backend, so each thread reads like a real conversation in the app's own voice. You answer with one JSON object, {"threads": [...]}: one thread for each record asked about, each with exactly the replies asked for, in order.

        How a thread reads:
        - Each reply answers \(answers): a question gets an answer, the one who posted thanks someone, two people politely disagree, someone adds a tip.
        - Short ones ("Saving this for Sunday.") beside longer ones; never the same opening twice, never "Great post!".
        - Never "Sample", "Lorem ipsum", "Test", a placeholder, or a word about the content being mock or generated.

        An example from \(example.app), the replies under one of its posts (\(example.shape)), answered as {"threads": [{"post": 1, "replies": [...]}]}:
        \(example.thread)
        """
    }

    private static let recipeExample = (app: "a recipe app",
        records: #"{"members": [{"handle": "saltandsimmer", "name": "Ines Moreau", "bio": "Cooking my way through my grandmother's notebook."}, {"handle": "pho_kevin", "name": "Kevin Tran", "bio": null}, {"handle": "doughdaily", "name": "Ruth Achterberg", "bio": "Bread most days. Cake when it's earned."}]}"#,
        shape: "1 answers the post, 2 answers 1, 3 answers 2, 4 answers the post",
        thread: #"{"threads": [{"post": 1, "replies": [{"id": 1, "text": "Did you salt the eggplant first? Mine always goes soggy."}, {"id": 2, "text": "Twenty minutes in a colander with a good pinch of salt, then pat it dry. Makes all the difference."}, {"id": 3, "text": "Trying that tonight, thank you!"}, {"id": 4, "text": "Saving this for Sunday."}]}]}"#)

    private static let runningExample = (app: "a trail-running club's app",
        records: #"{"members": [{"handle": "ridgeline_rae", "name": "Rae Lindqvist", "bio": "Slow miles, long views."}, {"handle": "mudandmiles", "name": "Omar Haddad", "bio": null}, {"handle": "kestrel_runs", "name": "Hana Sato", "bio": "Training for my first fifty. Send snacks."}]}"#,
        shape: "1 answers the post, 2 answers 1, 3 answers 2, 4 answers the post",
        thread: #"{"threads": [{"post": 1, "replies": [{"id": 1, "text": "Was the creek crossing passable after Thursday's rain?"}, {"id": 2, "text": "Knee deep at the second ford, but the rope is still up."}, {"id": 3, "text": "Good to know, I'll bring dry socks."}, {"id": 4, "text": "That view from the saddle never gets old."}]}]}"#)

    // MARK: - Records

    /// What a record people discuss can be, one a record in turn, so a batch reads like a feed rather than one post
    /// written six times. About people and what they do, never about a topic, so it fits any app.
    static let angles = [
        "showing something they made or did, and how it went",
        "a question for the others",
        "a tip or a shortcut they swear by",
        "something that went wrong, and what they learned",
        "asking for a recommendation",
        "a first time, or a small milestone",
        "comparing two ways of doing something",
        "sharing something they found: a link, a book, a place",
        "a plan for the week, asking for ideas",
        "an opinion others may disagree with",
        "thanking someone here for their advice",
        "a short, casual note about their day",
    ]

    static func recordsUser(_ ask: RecordAsk, theme: Theme, count: Int, problems: [String]) -> String {
        var parts: [String] = []
        parts.append("The app: \(theme.text).")
        let about = ask.about.map { " (\($0))" } ?? ""
        parts.append(problems.isEmpty ? "Write \(count) \(SwiftName.words(ask.plural))\(about)."
                                      : "Some \(SwiftName.words(ask.plural)) came back wrong. Write \(count) \(SwiftName.words(ask.plural))\(about) again.")
        var fields = ask.fields.map { "- \($0.name): \($0.note)" + ($0.optional ? " (may be null)" : "") }
        if !ask.groups.isEmpty { fields.append("- \(groupKey(ask)): the \(ask.groupNoun) it is posted in, by its short name: one of \(ask.groups.map(\.handle).joined(separator: ", "))") }
        parts.append("Each one has these fields:\n" + fields.joined(separator: "\n"))
        if !ask.groups.isEmpty {
            parts.append("The \(SwiftName.plural(ask.groupNoun)): " + ask.groups.map { "\($0.handle) (\"\($0.title)\")" }.joined(separator: ", ")
                         + ". Put each one where it belongs, and spread them over several.")
        }
        if !ask.angles.isEmpty {
            parts.append("What each one is, in order:\n" + ask.angles.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n"))
        }
        if ask.part == .content, ask.fields.contains(where: { $0.role == .title }) {
            let group = ask.groups.isEmpty ? "" : "never the \(ask.groupNoun)'s name, "
            parts.append("A title is what its writer typed for that one \(SwiftName.words(ask.type).lowercased()) alone: \(group)never numbered like a series, never \"Again\" or \"Part 2\".")
        }
        // Only handles: a model shown the titles already taken writes variations of them.
        if !ask.handles.isEmpty { parts.append("Handles already taken, never use again: " + ask.handles.suffix(80).joined(separator: ", ")) }
        if !problems.isEmpty { parts.append("What was wrong:\n" + problems.map { "- \($0)" }.joined(separator: "\n")) }
        parts.append("Answer {\"\(ask.plural)\": [...]} with \(count) of them.")
        return parts.joined(separator: "\n\n")
    }

    /// The key a record's group is answered under: `community`.
    static func groupKey(_ ask: RecordAsk) -> String {
        SwiftName.lowerCamel(SwiftName.upperCamel(ask.groupNoun.replacingOccurrences(of: " ", with: "_")))
    }

    static func recordsSchema(_ ask: RecordAsk, count: Int) -> Data {
        var properties: [String: Any] = [:]
        var required: [String] = []
        for field in ask.fields {
            var schema: [String: Any]
            switch field.kind {
            case .string: schema = ["type": field.optional ? ["string", "null"] : "string"]
            case .integer: schema = ["type": field.optional ? ["integer", "null"] : "integer"]
            case .number: schema = ["type": field.optional ? ["number", "null"] : "number"]
            case .choice(let values): schema = ["type": "string", "enum": values]
            case .strings: schema = ["type": "array", "items": ["type": "string"]]
            }
            schema["description"] = field.note
            properties[field.name] = schema
            required.append(field.name)
        }
        if !ask.groups.isEmpty {
            properties[groupKey(ask)] = ["type": "string", "enum": ask.groups.map(\.handle)]
            required.append(groupKey(ask))
        }
        let item: [String: Any] = ["type": "object", "required": required, "properties": properties]
        let list: [String: Any] = ["type": "array", "minItems": count, "maxItems": count, "items": item]
        let answer: [String: Any] = ["type": "object", "required": [ask.plural], "properties": [ask.plural: list]]
        return (try? JSONSerialization.data(withJSONObject: answer, options: [.sortedKeys])) ?? Data("{}".utf8)
    }

    // MARK: - Threads

    static func threadsUser(_ ask: ThreadAsk, theme: Theme, parents: [ThreadAsk.Parent], problems: [String]) -> String {
        let replies = repliesKey(ask), parentKey = parentKey(ask)
        var parts = ["The app: \(theme.text).",
                     problems.isEmpty ? "Write the \(SwiftName.plural(ask.noun)) under these \(SwiftName.plural(ask.parentNoun)):"
                                      : "Some threads came back wrong. Write the \(SwiftName.plural(ask.noun)) under these \(SwiftName.plural(ask.parentNoun)) again:"]
        for parent in parents {
            var line = "\(parent.number). \"\(parent.title)\" by \(parent.author)"
            if let body = parent.body, !body.isEmpty { line += ": " + body.replacingOccurrences(of: "\n", with: " ") }
            line += "\n   \(parent.count) \(parent.count == 1 ? ask.noun : SwiftName.plural(ask.noun))"
            if parent.shape.contains(where: { $0 != nil }) { line += "\n   " + answers(parent.shape, record: ask.parentNoun) }
            parts.append(line)
        }
        if !problems.isEmpty { parts.append("What was wrong:\n" + problems.map { "- \($0)" }.joined(separator: "\n")) }
        let numbers = parents.map { String($0.number) }.joined(separator: ", ")
        parts.append("Answer {\"threads\": [{\"\(parentKey)\": <number>, \"\(replies)\": [{\"id\": 1, \"text\": \"...\"}, ...]}, ...]}, one thread for each of \(numbers).")
        return parts.joined(separator: "\n\n")
    }

    /// Who answers whom, as the model is told it: "1 answers the post, 2 answers 1, 3 answers the post".
    static func answers(_ shape: [Int?], record: String) -> String {
        shape.enumerated().map { index, answered in
            "\(index + 1) answers " + (answered.map { String($0 + 1) } ?? "the \(record)")
        }.joined(separator: ", ")
    }

    static func repliesKey(_ ask: ThreadAsk) -> String { SwiftName.plural(SwiftName.lowerCamel(SwiftName.upperCamel(ask.noun.replacingOccurrences(of: " ", with: "_")))) }
    static func parentKey(_ ask: ThreadAsk) -> String { SwiftName.lowerCamel(SwiftName.upperCamel(ask.parentNoun.replacingOccurrences(of: " ", with: "_"))) }

    static func threadsSchema(_ ask: ThreadAsk) -> Data {
        let reply: [String: Any] = ["type": "object", "required": ["id", "text"],
                                    "properties": ["id": ["type": "integer"], "text": ["type": "string"]]]
        let thread: [String: Any] = ["type": "object", "required": [parentKey(ask), repliesKey(ask)],
                                     "properties": [parentKey(ask): ["type": "integer"], repliesKey(ask): ["type": "array", "items": reply]]]
        let answer: [String: Any] = ["type": "object", "required": ["threads"], "properties": ["threads": ["type": "array", "items": thread]]]
        return (try? JSONSerialization.data(withJSONObject: answer, options: [.sortedKeys])) ?? Data("{}".utf8)
    }
}
