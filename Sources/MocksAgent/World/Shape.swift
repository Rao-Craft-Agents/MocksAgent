//  WHAT: What each of an API's types is to the mock backend, read off its entity line: a record the world holds many
//        of, a view put together from records, a value made from what it sits in, a choice; what part each record
//        plays (the people, the groups they post in, the content, the replies under it, what a record owns); and what
//        each field holds.
//  PIN:  THE API'S OWN NAMES FIRST. `postID` names the API's `Post`, a `creator` field's type is its person; the
//        words a field is read by (`avatar` is a face, `published` when it was made) come after, and a field read as
//        nothing in particular is still filled with a value of its type, so every fixture decodes.

import Foundation

struct Shape: Sendable {
    let api: ClientAPI
    let entities: [String: Entity]
    let kinds: [String: TypeKind]
    /// The record types, in the order their lines came.
    let records: [String]
    /// The type the people are: whoever writes, owns or follows.
    let person: String?
    /// Record types that hold the content (`Post`, `Status`): written by a person, answered by replies.
    let contents: [String]
    /// Record types the content is posted in (`Community`), referred to by the content and writing none of it.
    let groups: [String]
    /// Record types that answer another record (`Comment` → `Post`), by type: the record they belong to.
    let children: [String: String]
    /// Record types a record holds a list of and nothing else refers to (`MediaAttachment` in a `Status`): their owner.
    let owned: [String: String]
    /// Every field's role, by type, then field.
    let roles: [String: [String: FieldRole]]

    init(_ api: ClientAPI) {
        self.api = api
        let entities = Dictionary(api.entities.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
        self.entities = entities
        var kinds: [String: TypeKind] = [:]
        for entity in api.entities {
            if entity.isEnum {
                kinds[entity.name] = entity.cases.contains { !$0.values.isEmpty } ? .carrier : .choice
            } else {
                kinds[entity.name] = entity.fields.contains { $0.name == "id" } ? .record : .value
            }
        }
        // A struct that holds a record or a view is a view, until nothing changes.
        var changed = true
        while changed {
            changed = false
            for entity in api.entities where kinds[entity.name] == .value {
                let holds = entity.fields.contains { $0.type.names.contains { kinds[$0] == .record || kinds[$0] == .view } }
                if holds { kinds[entity.name] = .view; changed = true }
            }
        }
        self.kinds = kinds
        let records = api.entities.filter { kinds[$0.name] == .record }.map(\.name)
        self.records = records

        // The person: the type the fields that say who (`creator`, `author`, `account`) hold most often.
        var votes: [String: Int] = [:]
        for entity in api.entities where !entity.isEnum {
            for field in entity.fields {
                guard Self.personWords.contains(SwiftName.normalized(field.name)), let base = Self.base(field.type), kinds[base] == .record else { continue }
                votes[base, default: 0] += 1
            }
        }
        let person = votes.max { $0.value < $1.value || ($0.value == $1.value && $0.key > $1.key) }?.key
            ?? records.first { Self.personTypeNames.contains(SwiftName.normalized($0)) }
        self.person = person

        var roles: [String: [String: FieldRole]] = [:]
        for entity in api.entities where !entity.isEnum {
            var fields: [String: FieldRole] = [:]
            for field in entity.fields {
                fields[field.name] = Self.role(of: field, in: entity, kinds: kinds, records: records, person: person)
            }
            roles[entity.name] = fields
        }
        self.roles = roles

        // The parts each record type plays.
        func refers(_ type: String) -> [String] {
            (roles[type] ?? [:]).values.compactMap { role -> String? in
                switch role {
                case .reference(let other), .record(let other): return other == type ? nil : other
                default: return nil
                }
            }
        }
        let authored = Set(records.filter { $0 != person && person.map(refers($0).contains) == true })
        var children: [String: String] = [:]
        for type in records.sorted() where authored.contains(type) {
            if let owner = refers(type).filter({ authored.contains($0) }).sorted().first { children[type] = owner }
        }
        let contents = records.filter { authored.contains($0) && children[$0] == nil }
        let groups = records.filter { type in
            type != person && !authored.contains(type) && contents.contains { refers($0).contains(type) }
        }
        var owned: [String: String] = [:]
        for type in records where type != person && !authored.contains(type) && !groups.contains(type) {
            let holders = records.filter { holder in
                holder != type && (roles[holder] ?? [:]).values.contains { $0 == .records(type) }
            }
            if let holder = holders.first { owned[type] = holder }
        }
        self.contents = contents
        self.groups = groups
        self.children = children
        self.owned = owned
    }

    // MARK: - Asking

    func entity(_ name: String) -> Entity? { entities[name] }

    func kind(of name: String) -> TypeKind {
        if ClientAPI.primitives.contains(name) { return .primitive }
        return kinds[name] ?? .unknown
    }

    func role(_ field: Field, of entity: String) -> FieldRole { roles[entity]?[field.name] ?? .other }

    /// The JSON key of `field`: its `@key`, else its name, snake_case when the API's keys are.
    func key(_ field: Field) -> String {
        if let key = field.key { return key }
        return api.snake ? SwiftName.snake(field.name) : field.name
    }

    /// The JSON value a plain enum's case is written as.
    func raw(_ item: Case, of entity: Entity) -> JSONValue {
        let integers = entity.cases.allSatisfy { $0.raw == nil || Int($0.raw!) != nil } && entity.cases.contains { $0.raw != nil }
        if integers { return .int(item.raw.flatMap { Int($0) } ?? (entity.cases.firstIndex { $0.name == item.name } ?? 0)) }
        if let raw = item.raw {
            return .string(raw.hasPrefix("\"") && raw.hasSuffix("\"") && raw.count >= 2 ? String(raw.dropFirst().dropLast()) : raw)
        }
        return .string(api.snake ? SwiftName.snake(item.name) : item.name)
    }

    /// The field of `entity` whose JSON key or Swift name is `name`.
    func field(_ name: String, of entity: String) -> Field? {
        self.entity(entity)?.fields.first { $0.name == name || key($0) == name }
    }

    /// The first field of `entity` with `role`.
    func field(of entity: String, where match: (FieldRole) -> Bool) -> Field? {
        self.entity(entity)?.fields.first { match(role($0, of: entity)) }
    }

    /// The named type at the bottom of `type`: `[Post]?` → `Post`.
    static func base(_ type: TypeRef) -> String? {
        switch type {
        case .named(let name): return name
        case .optional(let wrapped): return base(wrapped)
        case .array(let element): return base(element)
        case .dictionary: return nil
        }
    }

    /// Whether `type` is a list of something, under any optional.
    static func isList(_ type: TypeRef) -> Bool {
        if case .array = type.unwrapped { return true }
        return false
    }

    // MARK: - Words

    static let personWords: Set<String> = ["creator", "author", "user", "owner", "account", "person", "member", "poster", "sender",
                                           "recipient", "moderator", "admin", "profile", "writer", "publisher", "uploader", "reporter",
                                           "follower", "friend", "cook", "chef", "host", "organizer", "attendee", "customer", "seller",
                                           "buyer", "player", "student", "teacher", "artist", "submitter", "commenter", "reviewer"]
    static let personTypeNames: Set<String> = ["person", "user", "account", "author", "member", "profile", "people", "customer",
                                               "cook", "chef", "player", "student", "writer", "creator", "artist", "host"]
    static let parentWords: Set<String> = ["parent", "parentcomment", "inreplyto", "replyto", "answerto", "parentpost", "inresponseto"]

    /// The role of `field` of `entity`.
    static func role(of field: Field, in entity: Entity, kinds: [String: TypeKind], records: [String], person: String?) -> FieldRole {
        let name = field.name
        let word = SwiftName.normalized(name)
        let type = field.type.unwrapped
        let siblings = Set(entity.fields.map { SwiftName.normalized($0.name) })
        let doc = (field.doc ?? "").lowercased()

        // Records, views and enums by their type.
        if let base = base(type), let kind = kinds[base] {
            let list = isList(type)
            switch kind {
            case .record: return list ? .records(base) : .record(base)
            case .view, .value: return list ? .composites(base) : .composite(base)
            case .choice: return list ? .other : .choice(base)
            case .carrier: return list ? .other : .carrier(base)
            case .primitive, .unknown: break
            }
        }
        if isList(type) {
            // A list of primitives: the ids of records, or strings.
            if let element = base(type), ["Int", "String", "UUID", "Int64"].contains(element), let stem = idStem(name, plural: true),
               let target = referenced(stem, in: entity, records: records, person: person) {
                return .references(target)
            }
            return .other
        }
        guard case .named(let typeName) = type else { return .other }

        if name == "id" { return .id }
        if ["Int", "Int64", "Int32", "String", "UUID"].contains(typeName), let stem = idStem(name, plural: false) {
            if parentWords.contains(SwiftName.normalized(stem)), records.contains(entity.name) { return .parent }
            if let target = referenced(stem, in: entity, records: records, person: person) {
                return target == entity.name && parentWords.contains(SwiftName.normalized(stem)) ? .parent : .reference(target)
            }
        }

        switch typeName {
        case "String":
            return stringRole(word, siblings: siblings, doc: doc, entity: entity)
        case "URL":
            return urlRole(word, siblings: siblings)
        case "Date":
            if ["published", "created", "createdat", "added", "joined", "date", "timestamp", "posted", "postedat", "creationdate",
                "registered", "createdon", "addedat", "submitted", "time"].contains(word) { return .created }
            if ["updated", "updatedat", "edited", "editedat", "modified", "modifiedat", "lastmodified", "changed", "changedat"].contains(word) { return .updated }
            return .moment
        case "Int", "Int64", "Int32", "Int16", "Int8", "UInt", "UInt64", "UInt32", "UInt16", "UInt8":
            return intRole(word)
        case "Double", "Float", "Decimal":
            if ["score", "hotrank", "rank"].contains(word) { return .score }
            return .number
        case "Bool":
            if let value = field.defaultValue { return .flag(value == "true") }
            return .flag(["local", "verified", "published", "visible", "enabled", "active", "public", "discoverable", "indexable",
                          "available", "open"].contains(word))
        case "UUID": return .uuid
        case "Data": return .data
        default: return .other
        }
    }

    /// `creatorID` → `creator`, `community_id` → `community`, `mediaIDs` → `media`: what an id field names.
    static func idStem(_ name: String, plural: Bool) -> String? {
        let suffixes = plural ? ["IDs", "Ids", "_ids"] : ["ID", "Id", "_id"]
        for suffix in suffixes where name.hasSuffix(suffix) && name.count > suffix.count {
            return String(name.dropLast(suffix.count))
        }
        return nil
    }

    /// The record type an id field's stem names: the API's own type of that name, the person for `creator`, the
    /// record's own type for `parent`.
    static func referenced(_ stem: String, in entity: Entity, records: [String], person: String?) -> String? {
        var candidates = [stem]
        if let index = stem.lastIndex(where: { $0.isUppercase }), index != stem.startIndex { candidates.append(String(stem[index...])) }
        for candidate in candidates {
            let upper = SwiftName.upperCamel(candidate)
            if let exact = records.first(where: { $0 == upper }) { return exact }
            let normalized = SwiftName.normalized(candidate)
            if parentWords.contains(normalized), records.contains(entity.name) { return entity.name }
            if personWords.contains(normalized), let person { return person }
            if let suffixed = records.first(where: { $0.hasSuffix(upper) }) { return suffixed }
        }
        return nil
    }

    private static func stringRole(_ word: String, siblings: Set<String>, doc: String, entity: Entity) -> FieldRole {
        let format: TextFormat = doc.contains("markdown") || word.contains("markdown") ? .markdown
            : doc.contains("html") || word.contains("html") ? .html : .plain
        let named = siblings.contains("displayname") || siblings.contains("title") || siblings.contains("fullname")
            || siblings.contains("realname") || siblings.contains("preferredname")
        if ["username", "handle", "acct", "login", "slug", "screenname", "preferredusername", "userhandle"].contains(word) { return .handle }
        if word == "name" { return named ? .handle : .title }
        if ["displayname", "fullname", "realname", "nickname", "preferredname"].contains(word) { return .displayName }
        if ["title", "headline", "subject", "heading"].contains(word) { return .title }
        if ["body", "content", "text", "message", "markdown", "html", "comment", "story", "article", "review", "answer", "reply",
            "details", "post", "status", "contenthtml", "bodyhtml", "bodymarkdown"].contains(word) { return .body(format) }
        if ["description", "bio", "about", "summary", "note", "tagline", "blurb", "excerpt", "overview", "intro", "sidebar", "notes",
            "caption", "alt", "alttext", "info", "biography"].contains(word) { return .summary(format) }
        if ["spoilertext", "spoiler", "contentwarning", "cw", "warning"].contains(word) { return .warning }
        if word.contains("email") || word == "mail" { return .email }
        if ["password", "secret", "clientsecret", "token", "jwt", "accesstoken", "refreshtoken", "apikey", "authtoken", "sessiontoken",
            "idtoken", "deletetoken"].contains(word) { return .secret }
        if ["path", "ltree"].contains(word) { return .path }
        if ["language", "lang", "locale", "languagecode"].contains(word) { return .language }
        if ["color", "colour", "hex", "tint", "accentcolor", "accentcolour"].contains(word) { return .color }
        if word.hasSuffix("url") || word.hasSuffix("uri") || ["link", "href", "website", "homepage", "permalink"].contains(word) {
            return urlRole(word, siblings: siblings)
        }
        if ["avatar", "icon", "banner", "image", "photo", "picture", "thumbnail", "cover", "header", "logo", "file"].contains(word) {
            return urlRole(word, siblings: siblings)
        }
        return .text
    }

    private static func urlRole(_ word: String, siblings: Set<String>) -> FieldRole {
        let wide = ["banner", "header", "cover", "backdrop", "background", "headerurl", "bannerurl", "coverurl", "headerstatic"]
        if wide.contains(word) { return .image(.wide) }
        let faces = ["avatar", "avatarurl", "avatarstatic", "profileimage", "profilepicture", "picture", "photourl", "headshot"]
        let things = ["icon", "image", "photo", "thumbnail", "thumbnailurl", "thumb", "imageurl", "iconurl", "logo", "logourl",
                      "preview", "previewurl", "poster", "artwork", "screenshot", "media", "mediaurl", "file", "fileurl"]
        let isPerson = siblings.contains("displayname") || siblings.contains("username") || siblings.contains("acct") || siblings.contains("bio")
        if faces.contains(word) { return .image(isPerson || word.hasPrefix("avatar") ? .person : .thing) }
        if things.contains(word) { return .image(word == "icon" && isPerson ? .person : .thing) }
        if ["actorid", "actor", "uri", "permalink", "profileurl", "profile", "ap", "apid", "webfinger"].contains(word) { return .page }
        let handled = siblings.contains("displayname") || siblings.contains("username") || siblings.contains("acct") || siblings.contains("title")
        if word == "url", handled, !siblings.contains("body") { return .page }
        return .link
    }

    private static func intRole(_ word: String) -> FieldRole {
        if ["score", "points", "karma", "hotrank", "rank"].contains(word) { return .score }
        if ["upvotes", "ups", "upvotecount"].contains(word) { return .upvotes }
        if ["downvotes", "downs", "dislikes", "downvotecount"].contains(word) { return .downvotes }
        if ["myvote", "vote", "uservote", "myreaction", "myscore"].contains(word) { return .vote }
        if ["depth", "level", "indent", "indentlevel"].contains(word) { return .depth }
        if word.hasSuffix("count") || word.hasSuffix("counts") || word.hasPrefix("number") || word.hasPrefix("num")
            || word == "total" || word.hasSuffix("total") || word.hasPrefix("total") || word.hasPrefix("usersactive") {
            return .count(word)
        }
        let counted: Set<String> = ["comments", "posts", "replies", "likes", "favourites", "favorites", "reblogs", "boosts", "shares",
                                    "views", "followers", "following", "subscribers", "members", "users", "children", "downloads",
                                    "plays", "reactions", "votes", "reports", "answers", "reviews", "statuses", "items", "saves",
                                    "bookmarks", "comment", "post", "reply", "communities", "visits", "readers"]
        if counted.contains(word) { return .count(word) }
        return .number
    }
}
