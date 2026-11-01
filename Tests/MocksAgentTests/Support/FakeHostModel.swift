import Foundation
import GraniteAgents

/// A host model that answers each ask with what its script makes of it (the schema, the system prompt and the ask),
/// and keeps what it was asked.
final class FakeHostModel: AgentHostModel, @unchecked Sendable {
    struct Ask { let schema: Data; let system: String; let user: String }

    private let lock = NSLock()
    private let script: @Sendable (Ask, Int) -> Data
    private var kept: [Ask] = []

    /// A model whose answer to the `n`th ask (from 0) is `script(ask, n)`.
    init(_ script: @escaping @Sendable (Ask, Int) -> Data) { self.script = script }

    /// A model that answers its scripted replies in order, the last one again when it runs out.
    convenience init(replies: [String]) {
        self.init { _, number in Data(replies[min(number, replies.count - 1)].utf8) }
    }

    var asked: [Ask] { lock.withLock { kept } }

    func object(schema: Data, system: String, user: String, maxTokens: Int, seconds: Double) async throws -> Data {
        let ask = Ask(schema: schema, system: system, user: user)
        let number = lock.withLock { () -> Int in
            kept.append(ask)
            return kept.count - 1
        }
        return script(ask, number)
    }

    func text(system: String, user: String, maxTokens: Int, seconds: Double) async throws -> String { "" }
}
