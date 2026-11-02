//  WHAT: The world made: how many records of each type, who the people are, the groups they post in, the content and
//        the replies under it, what each one says (the content writer's: the host's model, or word lists), and all
//        else a record holds: ids that grow with time, dates spread over the last weeks, authors, groups, pictures,
//        votes, threads with depth.
//  PIN:  THE WRITER SAYS, THE BUILDER ARRANGES. What a record says comes from the writer; who wrote it, when, where,
//        and what it answers comes from here, so the fixtures agree with themselves whatever the writer said.

import Foundation

struct WorldBuilder {
    let shape: Shape
    let theme: Theme
    var random: Seeded
    var world: World
    /// How many records of each type, by type.
    var counts: [String: Int]
    /// The record types the API's answers hold.
    let needed: [String]
    var notes: [String] = []

    init(shape: Shape, theme: Theme, seed: Int, anchor: Date, counts: [String: Int]) {
        self.shape = shape
        self.theme = theme
        self.random = Seeded(seed)
        let host = shape.api.baseURL.flatMap { URL(string: $0)?.host } ?? "\(SwiftName.normalized(shape.api.stem)).example"
        self.world = World(anchor: anchor, host: host)
        self.needed = Self.needed(shape)
        var resolved: [String: Int] = [:]
        for type in needed { resolved[type] = Self.defaultCount(type, shape: shape) }
        for (type, count) in counts where resolved[type] != nil { resolved[type] = max(0, min(count, 300)) }
        // Replies follow their records unless the call says how many.
        for (child, owner) in shape.children where counts[child] == nil {
            if let owners = resolved[owner] { resolved[child] = min(owners * 3, 180) }
        }
        self.counts = resolved
    }

    /// The record types any answer holds, and the ones they refer to.
    static func needed(_ shape: Shape) -> [String] {
        var seen: Set<String> = [], stack: [String] = []
        for method in shape.api.methods {
            if case .json(let type) = method.answer { stack += type.names }
        }
        while let name = stack.popLast() {
            guard seen.insert(name).inserted, let entity = shape.entity(name) else { continue }
            stack += entity.fields.flatMap(\.type.names) + entity.cases.flatMap { $0.values.flatMap(\.type.names) }
            for role in (shape.roles[name] ?? [:]).values {
                if case .reference(let target) = role { stack.append(target) }
                if case .references(let target) = role { stack.append(target) }
            }
        }
        return shape.records.filter(seen.contains)
    }

    static func defaultCount(_ type: String, shape: Shape) -> Int {
        if type == shape.person { return 16 }
        if shape.groups.contains(type) { return 8 }
        if shape.contents.contains(type) { return 24 }
        if shape.children[type] != nil { return 72 }
        return 12
    }

    /// The type a `counts` line names: `posts`, `comments`, `people`, `communities`.
    static func type(named word: String, in shape: Shape) -> String? {
        let key = SwiftName.normalized(word)
        if ["people", "persons", "users", "members", "accounts", "authors"].contains(key), let person = shape.person { return person }
        return shape.records.first { record in
            let name = SwiftName.normalized(record)
            return key == name || key == SwiftName.normalized(SwiftName.plural(record)) || key == name + "s"
        }
    }

    // MARK: - Building

    mutating func build<W: ContentWriter>(_ writer: inout W, note: @Sendable (String) -> Void) async throws -> World {
        let order = buildOrder()
        for type in order {
            try Task.checkCancellation()
            let count = counts[type] ?? 0
            guard count > 0 else { world.records[type] = []; continue }
            if let owner = shape.children[type] {
                note("writing \(count) \(SwiftName.plural(SwiftName.words(type))) under \(world.count(owner)) \(SwiftName.plural(SwiftName.words(owner)))")
                try await makeReplies(type, owner: owner, total: count, writer: &writer)
            } else if let holder = shape.owned[type] {
                makeOwned(type, holder: holder)
            } else {
                note("writing \(count) \(SwiftName.plural(SwiftName.words(type)))")
                try await make(type, count: count, writer: &writer)
            }
        }
        for type in order { fill(type) }
        return world
    }

    /// People first, then the groups, the content, the replies, what records own, and the rest.
    func buildOrder() -> [String] {
        var order: [String] = []
        if let person = shape.person, needed.contains(person) { order.append(person) }
        order += needed.filter { shape.groups.contains($0) && !order.contains($0) }
        order += needed.filter { shape.contents.contains($0) && !order.contains($0) }
        order += needed.filter { shape.children[$0] == nil && shape.owned[$0] == nil && !order.contains($0) }
        // Replies after what they answer, owned records after their holders.
        var rest = needed.filter { !order.contains($0) }
        while !rest.isEmpty {
            let ready = rest.filter { type in
                let after = shape.children[type] ?? shape.owned[type]
                return after.map(order.contains) ?? true
            }
            order += ready.isEmpty ? rest : ready
            rest.removeAll { order.contains($0) }
        }
        return order
    }

    func part(_ type: String) -> RecordAsk.Part {
        if type == shape.person { return .person }
        if shape.groups.contains(type) { return .group }
        if shape.contents.contains(type) { return .content }
        return .other
    }

    // MARK: - A type's records

    private mutating func make<W: ContentWriter>(_ type: String, count: Int, writer: inout W) async throws {
        let part = part(type)
        let fields = askFields(type, part: part)
        let groups = part == .content ? groupsFor(type) : []
        var contents: [[String: JSONValue]] = []
        var taken: [String] = [], handles: [String] = []
        let size = part == .person ? 10 : part == .group ? 8 : part == .content ? 6 : 8
        // Content people discuss (posted in a group, or answered) reads like a feed: each record a different angle.
        let discussed = part == .content && (!groups.isEmpty || shape.children.values.contains(type))
        while contents.count < count {
            let wanted = min(size, count - contents.count)
            var ask = RecordAsk(type: type, plural: Self.plural(type, shape: shape), about: shape.entity(type)?.doc, fields: fields,
                                count: wanted, part: part)
            ask.groups = groups
            ask.groupNoun = groups.isEmpty ? "group" : SwiftName.words(groupType(for: type) ?? "group")
            ask.taken = taken
            ask.handles = handles
            ask.start = contents.count
            if discussed {
                ask.angles = (0..<wanted).map { ContentPrompt.angles[(contents.count + $0) % ContentPrompt.angles.count] }
            }
            let answer = fields.isEmpty && groups.isEmpty ? Array(repeating: [:], count: wanted) : try await writer.records(ask)
            let kept = Array(answer.prefix(wanted))
            contents += kept
            for item in kept {
                for field in fields where field.role == .handle || field.role == .title {
                    guard case .string(let text)? = item[field.name] else { continue }
                    taken.append(text)
                    if field.role == .handle { handles.append(text) }
                }
            }
            if kept.isEmpty { break }
        }
        let dates = makeDates(count: contents.count, part: part).sorted()
        var records: [World.Record] = []
        for (index, content) in contents.enumerated() {
            var record = World.Record(type: type, index: index, date: dates[index], popularity: random.popularity())
            record.values = content.filter { !$0.key.hasPrefix("_") }
            record.handle = text(content, role: .handle, of: type)
            record.title = text(content, role: .title, of: type) ?? text(content, role: .displayName, of: type) ?? record.handle
            switch part {
            case .person:
                record.picture = "person-\(index % 6 + 1)"
            case .group:
                record.popularity = 0.25 + 0.75 * random.unit()
                record.picture = "\(theme.thingPictures)-\(index % 6 + 1)"
            case .content:
                let look = random.unit()
                if look < 0.5 { record.picture = "\(theme.thingPictures)-\(random.int(1...6))" } else if look < 0.75 { record.link = true }
                if case .string(let handle)? = content["_group"], let groupType = groupType(for: type) {
                    record.group = world.find(groupType, handle)
                }
                if record.group == nil, let groupType = groupType(for: type), world.count(groupType) > 0 {
                    record.group = random.weighted(world.all(groupType).map(\.popularity))
                }
                if let person = shape.person, world.count(person) > 0 {
                    record.author = random.weighted(world.all(person).map { 0.2 + $0.popularity })
                }
            case .other:
                record.picture = "\(theme.thingPictures)-\(index % 6 + 1)"
            }
            let scale = part == .content ? 640.0 : part == .group ? 900.0 : 60.0
            record.upvotes = Int((1 + record.popularity * scale).rounded())
            record.downvotes = Int((Double(record.upvotes) * (0.02 + 0.1 * random.unit())).rounded())
            record.id = makeID(type, index: index, date: record.date)
            records.append(record)
        }
        // The signed-in person writes a couple of the posts too.
        if part == .content, let person = shape.person, world.count(person) > 0, records.count > 3 {
            for index in [records.count - 2, records.count / 2] { records[index].author = world.me }
        }
        world.records[type] = records
    }

    /// When each of `count` records was made, oldest first: content over the last three weeks (most of it recent),
    /// people and groups over the last years.
    private mutating func makeDates(count: Int, part: RecordAsk.Part) -> [Date] {
        (0..<count).map { _ in
            let hours: Double
            switch part {
            case .person: hours = Double(random.int(24 * 120...24 * 1_400))
            case .group: hours = Double(random.int(24 * 300...24 * 1_600))
            case .content: hours = 0.4 + 21 * 24 * pow(random.unit(), 1.8)
            case .other: hours = 1 + 60 * 24 * random.unit()
            }
            return Self.minute(world.anchor.addingTimeInterval(-hours * 3_600))
        }
    }

    /// An id for the `index`th record of `type`, growing with its date: a number, a UUID, or a string of digits.
    private mutating func makeID(_ type: String, index: Int, date: Date) -> JSONValue {
        guard let field = shape.entity(type)?.fields.first(where: { $0.name == "id" }) else { return .null }
        let base = 1_000 + (Seeded.seed(type) % 90) * 1_000
        switch field.type.unwrapped {
        case .named("UUID"):
            let bytes = (0..<16).map { _ in UInt8(random.int(0...255)) }
            let hex = bytes.map { String(format: "%02x", $0) }.joined()
            let parts = [hex.prefix(8), hex.dropFirst(8).prefix(4), "4" + hex.dropFirst(13).prefix(3), "a" + hex.dropFirst(17).prefix(3), hex.dropFirst(20).prefix(12)]
            return .string(parts.joined(separator: "-"))
        case .named("String"):
            // Like a snowflake: milliseconds since 1970, shifted, so a later record has a larger id.
            let stamp = Int64(date.timeIntervalSince1970 * 1_000) << 16 | Int64(index % 65_536)
            return .string(String(stamp))
        default:
            return .int(base + index * 3 + random.int(0...2))
        }
    }

    // MARK: - Replies

    /// Who answers whom in a thread of `count` replies: nil answers the record, an index an earlier reply. About half
    /// answer another, most often the one just before; a thread of four or more holds a reply to a reply to a reply.
    static func thread(_ count: Int, random: inout Seeded) -> [Int?] {
        var shape: [Int?] = []
        for index in 0..<count {
            guard index > 0, random.chance(0.5) else { shape.append(nil); continue }
            shape.append(random.chance(0.6) ? index - 1 : random.int(0...(index - 1)))
        }
        let deep = shape.contains { answered in answered.map { shape[$0] != nil } ?? false }
        if count >= 4, !deep { shape[1] = 0; shape[2] = 1 }
        return shape
    }

    private mutating func makeReplies<W: ContentWriter>(_ type: String, owner: String, total: Int, writer: inout W) async throws {
        let owners = world.all(owner)
        guard !owners.isEmpty else { world.records[type] = []; return }
        let allotted = Self.allot(total, weights: owners.map { 0.12 + $0.popularity }, cap: 12)
        guard let field = replyField(type) else { world.records[type] = []; return }
        let threaded = (shape.roles[type] ?? [:]).values.contains { $0 == .parent || $0 == .path || $0 == .depth }
        let persons = shape.person.map { world.all($0) } ?? []

        // Asks of a few records at a time, about a dozen replies an ask.
        var batches: [[Int]] = [], current: [Int] = [], replies = 0
        for (index, count) in allotted.enumerated() where count > 0 {
            if !current.isEmpty, replies + count > 12 || current.count >= 3 { batches.append(current); current = []; replies = 0 }
            current.append(index)
            replies += count
        }
        if !current.isEmpty { batches.append(current) }

        var made: [World.Record] = []
        for batch in batches {
            try Task.checkCancellation()
            var parents: [ThreadAsk.Parent] = []
            for (number, index) in batch.enumerated() {
                parents.append(ThreadAsk.Parent(number: number + 1, title: owners[index].title ?? "",
                                                body: Self.excerpt(owners[index], shape: shape),
                                                author: owners[index].author.flatMap { persons.indices.contains($0) ? persons[$0].handle : nil } ?? "someone",
                                                count: allotted[index],
                                                shape: threaded ? Self.thread(allotted[index], random: &random) : []))
            }
            let ask = ThreadAsk(parents: parents, field: field, threaded: threaded, noun: SwiftName.words(type),
                                parentNoun: SwiftName.words(owner))
            let threads = try await writer.threads(ask)
            for (position, index) in batch.enumerated() {
                let lines = position < threads.count ? threads[position] : []
                var placed: [Int] = []
                for line in lines.prefix(allotted[index]) {
                    let parent = line.replyTo.flatMap { $0 >= 0 && $0 < placed.count ? placed[$0] : nil }
                    // A reply comes minutes to a day or so after what it answers, and never after now: on a record
                    // posted an hour ago, the replies spread over that hour.
                    let after = parent.map { made[$0].date } ?? owners[index].date
                    let wanted = parent == nil ? 60 * pow(2, 1 + 10 * random.unit()) : 60 * pow(2, 1 + 8 * random.unit())
                    let room = max(60, world.anchor.timeIntervalSince(after))
                    let delay = wanted < room * 0.9 ? wanted : room * (0.1 + 0.8 * random.unit())
                    var record = World.Record(type: type, index: made.count, date: min(world.anchor, Self.minute(after.addingTimeInterval(delay))),
                                              popularity: random.popularity() * 0.6)
                    record.owner = index
                    record.parent = parent
                    record.depth = parent.map { made[$0].depth + 1 } ?? 0
                    record.values[field.name] = .string(line.text)
                    record.title = String(line.text.prefix(80))
                    record.group = owners[index].group
                    if !persons.isEmpty {
                        // Now and then the one who posted answers a reply.
                        let op = owners[index].author
                        if parent != nil, let op, random.chance(0.25) { record.author = op } else {
                            record.author = random.weighted(persons.map { 0.2 + $0.popularity })
                        }
                    }
                    record.upvotes = Int((1 + record.popularity * 90).rounded())
                    record.downvotes = Int((Double(record.upvotes) * 0.08 * random.unit()).rounded())
                    placed.append(made.count)
                    made.append(record)
                }
            }
        }
        // Ids grow with time: order by date, keep who answers whom.
        let order = made.indices.sorted { made[$0].date == made[$1].date ? $0 < $1 : made[$0].date < made[$1].date }
        var place = Array(repeating: 0, count: made.count)
        for (new, old) in order.enumerated() { place[old] = new }
        var records: [World.Record] = []
        for (new, old) in order.enumerated() {
            var record = made[old]
            record.index = new
            record.parent = record.parent.map { place[$0] }
            record.id = makeID(type, index: new, date: record.date)
            records.append(record)
        }
        world.records[type] = records
    }

    /// `total` split over records by weight, none over `cap`, the most loved ones first to get theirs.
    static func allot(_ total: Int, weights: [Double], cap: Int) -> [Int] {
        guard !weights.isEmpty, total > 0 else { return weights.map { _ in 0 } }
        let sum = weights.reduce(0, +)
        var counts = weights.map { min(cap, Int((Double(total) * $0 / sum).rounded(.down))) }
        var left = total - counts.reduce(0, +)
        let byWeight = weights.indices.sorted { weights[$0] > weights[$1] }
        var pass = 0
        while left > 0, pass < cap * weights.count {
            let index = byWeight[pass % byWeight.count]
            if counts[index] < cap { counts[index] += 1; left -= 1 }
            pass += 1
        }
        return counts
    }

    /// What a reply says: its body field.
    private func replyField(_ type: String) -> AskField? {
        guard let entity = shape.entity(type) else { return nil }
        let candidates = entity.fields.filter {
            if case .body = shape.role($0, of: type) { return true }
            return false
        }
        let field = candidates.first ?? entity.fields.first { shape.role($0, of: type) == .text || shape.role($0, of: type) == .title }
        guard let field else { return nil }
        return AskField(name: field.name, kind: .string, optional: false, role: shape.role(field, of: type),
                        note: "what the \(SwiftName.words(type)) says: one to three sentences, as a person replies")
    }

    private static func excerpt(_ record: World.Record, shape: Shape) -> String? {
        guard let entity = shape.entity(record.type) else { return nil }
        for field in entity.fields {
            if case .body = shape.role(field, of: record.type), case .string(let text)? = record.values[field.name] {
                return String(text.prefix(360))
            }
        }
        return nil
    }

    // MARK: - Owned records

    private mutating func makeOwned(_ type: String, holder: String) {
        var records: [World.Record] = []
        for owner in world.all(holder) {
            let count = owner.picture != nil ? random.int(1...2) : random.chance(0.1) ? 1 : 0
            for number in 0..<count {
                var record = World.Record(type: type, index: records.count, date: owner.date, popularity: owner.popularity)
                record.owner = owner.index
                record.picture = number == 0 ? owner.picture : "\(theme.thingPictures)-\(random.int(1...6))"
                record.title = owner.title
                record.id = makeID(type, index: records.count, date: owner.date)
                records.append(record)
            }
        }
        world.records[type] = records
    }

    // MARK: - What the writer is asked

    /// The fields of `type` the content writer fills: what it says, and the choices its content decides.
    func askFields(_ type: String, part: RecordAsk.Part) -> [AskField] {
        guard let entity = shape.entity(type) else { return [] }
        let noun = SwiftName.words(type)
        var fields: [AskField] = []
        for field in entity.fields {
            let role = shape.role(field, of: type)
            let optional = field.type.isOptional
            let note: String
            var kind = AskField.Kind.string
            switch role {
            case .handle:
                note = part == .person ? "their handle: lowercase letters, digits and underscores, 3 to 20 characters, unique"
                    : part == .group ? "the \(noun)'s short name in its address: lowercase letters, digits and underscores, unique"
                    : "a short unique name: lowercase letters, digits and underscores"
            case .displayName:
                note = "the name they go by: a real-sounding full name or a nickname"
            case .title:
                note = part == .group ? "the \(noun)'s name as shown: one to four plain words its members would look for, never a pun"
                    : part == .person ? "their name" : "its title as a person would write it, 15 to 90 characters"
            case .body(let format):
                let form = format == .markdown ? ", in Markdown: one to four short paragraphs, sometimes a list or **bold**"
                    : format == .html ? ", as HTML paragraphs (<p>…</p>)" : ": one to four short paragraphs"
                note = "what the \(noun) says\(form)" + (optional ? "; null for a picture or a link with nothing to add" : "")
            case .summary(let format):
                note = (part == .person ? "a one-line bio" : part == .group ? "what the \(noun) is for, one or two sentences"
                    : "one or two sentences about it") + (format == .html ? ", as HTML" : "") + (optional ? "; null now and then" : "")
            case .text:
                note = "\(SwiftName.words(field.name)): a few words"
            case .choice(let name):
                guard field.defaultValue == nil, let choice = shape.entity(name) else { continue }
                let values = choice.cases.compactMap { shape.raw($0, of: choice).text }
                kind = .choice(values)
                note = "one of: " + values.joined(separator: ", ")
            case .number:
                kind = field.type.unwrapped == .named("Double") || field.type.unwrapped == .named("Float") ? .number : .integer
                note = "\(SwiftName.words(field.name)): a number that fits"
            case .other:
                guard case .array(.named("String")) = field.type.unwrapped else { continue }
                kind = .strings
                note = "\(SwiftName.words(field.name)): two to four short ones"
            default:
                continue
            }
            let said = field.doc.map { $0.isEmpty ? note : "\(note) (\($0))" } ?? note
            fields.append(AskField(name: field.name, kind: kind, optional: optional, role: role, note: said))
        }
        return fields
    }

    /// The group type content of `type` is posted in.
    func groupType(for type: String) -> String? {
        let roles = shape.roles[type] ?? [:]
        return shape.groups.first { group in roles.values.contains { $0 == .reference(group) || $0 == .record(group) } }
    }

    /// The groups content of `type` may be posted in, by handle and title.
    private func groupsFor(_ type: String) -> [(handle: String, title: String)] {
        guard let group = groupType(for: type) else { return [] }
        return world.all(group).compactMap { record in record.handle.map { ($0, record.title ?? $0) } }
    }

    private func text(_ content: [String: JSONValue], role: FieldRole, of type: String) -> String? {
        guard let field = shape.field(of: type, where: { $0 == role }), case .string(let text)? = content[field.name] else { return nil }
        return text
    }

    static func plural(_ type: String, shape: Shape) -> String {
        if type == shape.person, ["Person", "People"].contains(type) { return "people" }
        return SwiftName.plural(SwiftName.lowerCamel(type))
    }

    static func minute(_ date: Date) -> Date {
        Date(timeIntervalSince1970: (date.timeIntervalSince1970 / 60).rounded(.down) * 60)
    }
}
