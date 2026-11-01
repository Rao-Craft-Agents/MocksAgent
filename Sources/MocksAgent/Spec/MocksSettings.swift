//  WHAT: What a call made the package's mocks from, kept beside `api.json` as `mocks.json`: the theme, the seed, the
//        counts, the scenarios and the files written. A later call keeps the theme and the seed it is not told
//        otherwise, and takes away a fixture the package no longer has.

import Foundation

struct MocksSettings: Codable, Equatable {
    var theme: String?
    var seed: Int
    var counts: [String]
    var scenarios: [MocksScenario]
    var files: [String]

    static let fileName = "mocks.json"

    static func read(in folder: URL) -> MocksSettings? {
        guard let data = try? Data(contentsOf: folder.appendingPathComponent(fileName)) else { return nil }
        return try? JSONDecoder().decode(MocksSettings.self, from: data)
    }

    /// The record as it is written: keys sorted, one line a field.
    var text: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = (try? encoder.encode(self)) ?? Data("{}".utf8)
        return String(decoding: data, as: UTF8.self) + "\n"
    }
}
