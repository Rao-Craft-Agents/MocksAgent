//  WHAT: `Tests/<Module>Tests/MockFixtureTests.swift`: the package's proof that its mock holds: every fixture decodes
//        as its endpoint's type, every endpoint answers through `.mock()`, an item asked for is the one found, a
//        list's pages end, a query narrows the list it should, every scenario fails as it should, and every picture
//        loads through `URLSession` and reads as an image.

import Foundation

struct TestEmitter {
    let api: ClientAPI
    let shape: Shape

    typealias Route = (method: ClientMethod, plan: RoutePlan, constants: [FixtureConstant])

    func file(_ routes: [Route], scenarios: [MocksScenario]) -> String {
        let client = api.client
        var lines = ["import Foundation", "import XCTest", "#if canImport(UIKit)", "import UIKit", "#elseif canImport(AppKit)", "import AppKit",
                     "#endif", "@testable import \(api.module)", "",
                     "/// The mock backend: every fixture reads as its endpoint's type, every endpoint answers through `.mock()`, the request",
                     "/// decides what is found, pages end, every scenario fails as it should, and every picture loads.",
                     "final class MockFixtureTests: XCTestCase {"]

        // Every fixture decodes.
        lines += ["    func testEveryFixtureReadsAsItsType() throws {", "        let decoder = \(api.codingType).decoder()"]
        for route in routes {
            for constant in route.constants {
                if constant.many {
                    lines.append("        for fixture in \(constant.reference) { _ = try decoder.decode(\(constant.type).self, from: Data(fixture.utf8)) }")
                } else {
                    lines.append("        _ = try decoder.decode(\(constant.type).self, from: Data(\(constant.reference).utf8))")
                }
            }
        }
        lines += ["    }", ""]

        // Every endpoint answers through the mock.
        lines += ["    func testEveryEndpointAnswers() async throws {", "        let client = \(client).mock(latency: .zero)"]
        var skipped: [String] = []
        for route in routes {
            // A body that names the item it is about (a vote on a post) names one the mock has.
            var setup: [String] = [], bodyName: String?
            if case .lookup(let lookup) = route.plan, case .body(let key) = lookup.key, let body = route.method.body,
               let field = Shape.base(body).flatMap(shape.entity)?.fields.first(where: { shape.key($0) == key }),
               let value = swift(lookup.sample, as: field.type) {
                setup = ["var body = \(body).preview", "body.\(SwiftName.member(field.name)) = \(value)"]
                bodyName = "body"
            }
            guard let call = call(route.method, route.plan, body: bodyName) else { skipped.append(route.method.name); continue }
            let checks = answerChecks(route)
            if checks.isEmpty, setup.isEmpty {
                lines.append("        _ = try await client.\(call)")
            } else {
                let answer = checks.isEmpty ? "_ = try await client.\(call)" : "let answer = try await client.\(call)"
                lines += ["        do {"] + (setup + [answer] + checks).map { "            " + $0 } + ["        }"]
            }
        }
        if !skipped.isEmpty {
            lines.append("        // \(skipped.joined(separator: ", ")) send a form or a body with no preview; their fixtures are read above.")
        }
        lines += ["    }"]

        // Pages end.
        let paged = routes.compactMap { route -> (Route, RoutePlan.List)? in
            guard case .list(let list) = route.plan, route.method.paging != nil else { return nil }
            return (route, list)
        }
        if !paged.isEmpty {
            lines += ["", "    func testEveryPagedListEnds() async throws {", "        let client = \(client).mock(latency: .zero)"]
            for (route, list) in paged {
                guard let call = pagesCall(route.method, route.plan, size: list.size) else { continue }
                let count = expectedCount(route.method, list)
                let expected = count == 0 ? 0 : (count + list.size - 1) / list.size
                let id = idExpression(list)
                lines += ["        do {", "            var pages = 0, seen: [String] = []", "            for try await page in client.\(call) {",
                          "                pages += 1", "                seen += page.items.map { \(id) }", "            }",
                          "            XCTAssertEqual(pages, \(expected), \"\(route.method.name): \(count) items, \(list.size) a page\")",
                          "            XCTAssertEqual(seen.count, \(count))",
                          "            XCTAssertEqual(Set(seen).count, seen.count, \"no item comes twice\")", "        }"]
            }
            lines += ["    }"]
        }

        // A query narrows its list.
        let narrowing = routes.compactMap { route -> String? in
            guard case .list(let list) = route.plan else { return nil }
            for filter in list.filters {
                guard let sample = filter.sample, filter.matches > 0, let check = narrowCheck(route.method, list, filter, sample) else { continue }
                return check
            }
            return nil
        }
        if !narrowing.isEmpty {
            lines += ["", "    func testTheRequestNarrowsItsList() async throws {", "        let client = \(client).mock(latency: .zero)"]
            lines += narrowing
            lines += ["    }"]
        }

        // Scenarios.
        if let probe = probe(routes) {
            lines += ["", "    func testEveryScenarioAnswersAsItShould() async throws {"]
            if scenarios.contains(.failing) {
                lines += ["        do {", "            _ = try await \(client).mock(.failing, latency: .zero).\(probe.call)",
                          "            XCTFail(\"a failing backend answers 500\")",
                          "        } catch \(api.errorType).status(let code, let message, _) {", "            XCTAssertEqual(code, 500)",
                          "            XCTAssertNotNil(message, \"the API's error body says what went wrong\")", "        }"]
            }
            if scenarios.contains(.unauthorized) {
                lines += ["        do {", "            _ = try await \(client).mock(.unauthorized, latency: .zero).\(probe.call)",
                          "            XCTFail(\"a backend that refuses answers 401\")",
                          "        } catch \(api.errorType).unauthorized(let message) {", "            XCTAssertNotNil(message)", "        }"]
            }
            if scenarios.contains(.empty) {
                if let items = probe.items {
                    lines += ["        let empty = try await \(client).mock(.empty, latency: .zero).\(probe.call)",
                              "        XCTAssertTrue(empty\(items).isEmpty, \"an empty backend lists nothing\")"]
                } else {
                    lines += ["        do {", "            _ = try await \(client).mock(.empty, latency: .zero).\(probe.call)",
                              "            XCTFail(\"an empty backend finds nothing\")",
                              "        } catch \(api.errorType).status(let code, _, _) {", "            XCTAssertEqual(code, 404)", "        }"]
                }
            }
            if scenarios.contains(.failing) {
                lines += ["        // A test may change how the backend answers between two calls: a load that fails, then a retry that works.",
                          "        let client = \(client).mock(.failing, latency: .zero)", "        (client.transport as? MockServer)?.scenario = .normal",
                          "        _ = try await client.\(probe.call)"]
            }
            if scenarios.contains(.slow) {
                lines += ["        let slow = MockServer(routes: \(client).mockRoutes, scenario: .slow, latency: .zero, slowLatency: .milliseconds(200))",
                          "        let started = Date()",
                          "        _ = try await \(client)(baseURL: \(client).mockBaseURL, tokens: MemoryTokenStore(), transport: slow, retry: .never).\(probe.call)",
                          "        XCTAssertGreaterThanOrEqual(Date().timeIntervalSince(started), 0.19, \"a slow backend takes its time\")"]
            }
            lines += ["    }"]

            // The app's services read `current`: the mock in a test, and a test may put another in its place.
            lines += ["", "    func testTheCurrentClientIsTheMockInATestAndCanBeReplaced() async throws {",
                      "        XCTAssertTrue(MockMode.isOn, \"a test run is on the mock backend\")",
                      "        let kept = \(client).current",
                      "        XCTAssertTrue(kept.transport is MockServer)",
                      "        \(client).current = .mock(.failing, latency: .zero)",
                      "        do {",
                      "            _ = try await \(client).current.\(probe.call)",
                      "            XCTFail(\"the client put in its place answers\")",
                      "        } catch {",
                      "            XCTAssertEqual((error as? \(api.errorType))?.statusCode, 500)",
                      "        }",
                      "        \(client).current = kept",
                      "        XCTAssertTrue(\(client).current === kept, \"and is put back\")",
                      "    }"]
        }

        // Pictures load.
        lines += ["", "    func testEveryPictureLoadsAsAnImage() async throws {", "        XCTAssertFalse(MockImages.names.isEmpty)",
                  "        for name in MockImages.names {", "            let url = try XCTUnwrap(MockImages.url(name))",
                  "            let (data, response) = try await URLSession.shared.data(from: url)",
                  "            XCTAssertEqual(response.mimeType, \"image/png\", name)", "            #if canImport(UIKit)",
                  "            XCTAssertNotNil(UIImage(data: data), name)", "            #elseif canImport(AppKit)",
                  "            XCTAssertNotNil(NSImage(data: data), name)", "            #endif", "        }", "    }", "}"]
        return lines.joined(separator: "\n") + "\n"
    }

    // MARK: - Calls

    /// `post(id: 10234)`: the method called with what it requires, a lookup's value where it takes one.
    func call(_ method: ClientMethod, _ plan: RoutePlan, body: String? = nil) -> String? {
        arguments(method, plan: plan, given: [:], body: body).map { "\(method.name)(\($0.joined(separator: ", ")))" }
    }

    /// `postsPages(limit: 10)`: every page, as many a page as the fixtures hold.
    private func pagesCall(_ method: ClientMethod, _ plan: RoutePlan, size: Int) -> String? {
        guard let paging = method.paging else { return nil }
        var given: [String: String] = [:]
        if let limit = paging.limit { given[limit.wire] = String(size) }
        guard let arguments = arguments(method, plan: plan, given: given, leaving: paging.marker.wire) else { return nil }
        return "\(method.name)Pages(\(arguments.joined(separator: ", ")))"
    }

    /// The arguments of a call of `method`, in the order it declares them: its body's preview, what it requires
    /// (the plan's own value where it has one), and the optional ones `given` names by wire name.
    private func arguments(_ method: ClientMethod, plan: RoutePlan, given: [String: String], leaving: String? = nil,
                           body name: String? = nil) -> [String]? {
        guard !method.multipart else { return nil }
        var arguments: [String] = []
        if let body = method.body {
            guard previewable(body) else { return nil }
            arguments.append(name ?? "\(body).preview")
        }
        for argument in method.path + method.query where argument.wire != leaving {
            if let value = given[argument.wire] {
                arguments.append("\(argument.name): \(value)")
            } else if argument.required {
                guard let value = literal(for: argument, plan) else { return nil }
                arguments.append("\(argument.name): \(value)")
            }
        }
        return arguments
    }

    /// A value `argument` may take: the lookup's own where it is the key, else one of its type.
    private func literal(for argument: ClientMethod.Argument, _ plan: RoutePlan) -> String? {
        if case .lookup(let lookup) = plan {
            let key: String
            switch lookup.key {
            case .path(let name), .query(let name): key = name
            case .body: key = ""
            }
            if key == argument.wire, let value = swift(lookup.sample, as: argument.type) { return value }
        }
        if case .list(let list) = plan, let filter = list.filters.first(where: { $0.parameter == argument.wire }), let sample = filter.sample,
           let value = swift(sample, as: argument.type) {
            return value
        }
        switch argument.type.unwrapped {
        case .named("Int"), .named("Int64"), .named("Int32"): return "1"
        case .named("Double"), .named("Float"): return "1"
        case .named("String"): return "\"a\""
        case .named("Bool"): return "true"
        case .named("UUID"): return "UUID()"
        case .named("Date"): return "Date()"
        case .named(let name):
            guard let entity = shape.entity(name), entity.isEnum, let first = entity.cases.first, first.values.isEmpty else { return nil }
            return ".\(SwiftName.member(first.name))"
        default: return nil
        }
    }

    /// `value` as a Swift literal of `type`, when it is an Int or a String.
    private func swift(_ value: JSONValue, as type: TypeRef) -> String? {
        switch (value, type.unwrapped) {
        case (.int(let number), .named(let name)) where ["Int", "Int64", "Int32"].contains(name): return String(number)
        case (.string(let text), .named("String")): return SwiftLiteral.quoted(text)
        default: return nil
        }
    }

    /// What an answer is checked for: the item asked for is the one found, a list's first page is full.
    private func answerChecks(_ route: Route) -> [String] {
        guard case .json(let answer) = route.method.answer else { return [] }
        switch route.plan {
        case .lookup(let lookup):
            if case .body = lookup.key { return [] }
            guard let path = swiftPath(answer, lookup.place + lookup.match), let value = swift(lookup.sample, as: path.type) else { return [] }
            return ["XCTAssertEqual(answer\(path.text), \(value), \"the item asked for is the one found\")"]
        case .list(let list):
            let items = list.itemsKey.flatMap { swiftPath(answer, [$0])?.text } ?? (list.itemsKey == nil ? "" : nil)
            guard let items else { return [] }
            return ["XCTAssertEqual(answer\(items).count, \(min(list.size, expectedCount(route.method, list))))"]
        case .echo(let echo):
            guard let body = route.method.body, previewable(body), let entity = Shape.base(body).flatMap(shape.entity) else { return [] }
            for field in entity.fields where field.type.unwrapped == .named("String") {
                guard let path = swiftPath(answer, echo.place + [shape.key(field)]), path.type.unwrapped == .named("String") else { continue }
                return ["XCTAssertEqual(answer\(path.text), \(body).preview.\(SwiftName.member(field.name)), \"the body is echoed back\")"]
            }
            return []
        default:
            return []
        }
    }

    /// How many items a call of `method` with what it requires lists: those its required filter names (an
    /// account's statuses), else every one.
    private func expectedCount(_ method: ClientMethod, _ list: RoutePlan.List) -> Int {
        for argument in method.path + method.query.filter(\.required) {
            if let filter = list.filters.first(where: { $0.parameter == argument.wire }), filter.sample != nil { return filter.matches }
        }
        return list.count
    }

    /// The check that a query narrows a list: every item it answers holds the value asked for.
    private func narrowCheck(_ method: ClientMethod, _ list: RoutePlan.List, _ filter: RoutePlan.Filter, _ sample: JSONValue) -> String? {
        guard let argument = (method.path + method.query).first(where: { $0.wire == filter.parameter }),
              let value = swift(sample, as: argument.type), case .json(let answer) = method.answer,
              let itemPath = swiftPath(list.item, filter.path), swift(sample, as: itemPath.type) != nil else { return nil }
        let items = list.itemsKey.flatMap { swiftPath(answer, [$0])?.text } ?? ""
        var given = [argument.wire: value]
        if let limit = method.paging?.limit?.wire ?? list.limit, limit != argument.wire { given[limit] = String(list.count) }
        guard let arguments = arguments(method, plan: .nothing, given: given) else { return nil }
        return ["        do {", "            let answer = try await client.\(method.name)(\(arguments.joined(separator: ", ")))",
                "            XCTAssertEqual(answer\(items).count, \(filter.matches))",
                "            XCTAssertTrue(answer\(items).allSatisfy { $0\(itemPath.text) == \(value) }, \"only the items \(filter.parameter) names\")",
                "        }"].joined(separator: "\n")
    }

    /// The call the scenarios are tried on: the first list, else the first lookup or fixture read with a GET.
    private func probe(_ routes: [Route]) -> (call: String, items: String?)? {
        for route in routes {
            guard case .list(let list) = route.plan, case .json(let answer) = route.method.answer, let call = call(route.method, route.plan) else { continue }
            let items = list.itemsKey.flatMap { swiftPath(answer, [$0])?.text } ?? (list.itemsKey == nil ? "" : nil)
            return (call, items)
        }
        for route in routes where route.method.endpoint.method == "GET" {
            guard case .lookup = route.plan, let call = call(route.method, route.plan) else { continue }
            return (call, nil)
        }
        return nil
    }

    /// `"\($0.post.id)"`: an item's id, as text.
    private func idExpression(_ list: RoutePlan.List) -> String {
        let id: [String]
        switch list.paging {
        case .cursor(_, let path, _) where !path.isEmpty: id = path
        default: id = idPath(list.item) ?? []
        }
        guard !id.isEmpty, let path = swiftPath(list.item, id) else { return "\"\\($0)\"" }
        return "\"\\($0\(path.text))\""
    }

    private func idPath(_ item: TypeRef) -> [String]? {
        guard let base = Shape.base(item), let entity = shape.entity(base) else { return nil }
        if let id = entity.fields.first(where: { $0.name == "id" }) { return [shape.key(id)] }
        guard let first = entity.fields.first, case .record(let type) = shape.role(first, of: base),
              let id = shape.entity(type)?.fields.first(where: { $0.name == "id" }) else { return nil }
        return [shape.key(first), shape.key(id)]
    }

    /// `.postView.post.id` for the JSON path `post_view.post.id` in `type`, with `?` where a step may be nil; nil
    /// when a key is no field or a step is a list.
    func swiftPath(_ type: TypeRef, _ path: [String]) -> (text: String, type: TypeRef)? {
        var current = type, text = ""
        for key in path {
            var optional = false
            if case .optional(let wrapped) = current { optional = true; current = wrapped }
            guard case .named(let name) = current, let entity = shape.entity(name), !entity.isEnum,
                  let field = entity.fields.first(where: { shape.key($0) == key }) else { return nil }
            text += (optional ? "?" : "") + "." + SwiftName.member(field.name)
            current = field.type
        }
        return (text, current)
    }

    /// Whether `type` has a `preview` that `network` wrote: every field it must have can be sampled.
    func previewable(_ type: TypeRef, seen: Set<String> = []) -> Bool {
        switch type {
        case .optional, .array, .dictionary: return true
        case .named(let name):
            if ClientAPI.primitives.contains(name) { return true }
            guard let entity = shape.entity(name), !seen.contains(name) else { return false }
            if entity.isEnum { return true }
            return entity.fields.allSatisfy { field in field.defaultValue != nil || previewable(field.type, seen: seen.union([name])) }
        }
    }
}
