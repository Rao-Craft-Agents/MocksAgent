//  WHAT: The lines a client package was made from, as `network` keeps them in the package's `api.json`, with a
//        call's own lines merged over them the way `network` merges a later call's: a line replaces the one with its
//        method and path, its name or its type, and the rest stays.

import Foundation

struct APIRecord: Codable, Equatable {
    var name: String
    var baseURL: String?
    var auth: String
    var authName: String?
    var paging: String
    var feeds: Bool
    var coding: String
    var dates: [String]
    var endpoints: [String]
    var entities: [String]

    static let fileName = "api.json"

    init(name: String, baseURL: String? = nil, auth: String = "none", authName: String? = nil, paging: String = "none",
         feeds: Bool = false, coding: String = "exact", dates: [String] = [], endpoints: [String] = [], entities: [String] = []) {
        self.name = name; self.baseURL = baseURL; self.auth = auth; self.authName = authName; self.paging = paging
        self.feeds = feeds; self.coding = coding; self.dates = dates; self.endpoints = endpoints; self.entities = entities
    }

    /// Read leniently: a key an older `network` did not write takes its default.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        baseURL = try container.decodeIfPresent(String.self, forKey: .baseURL)
        auth = try container.decodeIfPresent(String.self, forKey: .auth) ?? "none"
        authName = try container.decodeIfPresent(String.self, forKey: .authName)
        paging = try container.decodeIfPresent(String.self, forKey: .paging) ?? "none"
        feeds = try container.decodeIfPresent(Bool.self, forKey: .feeds) ?? false
        coding = try container.decodeIfPresent(String.self, forKey: .coding) ?? "exact"
        dates = try container.decodeIfPresent([String].self, forKey: .dates) ?? []
        endpoints = try container.decodeIfPresent([String].self, forKey: .endpoints) ?? []
        entities = try container.decodeIfPresent([String].self, forKey: .entities) ?? []
    }

    /// The record in `folder`, if `network` wrote one there.
    static func read(in folder: URL) -> APIRecord? {
        guard let data = try? Data(contentsOf: folder.appendingPathComponent(fileName)) else { return nil }
        return try? JSONDecoder().decode(APIRecord.self, from: data)
    }

    /// The record with `endpoints` and `entities` merged over its own.
    func merging(endpoints: [String]?, entities: [String]?) -> APIRecord {
        var merged = self
        merged.endpoints = Self.merge(self.endpoints, Self.clean(endpoints), keys: Self.endpointKeys)
        merged.entities = Self.merge(self.entities, Self.clean(entities), keys: Self.entityKeys)
        return merged
    }

    private static func clean(_ lines: [String]?) -> [String] {
        (lines ?? []).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    /// `old` with each line a `new` line shares a key with replaced in place, then the rest of `new`.
    static func merge(_ old: [String], _ new: [String], keys: (String) -> Set<String>) -> [String] {
        let newKeys = new.map(keys)
        var placed: Set<Int> = [], merged: [String] = []
        for line in old {
            let lineKeys = keys(line)
            if let index = newKeys.firstIndex(where: { !$0.isDisjoint(with: lineKeys) }) {
                if placed.insert(index).inserted { merged.append(new[index]) }
            } else {
                merged.append(line)
            }
        }
        for (index, line) in new.enumerated() where !placed.contains(index) { merged.append(line) }
        return merged
    }

    /// An endpoint line's method and path, and its name when it gives one.
    static func endpointKeys(_ line: String) -> Set<String> {
        guard let endpoint = try? EndpointLine.parse(line) else { return ["line " + line] }
        var keys: Set<String> = ["signature " + endpoint.signature]
        if let name = endpoint.name { keys.insert("name " + name) }
        return keys
    }

    /// An entity line's type name.
    static func entityKeys(_ line: String) -> Set<String> {
        if let entity = try? EntityLine.parse(line) { return ["type " + entity.name] }
        return ["line " + line]
    }
}
