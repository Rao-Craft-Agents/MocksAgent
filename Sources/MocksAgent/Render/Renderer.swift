//  WHAT: The world shown as the API shows it: a type rendered as JSON, its keys as the API writes them, in the
//        context of the records it is about. A record is its fields; a view puts its records together (a post's view:
//        the post, its creator, its community, its counts); a value is counted from the record it sits in.
//  PIN:  COUNTED, NOT MADE UP. A post's comment count is its comments in the world, a person's post count their
//        posts, a reply's child count the replies under it; only what the world holds no records of (followers, how
//        many were active this week) is read off a record's popularity.

import Foundation

struct Renderer: Sendable {
    let shape: Shape
    let world: World
    /// The token a sign-in answers.
    let token: String

    /// The records a value is about, the one it is most about first.
    typealias Context = [(type: String, index: Int)]

    /// `type` as JSON, about `context`.
    func render(_ type: TypeRef, _ context: Context = [], depth: Int = 0) -> JSONValue {
        switch type {
        case .optional(let wrapped): return render(wrapped, context, depth: depth)
        case .array(let element):
            guard let base = Shape.base(element) else { return .array([]) }
            return .array(list(of: base, element: element, context, depth: depth))
        case .dictionary: return .object([])
        case .named(let name):
            switch shape.kind(of: name) {
            case .record:
                let index = context.first { $0.type == name }?.index ?? resolve(name, in: context) ?? 0
                return world.count(name) > 0 ? record(name, index, depth: depth) : .null
            case .view: return view(name, context, depth: depth)
            case .value: return value(name, context, depth: depth)
            case .choice:
                guard let entity = shape.entity(name), let first = entity.cases.first else { return .null }
                return shape.raw(first, of: entity)
            case .carrier: return carrier(name, context, depth: depth)
            case .primitive: return primitive(name)
            case .unknown: return .null
            }
        }
    }

    /// The record `index` of `type`, every field in its line's order.
    func record(_ type: String, _ index: Int, depth: Int = 0) -> JSONValue {
        guard let entity = shape.entity(type), let record = world.record(type, index) else { return .null }
        let context: Context = [(type, index)]
        var members: [(key: String, value: JSONValue)] = []
        for field in entity.fields {
            let role = shape.role(field, of: type)
            let value: JSONValue
            switch role {
            case .record(let target):
                // A record that holds its own type again (a status's reblog) shows none, so nothing loops.
                if let held = record.holds[field.name]?.first, target != type, depth < 4 {
                    value = self.record(target, held, depth: depth + 1)
                } else {
                    value = field.type.isOptional ? .null : self.record(target, 0, depth: depth + 1)
                }
            case .records(let target):
                value = depth < 4 ? .array((record.holds[field.name] ?? []).map { self.record(target, $0, depth: depth + 1) }) : .array([])
            case .composite(let name):
                value = render(.named(name), context, depth: depth + 1)
            case .composites(let name):
                value = .array(list(of: name, element: .named(name), context, depth: depth + 1))
            case .count(let word):
                value = .int(count(word, of: record))
            case .carrier(let name):
                value = field.type.isOptional ? .null : carrier(name, context, depth: depth + 1)
            default:
                value = record.values[field.name] ?? (field.type.isOptional ? .null : WorldBuilder.zero(field.type))
            }
            members.append((shape.key(field), value))
        }
        return .object(members)
    }

    /// A view: its records found from the ones it is about (a post's creator is its author), then each field.
    func view(_ type: String, _ context: Context, depth: Int = 0) -> JSONValue {
        guard let entity = shape.entity(type) else { return .null }
        var context = context
        for _ in 0..<3 {
            for field in entity.fields {
                guard case .record(let target) = shape.role(field, of: type), !context.contains(where: { $0.type == target }),
                      let index = resolve(target, in: context) else { continue }
                context.append((target, index))
            }
        }
        let about = context.first.flatMap { world.record($0.type, $0.index) }
        var members: [(key: String, value: JSONValue)] = []
        for field in entity.fields {
            let role = shape.role(field, of: type)
            let value: JSONValue
            switch role {
            case .record(let target):
                if let found = context.first(where: { $0.type == target }) {
                    value = record(target, found.index, depth: depth + 1)
                } else {
                    value = field.type.isOptional || world.count(target) == 0 ? .null : record(target, 0, depth: depth + 1)
                }
            case .records(let target):
                let indices = about.map { world.related(target, to: $0, shape: shape) } ?? Array(0..<min(6, world.count(target)))
                value = .array(indices.prefix(10).map { record(target, $0, depth: depth + 1) })
            case .composite(let name):
                value = render(.named(name), context, depth: depth + 1)
            case .composites(let name):
                value = .array(list(of: name, element: .named(name), context, depth: depth + 1))
            default:
                value = loose(field, role: role, about: about, in: type)
            }
            members.append((shape.key(field), value))
        }
        return .object(members)
    }

    /// A struct of values: counted from the record it sits in, or made from the field's role.
    func value(_ type: String, _ context: Context, depth: Int = 0) -> JSONValue {
        guard let entity = shape.entity(type) else { return .null }
        let about = context.first.flatMap { world.record($0.type, $0.index) }
        var members: [(key: String, value: JSONValue)] = []
        for field in entity.fields {
            let role = shape.role(field, of: type)
            let value: JSONValue
            switch role {
            case .composite(let name): value = render(.named(name), context, depth: depth + 1)
            case .composites(let name): value = .array(list(of: name, element: .named(name), context, depth: depth + 1))
            default: value = loose(field, role: role, about: about, in: type)
            }
            members.append((shape.key(field), value))
        }
        return .object(members)
    }

    /// The items of a list of `base`: the records that belong with the context's record, each shown as `element`.
    func list(of base: String, element: TypeRef, _ context: Context, depth: Int) -> [JSONValue] {
        guard depth < 5 else { return [] }
        let about = context.first.flatMap { world.record($0.type, $0.index) }
        switch shape.kind(of: base) {
        case .record:
            let indices = about.map { world.related(base, to: $0, shape: shape) } ?? Array(0..<min(10, world.count(base)))
            return indices.prefix(10).map { record(base, $0, depth: depth + 1) }
        case .view:
            guard let primary = primaryRecord(of: base) else { return [view(base, context, depth: depth + 1)] }
            let indices = about.map { world.related(primary, to: $0, shape: shape) } ?? Array(0..<min(10, world.count(primary)))
            return indices.prefix(10).map { view(base, [(primary, $0)] + context, depth: depth + 1) }
        case .value:
            return (0..<3).map { _ in value(base, context, depth: depth + 1) }
        case .choice, .carrier, .primitive:
            return [render(element, context, depth: depth + 1)]
        case .unknown:
            return []
        }
    }

    /// The record type a view is about: its field named for its type (`post: Post`), else its first record.
    func primaryRecord(of view: String) -> String? {
        primaryField(of: view).flatMap { field -> String? in
            if case .record(let target) = shape.role(field, of: view) { return target }
            return nil
        }
    }

    func primaryField(of view: String) -> Field? {
        guard let entity = shape.entity(view) else { return nil }
        let records = entity.fields.filter { if case .record = shape.role($0, of: view) { return true } else { return false } }
        return records.first { field in
            if case .record(let target) = shape.role(field, of: view) { return SwiftName.normalized(field.name) == SwiftName.normalized(target) }
            return false
        } ?? records.first
    }

    /// The record of `target` the context's records refer to.
    func resolve(_ target: String, in context: Context) -> Int? {
        for (type, index) in context {
            guard let record = world.record(type, index) else { continue }
            if let found = world.resolve(target, of: record, shape: shape), type != target { return found }
        }
        return nil
    }

    // MARK: - Fields no record holds

    /// A field of a view or a value: counted, read off the record it is about, or made from its role.
    private func loose(_ field: Field, role: FieldRole, about: World.Record?, in type: String) -> JSONValue {
        let optional = field.type.isOptional
        let jitter = Self.unit("\(type).\(field.name).\(about?.type ?? "").\(about?.index ?? 0)")
        switch role {
        case .count(let word): return .int(count(word, of: about))
        case .score: return .int((about?.upvotes ?? 0) - (about?.downvotes ?? 0))
        case .upvotes: return .int(about?.upvotes ?? 0)
        case .downvotes: return .int(about?.downvotes ?? 0)
        case .vote: return optional ? (jitter < 0.15 ? .int(1) : .null) : .int(0)
        case .created: return about.map { .string(WorldBuilder.iso($0.date)) } ?? (optional ? .null : .string(WorldBuilder.iso(world.anchor)))
        case .moment, .updated:
            if let about, let latest = latestReply(to: about) { return .string(WorldBuilder.iso(latest)) }
            return optional ? .null : .string(WorldBuilder.iso(about?.date ?? world.anchor))
        case .secret: return .string(token)
        case .flag(let usual):
            let word = SwiftName.normalized(field.name)
            if ["saved", "read", "subscribed", "bookmarked", "favourited", "favorited", "liked", "followed", "following"].contains(word) {
                return .bool(jitter < 0.2)
            }
            return .bool(usual)
        case .choice(let name):
            guard let entity = shape.entity(name), !entity.cases.isEmpty else { return .null }
            if let value = field.defaultValue, let item = entity.cases.first(where: { ".\($0.name)" == value }) { return shape.raw(item, of: entity) }
            // A membership reads as most people's: not a member, a few are.
            let negative = entity.cases.firstIndex { SwiftName.normalized($0.name).hasPrefix("not") || SwiftName.normalized($0.name).hasPrefix("no") }
            if let negative { return shape.raw(entity.cases[jitter < 0.3 ? 0 : negative], of: entity) }
            return shape.raw(entity.cases[0], of: entity)
        case .carrier(let name): return optional ? .null : carrier(name, [], depth: 1)
        case .number:
            var random = Seeded(Seeded.seed("\(type).\(field.name).\(about?.index ?? 0)"))
            let integer = !(["Double", "Float", "Decimal"].contains(Shape.base(field.type) ?? ""))
            return WordWriter.number(field.name, integer: integer, index: about?.index ?? 0, random: &random)
        default:
            // A field the record it is about holds too (a session's `username`): its value there.
            if let about, let same = shape.field(field.name, of: about.type), let value = about.values[same.name] { return value }
            if optional { return .null }
            switch role {
            case .handle: return .string(about?.handle ?? "member")
            case .title, .displayName: return .string(about?.title ?? "")
            case .page, .link: return .string("https://\(world.host)/")
            case .image: return .string("mock-image://place-1")
            default: return WorldBuilder.zero(field.type)
            }
        }
    }

    /// How many of what `word` counts belong with `record`: its replies, its posts, its comments; or, for what the
    /// world holds no records of, a number its popularity gives.
    func count(_ word: String, of record: World.Record?) -> Int {
        guard let record else { return 0 }
        var stem = word
        for suffix in ["counts", "count", "total"] where stem.hasSuffix(suffix) && stem.count > suffix.count { stem.removeLast(suffix.count) }
        for prefix in ["total", "number", "num"] where stem.hasPrefix(prefix) && stem.count > prefix.count { stem.removeFirst(prefix.count) }
        let popularity = record.popularity
        if ["child", "children", "replies", "reply", "descendant", "descendants"].contains(stem) {
            if shape.children[record.type] != nil || world.all(record.type).contains(where: { $0.parent != nil }) {
                return world.descendants(of: record)
            }
            if let child = shape.children.first(where: { $0.value == record.type })?.key {
                return world.all(child).filter { $0.owner == record.index }.count
            }
            return 0
        }
        if let counted = countedType(stem) {
            if counted == record.type { return world.all(counted).filter { $0.parent == record.index }.count }
            if record.type == shape.person { return world.all(counted).filter { $0.author == record.index }.count }
            if shape.groups.contains(record.type) { return world.all(counted).filter { $0.group == record.index }.count }
            if shape.children[counted] == record.type || shape.owned[counted] == record.type {
                return world.all(counted).filter { $0.owner == record.index }.count
            }
        }
        let jitter = Self.unit("\(record.type).\(record.index).\(stem)")
        switch stem {
        case "followers", "subscribers", "members", "users", "readers":
            return record.type == shape.person ? Int(3 + popularity * 2_400 + jitter * 40) : Int(60 + popularity * 14_000 + jitter * 300)
        case "following": return Int(10 + jitter * 300)
        case _ where stem.hasPrefix("usersactive"):
            let base = 60 + popularity * 14_000
            let share = stem.hasSuffix("day") ? 0.02 : stem.hasSuffix("week") ? 0.08 : stem.hasSuffix("month") ? 0.2 : 0.45
            return Int(base * share * (0.8 + 0.4 * jitter))
        case "likes", "favourites", "favorites", "votes", "reactions", "saves", "bookmarks":
            return Int(Double(record.upvotes) * (0.7 + 0.3 * jitter))
        case "reblogs", "boosts", "shares": return Int(Double(record.upvotes) * (0.08 + 0.1 * jitter))
        case "views", "visits", "plays", "downloads": return Int(Double(record.upvotes + 3) * (8 + 10 * jitter))
        default: return Int(popularity * 40 + jitter * 8)
        }
    }

    /// The record type `stem` names: `comments` → `Comment`, `post` → `Post`, `statuses` → `Status`.
    private func countedType(_ stem: String) -> String? {
        shape.records.first { record in
            let name = SwiftName.normalized(record)
            return stem == name || stem == SwiftName.normalized(SwiftName.plural(record)) || stem == name + "s"
        }
    }

    /// When the newest reply to `record` was written.
    private func latestReply(to record: World.Record) -> Date? {
        if let child = shape.children.first(where: { $0.value == record.type })?.key {
            return world.all(child).filter { $0.owner == record.index }.map(\.date).max()
        }
        return nil
    }

    /// An enum's first case that carries values, as Swift writes it: `{"photo": {"_0": "…"}}`.
    private func carrier(_ name: String, _ context: Context, depth: Int) -> JSONValue {
        guard let entity = shape.entity(name), let item = entity.cases.first else { return .null }
        let values: [(key: String, value: JSONValue)] = item.values.enumerated().map { index, value in
            (value.label ?? "_\(index)", depth < 4 ? render(value.type, context, depth: depth + 1) : WorldBuilder.zero(value.type))
        }
        return .object([(item.name, .object(values))])
    }

    private func primitive(_ name: String) -> JSONValue {
        switch name {
        case "String": return .string(token)
        case "Bool": return .bool(true)
        case "Date": return .string(WorldBuilder.iso(world.anchor))
        case "URL": return .string("https://\(world.host)/")
        default: return WorldBuilder.zero(.named(name))
        }
    }

    /// A number in `0..<1` that is the same for the same text.
    static func unit(_ text: String) -> Double {
        var random = Seeded(Seeded.seed(text))
        return random.unit()
    }
}
