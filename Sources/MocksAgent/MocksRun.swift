//  WHAT: One call, from the client package to the files: the package found and its lines read (every problem refused
//        at once), the world made (what the records say written by the host's model in batches, or word lists),
//        each endpoint's answer planned from it, the pictures drawn, and the runtime, the routes, the fixtures and
//        the tests written into the package together, after every Swift file parses.
//  PIN:  THE PACKAGE IS NETWORK'S. Mocks are written into a client package `network` made (its `api.json`, its
//        `<Client>`, its transport), so `.mock()` is that client on another transport; a folder without them is
//        refused, never guessed at.
//  PIN:  NO MODEL, STILL BELIEVABLE. Without the host's model the records come from word lists, varied and never
//        "Sample", and the notes say a model writes them in the app's own voice.

import Foundation
import GraniteAgents

struct MocksRun: Sendable {
    let input: MocksAgent.Input
    let host: AgentHost
    let yield: @Sendable (MocksFrame) -> Void

    func run() async throws -> MocksResult {
        // The folder is the call's, else the host's, else the process's.
        let files = AgentFiles(directory: input.directory ?? host.directory)
        let note = host.note
        let folder = try Self.package(input.package, files: files)
        guard let stored = APIRecord.read(in: folder) else {
            throw MocksError.noPackage("`\(files.relative(folder))/api.json` could not be read: make the client again with network")
        }
        let api = try ClientAPI.resolve(stored.merging(endpoints: input.endpoints, entities: input.entities))
        var reasons: [String] = []
        let source = folder.appendingPathComponent("Sources/\(api.module)")
        for required in ["\(api.client).swift", "Transport/HTTPTransport.swift", "Auth/MemoryTokenStore.swift", "Coding/\(api.codingType).swift"]
            where !FileManager.default.fileExists(atPath: source.appendingPathComponent(required).path) {
            reasons.append("`\(files.relative(source))/\(required)` is missing: the package is not a client `network` made, or was changed by hand")
        }
        if api.methods.isEmpty { reasons.append("the package has no endpoints to answer: give `network` its endpoint lines first") }
        let shape = Shape(api)
        let previous = MocksSettings.read(in: folder)
        let countLines = (input.counts ?? previous?.counts ?? []).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        var counts: [String: Int] = [:]
        for line in countLines {
            switch Self.count(line, shape: shape) {
            case .success(let pair): counts[pair.type] = pair.count
            case .failure(let failure): reasons.append(failure.reason)
            }
        }
        guard reasons.isEmpty else { throw MocksError.refused(reasons) }
        yield(.read(endpoints: api.methods.count, types: api.entities.count))

        let theme = Theme(input.theme ?? previous?.theme, package: api.stem)
        let seed = input.seed ?? previous?.seed ?? Seeded.seed(api.module)
        let scenarios = Self.scenarios(input.scenarios ?? previous?.scenarios)
        let anchor = WorldBuilder.minute(Date())
        var notes: [String] = []

        // The world, its words from the host's model or the word lists.
        var builder = WorldBuilder(shape: shape, theme: theme, seed: seed, anchor: anchor, counts: counts)
        let world: World
        var written = false
        if let model = host.model {
            var writer = ModelWriter(model: model, theme: theme, rounds: min(max(input.rounds ?? 3, 1), 6), seed: seed, note: note)
            world = try await builder.build(&writer, note: note)
            written = true
            notes += writer.notes
            notes.append("the host's model wrote what the records say, in \(writer.asks) ask\(writer.asks == 1 ? "" : "s")\(writer.retries > 0 ? ", \(writer.retries) of them asked again" : "")")
        } else {
            var writer = WordWriter(theme: theme, seed: seed)
            world = try await builder.build(&writer, note: note)
            notes.append("no model was offered, so the records say what word lists say; call again with the host's model for records in the app's own voice")
        }
        if input.theme == nil, previous?.theme == nil { notes.append("no theme was given, so the records are a general community's; say `theme` for the app's own") }
        let records = Dictionary(uniqueKeysWithValues: builder.needed.map { ($0, world.count($0)) })
        yield(.made(records: records, asks: 0))

        // Each endpoint's answer, the pictures, the files.
        let token = Self.token(api: api, shape: shape, world: world, seed: seed)
        let renderer = Renderer(shape: shape, world: world, token: token)
        let plans = RoutePlanner(shape: shape, world: world, renderer: renderer).plans()
        note("drawing \(MockArt.names.count) pictures and writing the fixtures of \(api.methods.count) endpoints")
        let images = MockArt.drawAll()
        let emitter = MocksEmitter(api: api, shape: shape, theme: theme, anchor: anchor, token: token, plans: plans, images: images, scenarios: scenarios)
        let made = emitter.files()
        let kept = made.map(\.path) + [MocksSettings.fileName]
        var planned = made.map { (url: folder.appendingPathComponent($0.path), text: $0.text) }
        let record = MocksSettings(theme: input.theme ?? previous?.theme, seed: seed, counts: countLines, scenarios: scenarios, files: kept.sorted())
        planned.append((folder.appendingPathComponent(MocksSettings.fileName), record.text))
        let paths = try files.write(planned)

        // What an earlier call wrote and the mock no longer has.
        for old in previous?.files ?? [] where !kept.contains(old) {
            let url = folder.appendingPathComponent(old)
            guard url.path.hasPrefix(folder.path + "/"), (try? FileManager.default.removeItem(at: url)) != nil else { continue }
            notes.append("removed \(old), which the mock no longer has")
        }
        note("wrote \(paths.count) files into \(files.relative(folder))")
        let routes = folder.appendingPathComponent("Sources/\(api.module)/Mocks/\(api.client)+Mock.swift").path
        return MocksResult(path: paths.first { $0 == routes } ?? paths.first, paths: paths, package: folder.path, client: api.client,
                           endpoints: api.methods.map(\.name), records: records, images: images.count, written: written, notes: notes)
    }

    /// The client package: the one named, else the only one under `Packages/` with an `api.json`, else the folder
    /// itself when it is one.
    static func package(_ named: String?, files: AgentFiles) throws -> URL {
        let manager = FileManager.default
        func isClient(_ url: URL) -> Bool { manager.fileExists(atPath: url.appendingPathComponent(APIRecord.fileName).path) }
        if let named = named?.trimmingCharacters(in: .whitespaces), !named.isEmpty {
            let url = files.resolve(named)
            guard isClient(url) else {
                throw MocksError.noPackage("`\(files.relative(url))` has no api.json: name a client package `network` made (Packages/<Name>), or make one with network first")
            }
            return url
        }
        let packages = files.resolve("Packages")
        var found = ((try? manager.contentsOfDirectory(atPath: packages.path)) ?? []).sorted().map { packages.appendingPathComponent($0) }.filter(isClient)
        if found.isEmpty, isClient(files.root) { found = [files.root] }
        guard let first = found.first else {
            throw MocksError.noPackage("no client package with an api.json under Packages/: make the API's client with network first, or name its folder in `package`")
        }
        guard found.count == 1 else {
            throw MocksError.noPackage("\(found.count) client packages are under Packages/ (\(found.map(\.lastPathComponent).joined(separator: ", "))): name one in `package`")
        }
        return first
    }

    /// `posts: 40`, `40 posts`: a type and how many.
    static func count(_ line: String, shape: Shape) -> Result<(type: String, count: Int), ContentCheck.Failure> {
        let words = line.replacingOccurrences(of: ":", with: " ").replacingOccurrences(of: "=", with: " ").split(separator: " ").map(String.init)
        guard words.count == 2, let number = Int(words[1]) ?? Int(words[0]) else {
            return .failure(ContentCheck.Failure("`\(line)` is not a count: say `posts: 40`"))
        }
        let name = Int(words[1]) == nil ? words[1] : words[0]
        guard let type = WorldBuilder.type(named: name, in: shape) else {
            let types = shape.records.map { SwiftName.plural(SwiftName.lowerCamel($0)) }.joined(separator: ", ")
            return .failure(ContentCheck.Failure("`\(line)` names no record the API answers; it has \(types)"))
        }
        guard number >= 0, number <= 300 else { return .failure(ContentCheck.Failure("`\(line)`: between 0 and 300 of a type")) }
        return .success((type, number))
    }

    /// The scenarios the tests prove: the ones named and `normal`, every one when none are named.
    static func scenarios(_ named: [MocksScenario]?) -> [MocksScenario] {
        guard let named, !named.isEmpty else { return MocksScenario.allCases }
        return MocksScenario.allCases.filter { $0 == .normal || named.contains($0) }
    }

    /// The token a sign-in answers: a JWT's shape when the API's token field is `jwt`, else an opaque one.
    static func token(api: ClientAPI, shape: Shape, world: World, seed: Int) -> String {
        var random = Seeded(seed &+ 7)
        let alphabet = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_")
        let signature = String((0..<43).map { _ in alphabet[random.int(0...(alphabet.count - 1))] })
        let isJWT = api.methods.contains { SwiftName.normalized($0.tokenField ?? "") == "jwt" }
        guard isJWT else { return signature }
        func base64URL(_ text: String) -> String {
            Data(text.utf8).base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: "")
        }
        let me = shape.person.flatMap { world.record($0, world.me)?.id.text } ?? "1"
        return base64URL(#"{"alg":"HS256","typ":"JWT"}"#) + "." + base64URL("{\"sub\":\"\(me)\",\"iss\":\"\(world.host)\"}") + "." + signature
    }
}
