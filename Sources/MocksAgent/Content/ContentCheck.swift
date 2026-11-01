//  WHAT: A model's answer checked against the entity lines before a word of it lands: every field asked for, each of
//        its type, a choice one of its cases, a handle unique and a handle, a title not given twice, a group one of
//        the groups, nothing a placeholder; a thread's replies each answering the record or an earlier reply, with
//        the depth asked for. What fails is said in a sentence the model can act on.

import Foundation

enum ContentCheck {
    /// The records of an answer that pass, each by field name (the group under `"_group"`), and a sentence for each
    /// that does not.
    static func records(_ data: Data, ask: RecordAsk, count: Int, taken: Set<String>) -> (good: [[String: JSONValue]], problems: [String]) {
        guard let answer = JSONValue.parse(data) else { return ([], ["the answer was not the JSON object asked for"]) }
        let items = list(in: answer, key: ask.plural)
        guard !items.isEmpty else { return ([], ["the answer held no list under \"\(ask.plural)\""]) }
        var good: [[String: JSONValue]] = [], problems: [String] = []
        var seen = taken
        let groupKey = ContentPrompt.groupKey(ask)
        for (number, item) in items.prefix(count).enumerated() {
            guard case .object = item else { problems.append("\(number + 1): it is not an object"); continue }
            var record: [String: JSONValue] = [:], wrong: [String] = []
            for field in ask.fields {
                let value = member(item, field.name)
                switch check(value, field) {
                case .success(let checked): record[field.name] = checked
                case .failure(let failure): wrong.append(failure.reason)
                }
            }
            if !ask.groups.isEmpty {
                let said = member(item, groupKey) ?? member(item, "group")
                if let text = said?.text, let group = ask.groups.first(where: { $0.handle.caseInsensitiveCompare(text) == .orderedSame || $0.title.caseInsensitiveCompare(text) == .orderedSame }) {
                    record["_group"] = .string(group.handle)
                } else {
                    wrong.append("`\(groupKey)` \(said?.compact ?? "is missing"), which is not one of the \(SwiftName.plural(ask.groupNoun))")
                }
            }
            // A handle or a title is said once.
            for field in ask.fields where field.role == .handle || field.role == .title {
                guard case .string(let text)? = record[field.name] else { continue }
                if seen.contains(text.lowercased()) { wrong.append("`\(field.name)` \"\(text)\" is already taken") }
            }
            if wrong.isEmpty {
                for field in ask.fields where field.role == .handle || field.role == .title {
                    if case .string(let text)? = record[field.name] { seen.insert(text.lowercased()) }
                }
                good.append(record)
            } else {
                problems.append("\(number + 1): " + wrong.joined(separator: "; "))
            }
        }
        if items.count < count { problems.append("\(count - items.count) of the \(count) asked for were missing") }
        return (good, problems)
    }

    /// One field's value, checked and made exact: a choice in its case, a number from a string of digits, a handle in
    /// lowercase.
    static func check(_ value: JSONValue?, _ field: AskField) -> Result<JSONValue, Failure> {
        let name = "`\(field.name)`"
        guard let value, !value.isNull else {
            return field.optional ? .success(.null) : .failure(Failure("\(name) is missing"))
        }
        switch field.kind {
        case .string:
            guard case .string(let raw) = value else { return .failure(Failure("\(name) is not text")) }
            let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if text.isEmpty { return field.optional ? .success(.null) : .failure(Failure("\(name) is empty")) }
            if let placeholder = placeholder(text) { return .failure(Failure("\(name) reads as a placeholder (\(placeholder)); write what a person would")) }
            switch field.role {
            case .handle:
                let handle = text.lowercased().replacingOccurrences(of: " ", with: "_").trimmingCharacters(in: CharacterSet(charactersIn: "@"))
                guard handle.range(of: #"^[a-z0-9_.]{2,30}$"#, options: .regularExpression) != nil else {
                    return .failure(Failure("\(name) \"\(text)\" is not a handle: lowercase letters, digits and underscores"))
                }
                return .success(.string(handle))
            case .title, .displayName:
                if text.count > 200 { return .failure(Failure("\(name) is \(text.count) characters; keep it under 120")) }
            default:
                if text.count > 4_000 { return .failure(Failure("\(name) is \(text.count) characters; keep it under 1,500")) }
            }
            return .success(.string(text))
        case .integer:
            switch value {
            case .int: return .success(value)
            case .double(let number) where number == number.rounded(): return .success(.int(Int(number)))
            case .string(let text) where Int(text.trimmingCharacters(in: .whitespaces)) != nil: return .success(.int(Int(text.trimmingCharacters(in: .whitespaces))!))
            default: return .failure(Failure("\(name) is not a whole number"))
            }
        case .number:
            switch value {
            case .int(let number): return .success(.double(Double(number)))
            case .double: return .success(value)
            case .string(let text) where Double(text.trimmingCharacters(in: .whitespaces)) != nil: return .success(.double(Double(text.trimmingCharacters(in: .whitespaces))!))
            default: return .failure(Failure("\(name) is not a number"))
            }
        case .choice(let values):
            guard let text = value.text, let match = values.first(where: { SwiftName.normalized($0) == SwiftName.normalized(text) }) else {
                return .failure(Failure("\(name) \(value.compact) is not one of \(values.joined(separator: ", "))"))
            }
            return .success(.string(match))
        case .strings:
            if case .array(let items) = value {
                let texts = items.compactMap { item -> JSONValue? in
                    guard case .string(let text) = item, !text.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
                    return .string(text.trimmingCharacters(in: .whitespaces))
                }
                return .success(.array(texts))
            }
            if case .string(let text) = value {
                return .success(.array(text.split(separator: ",").map { .string($0.trimmingCharacters(in: .whitespaces)) }.filter { $0 != .string("") }))
            }
            return .failure(Failure("\(name) is not a list of strings"))
        }
    }

    struct Failure: Error, Equatable {
        var reason: String
        init(_ reason: String) { self.reason = reason }
    }

    /// The threads of an answer, by parent number: each a list of replies, or why it cannot be used.
    static func threads(_ data: Data, ask: ThreadAsk, parents: [ThreadAsk.Parent]) -> [Int: Result<[ThreadLine], Failure>] {
        var out: [Int: Result<[ThreadLine], Failure>] = [:]
        guard let answer = JSONValue.parse(data) else {
            for parent in parents { out[parent.number] = .failure(Failure("\(parent.number): the answer was not the JSON object asked for")) }
            return out
        }
        let threads = list(in: answer, key: "threads")
        let parentKey = ContentPrompt.parentKey(ask), repliesKey = ContentPrompt.repliesKey(ask)
        for (position, parent) in parents.enumerated() {
            let thread = threads.first { member($0, parentKey)?.text == String(parent.number) || member($0, "number")?.text == String(parent.number) }
                ?? (position < threads.count && member(threads[position], parentKey) == nil ? threads[position] : nil)
            guard let thread else { out[parent.number] = .failure(Failure("\(parent.number): its thread is missing")); continue }
            let replies = list(in: thread, key: repliesKey)
            out[parent.number] = lines(replies, parent: parent, threaded: ask.threaded)
        }
        return out
    }

    private static func lines(_ replies: [JSONValue], parent: ThreadAsk.Parent, threaded: Bool) -> Result<[ThreadLine], Failure> {
        let number = parent.number
        guard replies.count >= parent.count else {
            return .failure(Failure("\(number): it has \(replies.count) replies, and \(parent.count) were asked for"))
        }
        var ids: [String: Int] = [:], lines: [ThreadLine] = [], seen: Set<String> = []
        for (index, reply) in replies.prefix(parent.count).enumerated() {
            guard let text = (member(reply, "text") ?? member(reply, "content") ?? member(reply, "body"))?.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !text.isEmpty else { return .failure(Failure("\(number): reply \(index + 1) says nothing")) }
            if let placeholder = placeholder(text) { return .failure(Failure("\(number): reply \(index + 1) reads as a placeholder (\(placeholder))")) }
            if !seen.insert(text.lowercased()).inserted { return .failure(Failure("\(number): two replies say the same thing")) }
            var replyTo: Int?
            if threaded, let target = member(reply, "replyTo") ?? member(reply, "reply_to"), !target.isNull {
                guard let key = target.text, let earlier = ids[key] else {
                    return .failure(Failure("\(number): reply \(index + 1) answers \(target.compact), which is not an earlier reply's id"))
                }
                replyTo = earlier
            }
            ids[member(reply, "id")?.text ?? String(index + 1)] = index
            lines.append(ThreadLine(replyTo: replyTo, text: text))
        }
        if threaded, parent.count >= 4 {
            let deep = lines.contains { line in line.replyTo.map { lines[$0].replyTo != nil } ?? false }
            if !deep { return .failure(Failure("\(number): no reply answers a reply to a reply; give the thread depth")) }
        }
        return .success(lines)
    }

    /// What a text that reads as a placeholder reads as; nil when it reads as a person's.
    static func placeholder(_ text: String) -> String? {
        let lower = text.lowercased()
        for word in ["lorem ipsum", "sample", "placeholder", "dummy", "test post", "example post", "user 1", "post 1", "foo bar", "asdf"]
            where lower.contains(word) {
            return "\"\(word)\""
        }
        if ["string", "text", "title", "name", "n/a", "tbd", "todo", "null", "none", "..."].contains(lower) { return "\"\(lower)\"" }
        return nil
    }

    /// The list under `key` in an answer, or the answer's only list, or the answer when it is one.
    static func list(in answer: JSONValue, key: String) -> [JSONValue] {
        if case .array(let items) = answer { return items }
        if case .array(let items)? = member(answer, key) { return items }
        if case .object(let members) = answer {
            for member in members { if case .array(let items) = member.value { return items } }
        }
        return []
    }

    /// The value of `name` in an object, its key as written, in snake_case, or in any case.
    static func member(_ value: JSONValue, _ name: String) -> JSONValue? {
        guard case .object(let members) = value else { return nil }
        if let exact = members.first(where: { $0.key == name }) { return exact.value }
        let normalized = SwiftName.normalized(name)
        return members.first { SwiftName.normalized($0.key) == normalized }?.value
    }
}
