//  WHAT: How a long text field is written: plain, Markdown or HTML, as its doc or its name says.

import Foundation

/// How a long text is written.
enum TextFormat: String, Equatable, Sendable {
    case plain, markdown, html
}
