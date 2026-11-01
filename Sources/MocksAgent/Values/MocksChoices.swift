import Foundation

/// A way the mock backend answers, as a call names it: the scenarios a package's tests prove.
public enum MocksScenario: String, Codable, Sendable, CaseIterable {
    /// Every endpoint answers with its fixtures.
    case normal
    /// Every list answers with no items, and nothing is found by its id.
    case empty
    /// Every request fails with a server error (500) and the API's error body.
    case failing
    /// Every request is refused (401) with the API's error body.
    case unauthorized
    /// Every answer comes after a long wait.
    case slow
}
