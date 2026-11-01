//  WHAT: The mock backend's runtime, as the files a client package carries in `Sources/<Module>/Mocks/`: the JSON it
//        reads and writes, the routes and their answers, the server that answers in the process, the scenarios, and
//        the switch an app's services read. `__CLIENT__` is the client's type.
//  PIN:  ONE RUNTIME, EVERY API. What differs between APIs is data (`<Client>+Mock.swift`'s routes, the fixtures);
//        these files are the same for every package, so a package's mock behaves as every other's does.

enum RuntimeTemplates {
    /// `MockJSON.swift`: the JSON the mock backend reads, cuts and writes.
    static let mockJSON = #"""
    import Foundation

    /// A JSON value as the mock backend reads and writes it: a fixture parsed, cut into a page, searched, echoed.
    enum MockJSON: Hashable, Sendable {
        case null
        case bool(Bool)
        case int(Int)
        case double(Double)
        case string(String)
        case array([MockJSON])
        case object([String: MockJSON])

        /// `text` read as JSON; nil when it is not JSON.
        init?(parsing text: String) {
            self.init(data: Data(text.utf8))
        }

        /// `data` read as JSON; nil when it is not JSON.
        init?(data: Data) {
            guard let value = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) else { return nil }
            self.init(foundation: value)
        }

        private init(foundation value: Any) {
            switch value {
            case let number as NSNumber:
                if CFGetTypeID(number) == CFBooleanGetTypeID() {
                    self = .bool(number.boolValue)
                } else if CFNumberIsFloatType(number) {
                    self = .double(number.doubleValue)
                } else {
                    self = .int(number.intValue)
                }
            case let text as String:
                self = .string(text)
            case let array as [Any]:
                self = .array(array.map(MockJSON.init(foundation:)))
            case let object as [String: Any]:
                self = .object(object.mapValues(MockJSON.init(foundation:)))
            default:
                self = .null
            }
        }

        /// The value at `path`, one object key a step; nil when a key is missing.
        subscript(path: [String]) -> MockJSON? {
            var value = self
            for key in path {
                guard case .object(let object) = value, let next = object[key] else { return nil }
                value = next
            }
            return value
        }

        /// Sets the value at `path`, making the objects on the way.
        mutating func set(_ path: [String], to value: MockJSON) {
            guard let key = path.first else {
                self = value
                return
            }
            var object: [String: MockJSON] = [:]
            if case .object(let existing) = self { object = existing }
            var child = object[key] ?? .null
            child.set(Array(path.dropFirst()), to: value)
            object[key] = child
            self = .object(object)
        }

        /// The value as a query or a path says it (`42`, `true`, `Hot`); nil for null, a list or an object.
        var text: String? {
            switch self {
            case .string(let text): return text
            case .int(let value): return String(value)
            case .double(let value): return value == value.rounded() && abs(value) < 1e15 ? String(Int(value)) : String(value)
            case .bool(let value): return value ? "true" : "false"
            case .null, .array, .object: return nil
            }
        }

        /// Whether the value says `wanted`, as a request writes it: `42` is the number 42, a name in any case.
        func says(_ wanted: String) -> Bool {
            guard let text else { return false }
            return text == wanted || text.caseInsensitiveCompare(wanted) == .orderedSame
        }

        /// Whether any text the value holds, a picture's or a link's aside, contains `query`, in any case.
        func contains(_ query: String) -> Bool {
            switch self {
            case .string(let text):
                guard !text.hasPrefix(MockImages.scheme), !text.hasPrefix("http") else { return false }
                return text.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil
            case .array(let items): return items.contains { $0.contains(query) }
            case .object(let object): return object.values.contains { $0.contains(query) }
            case .null, .bool, .int, .double: return false
            }
        }

        /// The value with every string it holds passed through `transform`.
        func mapStrings(_ transform: (String) -> String) -> MockJSON {
            switch self {
            case .string(let text): return .string(transform(text))
            case .array(let items): return .array(items.map { $0.mapStrings(transform) })
            case .object(let object): return .object(object.mapValues { $0.mapStrings(transform) })
            case .null, .bool, .int, .double: return self
            }
        }

        /// The value as JSON text: keys sorted, slashes as they are.
        var json: String {
            var out = ""
            write(into: &out)
            return out
        }

        private func write(into out: inout String) {
            switch self {
            case .null: out += "null"
            case .bool(let value): out += value ? "true" : "false"
            case .int(let value): out += String(value)
            case .double(let value): out += value.isFinite ? String(value) : "null"
            case .string(let text): Self.quote(text, into: &out)
            case .array(let items):
                out += "["
                for (index, item) in items.enumerated() {
                    if index > 0 { out += "," }
                    item.write(into: &out)
                }
                out += "]"
            case .object(let object):
                out += "{"
                for (index, key) in object.keys.sorted().enumerated() {
                    if index > 0 { out += "," }
                    Self.quote(key, into: &out)
                    out += ":"
                    object[key]?.write(into: &out)
                }
                out += "}"
            }
        }

        private static func quote(_ text: String, into out: inout String) {
            out += "\""
            for scalar in text.unicodeScalars {
                switch scalar {
                case "\"": out += "\\\""
                case "\\": out += "\\\\"
                case "\n": out += "\\n"
                case "\r": out += "\\r"
                case "\t": out += "\\t"
                case let control where control.value < 0x20: out += String(format: "\\u%04x", control.value)
                default: out.unicodeScalars.append(scalar)
                }
            }
            out += "\""
        }
    }

    """#

    /// `MockAnswer.swift`: how a route answers, and the parts of each answer.
    static let mockAnswer = #"""
    import Foundation

    /// How a route of the mock backend answers.
    enum MockAnswer: Sendable {
        /// A fixture as it is, with its status.
        case fixture(String, status: Int = 200)
        /// Bytes as they are, with their content type: a picture, a text.
        case body(Data, contentType: String)
        /// No body (204): a delete, an action that answers nothing.
        case nothing
        /// The items of a list, narrowed by the request and cut into the page it asks for.
        case list(List)
        /// One item, found by a value the request names, set into its response.
        case lookup(Lookup)
        /// What the request's body made: its fixture with the body's values, a new id and the time.
        case echo(Echo)

        /// A list endpoint: the items its fixture's pages hold, narrowed by the request's filters and search, ordered by
        /// its sort, and cut into the page it asks for.
        struct List: Sendable {
            /// The list's pages, each a response as the server sends it.
            var pages: [String]
            /// The key of the items in a response; nil when a response is the list itself.
            var items: String?
            /// How a request asks for the page after the one it has.
            var paging: Paging
            /// The query parameter that says how many items a page holds; `size` when the request says none.
            var limit: String?
            var size: Int
            /// Query parameters that narrow the list, each with the path of the value it must equal in an item.
            var filters: [String: [String]]
            /// Query parameters whose text an item must contain somewhere: a search.
            var search: [String]
            /// The query parameter that orders the list, and the order each of its values asks for.
            var sort: Sort?
            /// Keys of a response that count the items: set to the count of the narrowed list.
            var totals: [String]

            init(pages: [String], items: String?, paging: Paging = .none, limit: String? = nil, size: Int = 20,
                 filters: [String: [String]] = [:], search: [String] = [], sort: Sort? = nil, totals: [String] = []) {
                self.pages = pages
                self.items = items
                self.paging = paging
                self.limit = limit
                self.size = size
                self.filters = filters
                self.search = search
                self.sort = sort
                self.totals = totals
            }
        }

        /// How a list endpoint asks for the page after the one it has.
        enum Paging: Sendable {
            /// Not paged: every item at once.
            case none
            /// A page number in the query parameter, from 1.
            case page(String)
            /// A cursor in the query parameter: the value at `id` of the last item of the page before (its place in the
            /// list when `id` is empty). The next cursor is the response's `next` key, or a `Link` header when it is nil.
            case cursor(String, id: [String], next: String?)
        }

        /// The query parameter that orders a list, and the order each of its values asks for.
        struct Sort: Sendable {
            var parameter: String
            /// A value's order: the path of what it orders by, and whether the most comes first.
            var orders: [String: (path: [String], descending: Bool)]
        }

        /// An endpoint that answers one item, found by a value of the request, put into its response with the lists
        /// that refer to it.
        struct Lookup: Sendable {
            /// Where the request says the value.
            var key: Key
            /// Where the items are.
            var items: Items
            /// The path of the value in an item that the request's value names.
            var match: [String]
            /// The response the item goes into, and where; no response: the item is the response.
            var response: String?
            var place: [String]
            /// Lists of the response filled with the items that refer to the one found.
            var related: [Related]

            init(key: Key, items: Items, match: [String], response: String? = nil, place: [String] = [], related: [Related] = []) {
                self.key = key
                self.items = items
                self.match = match
                self.response = response
                self.place = place
                self.related = related
            }
        }

        /// Where a request says the value a lookup finds an item by.
        enum Key: Sendable {
            /// A `{name}` segment of the path.
            case path(String)
            /// A query parameter.
            case query(String)
            /// A key of the JSON body.
            case body(String)
        }

        /// Where a lookup's items are.
        enum Items: Sendable {
            /// The items of another route's list, or the value at `at` in each of them.
            case route(HTTPMethod, String, at: [String]? = nil)
            /// Items of its own, each as JSON.
            case own([String])
        }

        /// A list in a lookup's response: the items whose value at `match` is the found item's value at `to`.
        struct Related: Sendable {
            var place: [String]
            var items: Items
            var match: [String]
            var to: [String]
            /// At most this many.
            var limit: Int?

            init(place: [String], items: Items, match: [String], to: [String], limit: Int? = nil) {
                self.place = place
                self.items = items
                self.match = match
                self.to = to
                self.limit = limit
            }
        }

        /// An endpoint that makes something from the request's body.
        struct Echo: Sendable {
            /// The response, as a fixture.
            var response: String
            /// Where the made item is in the response; empty: the response is the item.
            var place: [String]
            /// The made item's id key, given a new value; its date keys, set to now.
            var id: String?
            var dates: [String]
            /// Items the body refers to, brought into the response.
            var joins: [Join]

            init(response: String, place: [String] = [], id: String? = nil, dates: [String] = [], joins: [Join] = []) {
                self.response = response
                self.place = place
                self.id = id
                self.dates = dates
                self.joins = joins
            }
        }

        /// An item a body refers to (its `community_id`), found and set into the response (its `post_view.community`).
        struct Join: Sendable {
            var body: String
            var items: Items
            var match: [String]
            var place: [String]
        }
    }

    """#

    /// `MockRoute.swift`: a route: a method and a path, matched with its `{name}` segments.
    static let mockRoute = #"""
    import Foundation

    /// One endpoint of the mock backend: the requests it answers, a method and a path (`{name}` stands for one
    /// segment), and how it answers them.
    struct MockRoute: Sendable {
        var method: HTTPMethod
        var path: String
        var answer: MockAnswer

        init(_ method: HTTPMethod, _ path: String, _ answer: MockAnswer) {
            self.method = method
            self.path = path
            self.answer = answer
        }

        /// The values of the path's `{name}` segments when a request with `method` and `path` is this route's; nil when
        /// it is not.
        func parameters(_ method: String, _ path: String) -> [String: String]? {
            guard method == self.method.rawValue else { return nil }
            let expected = self.path.split(separator: "/"), given = path.split(separator: "/")
            guard expected.count == given.count else { return nil }
            var values: [String: String] = [:]
            for (segment, value) in zip(expected, given) {
                if segment.hasPrefix("{"), segment.hasSuffix("}") {
                    values[String(segment.dropFirst().dropLast())] = String(value).removingPercentEncoding ?? String(value)
                } else if segment != value {
                    return nil
                }
            }
            return values
        }
    }

    """#

    /// `MockServer.swift`: the transport that answers in the process.
    static let mockServer = #"""
    import Foundation
    import os

    /// The mock backend: a transport that answers the client in the process, from the fixtures, the way the API would:
    /// a list narrowed by the request and cut into the page it asks for, an item found by the value it names, a body
    /// echoed back as what it made, a 404 for what is not there. Nothing leaves the device.
    ///
    /// ```swift
    /// let client = __CLIENT__.mock(.failing, latency: .zero)
    /// (client.transport as? MockServer)?.scenario = .normal   // a test may change how it answers between two calls
    /// ```
    public final class MockServer: HTTPTransport, Sendable {
        private struct State: Sendable {
            var scenario: MockScenario
            var requests: [URLRequest] = []
            var made = 0
            var parsed: [String: MockJSON] = [:]
        }

        let routes: [MockRoute]
        /// How long an answer takes.
        public let latency: Duration
        /// How long an answer takes in the `slow` scenario.
        public let slowLatency: Duration
        private let state: OSAllocatedUnfairLock<State>

        init(routes: [MockRoute], scenario: MockScenario = .normal, latency: Duration = .milliseconds(250),
             slowLatency: Duration = .seconds(3)) {
            self.routes = routes
            self.latency = latency
            self.slowLatency = slowLatency
            self.state = OSAllocatedUnfairLock(initialState: State(scenario: scenario))
        }

        /// How it answers. A test may change it between calls: a load that fails, then a retry that works.
        public var scenario: MockScenario {
            get { state.withLock { $0.scenario } }
            set { state.withLock { $0.scenario = newValue } }
        }

        /// Every request sent, in order: the last 500.
        public var requests: [URLRequest] { state.withLock { $0.requests } }

        public func send(_ request: URLRequest) async throws -> HTTPResponse {
            let scenario = state.withLock { state -> MockScenario in
                state.requests.append(request)
                if state.requests.count > 500 { state.requests.removeFirst(state.requests.count - 500) }
                return state.scenario
            }
            let wait = scenario == .slow ? slowLatency : latency
            if wait > .zero { try await Task.sleep(for: wait) }
            switch scenario {
            case .failing: return failure(500)
            case .unauthorized: return failure(401)
            case .normal, .empty, .slow: break
            }
            let method = request.httpMethod?.uppercased() ?? "GET"
            let path = request.url?.path ?? "/"
            // A route whose segments are all literal wins over one with a `{name}` that also matches.
            let matched = routes.compactMap { route in route.parameters(method, path).map { (route, $0) } }
                .min { $0.1.count < $1.1.count }
            guard let (route, parameters) = matched else { return failure(404) }
            let empty = scenario == .empty
            switch route.answer {
            case .fixture(let text, let status): return respond(parsed(text), status: status)
            case .body(let data, let contentType): return HTTPResponse(status: 200, headers: ["Content-Type": contentType], body: data)
            case .nothing: return HTTPResponse(status: 204)
            case .list(let list): return answer(list, request: request, parameters: parameters, empty: empty)
            case .lookup(let lookup): return answer(lookup, request: request, parameters: parameters, empty: empty)
            case .echo(let echo): return answer(echo, request: request)
            }
        }

        // MARK: - Answers

        private func answer(_ list: MockAnswer.List, request: URLRequest, parameters: [String: String], empty: Bool) -> HTTPResponse {
            // A path's `{name}` narrows a list as a query parameter does (`/accounts/{id}/statuses`).
            let query = Self.query(of: request).merging(parameters) { asked, _ in asked }
            let pages = list.pages.map(parsed)
            var items = pages.flatMap { Self.items(of: $0, at: list.items) }
            for (parameter, path) in list.filters.sorted(by: { $0.key < $1.key }) {
                guard let wanted = query[parameter], !wanted.isEmpty else { continue }
                items = items.filter { $0[path]?.says(wanted) == true }
            }
            for parameter in list.search {
                guard let wanted = query[parameter]?.trimmingCharacters(in: .whitespaces), !wanted.isEmpty else { continue }
                items = items.filter { $0.contains(wanted) }
            }
            if let sort = list.sort, let value = query[sort.parameter], let order = sort.orders[value] {
                items = Self.sorted(items, by: order.path, descending: order.descending)
            }
            if empty { items = [] }
            let size = list.limit.flatMap { query[$0] }.flatMap { Int($0) }.map { max(1, $0) } ?? list.size
            var page: [MockJSON]
            var next: String?
            switch list.paging {
            case .none:
                page = items
            case .page(let parameter):
                let number = max(1, query[parameter].flatMap { Int($0) } ?? 1)
                let start = (number - 1) * size
                page = start < items.count ? Array(items[start..<min(start + size, items.count)]) : []
            case .cursor(let parameter, let id, _):
                var start = 0
                if let cursor = query[parameter], !cursor.isEmpty {
                    start = id.isEmpty ? Int(cursor) ?? items.count : items.firstIndex { $0[id]?.text == cursor }.map { $0 + 1 } ?? items.count
                }
                start = min(max(0, start), items.count)
                page = Array(items[start..<min(start + size, items.count)])
                if start + size < items.count, let last = page.last { next = id.isEmpty ? String(start + size) : last[id]?.text }
            }
            var response: MockJSON = .array(page)
            if let key = list.items {
                response = pages.first ?? .object([:])
                response.set([key], to: .array(page))
            }
            for key in list.totals { response.set([key], to: .int(items.count)) }
            var headers: [String: String] = [:]
            if case .cursor(let parameter, _, let key) = list.paging {
                if let key {
                    let numeric: Bool = { if case .int? = pages.first?[[key]] { return true } else { return false } }()
                    let value: MockJSON = next.map { numeric ? Int($0).map(MockJSON.int) ?? .string($0) : .string($0) } ?? .null
                    response.set([key], to: value)
                } else if let next, let url = Self.url(request.url, setting: parameter, to: next) {
                    headers["Link"] = "<\(url.absoluteString)>; rel=\"next\""
                }
            }
            return respond(response, headers: headers)
        }

        private func answer(_ lookup: MockAnswer.Lookup, request: URLRequest, parameters: [String: String], empty: Bool) -> HTTPResponse {
            let wanted: String?
            switch lookup.key {
            case .path(let name): wanted = parameters[name]
            case .query(let name): wanted = Self.query(of: request)[name]
            case .body(let key): wanted = request.httpBody.flatMap { MockJSON(data: $0) }?[[key]]?.text
            }
            guard let wanted else { return failure(400) }
            guard !empty, let item = items(lookup.items).first(where: { $0[lookup.match]?.says(wanted) == true }) else { return failure(404) }
            var response = lookup.response.map(parsed) ?? item
            response.set(lookup.place, to: item)
            for related in lookup.related {
                guard let value = item[related.to]?.text else { continue }
                var list = items(related.items).filter { $0[related.match]?.says(value) == true }
                if let limit = related.limit { list = Array(list.prefix(limit)) }
                response.set(related.place, to: .array(list))
            }
            return respond(response)
        }

        private func answer(_ echo: MockAnswer.Echo, request: URLRequest) -> HTTPResponse {
            var response = parsed(echo.response)
            let body = request.httpBody.flatMap { MockJSON(data: $0) }
            var made = response[echo.place] ?? .object([:])
            // The body's values over the made item's, where the item has the key.
            if case .object(let sent)? = body, case .object(var fields) = made {
                for (key, value) in sent where fields[key] != nil { fields[key] = value }
                made = .object(fields)
            }
            let number = state.withLock { state -> Int in
                state.made += 1
                return state.made
            }
            if let key = echo.id {
                switch made[[key]] {
                case .int(let old)?: made.set([key], to: .int(old + 1_000_000 + number))
                case .string(let old)?: made.set([key], to: .string("\(old)-\(number)"))
                default: break
                }
            }
            let now = Self.iso(Date())
            for key in echo.dates { made.set([key], to: .string(now)) }
            response.set(echo.place, to: made)
            for join in echo.joins {
                guard let value = body?[[join.body]]?.text,
                      let found = items(join.items).first(where: { $0[join.match]?.says(value) == true }) else { continue }
                response.set(join.place, to: found)
            }
            return respond(response)
        }

        /// The API's error body for `status`, saying what went wrong as a server would.
        private func failure(_ status: Int) -> HTTPResponse {
            let message: String
            switch status {
            case 400: message = "The request is missing something it needs."
            case 401: message = "Your session has ended. Sign in again to continue."
            case 404: message = "That could not be found. It may have been removed."
            default: message = "The server ran into a problem. Try again in a moment."
            }
            return respond(MockFixtures.errorBody(message), status: status)
        }

        // MARK: - Fixtures

        /// The items `source` names, each as JSON.
        private func items(_ source: MockAnswer.Items) -> [MockJSON] {
            switch source {
            case .route(let method, let path, let at):
                guard let route = routes.first(where: { $0.method == method && $0.path == path }),
                      case .list(let list) = route.answer else { return [] }
                let all = list.pages.map(parsed).flatMap { Self.items(of: $0, at: list.items) }
                guard let at else { return all }
                return all.compactMap { $0[at] }
            case .own(let texts):
                return texts.map(parsed)
            }
        }

        /// A fixture read once, its dates moved by the time since it was written.
        private func parsed(_ text: String) -> MockJSON {
            if let known = state.withLock({ $0.parsed[text] }) { return known }
            let shift = Date().timeIntervalSince(MockFixtures.writtenAt)
            let json = (MockJSON(parsing: text) ?? .null).mapStrings { Self.moved($0, by: shift) }
            state.withLock { $0.parsed[text] = json }
            return json
        }

        private func respond(_ json: MockJSON, status: Int = 200, headers: [String: String] = [:]) -> HTTPResponse {
            var headers = headers
            headers["Content-Type"] = "application/json"
            let body = json.mapStrings(MockImages.resolve).json
            return HTTPResponse(status: status, headers: headers, body: Data(body.utf8))
        }

        // MARK: - Helpers

        private static func items(of response: MockJSON, at key: String?) -> [MockJSON] {
            let list = key.map { response[[$0]] } ?? response
            if case .array(let items)? = list { return items }
            return []
        }

        private static func query(of request: URLRequest) -> [String: String] {
            guard let url = request.url, let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems else { return [:] }
            var query: [String: String] = [:]
            for item in items { query[item.name] = item.value ?? "" }
            return query
        }

        private static func sorted(_ items: [MockJSON], by path: [String], descending: Bool) -> [MockJSON] {
            items.enumerated().sorted { a, b in
                let left = a.element[path], right = b.element[path]
                let ordered: Bool?
                switch (left, right) {
                case (.int(let x)?, .int(let y)?): ordered = x == y ? nil : x < y
                case (.double(let x)?, .double(let y)?): ordered = x == y ? nil : x < y
                default:
                    let x = left?.text ?? "", y = right?.text ?? ""
                    ordered = x == y ? nil : x < y
                }
                guard let ordered else { return a.offset < b.offset }
                return descending ? !ordered : ordered
            }.map(\.element)
        }

        /// `url` with the query parameter `name` set to `value`: the next page's address, for a `Link` header.
        private static func url(_ url: URL?, setting name: String, to value: String) -> URL? {
            guard let url, var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
            var items = (components.queryItems ?? []).filter { $0.name != name }
            items.append(URLQueryItem(name: name, value: value))
            components.queryItems = items
            return components.url
        }

        /// `text` moved by `shift` seconds when it is a date as the fixtures write it (`2026-10-28T14:03:00Z`).
        private static func moved(_ text: String, by shift: TimeInterval) -> String {
            guard text.count == 20, text.hasSuffix("Z"), text.dropFirst(10).first == "T",
                  let date = try? Date(text, strategy: .iso8601) else { return text }
            return iso(date.addingTimeInterval(shift))
        }

        private static func iso(_ date: Date) -> String {
            date.formatted(.iso8601)
        }
    }

    """#

    /// `MockScenario.swift`: the ways the mock backend answers.
    static let mockScenario = #"""
    import Foundation

    /// How the mock backend answers: as the API does on a good day, or as it does when something goes wrong, so a
    /// screen's empty, error, signed-out and loading states can be seen, tested and captured.
    public enum MockScenario: String, CaseIterable, Sendable {
        /// Every endpoint answers with its fixtures.
        case normal
        /// Every list answers with no items, and nothing is found by its id.
        case empty
        /// Every request fails with a server error (500) and the API's error body.
        case failing
        /// Every request is refused (401) with the API's error body: signed out, or the session ended.
        case unauthorized
        /// Every answer comes, after a long wait: for loading states.
        case slow
    }

    """#

    /// `MockMode.swift`: when the app runs on the mock, and `<Client>.current`.
    static let mockMode = #"""
    import Foundation
    import os

    /// Whether the app runs on the mock backend instead of the live API: what `__CLIENT__.current` reads.
    ///
    /// On when the app is launched with `-mock YES` (a launch argument, as UI tests and screenshots pass it) or with
    /// `MOCK=1` in its environment, in Xcode's previews, and in a test run; `-mock NO` or `MOCK=0` turns it off. A
    /// scenario is picked with `-mockScenario empty` or `MOCK_SCENARIO=empty`.
    public enum MockMode {
        /// Whether the mock backend answers.
        public static var isOn: Bool {
            let environment = ProcessInfo.processInfo.environment
            if let said = UserDefaults.standard.string(forKey: "mock") { return isYes(said) }
            if let said = environment["MOCK"] { return isYes(said) }
            return environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" || isTesting
        }

        /// The scenario the mock backend answers in: `normal` unless the launch names another.
        public static var scenario: MockScenario {
            let said = UserDefaults.standard.string(forKey: "mockScenario") ?? ProcessInfo.processInfo.environment["MOCK_SCENARIO"]
            return said.flatMap { MockScenario(rawValue: $0.lowercased()) } ?? .normal
        }

        /// Whether the process is a test run, XCTest's or Swift Testing's: a test never reaches a live server.
        static var isTesting: Bool {
            let environment = ProcessInfo.processInfo.environment
            return environment["XCTestConfigurationFilePath"] != nil || environment["XCTestBundlePath"] != nil
                || environment["XCTestSessionIdentifier"] != nil || NSClassFromString("XCTestCase") != nil
        }

        private static func isYes(_ text: String) -> Bool {
            ["1", "yes", "true", "on"].contains(text.lowercased())
        }
    }

    extension __CLIENT__ {
        /// The client the app's services use: the mock backend when `MockMode.isOn`, the live API otherwise. A test may
        /// put another in its place (a failing mock) and put it back.
        ///
        /// ```swift
        /// let answer = try await __CLIENT__.current.__EXAMPLE_CALL__
        /// __CLIENT__.current = .mock(.failing, latency: .zero)
        /// ```
        public static var current: __CLIENT__ {
            get { currentClient.withLock { $0 } }
            set { currentClient.withLock { $0 = newValue } }
        }

        /// Where `current` is kept: made the first time it is read, from `MockMode`.
        private static let currentClient = OSAllocatedUnfairLock(
            initialState: MockMode.isOn ? __CLIENT__.mock(MockMode.scenario) : __CLIENT__())
    }

    """#

}
