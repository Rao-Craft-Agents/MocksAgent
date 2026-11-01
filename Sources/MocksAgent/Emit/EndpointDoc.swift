//  WHAT: Doc comment lines, wrapped at 120 columns.

import Foundation

enum EndpointDoc {
    /// `text` as `///` lines at `indent`, none past 120 columns.
    static func lines(_ text: String, indent: String) -> [String] {
        var lines: [String] = [], line = ""
        for word in text.split(separator: " ") {
            if !line.isEmpty, indent.count + 4 + line.count + 1 + word.count > 120 {
                lines.append("\(indent)/// \(line)")
                line = ""
            }
            line += (line.isEmpty ? "" : " ") + word
        }
        lines.append("\(indent)/// \(line)")
        return lines
    }
}
