//  WHAT: Picks that come out the same for the same seed (SplitMix64): which records a person wrote, when, how many
//        votes, which picture. A call with the same seed and the same words makes the same fixtures.

import Foundation

struct Seeded: Sendable {
    private var state: UInt64

    init(_ seed: Int) {
        state = UInt64(bitPattern: Int64(seed)) &+ 0x9E37_79B9_7F4A_7C15
    }

    /// A seed made from `text`: the same text, the same picks, on every run.
    static func seed(_ text: String) -> Int {
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in text.utf8 { hash = (hash ^ UInt64(byte)) &* 0x0000_0100_0000_01B3 }
        return Int(truncatingIfNeeded: hash & 0x7FFF_FFFF)
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// A number in `0..<1`.
    mutating func unit() -> Double { Double(next() >> 11) / Double(1 << 53) }

    /// A whole number in `range`.
    mutating func int(_ range: ClosedRange<Int>) -> Int {
        range.lowerBound + Int(next() % UInt64(range.upperBound - range.lowerBound + 1))
    }

    /// True `probability` of the time.
    mutating func chance(_ probability: Double) -> Bool { unit() < probability }

    /// One of `items`.
    mutating func pick<T>(_ items: [T]) -> T { items[int(0...(items.count - 1))] }

    /// An index into `weights`, each as likely as its weight.
    mutating func weighted(_ weights: [Double]) -> Int {
        let total = weights.reduce(0, +)
        guard total > 0 else { return int(0...(weights.count - 1)) }
        var left = unit() * total
        for (index, weight) in weights.enumerated() {
            left -= weight
            if left < 0 { return index }
        }
        return weights.count - 1
    }

    /// `items` in an order of its own.
    mutating func shuffled<T>(_ items: [T]) -> [T] {
        var items = items
        guard items.count > 1 else { return items }
        for index in stride(from: items.count - 1, to: 0, by: -1) {
            items.swapAt(index, int(0...index))
        }
        return items
    }

    /// A popularity in `0...1` with a long tail: most records quiet, a few loved.
    mutating func popularity() -> Double { pow(unit(), 2.6) }
}
