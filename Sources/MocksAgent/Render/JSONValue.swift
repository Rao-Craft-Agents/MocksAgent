//  WHAT: A JSON value with its keys in the order a type declares them: what a fixture is written as, pretty-printed
//        the way a person reads an API's answer, and read back to check a model's answer.
//  PIN:  KEYS IN THE TYPE'S ORDER. A fixture is read beside the type it decodes as; `id` first, the title before the
//        body, as the entity line says them.

import Foundation

indirect enum JSONValue: Equatable, Sendable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([JSONValue])
    case object([(key: String, value: JSONValue)])

    static func == (a: JSONValue, b: JSONValue) -> Bool {
        switch (a, b) {
        case (.null, .null): return true
        case (.bool(let x), .bool(let y)): return x == y
        case (.int(let x), .int(let y)): return x == y
        case (.double(let x), .double(let y)): return x == y
        case (.string(let x), .string(let y)): return x == y
        case (.array(let x), .array(let y)): return x == y
        case (.object(let x), .object(let y)): return x.map(\.key) == y.map(\.key) && x.map(\.value) == y.map(\.value)
        default: return false
        }
    }

    /// The value of `key` in an object.
    subscript(key: String) -> JSONValue? {
        guard case .object(let members) = self else { return nil }
        return members.first { $0.key == key }?.value
    }

    /// The value at `path`, one key a step.
    subscript(path path: [String]) -> JSONValue? {
        var value: JSONValue? = self
        for key in path { value = value?[key] }
        return value
    }

    /// Sets `key` of an object, in place when it is there, last when it is not.
    mutating func set(_ key: String, _ value: JSONValue) {
        guard case .object(var members) = self else { return }
        if let index = members.firstIndex(where: { $0.key == key }) { members[index].value = value } else { members.append((key, value)) }
        self = .object(members)
    }

    /// Sets the value at `path`, when every object on the way is there.
    mutating func set(path: [String], _ value: JSONValue) {
        guard let key = path.first else { self = value; return }
        guard path.count > 1 else { set(key, value); return }
        guard var child = self[key] else { return }
        child.set(path: Array(path.dropFirst()), value)
        set(key, child)
    }

    var isNull: Bool { self == .null }

    /// A string's text, or a number's or a Bool's as a URL writes it.
    var text: String? {
        switch self {
        case .string(let text): return text
        case .int(let value): return String(value)
        case .double(let value): return String(value)
        case .bool(let value): return value ? "true" : "false"
        default: return nil
        }
    }

    // MARK: - Reading

    /// `data` read as JSON, an object's keys in the order the text has them; nil when it is not JSON.
    static func parse(_ data: Data) -> JSONValue? {
        var reader = Reader(bytes: Array(data))
        guard let value = reader.value() else { return nil }
        reader.skipSpace()
        return reader.index == reader.bytes.count ? value : nil
    }

    // MARK: - Writing

    /// The value as JSON, two spaces an indent, each member and element on its own line.
    func pretty(_ indent: Int = 0) -> String {
        let pad = String(repeating: " ", count: indent + 2), end = String(repeating: " ", count: indent)
        switch self {
        case .array(let items):
            guard !items.isEmpty else { return "[]" }
            return "[\n" + items.map { pad + $0.pretty(indent + 2) }.joined(separator: ",\n") + "\n\(end)]"
        case .object(let members):
            guard !members.isEmpty else { return "{}" }
            return "{\n" + members.map { "\(pad)\(Self.quoted($0.key)): \($0.value.pretty(indent + 2))" }.joined(separator: ",\n") + "\n\(end)}"
        default:
            return compact
        }
    }

    /// The value as JSON on one line.
    var compact: String {
        switch self {
        case .null: return "null"
        case .bool(let value): return value ? "true" : "false"
        case .int(let value): return String(value)
        case .double(let value): return value.isFinite ? Self.number(value) : "null"
        case .string(let text): return Self.quoted(text)
        case .array(let items): return "[" + items.map(\.compact).joined(separator: ", ") + "]"
        case .object(let members): return "{" + members.map { "\(Self.quoted($0.key)): \($0.value.compact)" }.joined(separator: ", ") + "}"
        }
    }

    /// `4.5`, `4.0`, `0.25`: a Double as JSON writes it, never in exponent form for an everyday number.
    static func number(_ value: Double) -> String {
        if value == value.rounded(), abs(value) < 1e15 { return String(format: "%.1f", value) }
        var text = String(format: "%.6f", value)
        while text.hasSuffix("0") { text.removeLast() }
        return text
    }

    /// A JSON string of `text`: quotes, backslashes and control characters escaped, nothing else.
    static func quoted(_ text: String) -> String {
        var out = "\""
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
        return out + "\""
    }
}

extension JSONValue {
    /// JSON text read into a `JSONValue`, keys kept in order.
    fileprivate struct Reader {
        let bytes: [UInt8]
        var index = 0

        mutating func skipSpace() {
            while index < bytes.count, [0x20, 0x0A, 0x0D, 0x09].contains(bytes[index]) { index += 1 }
        }

        mutating func value() -> JSONValue? {
            skipSpace()
            guard index < bytes.count else { return nil }
            switch bytes[index] {
            case UInt8(ascii: "{"): return object()
            case UInt8(ascii: "["): return array()
            case UInt8(ascii: "\""): return string().map(JSONValue.string)
            case UInt8(ascii: "t"): return word("true", .bool(true))
            case UInt8(ascii: "f"): return word("false", .bool(false))
            case UInt8(ascii: "n"): return word("null", .null)
            default: return number()
            }
        }

        private mutating func word(_ text: String, _ value: JSONValue) -> JSONValue? {
            let expected = Array(text.utf8)
            guard index + expected.count <= bytes.count, Array(bytes[index..<index + expected.count]) == expected else { return nil }
            index += expected.count
            return value
        }

        private mutating func object() -> JSONValue? {
            index += 1
            var members: [(key: String, value: JSONValue)] = []
            skipSpace()
            if index < bytes.count, bytes[index] == UInt8(ascii: "}") { index += 1; return .object(members) }
            while true {
                skipSpace()
                guard index < bytes.count, bytes[index] == UInt8(ascii: "\""), let key = string() else { return nil }
                skipSpace()
                guard index < bytes.count, bytes[index] == UInt8(ascii: ":") else { return nil }
                index += 1
                guard let value = value() else { return nil }
                members.append((key, value))
                skipSpace()
                guard index < bytes.count else { return nil }
                if bytes[index] == UInt8(ascii: ",") { index += 1; continue }
                if bytes[index] == UInt8(ascii: "}") { index += 1; return .object(members) }
                return nil
            }
        }

        private mutating func array() -> JSONValue? {
            index += 1
            var items: [JSONValue] = []
            skipSpace()
            if index < bytes.count, bytes[index] == UInt8(ascii: "]") { index += 1; return .array(items) }
            while true {
                guard let item = value() else { return nil }
                items.append(item)
                skipSpace()
                guard index < bytes.count else { return nil }
                if bytes[index] == UInt8(ascii: ",") { index += 1; continue }
                if bytes[index] == UInt8(ascii: "]") { index += 1; return .array(items) }
                return nil
            }
        }

        private mutating func string() -> String? {
            index += 1
            var out: [UInt8] = []
            while index < bytes.count {
                let byte = bytes[index]
                index += 1
                if byte == UInt8(ascii: "\"") { return String(decoding: out, as: UTF8.self) }
                guard byte == UInt8(ascii: "\\") else { out.append(byte); continue }
                guard index < bytes.count else { return nil }
                let escaped = bytes[index]
                index += 1
                switch escaped {
                case UInt8(ascii: "n"): out.append(0x0A)
                case UInt8(ascii: "t"): out.append(0x09)
                case UInt8(ascii: "r"): out.append(0x0D)
                case UInt8(ascii: "b"): out.append(0x08)
                case UInt8(ascii: "f"): out.append(0x0C)
                case UInt8(ascii: "u"):
                    guard index + 4 <= bytes.count, var code = UInt32(String(decoding: bytes[index..<index + 4], as: UTF8.self), radix: 16) else { return nil }
                    index += 4
                    // A surrogate pair: the low half follows as another \u.
                    if (0xD800...0xDBFF).contains(code), index + 6 <= bytes.count, bytes[index] == UInt8(ascii: "\\"), bytes[index + 1] == UInt8(ascii: "u"),
                       let low = UInt32(String(decoding: bytes[index + 2..<index + 6], as: UTF8.self), radix: 16), (0xDC00...0xDFFF).contains(low) {
                        code = 0x10000 + ((code - 0xD800) << 10) + (low - 0xDC00)
                        index += 6
                    }
                    out.append(contentsOf: Array(String(Unicode.Scalar(code).map(Character.init) ?? "?").utf8))
                default: out.append(escaped)
                }
            }
            return nil
        }

        private mutating func number() -> JSONValue? {
            let start = index
            while index < bytes.count, "+-0123456789.eE".utf8.contains(bytes[index]) { index += 1 }
            let text = String(decoding: bytes[start..<index], as: UTF8.self)
            guard !text.isEmpty else { return nil }
            if let integer = Int(text) { return .int(integer) }
            return Double(text).map(JSONValue.double)
        }
    }
}
