//  WHAT: Values said in Swift: a JSON fixture as a raw string literal a person reads as JSON, a string as a quoted
//        literal, a path as an array of keys.
//  PIN:  NOTHING IN A FIXTURE CAN END ITS LITERAL. The raw string's `#` count is chosen so no `"""#` and no `\#`
//        inside the JSON is read as Swift.

import Foundation

enum SwiftLiteral {
    /// `json` as a multi-line raw string literal, its lines at `indent` spaces, the closing delimiter too.
    static func raw(_ json: JSONValue, indent: Int) -> String {
        let text = json.pretty()
        var hashes = "#"
        while text.contains("\"\"\"" + hashes) || text.contains("\\" + hashes) { hashes += "#" }
        let pad = String(repeating: " ", count: indent)
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map { pad + $0 }
        return "\(hashes)\"\"\"\n" + lines.joined(separator: "\n") + "\n\(pad)\"\"\"\(hashes)"
    }

    /// `text` as a Swift string literal.
    static func quoted(_ text: String) -> String {
        var out = "\""
        for character in text {
            switch character {
            case "\\": out += "\\\\"
            case "\"": out += "\\\""
            case "\n": out += "\\n"
            case "\t": out += "\\t"
            case "\r": out += "\\r"
            default: out.append(character)
            }
        }
        return out + "\""
    }

    /// `["post", "id"]`.
    static func path(_ keys: [String]) -> String {
        "[" + keys.map(quoted).joined(separator: ", ") + "]"
    }
}
