//  WHAT: Every file the call writes into the client package, by its path in the package: the runtime under
//        `Sources/<Module>/Mocks/`, the pictures, the shared fixtures, `<Client>+Mock.swift` with its routes, a
//        fixture file an endpoint under `Mocks/Fixtures/`, and `Tests/<Module>Tests/MockFixtureTests.swift`.

import Foundation

struct MocksEmitter {
    let api: ClientAPI
    let shape: Shape
    let theme: Theme
    let anchor: Date
    let token: String
    let plans: [RoutePlan]
    let images: [(name: String, base64: String)]
    let scenarios: [MocksScenario]

    /// Every route, with the fixtures it names.
    var routes: [(method: ClientMethod, plan: RoutePlan, constants: [FixtureConstant])] {
        let fixtures = FixtureEmitter(api: api, shape: shape)
        return zip(api.methods, plans).map { method, plan in (method, plan, fixtures.constants(method, plan)) }
    }

    func files() -> [(path: String, text: String)] {
        let source = "Sources/\(api.module)/Mocks", tests = "Tests/\(api.module)Tests"
        let example = exampleCall()
        var files: [(String, String)] = []
        for (name, template) in [("MockJSON", RuntimeTemplates.mockJSON), ("MockAnswer", RuntimeTemplates.mockAnswer),
                                 ("MockRoute", RuntimeTemplates.mockRoute), ("MockServer", RuntimeTemplates.mockServer),
                                 ("MockScenario", RuntimeTemplates.mockScenario), ("MockMode", RuntimeTemplates.mockMode)] {
            files.append(("\(source)/\(name).swift", template.replacingOccurrences(of: "__CLIENT__", with: api.client)
                .replacingOccurrences(of: "__EXAMPLE_CALL__", with: example)))
        }
        files.append(("\(source)/MockImages.swift", imagesFile()))
        files.append(("\(source)/MockFixtures.swift", fixturesFile()))
        let routes = self.routes
        files.append(("\(source)/\(api.client)+Mock.swift", RouteEmitter(api: api).file(plans: routes, example: example, theme: theme)))
        let fixtures = FixtureEmitter(api: api, shape: shape)
        for route in routes where !route.constants.isEmpty {
            files.append(("\(source)/Fixtures/\(route.method.typeName)Fixture.swift", fixtures.file(route.constants)))
        }
        files.append(("\(tests)/MockFixtureTests.swift", TestEmitter(api: api, shape: shape).file(routes, scenarios: scenarios)))
        return files.map { (path: $0.0, text: $0.1) }
    }

    /// A call to show in a doc: the first list, else the first read, else the first endpoint, with what it requires.
    func exampleCall() -> String {
        let tests = TestEmitter(api: api, shape: shape)
        let reads = routes.filter { $0.method.endpoint.method == "GET" }
        let lists = reads.filter { if case .list = $0.plan { return true } else { return false } }
        for route in lists + reads + routes {
            if let call = tests.call(route.method, route.plan) { return call }
        }
        return "send(Request<NoContent>(.get, \"/\"))"
    }

    private func imagesFile() -> String {
        var lines = ["import Foundation", "",
                     "/// The pictures the fixtures show, drawn for the mock backend (faces, dishes and places, each a soft gradient with a",
                     "/// mark) and kept here as PNGs, so nothing is fetched from anyone's server. A fixture names one as",
                     "/// `mock-image://<name>`; the mock backend answers it as a `data:` URL, which `AsyncImage` and `URLSession` load",
                     "/// like any other.",
                     "public enum MockImages {",
                     "    /// Every picture, by name, as base64 PNG.",
                     "    static let png: [String: String] = ["]
        for image in images { lines.append("        \(SwiftLiteral.quoted(image.name)): \"\(image.base64)\",") }
        lines += ["    ]", "",
                  "    /// How a fixture names a picture: `mock-image://food-1`.",
                  "    static let scheme = \"mock-image://\"", "",
                  "    /// The names of every picture.",
                  "    public static var names: [String] { png.keys.sorted() }", "",
                  "    /// The picture `name` as a `data:` URL, for `AsyncImage` in a preview; nil when there is none.",
                  "    public static func url(_ name: String) -> URL? {",
                  "        png[name].flatMap { URL(string: \"data:image/png;base64,\" + $0) }",
                  "    }", "",
                  "    /// The picture `name`'s bytes; nil when there is none.",
                  "    public static func data(_ name: String) -> Data? {",
                  "        png[name].flatMap { Data(base64Encoded: $0) }",
                  "    }", "",
                  "    /// `text` with a `mock-image://<name>` turned into its `data:` URL; anything else as it is.",
                  "    static func resolve(_ text: String) -> String {",
                  "        guard text.hasPrefix(scheme), let base64 = png[String(text.dropFirst(scheme.count))] else { return text }",
                  "        return \"data:image/png;base64,\" + base64",
                  "    }", "}"]
        return lines.joined(separator: "\n") + "\n"
    }

    private func fixturesFile() -> String {
        let seconds = Int(anchor.timeIntervalSince1970)
        var lines = ["import Foundation", ""]
        lines += EndpointDoc.lines("What the mock backend answers, endpoint by endpoint (`Fixtures/`), written for \(Self.clause(theme.text)), and what every answer shares.", indent: "")
        lines += ["enum MockFixtures {",
                  "    /// When the fixtures were written: the mock backend moves every date by the time since, so the newest one is",
                  "    /// always as fresh as it was then.",
                  "    static let writtenAt = Date(timeIntervalSince1970: \(Self.grouped(seconds)))", "",
                  "    /// The token the mock client starts signed in with, and a sign-in answers.",
                  "    static let sessionToken = \(SwiftLiteral.quoted(token))", "",
                  "    /// The API's error body, saying `message`.",
                  "    static func errorBody(_ message: String) -> MockJSON {",
                  "        \(errorBody())",
                  "    }", "}"]
        return lines.joined(separator: "\n") + "\n"
    }

    /// The API's error type, with `message` where it says what went wrong; `{"error": message}` when the API has none.
    private func errorBody() -> String {
        let candidates = api.entities.filter { !$0.isEnum && $0.name.contains("Error") && shape.kind(of: $0.name) == .value }
        for entity in candidates {
            guard let said = entity.fields.first(where: {
                $0.type.unwrapped == .named("String") && ["message", "error", "detail", "msg", "description", "reason", "title"].contains(SwiftName.normalized($0.name))
            }) else { continue }
            let members = entity.fields.compactMap { field -> String? in
                let key = SwiftLiteral.quoted(shape.key(field))
                if field.name == said.name { return "\(key): .string(message)" }
                if field.type.isOptional || field.defaultValue != nil { return nil }
                switch field.type.unwrapped {
                case .named("String"): return "\(key): .string(\"\")"
                case .named("Bool"): return "\(key): .bool(false)"
                case .named("Double"), .named("Float"): return "\(key): .double(0)"
                case .array: return "\(key): .array([])"
                case .named(let name) where ClientAPI.primitives.contains(name): return "\(key): .int(0)"
                default: return "\(key): .null"
                }
            }
            return ".object([\(members.joined(separator: ", "))])"
        }
        return ".object([\"error\": .string(message)])"
    }

    /// `a cozy recipe-sharing community`, lowercased at the start unless it is a name, no full stop.
    static func clause(_ text: String) -> String {
        var text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        while text.hasSuffix(".") { text.removeLast() }
        guard let first = text.first, first.isUppercase, !(text.dropFirst().first?.isUppercase ?? false),
              !text.hasPrefix("I ") else { return text }
        let word = text.prefix { $0 != " " }
        return ["A", "An", "The"].contains(String(word)) ? first.lowercased() + text.dropFirst() : text
    }

    /// `1762000000` → `1_762_000_000`.
    static func grouped(_ value: Int) -> String {
        let digits = String(value)
        var out = ""
        for (index, digit) in digits.enumerated() {
            if index > 0, (digits.count - index) % 3 == 0 { out += "_" }
            out.append(digit)
        }
        return out
    }
}
