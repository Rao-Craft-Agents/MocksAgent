//  WHAT: How records stand to each other, asked the same way when a field is filled and when a view is shown: the
//        record one refers to (its author, its group, what it answers), and the records that belong with one (a
//        person's posts, a group's people, a post's replies).

import Foundation

extension World {
    /// The index of the record of `target` that `record` refers to: its author, its group, what it answers or belongs
    /// to; another record, the same one every time, when it stands in none of these.
    func resolve(_ target: String, of record: Record, shape: Shape) -> Int? {
        guard count(target) > 0 else { return nil }
        if target == shape.person, let author = record.author { return author }
        if shape.groups.contains(target), let group = record.group { return group }
        if shape.children[record.type] == target || shape.owned[record.type] == target, let owner = record.owner { return owner }
        if target == record.type { return record.parent }
        if target == shape.person, record.type == shape.person { return (record.index + 1) % count(target) }
        if let owner = record.owner, let ownerType = shape.children[record.type] ?? shape.owned[record.type],
           let held = self.record(ownerType, owner), let found = resolve(target, of: held, shape: shape) { return found }
        return (record.index * 7 + 3) % count(target)
    }

    /// The records of `target` that belong with `record`: a person's posts, a group's people and posts, a post's
    /// replies; a few, the same every time, when none do.
    func related(_ target: String, to record: Record, shape: Shape) -> [Int] {
        let candidates = all(target)
        if record.type == shape.person, target != shape.person {
            return candidates.filter { $0.author == record.index }.map(\.index)
        }
        if shape.groups.contains(record.type) {
            if target == shape.person {
                // Its people: who posts in it, in the order they first did.
                var seen: [Int] = []
                for type in shape.contents {
                    for held in all(type) where held.group == record.index {
                        if let author = held.author, !seen.contains(author) { seen.append(author) }
                    }
                }
                return seen
            }
            return candidates.filter { $0.group == record.index }.map(\.index)
        }
        if shape.children[target] == record.type || shape.owned[target] == record.type {
            return candidates.filter { $0.owner == record.index }.map(\.index)
        }
        if target == record.type { return candidates.filter { $0.parent == record.index }.map(\.index) }
        guard !candidates.isEmpty else { return [] }
        let start = (record.index * 5) % candidates.count
        return (0..<min(candidates.count, 6)).map { (start + $0) % candidates.count }
    }

    /// Every reply under `record`, however deep.
    func descendants(of record: Record) -> Int {
        let replies = all(record.type)
        var count = 0, frontier: Set<Int> = [record.index]
        while !frontier.isEmpty {
            let next = Set(replies.filter { $0.parent.map(frontier.contains) == true }.map(\.index))
            count += next.count
            frontier = next
        }
        return count
    }
}
