//  WHAT: The client package as `mocks` reads it: its names (`LemmyKit`, `LemmyClient`, `LemmyCoding`), its base URL,
//        auth, JSON keys and dates, its types, and every endpoint as the method `network` wrote, resolved from the
//        lines in its `api.json` exactly as `network` resolves them.
//  PIN:  EVERY PROBLEM AT ONCE. A line that cannot be read, a type no line declares: one sentence each, all of them,
//        and nothing is written.

import Foundation

struct ClientAPI: Sendable {
    /// The package, the library and the module: `LemmyKit`.
    var module: String
    /// What the package's types are named by: `Lemmy` (`LemmyClient`, `LemmyError`, `LemmyCoding`).
    var stem: String
    var baseURL: String?
    /// `none`, `bearer`, `basic`, `header` or `query`.
    var auth: String
    /// Whether JSON keys are snake_case.
    var snake: Bool
    var dates: [String]
    var feeds: Bool
    var entities: [Entity]
    var methods: [ClientMethod]

    var client: String { stem + "Client" }
    var errorType: String { stem + "Error" }
    var codingType: String { stem + "Coding" }

    func entity(_ name: String) -> Entity? { entities.first { $0.name == name } }

    static let primitives: Set<String> = ["String", "Int", "Int64", "Int32", "Int16", "Int8", "UInt", "UInt64", "UInt32",
                                          "UInt16", "UInt8", "Double", "Float", "Bool", "Date", "URL", "UUID", "Decimal", "Data"]

    /// The package `record` describes, its lines read and its endpoints resolved; every problem at once.
    static func resolve(_ record: APIRecord) throws -> ClientAPI {
        var reasons: [String] = []
        var entities: [Entity] = []
        for line in record.entities where !line.trimmingCharacters(in: .whitespaces).isEmpty {
            do { entities.append(try EntityLine.parse(line)) } catch { reasons.append("\(error)") }
        }
        var endpoints: [Endpoint] = []
        for line in record.endpoints where !line.trimmingCharacters(in: .whitespaces).isEmpty {
            do { endpoints.append(try EndpointLine.parse(line)) } catch { reasons.append("\(error)") }
        }
        let known = Set(entities.map(\.name))
        for entity in entities {
            let mentioned = entity.fields.flatMap(\.type.names) + entity.cases.flatMap { $0.values.flatMap(\.type.names) }
            for name in Set(mentioned).sorted() where !known.contains(name) && !primitives.contains(name) {
                reasons.append("`\(entity.name)` names `\(name)`, which no entity line declares")
            }
        }
        var api = ClientAPI(module: record.name, stem: stem(of: record.name), baseURL: record.baseURL, auth: record.auth,
                            snake: record.coding == "snake", dates: record.dates, feeds: record.feeds, entities: entities, methods: [])
        let paging = record.paging
        for endpoint in endpoints {
            let (method, problems) = api.method(for: endpoint, paging: paging)
            reasons += problems
            if let method { api.methods.append(method) }
        }
        guard reasons.isEmpty else { throw MocksError.refused(reasons) }
        return api
    }

    /// `RecipeKit` → `Recipe`, `MastodonAPI` → `Mastodon`, `Lemmy` → `Lemmy`.
    static func stem(of module: String) -> String {
        for suffix in ["Kit", "API", "SDK", "Client"] where module.hasSuffix(suffix) && module.count > suffix.count {
            let stem = String(module.dropLast(suffix.count))
            if SwiftName.isTypeName(stem) { return stem }
        }
        return module
    }

    static func isPageName(_ wire: String) -> Bool { ["page", "pagenumber", "pageno"].contains(SwiftName.normalized(wire)) }

    static func isCursorName(_ wire: String) -> Bool {
        ["cursor", "pagecursor", "maxid", "after", "pagetoken", "nextpagetoken", "nexttoken", "continuation",
         "continuationtoken", "nextcursor", "next", "startcursor", "startafter"].contains(SwiftName.normalized(wire))
    }

    static func isCountName(_ wire: String) -> Bool {
        ["page", "pagenumber", "pageno", "limit", "perpage", "pagesize", "offset", "count", "size"].contains(SwiftName.normalized(wire))
    }

    static let nextFieldNames = ["nextpage", "nextcursor", "nextpagecursor", "cursor", "next", "nextpagetoken", "nexttoken",
                                 "pagetoken", "after", "endcursor", "continuation", "continuationtoken"]
    static let tokenFieldNames = ["token", "accesstoken", "jwt", "authtoken", "sessiontoken", "idtoken", "bearertoken",
                                  "apitoken", "apikey", "key"]

    /// The method `endpoint` is, as `network` names and pages it, or the reasons it cannot be read.
    func method(for endpoint: Endpoint, paging pagingKind: String) -> (ClientMethod?, [String]) {
        var reasons: [String] = []
        let signature = "`\(endpoint.signature)`"
        func check(_ type: TypeRef) {
            for name in type.names where !Self.primitives.contains(name) && entity(name) == nil {
                reasons.append("\(signature) names `\(name)`, which no entity line declares")
            }
        }
        func argument(_ parameter: Endpoint.Parameter) -> ClientMethod.Argument {
            var type = parameter.type
            if !parameter.typed, Self.isCountName(parameter.wire) { type = .named("Int") }
            return .init(wire: parameter.wire, name: SwiftName.camel(parameter.wire), type: type, required: parameter.required)
        }
        let path = endpoint.pathParameters.map(argument)
        let query = endpoint.query.map(argument)
        var body: TypeRef?
        var multipart = false
        switch endpoint.body {
        case .json(let type)?: check(type); body = type
        case .multipart?: multipart = true
        case nil: break
        }
        let answer: ClientMethod.Answer
        switch endpoint.response {
        case nil: answer = .nothing
        case .named("Data")?: answer = .data
        case .named("String")?: answer = .text
        case let type?: check(type); answer = .json(type)
        }
        let name = endpoint.name ?? Self.defaultName(endpoint)

        var plan: ClientMethod.Paging?
        if endpoint.paged, pagingKind != "none", case .json(let type) = answer, let items = itemsOf(endpoint, type) {
            let limit = query.first { ["limit", "perpage", "pagesize", "count"].contains(SwiftName.normalized($0.wire)) && $0.type == .named("Int") }
            if pagingKind == "page", let marker = query.first(where: { Self.isPageName($0.wire) }) {
                plan = .init(item: items.item, itemsField: items.field, marker: marker, next: .number, limit: limit)
            } else if pagingKind == "cursor", let marker = query.first(where: { Self.isCursorName($0.wire) }) {
                var next = ClientMethod.Next.link
                if case .named(let typeName) = type, let entity = entity(typeName),
                   let field = entity.fields.first(where: { Self.nextFieldNames.contains(SwiftName.normalized($0.name)) }),
                   [.named("String"), .named("Int")].contains(field.type.unwrapped) {
                    next = .field(field.name, field.type)
                }
                plan = .init(item: items.item, itemsField: items.field, marker: marker, next: next, limit: limit)
            }
        }

        var token: String?
        if endpoint.storesToken {
            switch answer {
            case .text: token = ""
            case .json(.named(let type)):
                if let entity = entity(type) {
                    let field = endpoint.tokenField.flatMap { name in entity.fields.first { $0.name == name } }
                        ?? entity.fields.first { Self.tokenFieldNames.contains(SwiftName.normalized($0.name)) }
                    token = field?.name
                }
            default: break
            }
        }
        guard reasons.isEmpty else { return (nil, reasons) }
        return (ClientMethod(endpoint: endpoint, name: name, path: path, query: query, body: body, multipart: multipart,
                             answer: answer, paging: plan, tokenField: token), [])
    }

    /// The type of one item of a paged endpoint and the field that holds them.
    private func itemsOf(_ endpoint: Endpoint, _ type: TypeRef) -> (item: TypeRef, field: String?)? {
        if case .array(let element) = type { return (element, nil) }
        guard case .named(let name) = type, let entity = entity(name), !entity.isEnum else { return nil }
        func element(of field: Field) -> TypeRef? {
            if case .array(let element) = field.type.unwrapped { return element }
            return nil
        }
        if let named = endpoint.itemsField {
            guard let field = entity.fields.first(where: { $0.name == named }), let item = element(of: field) else { return nil }
            return (item, field.name)
        }
        let lists = entity.fields.filter { element(of: $0) != nil }
        guard lists.count == 1, let field = lists.first, let item = element(of: field) else { return nil }
        return (item, field.name)
    }

    /// The path's segments after an `api` and a version: `/api/v3/post/list` → `post`, `list`.
    static func resourceSegments(_ path: String) -> [String] {
        var segments = path.split(separator: "/").map(String.init).filter { !$0.hasPrefix("{") }
        while let first = segments.first,
              first.lowercased() == "api" || first.range(of: #"^[vV]\d+(\.\d+)?$"#, options: .regularExpression) != nil {
            segments.removeFirst()
        }
        return segments.filter { EndpointLine.isWireName($0) }
    }

    /// `GET /api/v3/post/list` → `postList`; `DELETE /api/v1/statuses/{id}` → `deleteStatuses`.
    static func defaultName(_ endpoint: Endpoint) -> String {
        let words = resourceSegments(endpoint.path)
        let joined = words.map(SwiftName.upperCamel).joined()
        if endpoint.method == "GET" {
            return joined.isEmpty ? "root" : joined.prefix(1).lowercased() + joined.dropFirst()
        }
        return endpoint.method.lowercased() + joined
    }
}
