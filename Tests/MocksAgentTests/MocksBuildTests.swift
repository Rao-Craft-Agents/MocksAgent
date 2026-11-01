import Foundation
import GraniteAgents
import XCTest
@testable import MocksAgent

/// The mock built and run as an app would: an app made through the installed `granite` and `network` runners (a
/// Lemmy-like API), `mocks` on a scripted model whose first batch of posts must be asked again, then the client
/// package's tests on macOS, the package built and its mock tests run on an iOS simulator, and a SwiftUI feed that
/// loads two pages through `.mock()` drawn with its pictures to a PNG (and an `AsyncImage` shown to load one).
/// Gated (`MOCKS_BUILD=1`): it takes minutes. `MOCKS_ARTIFACTS=<folder>` keeps the PNG there.
final class MocksBuildTests: XCTestCase {
    func testTheMockBuildsRunsAndDrawsACommunity() async throws {
        let environment = ProcessInfo.processInfo.environment
        try XCTSkipUnless(environment["MOCKS_BUILD"] == "1", "set MOCKS_BUILD=1 to build the output")
        let runners = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".rao/apps/craft/agents")
        let app = try Fixture.folder().appendingPathComponent("Hearth")
        try FileManager.default.createDirectory(at: app, withIntermediateDirectories: true)
        // The builds' products are hundreds of megabytes: they go when the test does; the app's files stay.
        defer {
            for products in ["dd", "Packages/LemmyKit/.build", "Gallery/.build"] {
                try? FileManager.default.removeItem(at: app.appendingPathComponent(products))
            }
        }

        // The app, as Craft makes it: a granite project, then a network client of a Lemmy-like API.
        let project = try Self.perform(runners.appendingPathComponent("GraniteAgent/agent"), word: "granite", in: app,
                                       input: ["make": "project", "name": "Hearth", "bundleId": "nyc.rao.hearth"])
        XCTAssertNotNil(project["paths"])
        let network = try Self.perform(runners.appendingPathComponent("NetworkAgent/agent"), word: "network", in: app, input: [
            "name": "LemmyKit", "baseURL": "https://lemmy.example", "auth": "bearer", "coding": "snake", "dates": ["yyyy-MM-dd HH:mm:ss"],
            "endpoints": Fixture.lemmyEndpoints, "entities": Fixture.lemmyEntities,
        ])
        XCTAssertEqual(network["client"] as? String, "LemmyClient")
        let package = app.appendingPathComponent("Packages/LemmyKit")

        // The mock, on a model that writes a recipe community and gets its first batch of posts wrong.
        let model = Kitchen.model()
        var input = MocksAgent.Input(theme: Kitchen.theme, counts: ["posts: 30", "comments: 90", "people: 18"])
        input.directory = app.path
        let result = try await MocksRun(input: input, host: AgentHost(directory: app.path, model: model, note: { print("note:", $0) }), yield: { _ in }).run()
        XCTAssertTrue(result.written)
        XCTAssertTrue(model.asked.contains { $0.user.contains("came back wrong") }, "the bad batch was asked for again")
        XCTAssertFalse(result.notes.contains { $0.contains("word lists") }, "\(result.notes)")
        print("mocks:", result.paths.count, "files,", result.records, result.notes)

        // The package's own tests on macOS: the client's and the mock's.
        let macTests = try Self.run(["swift", "test", "--package-path", package.path], in: package)
        XCTAssertEqual(macTests.status, 0, String(macTests.output.suffix(4_000)))
        XCTAssertTrue(macTests.output.contains("MockFixtureTests"), String(macTests.output.suffix(2_000)))
        print(macTests.output.split(separator: "\n").filter { $0.contains("Executed") }.last ?? "")

        // Built for the iOS simulator, and the mock's tests run on one: the pictures load through URLSession there too.
        let derived = app.appendingPathComponent("dd").path
        let iosBuild = try Self.run(["xcodebuild", "-scheme", "LemmyKit", "-destination", "generic/platform=iOS Simulator", "-derivedDataPath", derived,
                                     "-skipPackagePluginValidation", "-skipMacroValidation", "build"], in: package)
        XCTAssertEqual(iosBuild.status, 0, String(iosBuild.output.suffix(4_000)))
        if let device = try Self.shutDownSimulator() {
            defer { _ = try? Self.run(["xcrun", "simctl", "shutdown", device], in: package) }
            let iosTests = try Self.run(["xcodebuild", "test", "-scheme", "LemmyKit", "-destination", "platform=iOS Simulator,id=\(device)",
                                         "-derivedDataPath", derived, "-only-testing:LemmyKitTests/MockFixtureTests",
                                         "-skipPackagePluginValidation", "-skipMacroValidation"], in: package)
            XCTAssertEqual(iosTests.status, 0, String(iosTests.output.suffix(4_000)))
            XCTAssertTrue(iosTests.output.contains("testEveryPictureLoadsAsAnImage") && iosTests.output.contains("** TEST SUCCEEDED **"),
                          String(iosTests.output.suffix(3_000)))
            print("iOS:", iosTests.output.split(separator: "\n").filter { $0.contains("Executed") || $0.contains("TEST SUCCEEDED") }.joined(separator: " | "))
        } else {
            print("iOS: no simulator that is shut down to run the tests on; built only")
        }

        // A SwiftUI feed on two pages of the mock, drawn with its pictures.
        let gallery = app.appendingPathComponent("Gallery")
        try FileManager.default.createDirectory(at: gallery.appendingPathComponent("Sources/Feed"), withIntermediateDirectories: true)
        try Self.galleryManifest.write(to: gallery.appendingPathComponent("Package.swift"), atomically: true, encoding: .utf8)
        try Self.feed.write(to: gallery.appendingPathComponent("Sources/Feed/main.swift"), atomically: true, encoding: .utf8)
        let artifacts = environment["MOCKS_ARTIFACTS"].map { URL(fileURLWithPath: $0) } ?? app
        try FileManager.default.createDirectory(at: artifacts, withIntermediateDirectories: true)
        let png = artifacts.appendingPathComponent("mocks-feed.png")
        let drawn = try Self.run(["swift", "run", "--package-path", gallery.path, "Feed", png.path], in: gallery)
        XCTAssertEqual(drawn.status, 0, String(drawn.output.suffix(4_000)))
        XCTAssertTrue(drawn.output.contains("rendered 6 posts from 2 pages"), String(drawn.output.suffix(2_000)))
        XCTAssertTrue(drawn.output.contains("asyncimage: loaded"), String(drawn.output.suffix(2_000)))
        XCTAssertGreaterThan((try? Data(contentsOf: png).count) ?? 0, 50_000)
        print("feed:", png.path)
        print(drawn.output.split(separator: "\n").filter { $0.hasPrefix("page") || $0.hasPrefix("asyncimage") || $0.hasPrefix("rendered") }.joined(separator: "\n"))
    }

    /// Two other shapes of API, each made by the `network` runner and mocked with no model (word lists): a
    /// Mastodon-like one (string ids, an account in each status, attachments a status owns, a timeline paged by
    /// `max_id` and the `Link` header, a list narrowed by its path) and a recipe one (exact keys, a page envelope with a
    /// total, no people). Each package's own tests then run.
    func testOtherShapesOfAPIBuildAndPassTheirTests() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["MOCKS_BUILD"] == "1", "set MOCKS_BUILD=1 to build the output")
        let runner = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".rao/apps/craft/agents/NetworkAgent/agent")
        for record in [Fixture.mastodon, Fixture.recipes] {
            let folder = try Fixture.folder()
            let package = folder.appendingPathComponent("Packages/\(record.name)")
            defer { try? FileManager.default.removeItem(at: package.appendingPathComponent(".build")) }
            _ = try Self.perform(runner, word: "network", in: folder, input: [
                "name": record.name, "baseURL": record.baseURL ?? "", "auth": record.auth, "paging": record.paging, "coding": record.coding,
                "endpoints": record.endpoints, "entities": record.entities, "link": false,
            ])
            let result = try await MocksRun(input: .init(theme: "a small social app for neighbours", directory: folder.path),
                                            host: AgentHost(directory: folder.path), yield: { _ in }).run()
            XCTAssertFalse(result.written)
            let tests = try Self.run(["swift", "test", "--package-path", package.path], in: package)
            XCTAssertEqual(tests.status, 0, "\(record.name): " + String(tests.output.suffix(4_000)))
            XCTAssertTrue(tests.output.contains("MockFixtureTests"), record.name)
            print(record.name + ":", result.records, tests.output.split(separator: "\n").filter { $0.contains("Executed") }.last ?? "")
        }
    }

    // MARK: - The wire, as Craft speaks it

    /// One call of an installed runner: one JSON line in, from inside `folder`; the output's JSON object out.
    static func perform(_ runner: URL, word: String, in folder: URL, input: [String: Any]) throws -> [String: Any] {
        let line = try JSONSerialization.data(withJSONObject: ["perform": ["word": word, "directory": folder.path, "ask": "make the fixture app",
                                                                         "model": false, "input": input]])
        let process = Process()
        process.executableURL = runner
        process.currentDirectoryURL = folder
        let stdin = Pipe(), stdout = Pipe()
        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = FileHandle.nullDevice
        try process.run()
        stdin.fileHandleForWriting.write(line + Data("\n".utf8))
        try stdin.fileHandleForWriting.close()
        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        for text in String(decoding: data, as: UTF8.self).split(separator: "\n") {
            guard let object = try JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any] else { continue }
            if let output = object["output"] as? [String: Any] { return output }
            if let failed = object["failed"] { throw NSError(domain: word, code: 1, userInfo: [NSLocalizedDescriptionKey: "\(failed)"]) }
        }
        throw NSError(domain: word, code: 2, userInfo: [NSLocalizedDescriptionKey: "no output: \(String(decoding: data, as: UTF8.self).suffix(500))"])
    }

    static func run(_ arguments: [String], in folder: URL) throws -> (status: Int32, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = arguments
        process.currentDirectoryURL = folder
        let out = Pipe()
        process.standardOutput = out
        process.standardError = out
        process.standardInput = FileHandle.nullDevice
        try process.run()
        let data = out.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (process.terminationStatus, String(decoding: data, as: UTF8.self))
    }

    /// An iPhone simulator that is shut down (one another process has booted is left alone); nil when there is none.
    static func shutDownSimulator() throws -> String? {
        let listed = try run(["xcrun", "simctl", "list", "devices", "available", "-j"], in: URL(fileURLWithPath: NSTemporaryDirectory()))
        guard let object = try JSONSerialization.jsonObject(with: Data(listed.output.utf8)) as? [String: Any],
              let devices = object["devices"] as? [String: [[String: Any]]] else { return nil }
        for (runtime, list) in devices.sorted(by: { $0.key > $1.key }) where runtime.contains("iOS") {
            for device in list where (device["name"] as? String)?.hasPrefix("iPhone") == true && device["state"] as? String == "Shutdown" {
                return device["udid"] as? String
            }
        }
        return nil
    }

    static let galleryManifest = """
        // swift-tools-version:6.0
        import PackageDescription

        let package = Package(
            name: "Gallery",
            platforms: [.macOS(.v14)],
            dependencies: [.package(path: "../Packages/LemmyKit")],
            targets: [.executableTarget(name: "Feed", dependencies: [.product(name: "LemmyKit", package: "LemmyKit")],
                                        swiftSettings: [.swiftLanguageMode(.v6)])]
        )
        """

    /// The feed: two pages of the mock's posts, drawn with their pictures by `ImageRenderer`, then one picture shown
    /// by `AsyncImage` in a window, to prove a `data:` URL loads there as it would in an app.
    static let feed = #"""
        import AppKit
        import LemmyKit
        import SwiftUI

        struct PostRow: View {
            let item: PostView
            let pictures: [URL: NSImage]

            var body: some View {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        picture(item.community.icon).frame(width: 22, height: 22).clipShape(Circle())
                        Text("c/\(item.community.name)").font(.subheadline.weight(.semibold))
                        Text("·").foregroundStyle(.secondary)
                        Text(item.post.published, format: .relative(presentation: .named)).font(.subheadline).foregroundStyle(.secondary)
                        Spacer()
                    }
                    Text(item.post.name).font(.headline)
                    if let body = item.post.body, let text = try? AttributedString(markdown: body, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
                        Text(text).font(.subheadline).foregroundStyle(.secondary).lineLimit(3)
                    }
                    if let thumbnail = item.post.thumbnailURL {
                        picture(thumbnail).frame(height: 170).frame(maxWidth: .infinity).clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    HStack(spacing: 14) {
                        HStack(spacing: 6) {
                            picture(item.creator.avatar).frame(width: 18, height: 18).clipShape(Circle())
                            Text(item.creator.displayName ?? item.creator.name).font(.footnote)
                        }
                        Spacer()
                        Label("\(item.counts.score)", systemImage: "arrow.up").font(.footnote)
                        Label("\(item.counts.comments)", systemImage: "bubble.left").font(.footnote)
                    }
                    .foregroundStyle(.secondary)
                }
                .padding(16)
            }

            func picture(_ url: URL?) -> some View {
                ZStack {
                    if let url, let image = pictures[url] {
                        Image(nsImage: image).resizable().scaledToFill()
                    } else {
                        Color.gray.opacity(0.2)
                    }
                }
            }
        }

        struct Feed: View {
            let posts: [PostView]
            let pictures: [URL: NSImage]

            var body: some View {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("Home").font(.largeTitle.bold())
                        Spacer()
                        Image(systemName: "line.3.horizontal.decrease.circle").font(.title2).foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16).padding(.top, 20).padding(.bottom, 4)
                    ForEach(posts, id: \.post.id) { item in
                        PostRow(item: item, pictures: pictures)
                        Divider().padding(.leading, 16)
                    }
                }
                .frame(width: 430)
                .background(Color.white)
                .environment(\.colorScheme, .light)
            }
        }

        final class Loaded: @unchecked Sendable {
            var posts: [PostView] = []
            var pictures: [URL: Data] = [:]
            var failure: String?
        }

        let loaded = Loaded()
        let done = DispatchSemaphore(value: 0)
        Task.detached {
            do {
                let client = LemmyClient.mock(latency: .zero)
                let first = try await client.posts(page: 1, limit: 3)
                let second = try await client.posts(page: 2, limit: 3)
                print("page 1:", first.posts.map(\.post.id), "page 2:", second.posts.map(\.post.id))
                loaded.posts = first.posts + second.posts
                // Every picture through URLSession, as AsyncImage loads one.
                let urls = Set(loaded.posts.flatMap { [$0.post.thumbnailURL, $0.creator.avatar, $0.community.icon] }.compactMap { $0 })
                for url in urls { loaded.pictures[url] = try await URLSession.shared.data(from: url).0 }
            } catch {
                loaded.failure = "\(error)"
            }
            done.signal()
        }
        done.wait()
        if let failure = loaded.failure { fatalError(failure) }

        MainActor.assumeIsolated {
            let pictures = loaded.pictures.compactMapValues { NSImage(data: $0) }
            let renderer = ImageRenderer(content: Feed(posts: loaded.posts, pictures: pictures))
            renderer.scale = 2
            guard let image = renderer.cgImage,
                  let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else { fatalError("no image") }
            try! png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
            print("rendered \(loaded.posts.count) posts from 2 pages, \(pictures.count) pictures, \(image.width)x\(image.height)")

            // AsyncImage in a window, on the first picture the feed shows.
            final class Seen: @unchecked Sendable { var loaded = false; var failed: String? }
            let seen = Seen()
            let url = loaded.posts.compactMap(\.post.thumbnailURL).first!
            NSApplication.shared.setActivationPolicy(.prohibited)
            let window = NSWindow(contentRect: NSRect(x: -4000, y: -4000, width: 240, height: 160), styleMask: .borderless, backing: .buffered, defer: false)
            window.contentView = NSHostingView(rootView: AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image): image.resizable().onAppear { seen.loaded = true }
                case .failure(let error): Color.red.onAppear { seen.failed = "\(error)" }
                default: Color.gray
                }
            }.frame(width: 240, height: 160))
            window.orderFrontRegardless()
            let deadline = Date().addingTimeInterval(15)
            while !seen.loaded, seen.failed == nil, Date() < deadline { RunLoop.main.run(until: Date().addingTimeInterval(0.05)) }
            print(seen.loaded ? "asyncimage: loaded \(url.absoluteString.prefix(30))…" : "asyncimage: failed \(seen.failed ?? "timed out")")
            window.orderOut(nil)
        }
        """#
}
