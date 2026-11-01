//  WHAT: One fixture the package keeps: its name in `MockFixtures`, what it is, its JSON (one answer or a list of
//        them), and the type each one decodes as.

import Foundation

struct FixtureConstant: Sendable {
    var name: String
    var doc: String
    var values: [JSONValue]
    /// Whether it is a list of answers (a list's pages, a lookup's items) or one.
    var many: Bool
    var type: TypeRef

    /// `MockFixtures.posts`.
    var reference: String { "MockFixtures.\(name)" }
}
