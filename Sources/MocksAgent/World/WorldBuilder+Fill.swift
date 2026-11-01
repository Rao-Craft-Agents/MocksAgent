//  WHAT: Every field of every record given its value, once all the records are made: what refers to what (a post's
//        creator id is its author's), the pictures, the links and pages, the dates, the votes, the paths of a thread,
//        the flags, and what the writer said. Counts are left for the renderer, which counts the world as it shows it.
//  PIN:  EVERY FIELD HOLDS A VALUE OF ITS TYPE. A required field the roles do not place still gets one, so every
//        fixture decodes as its type.

import Foundation

extension WorldBuilder {
    mutating func fill(_ type: String) {
        guard let entity = shape.entity(type), var records = world.records[type] else { return }
        for index in records.indices {
            for field in entity.fields {
                if let value = value(field, of: records[index]) { records[index].values[field.name] = value }
                if let held = holds(field, of: records[index]) { records[index].holds[field.name] = held }
            }
        }
        world.records[type] = records
    }

    /// What `field` of `record` holds, or nil when the renderer makes it (a count, a record in place, a struct).
    private mutating func value(_ field: Field, of record: World.Record) -> JSONValue? {
        let role = shape.role(field, of: record.type)
        let optional = field.type.isOptional
        let said = record.values[field.name]
        switch role {
        case .id: return record.id
        case .reference(let target): return reference(target, field: field, of: record) ?? (optional ? .null : Self.zero(field.type))
        case .references(let target):
            let ids = world.related(target, to: record, shape: shape).prefix(3).compactMap { world.record(target, $0)?.id }
            return .array(Array(ids))
        case .parent:
            if let parent = record.parent, let id = world.record(record.type, parent)?.id { return id }
            return optional ? .null : Self.zero(field.type)
        case .record, .records, .composite, .composites, .count, .carrier: return nil
        case .choice(let name):
            if let said, !said.isNull { return said }
            return choice(name, field: field)
        case .handle:
            if let said, !said.isNull { return said }
            return .string(record.handle ?? WordWriter.slug(record.title ?? "\(record.type) \(record.index + 1)").replacingOccurrences(of: "-", with: "_"))
        case .displayName, .title, .body, .summary, .text:
            if let said { return optional || !said.isNull ? said : .string(record.title ?? "") }
            if optional { return .null }
            return .string(record.title ?? record.handle ?? SwiftName.words(field.name).capitalized)
        case .warning: return optional ? .null : .string("")
        case .email: return .string("\(record.handle ?? "someone")@example.com")
        case .secret: return optional ? .null : .string(Self.token(&random))
        case .image(let subject): return picture(subject, field: field, of: record)
        case .link:
            if record.link || !optional { return .string(link(record)) }
            return .null
        case .page: return .string(page(record))
        case .created: return .string(Self.iso(record.date))
        case .updated:
            if optional {
                guard random.chance(0.15) else { return .null }
                return .string(Self.iso(min(world.anchor, record.date.addingTimeInterval(Double(random.int(10...360)) * 60))))
            }
            return .string(Self.iso(record.date))
        case .moment:
            if optional, random.chance(0.6) { return .null }
            return .string(Self.iso(record.date.addingTimeInterval(Double(random.int(1...72)) * 3_600)))
        case .score: return .int(record.upvotes - record.downvotes)
        case .upvotes: return .int(record.upvotes)
        case .downvotes: return .int(record.downvotes)
        case .vote: return optional ? (random.chance(0.15) ? .int(1) : .null) : .int(0)
        case .path: return .string(path(record))
        case .depth: return .int(record.depth)
        case .flag(let usual): return .bool(flag(field, usual: usual, of: record))
        case .number:
            if let said, !said.isNull { return said }
            let integer = !(["Double", "Float", "Decimal"].contains(Shape.base(field.type) ?? ""))
            return WordWriter.number(field.name, integer: integer, index: record.index, random: &random)
        case .language: return .string("en")
        case .color: return .string(random.pick(["#E07A5F", "#3D405B", "#81B29A", "#F2CC8F", "#6D597A", "#B56576", "#457B9D"]))
        case .uuid: return makeUUID()
        case .data: return .string("")
        case .other:
            if let said { return said }
            if case .array = field.type.unwrapped { return .array([]) }
            if case .dictionary = field.type.unwrapped { return .object([]) }
            return optional ? .null : Self.zero(field.type)
        }
    }

    /// The records `field` holds in place: an author's account, a status's attachments.
    private func holds(_ field: Field, of record: World.Record) -> [Int]? {
        switch shape.role(field, of: record.type) {
        case .record(let target):
            if target == record.type { return [] }
            return world.resolve(target, of: record, shape: shape).map { [$0] } ?? []
        case .records(let target):
            if shape.owned[target] == record.type { return world.all(target).filter { $0.owner == record.index }.map(\.index) }
            return Array(world.related(target, to: record, shape: shape).prefix(4))
        default:
            return nil
        }
    }

    /// The id of the record of `target` that `field` of `record` refers to.
    private func reference(_ target: String, field: Field, of record: World.Record) -> JSONValue? {
        world.resolve(target, of: record, shape: shape).flatMap { world.record(target, $0)?.id }
    }

    // MARK: - Values

    private mutating func choice(_ name: String, field: Field) -> JSONValue {
        guard let choice = shape.entity(name), !choice.cases.isEmpty else { return .null }
        if let value = field.defaultValue, value.hasPrefix("."), let item = choice.cases.first(where: { ".\($0.name)" == value || ".`\($0.name)`" == value }),
           random.chance(0.88) {
            return shape.raw(item, of: choice)
        }
        let index = random.weighted(choice.cases.indices.map { $0 == 0 ? 4.0 : 1.0 })
        return shape.raw(choice.cases[index], of: choice)
    }

    private mutating func picture(_ subject: ImageSubject, field: Field, of record: World.Record) -> JSONValue {
        let optional = field.type.isOptional
        switch subject {
        case .person:
            return .string("mock-image://\(record.picture ?? "person-\(record.index % 6 + 1)")")
        case .wide:
            if optional, random.chance(0.35) { return .null }
            return .string("mock-image://place-\((record.index * 5 + 2) % 6 + 1)")
        case .thing:
            if let picture = record.picture { return .string("mock-image://\(picture)") }
            if shape.contents.contains(record.type), record.link, random.chance(0.5) {
                return .string("mock-image://\(theme.thingPictures)-\(record.index % 6 + 1)")
            }
            return optional ? .null : .string("mock-image://\(theme.thingPictures)-\(record.index % 6 + 1)")
        }
    }

    private func link(_ record: World.Record) -> String {
        let slug = WordWriter.slug(record.title ?? "\(record.type) \(record.index)")
        let sites = ["www.example.com", "blog.example.org", "news.example.net", "notes.example.com"]
        return "https://\(sites[record.index % sites.count])/\(Calendar(identifier: .gregorian).component(.year, from: record.date))/\(slug.isEmpty ? "post" : slug)"
    }

    private func page(_ record: World.Record) -> String {
        let host = "https://\(world.host)"
        if record.type == shape.person { return "\(host)/u/\(record.handle ?? record.id.text ?? "\(record.index)")" }
        if shape.groups.contains(record.type) { return "\(host)/c/\(record.handle ?? record.id.text ?? "\(record.index)")" }
        let noun = SwiftName.snake(SwiftName.lowerCamel(record.type))
        return "\(host)/\(noun)/\(record.id.text ?? "\(record.index)")"
    }

    /// A thread's path: `0`, then each id from the top reply down to this one.
    private func path(_ record: World.Record) -> String {
        var ids: [String] = [], current: World.Record? = record
        while let reply = current {
            ids.insert(reply.id.text ?? "\(reply.index)", at: 0)
            current = reply.parent.flatMap { world.record(record.type, $0) }
        }
        return (["0"] + ids).joined(separator: ".")
    }

    private mutating func flag(_ field: Field, usual: Bool, of record: World.Record) -> Bool {
        let word = SwiftName.normalized(field.name)
        if word.hasPrefix("featured") || ["pinned", "sticky", "stickied"].contains(word) {
            // The most loved post of the newest few is pinned.
            guard shape.contents.contains(record.type) else { return false }
            let newest = world.all(record.type).suffix(8)
            return newest.max { $0.popularity < $1.popularity }?.index == record.index
        }
        if ["nsfw", "sensitive", "deleted", "removed", "banned", "blocked", "hidden", "spam"].contains(word) { return false }
        if word == "locked" { return random.chance(0.03) }
        if ["saved", "read", "bookmarked", "favourited", "favorited", "subscribed", "liked", "followed", "following"].contains(word) {
            return random.chance(0.2)
        }
        if word == "bot" || word == "botaccount" { return random.chance(0.04) }
        if word == "local" { return random.chance(0.85) }
        if word == "admin" { return record.type == shape.person && record.index == world.me }
        return usual
    }

    private mutating func makeUUID() -> JSONValue {
        let hex = (0..<16).map { _ in String(format: "%02x", random.int(0...255)) }.joined()
        let parts = [hex.prefix(8), hex.dropFirst(8).prefix(4), "4" + hex.dropFirst(13).prefix(3), "8" + hex.dropFirst(17).prefix(3), hex.dropFirst(20).prefix(12)]
        return .string(parts.joined(separator: "-"))
    }

    static func token(_ random: inout Seeded) -> String {
        let alphabet = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
        return String((0..<32).map { _ in alphabet[random.int(0...(alphabet.count - 1))] })
    }

    /// A value of `type` that decodes: zero, empty, the first moment of 2026.
    static func zero(_ type: TypeRef) -> JSONValue {
        switch type {
        case .optional: return .null
        case .array: return .array([])
        case .dictionary: return .object([])
        case .named(let name):
            switch name {
            case "String": return .string("")
            case "Bool": return .bool(false)
            case "Double", "Float", "Decimal": return .double(0)
            case "Date": return .string("2026-01-01T00:00:00Z")
            case "URL": return .string("https://example.com")
            case "UUID": return .string("00000000-0000-4000-8000-000000000000")
            case "Data": return .string("")
            default: return .int(0)
            }
        }
    }

    /// `2026-10-28T14:03:00Z`: how the fixtures write a date.
    static func iso(_ date: Date) -> String {
        date.formatted(.iso8601)
    }
}
