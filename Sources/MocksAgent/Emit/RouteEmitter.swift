//  WHAT: `<Client>+Mock.swift`: `mock(_:latency:)`, the client on the mock backend, signed in, and the routes that
//        say how the mock answers each endpoint, one `MockRoute` a line of the API.

import Foundation

struct RouteEmitter {
    let api: ClientAPI

    func file(plans: [(method: ClientMethod, plan: RoutePlan, constants: [FixtureConstant])], example: String, theme: Theme) -> String {
        let client = api.client
        let base = api.baseURL ?? "https://\(SwiftName.normalized(api.stem)).example"
        var lines = ["import Foundation", "", "extension \(client) {"]
        lines += EndpointDoc.lines("A client on the mock backend, signed in: every endpoint answered from `Mocks/Fixtures` the way the "
            + "\(api.stem) API answers it (a list a page at a time, an item by the id asked for, a body echoed back as what it made), "
            + "with no network. `scenario` makes it answer as the API does when something goes wrong; `latency` is how long each "
            + "answer takes.", indent: "    ")
        lines += ["    ///", "    /// ```swift", "    /// let client = \(client).mock()", "    /// let answer = try await client.\(example)",
                  "    /// let failing = \(client).mock(.failing, latency: .zero)", "    /// ```"]
        lines.append("    public static func mock(_ scenario: MockScenario = .normal, latency: Duration = .milliseconds(250)) -> \(client) {")
        lines.append("        let server = MockServer(routes: mockRoutes, scenario: scenario, latency: latency)")
        if api.auth == "none" {
            lines.append("        return \(client)(baseURL: mockBaseURL, tokens: MemoryTokenStore(), transport: server, retry: .never)")
        } else {
            lines.append("        let tokens = MemoryTokenStore([hostKey(mockBaseURL): MockFixtures.sessionToken])")
            lines.append("        return \(client)(baseURL: mockBaseURL, tokens: tokens, transport: server, retry: .never)")
        }
        lines += ["    }", "",
                  "    /// Where the mock client sends: the API's own address, so the links its answers hold read as they would.",
                  "    static let mockBaseURL = URL(string: \(SwiftLiteral.quoted(base)))!", "",
                  "    /// How the mock backend answers each endpoint.",
                  "    static let mockRoutes: [MockRoute] = ["]
        for (method, plan, constants) in plans {
            lines += route(method, plan, constants).map { "        " + $0 }
        }
        lines += ["    ]", "}"]
        return lines.joined(separator: "\n") + "\n"
    }

    /// One route, as lines of Swift ending in a comma.
    private func route(_ method: ClientMethod, _ plan: RoutePlan, _ constants: [FixtureConstant]) -> [String] {
        let head = "MockRoute(.\(method.endpoint.method.lowercased()), \(SwiftLiteral.quoted(method.endpoint.path)), "
        func named(_ suffix: String) -> String { constants.first { $0.name.hasSuffix(suffix) }?.reference ?? "[]" }
        switch plan {
        case .nothing: return [head + ".nothing),"]
        case .picture: return [head + ".body(MockImages.data(\"\(MockArt.names.first ?? "food-1")\") ?? Data(), contentType: \"image/png\")),"]
        case .text(let text): return [head + ".body(Data(\(SwiftLiteral.quoted(text)).utf8), contentType: \"text/plain\")),"]
        case .fixture: return [head + ".fixture(\(constants.first?.reference ?? "\"{}\""))),"]
        case .list(let list):
            var arguments = ["pages: \(constants.first?.reference ?? "[]")", "items: \(list.itemsKey.map(SwiftLiteral.quoted) ?? "nil")"]
            switch list.paging {
            case .none: break
            case .page(let parameter): arguments.append("paging: .page(\(SwiftLiteral.quoted(parameter)))")
            case .cursor(let parameter, let id, let next):
                arguments.append("paging: .cursor(\(SwiftLiteral.quoted(parameter)), id: \(SwiftLiteral.path(id)), next: \(next.map(SwiftLiteral.quoted) ?? "nil"))")
            }
            if let limit = list.limit { arguments.append("limit: \(SwiftLiteral.quoted(limit))") }
            arguments.append("size: \(list.size)")
            if !list.filters.isEmpty {
                arguments.append("filters: [" + list.filters.map { "\(SwiftLiteral.quoted($0.parameter)): \(SwiftLiteral.path($0.path))" }.joined(separator: ", ") + "]")
            }
            if !list.search.isEmpty { arguments.append("search: [" + list.search.map(SwiftLiteral.quoted).joined(separator: ", ") + "]") }
            if let sort = list.sort {
                let orders = sort.orders.map { "\(SwiftLiteral.quoted($0.value)): (\(SwiftLiteral.path($0.path)), \($0.descending))" }
                let line = "sort: .init(parameter: \(SwiftLiteral.quoted(sort.parameter)), orders: [\(orders.joined(separator: ", "))])"
                arguments.append(line.count <= 100 ? line
                    : (["sort: .init(parameter: \(SwiftLiteral.quoted(sort.parameter)), orders: ["] + orders.map { "    \($0)," } + ["])"]).joined(separator: "\n"))
            }
            if !list.totals.isEmpty { arguments.append("totals: [" + list.totals.map(SwiftLiteral.quoted).joined(separator: ", ") + "]") }
            return wrap(head + ".list(.init(", arguments, close: "))),")
        case .lookup(let lookup):
            var arguments = ["key: \(key(lookup.key))", "items: \(items(lookup.items, own: constants.first { $0.name.hasSuffix("Items") }?.reference))",
                             "match: \(SwiftLiteral.path(lookup.match))"]
            if lookup.response != nil { arguments.append("response: \(constants.first?.reference ?? "nil")") }
            if !lookup.place.isEmpty { arguments.append("place: \(SwiftLiteral.path(lookup.place))") }
            if !lookup.related.isEmpty {
                let related = lookup.related.map { related -> String in
                    let own = constants.first { $0.name.hasSuffix(SwiftName.upperCamel(related.place.last ?? "items")) }?.reference
                    return ".init(place: \(SwiftLiteral.path(related.place)), items: \(items(related.items, own: own)), match: \(SwiftLiteral.path(related.match)), to: \(SwiftLiteral.path(related.to))\(related.limit.map { ", limit: \($0)" } ?? ""))"
                }
                arguments.append((["related: ["] + related.map { "    \($0)," } + ["]"]).joined(separator: "\n"))
            }
            return wrap(head + ".lookup(.init(", arguments, close: "))),")
        case .echo(let echo):
            var arguments = ["response: \(constants.first?.reference ?? "\"{}\"")"]
            if !echo.place.isEmpty { arguments.append("place: \(SwiftLiteral.path(echo.place))") }
            if let id = echo.id { arguments.append("id: \(SwiftLiteral.quoted(id))") }
            if !echo.dates.isEmpty { arguments.append("dates: [" + echo.dates.map(SwiftLiteral.quoted).joined(separator: ", ") + "]") }
            if !echo.joins.isEmpty {
                let joins = echo.joins.map { join -> String in
                    let own = constants.first { $0.name.hasSuffix(SwiftName.upperCamel(join.body) + "Items") }?.reference
                    return ".init(body: \(SwiftLiteral.quoted(join.body)), items: \(items(join.items, own: own)), match: \(SwiftLiteral.path(join.match)), place: \(SwiftLiteral.path(join.place)))"
                }
                arguments.append((["joins: ["] + joins.map { "    \($0)," } + ["]"]).joined(separator: "\n"))
            }
            return wrap(head + ".echo(.init(", arguments, close: "))),")
        }
    }

    private func key(_ key: RoutePlan.Key) -> String {
        switch key {
        case .path(let name): return ".path(\(SwiftLiteral.quoted(name)))"
        case .query(let name): return ".query(\(SwiftLiteral.quoted(name)))"
        case .body(let name): return ".body(\(SwiftLiteral.quoted(name)))"
        }
    }

    private func items(_ items: RoutePlan.Items, own: String?) -> String {
        switch items {
        case .route(let method, let path, let at):
            return ".route(.\(method.lowercased()), \(SwiftLiteral.quoted(path))\(at.map { ", at: \(SwiftLiteral.path($0))" } ?? ""))"
        case .own: return ".own(\(own ?? "[]"))"
        }
    }

    /// `head` and its arguments on one line when it fits, else one argument a line.
    private func wrap(_ head: String, _ arguments: [String], close: String) -> [String] {
        let line = head + arguments.joined(separator: ", ") + close
        if line.count <= 112, !line.contains("\n") { return [line] }
        var lines = [head]
        for (index, argument) in arguments.enumerated() {
            let parts = argument.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
            for (number, part) in parts.enumerated() {
                let last = number == parts.count - 1
                lines.append("    " + part + (last && index < arguments.count - 1 ? "," : ""))
            }
        }
        lines.append(close)
        return lines
    }
}
