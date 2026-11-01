//  WHAT: The fixtures each route needs, named and written: one file an endpoint, `Mocks/Fixtures/<Name>Fixture.swift`,
//        an extension of `MockFixtures` whose constants hold the JSON as raw string literals.
//  PIN:  NO RESOURCES. A fixture is a Swift literal, so the package builds and the app ships with no bundle to find.

import Foundation

struct FixtureEmitter {
    let api: ClientAPI
    let shape: Shape

    /// Names `MockFixtures` keeps for itself.
    static let reserved: Set<String> = ["writtenAt", "sessionToken", "errorBody"]

    /// The constants `plan` of `method` needs, in the order the route names them.
    func constants(_ method: ClientMethod, _ plan: RoutePlan) -> [FixtureConstant] {
        let name = Self.reserved.contains(method.name) ? method.name + "Fixture" : method.name
        let wire = "`\(method.endpoint.signature)`"
        let about = method.endpoint.doc.map { ": \(Self.lower($0))" } ?? ""
        switch plan {
        case .nothing, .picture, .text:
            return []
        case .fixture(let json, let type):
            return [FixtureConstant(name: name, doc: "\(wire)\(about).", values: [json], many: false, type: type)]
        case .list(let list):
            let pages = list.pages.count == 1 ? "one response" : "a response a page, \(list.size) to a page"
            return [FixtureConstant(name: name, doc: "\(wire)\(about): \(pages).", values: list.pages, many: true, type: list.type)]
        case .lookup(let lookup):
            var constants: [FixtureConstant] = []
            if let response = lookup.response {
                constants.append(FixtureConstant(name: name, doc: "\(wire)\(about): the answer the item found is set into.", values: [response],
                                                 many: false, type: lookup.type))
            }
            if case .own(let items, let type) = lookup.items {
                constants.append(FixtureConstant(name: name + "Items", doc: "What \(wire) finds its item among.", values: items, many: true, type: type))
            }
            for related in lookup.related {
                if case .own(let items, let type) = related.items {
                    let place = SwiftName.upperCamel(related.place.last ?? "items")
                    constants.append(FixtureConstant(name: name + place, doc: "What \(wire) lists under `\(related.place.joined(separator: "."))`, among them those of the item found.",
                                                     values: items, many: true, type: type))
                }
            }
            return constants
        case .echo(let echo):
            var constants = [FixtureConstant(name: name, doc: "\(wire)\(about): what it answers, the request's body set over it.",
                                             values: [echo.response], many: false, type: echo.type)]
            for join in echo.joins {
                if case .own(let items, let type) = join.items {
                    constants.append(FixtureConstant(name: name + SwiftName.upperCamel(join.body) + "Items",
                                                     doc: "What `\(join.body)` in \(wire)'s body names.", values: items, many: true, type: type))
                }
            }
            return constants
        }
    }

    /// The file of `method`'s constants.
    func file(_ constants: [FixtureConstant]) -> String {
        var lines = ["import Foundation", "", "extension MockFixtures {"]
        for (index, constant) in constants.enumerated() {
            if index > 0 { lines.append("") }
            lines += EndpointDoc.lines(constant.doc, indent: "    ")
            if constant.many {
                lines.append("    static let \(constant.name): [String] = [")
                for value in constant.values {
                    lines.append("        " + SwiftLiteral.raw(value, indent: 8) + ",")
                }
                lines.append("    ]")
            } else if let value = constant.values.first {
                lines.append("    static let \(constant.name) = " + SwiftLiteral.raw(value, indent: 4))
            }
        }
        lines.append("}")
        return lines.joined(separator: "\n") + "\n"
    }

    private static func lower(_ text: String) -> String {
        var text = text.trimmingCharacters(in: .whitespaces)
        if text.hasSuffix(".") { text.removeLast() }
        guard let first = text.first, !(text.dropFirst().first?.isUppercase ?? false) else { return text }
        return first.lowercased() + text.dropFirst()
    }
}
