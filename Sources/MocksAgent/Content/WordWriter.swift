//  WHAT: The content writer when no model is offered: what each record says, from the word lists of the theme's kind
//        of place, picked by the seed. Varied, never "Sample"; a call's notes say a model writes better.

import Foundation

struct WordWriter: ContentWriter {
    let theme: Theme
    var random: Seeded
    private var used: Set<String> = []
    private var titleCursor = 0
    private var nameCursor = 0
    private var groupCursor = 0

    var asks: Int { 0 }
    var retries: Int { 0 }
    var notes: [String] { [] }

    init(theme: Theme, seed: Int) {
        self.theme = theme
        self.random = Seeded(seed &+ 101)
    }

    mutating func records(_ ask: RecordAsk) async throws -> [[String: JSONValue]] {
        for taken in ask.taken { used.insert(taken.lowercased()) }
        let place = WordLists.place(theme.domain)
        var out: [[String: JSONValue]] = []
        for _ in 0..<ask.count {
            var item: [String: JSONValue] = [:]
            var person: (first: String, last: String)?
            var group: (handle: String, title: String, about: String)?
            switch ask.part {
            case .person: person = nextPerson()
            case .group: group = nextGroup(place)
            case .content, .other: break
            }
            let title = ask.part == .content || ask.part == .other ? nextTitle(place) : nil
            for field in ask.fields {
                let value: JSONValue
                switch (field.role, field.kind) {
                case (.handle, _):
                    if let person { value = .string(handle(for: person)) }
                    else if let group { value = .string(unique(group.handle)) }
                    else { value = .string(unique(Self.slug(title ?? place.groups[0].handle))) }
                case (.displayName, _):
                    value = person.map { .string("\($0.first) \($0.last)") } ?? .string(title ?? "Neighbour")
                case (.title, _):
                    value = .string(group?.title ?? title ?? person.map { "\($0.first) \($0.last)" } ?? random.pick(place.titles))
                case (.body(let format), _):
                    value = field.optional && random.chance(0.2) ? .null : .string(body(place, format: format))
                case (.summary, _):
                    if let group { value = .string(group.about) }
                    else if person != nil { value = field.optional && random.chance(0.25) ? .null : .string(random.pick(place.bios)) }
                    else { value = .string(random.pick(place.sentences)) }
                case (_, .choice(let values)):
                    value = .string(values[random.weighted(values.indices.map { $0 == 0 ? 3.0 : 1.0 })])
                case (_, .integer):
                    value = Self.number(field.name, integer: true, index: ask.start + out.count, random: &random)
                case (_, .number):
                    value = Self.number(field.name, integer: false, index: ask.start + out.count, random: &random)
                case (_, .strings):
                    value = .array(random.shuffled(place.groups.map(\.handle)).prefix(random.int(1...3)).map { .string($0) })
                case (_, .string):
                    value = .string(group?.title ?? title ?? random.pick(place.groups).title)
                }
                item[field.name] = value
            }
            if !ask.groups.isEmpty {
                // A record goes in the group its title is about when the word lists say so; else any.
                item["_group"] = .string(random.pick(ask.groups).handle)
            }
            out.append(item)
        }
        return out
    }

    mutating func threads(_ ask: ThreadAsk) async throws -> [[ThreadLine]] {
        let place = WordLists.place(theme.domain)
        return ask.parents.map { parent in
            var lines: [ThreadLine] = []
            for index in 0..<parent.count {
                let answers = ask.threaded && index > 0 && random.chance(0.55) ? random.int(0...(index - 1)) : nil
                let text = answers == nil ? random.pick(place.replies + place.sentences) : random.pick(place.replies)
                lines.append(ThreadLine(replyTo: answers, text: text))
            }
            return lines
        }
    }

    // MARK: - Words

    private mutating func nextPerson() -> (first: String, last: String) {
        defer { nameCursor += 1 }
        let first = WordLists.firstNames[(nameCursor * 7 + 3) % WordLists.firstNames.count]
        let last = WordLists.lastNames[(nameCursor * 11 + 5) % WordLists.lastNames.count]
        return (first, last)
    }

    private mutating func nextGroup(_ place: WordLists.Place) -> (handle: String, title: String, about: String) {
        defer { groupCursor += 1 }
        let group = place.groups[groupCursor % place.groups.count]
        guard groupCursor >= place.groups.count else { return group }
        let round = groupCursor / place.groups.count + 1
        return ("\(group.handle)\(round)", "\(group.title) \(round)", group.about)
    }

    private mutating func nextTitle(_ place: WordLists.Place) -> String {
        defer { titleCursor += 1 }
        let title = place.titles[(titleCursor * 7) % place.titles.count]
        let round = titleCursor / place.titles.count
        return round == 0 ? title : "\(title) (\(["again", "part two", "an update", "one more time"][round % 4]))"
    }

    private mutating func handle(for person: (first: String, last: String)) -> String {
        let first = person.first.lowercased(), last = person.last.lowercased()
        let candidates = [first, "\(first)_\(last.prefix(3))", "\(first)\(random.pick(WordLists.handleSuffixes))", "\(first).\(last)",
                          "\(first)\(random.int(2...99))"]
        for candidate in candidates where !used.contains(candidate) {
            used.insert(candidate)
            return candidate
        }
        return unique(first)
    }

    private mutating func unique(_ base: String) -> String {
        var candidate = base, number = 2
        while used.contains(candidate.lowercased()) { candidate = "\(base)\(number)"; number += 1 }
        used.insert(candidate.lowercased())
        return candidate
    }

    private mutating func body(_ place: WordLists.Place, format: TextFormat) -> String {
        let sentences = random.shuffled(place.sentences).prefix(random.int(2...3))
        switch format {
        case .plain: return sentences.joined(separator: " ")
        case .html: return sentences.map { "<p>\($0)</p>" }.joined()
        case .markdown:
            var text = sentences.joined(separator: " ")
            if random.chance(0.4) {
                text += "\n\n" + random.shuffled(place.sentences).prefix(2).map { "- \($0)" }.joined(separator: "\n")
            }
            return text
        }
    }

    /// `my-first-loaf` from a title.
    static func slug(_ text: String) -> String {
        let words = text.lowercased().split { !$0.isLetter && !$0.isNumber }
        return words.prefix(5).joined(separator: "-")
    }

    /// A number a field's name suggests: minutes, servings, a price, a rating; `index` for an order.
    static func number(_ name: String, integer: Bool, index: Int, random: inout Seeded) -> JSONValue {
        let word = SwiftName.normalized(name)
        func whole(_ range: ClosedRange<Int>, step: Int = 1) -> JSONValue {
            let value = random.int(range.lowerBound / step...range.upperBound / step) * step
            return integer ? .int(value) : .double(Double(value))
        }
        if ["minutes", "duration", "cooktime", "preptime", "totaltime", "time", "mins", "readingtime"].contains(where: word.contains) { return whole(10...90, step: 5) }
        if ["servings", "serves", "portions", "yield"].contains(where: word.contains) { return whole(2...8) }
        if ["quantity", "qty", "amount"].contains(where: word.contains) { return whole(1...12) }
        if ["price", "cost"].contains(where: word.contains) {
            return integer ? .int(random.int(3...60)) : .double(Double(random.int(300...6000)) / 100)
        }
        if ["rating", "stars"].contains(where: word.contains) {
            return integer ? .int(random.int(3...5)) : .double(Double(random.int(35...50)) / 10)
        }
        if word.contains("year") { return whole(1962...2025) }
        if word.contains("age") { return whole(19...71) }
        if ["order", "position", "index", "step", "sort", "number"].contains(where: word.contains) { return integer ? .int(index + 1) : .double(Double(index + 1)) }
        if word.contains("calorie") { return whole(150...900, step: 10) }
        if ["distance", "km", "miles", "length"].contains(where: word.contains) { return whole(2...40) }
        if ["weight", "grams", "size"].contains(where: word.contains) { return whole(50...1000, step: 10) }
        if word.contains("latitude") || word == "lat" { return .double(Double(random.int(-6000...6000)) / 100) }
        if word.contains("longitude") || word == "lng" || word == "lon" { return .double(Double(random.int(-17000...17000)) / 100) }
        return whole(1...100)
    }
}
