//  WHAT: The content writer on the host's model: a batch of records or a few threads a time, each answer checked
//        (`ContentCheck`), what fails asked for again with the reasons, up to the call's rounds; what still fails
//        after them is written from the word lists and said in the notes.
//  PIN:  NARROW ASKS. Six posts, ten people or about a dozen replies an ask, each a fresh session, budgeted for a
//        local model (~50 tokens a second); never "write the fixtures".

import Foundation
import GraniteAgents

struct ModelWriter: ContentWriter {
    let model: any AgentHostModel
    let theme: Theme
    let rounds: Int
    let note: @Sendable (String) -> Void
    var fallback: WordWriter
    private(set) var asks = 0
    private(set) var retries = 0
    private(set) var notes: [String] = []

    init(model: any AgentHostModel, theme: Theme, rounds: Int, seed: Int, note: @escaping @Sendable (String) -> Void) {
        self.model = model
        self.theme = theme
        self.rounds = max(1, rounds)
        self.note = note
        self.fallback = WordWriter(theme: theme, seed: seed)
    }

    mutating func records(_ ask: RecordAsk) async throws -> [[String: JSONValue]] {
        var good: [[String: JSONValue]] = [], problems: [String] = []
        var taken = Set(ask.taken.map { $0.lowercased() })
        let system = ContentPrompt.recordsSystem(theme)
        for round in 1...rounds {
            try Task.checkCancellation()
            let wanted = ask.count - good.count
            guard wanted > 0 else { break }
            var asked = ask
            asked.taken = ask.taken + good.flatMap { record in
                ask.fields.filter { $0.role == .handle || $0.role == .title }.compactMap { record[$0.name]?.text }
            }
            asked.handles = ask.handles + good.flatMap { record in
                ask.fields.filter { $0.role == .handle }.compactMap { record[$0.name]?.text }
            }
            asked.angles = Array(ask.angles.suffix(wanted))
            let user = ContentPrompt.recordsUser(asked, theme: theme, count: wanted, problems: round == 1 ? [] : problems)
            let perRecord = ask.part == .content ? 420 : 160
            let maxTokens = min(8_000, 300 + perRecord * wanted)
            asks += 1
            if round > 1 { retries += 1 }
            do {
                let data = try await model.object(schema: ContentPrompt.recordsSchema(asked, count: wanted), system: system, user: user,
                                                  maxTokens: maxTokens, seconds: 60 + Double(maxTokens) / 25)
                let checked = ContentCheck.records(data, ask: asked, count: wanted, taken: taken)
                for record in checked.good {
                    for field in ask.fields where field.role == .handle || field.role == .title {
                        if let text = record[field.name]?.text { taken.insert(text.lowercased()) }
                    }
                }
                good += checked.good
                problems = checked.problems
            } catch {
                if error is CancellationError || Task.isCancelled { throw CancellationError() }
                problems = ["no answer came back (\(error))"]
            }
            if good.count < ask.count, round < rounds, let first = problems.first {
                note("\(SwiftName.words(ask.plural)): asking again for \(ask.count - good.count): \(first.prefix(90))")
            }
        }
        if good.count < ask.count {
            var rest = ask
            rest.count = ask.count - good.count
            rest.taken = Array(taken)
            good += try await fallback.records(rest)
            notes.append("\(rest.count) of the \(SwiftName.words(ask.plural)) came from word lists after \(rounds) answers that did not pass: \(problems.first ?? "no answer")")
        }
        return good
    }

    mutating func threads(_ ask: ThreadAsk) async throws -> [[ThreadLine]] {
        var done: [Int: [ThreadLine]] = [:], problems: [String] = []
        let system = ContentPrompt.threadsSystem(theme, ask: ask)
        for round in 1...rounds {
            try Task.checkCancellation()
            let pending = ask.parents.filter { done[$0.number] == nil }
            guard !pending.isEmpty else { break }
            let user = ContentPrompt.threadsUser(ask, theme: theme, parents: pending, problems: round == 1 ? [] : problems)
            let replies = pending.reduce(0) { $0 + $1.count }
            let maxTokens = min(8_000, 250 + 150 * replies)
            asks += 1
            if round > 1 { retries += 1 }
            do {
                let data = try await model.object(schema: ContentPrompt.threadsSchema(ask), system: system, user: user,
                                                  maxTokens: maxTokens, seconds: 60 + Double(maxTokens) / 25)
                problems = []
                for (number, result) in ContentCheck.threads(data, ask: ask, parents: pending) {
                    switch result {
                    case .success(let lines): done[number] = lines
                    case .failure(let failure): problems.append(failure.reason)
                    }
                }
            } catch {
                if error is CancellationError || Task.isCancelled { throw CancellationError() }
                problems = ["no answer came back (\(error))"]
            }
            if done.count < ask.parents.count, round < rounds, let first = problems.first {
                note("\(SwiftName.plural(ask.noun)): asking again for \(ask.parents.count - done.count) thread\(ask.parents.count - done.count == 1 ? "" : "s"): \(first.prefix(90))")
            }
        }
        let missing = ask.parents.filter { done[$0.number] == nil }
        if !missing.isEmpty {
            var rest = ask
            rest.parents = missing
            for (parent, lines) in zip(missing, try await fallback.threads(rest)) { done[parent.number] = lines }
            notes.append("\(missing.count) thread\(missing.count == 1 ? "" : "s") of \(SwiftName.plural(ask.noun)) came from word lists after \(rounds) answers that did not pass: \(problems.first ?? "no answer")")
        }
        return ask.parents.map { done[$0.number] ?? [] }
    }
}
