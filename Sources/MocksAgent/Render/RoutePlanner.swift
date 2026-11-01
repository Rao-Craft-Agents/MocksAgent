//  WHAT: What each endpoint of the API answers on the mock backend, planned from its line and the world: a paged
//        list cut from every record of its kind (narrowed by the query's ids, searched, ordered by its sort), one
//        item found by the id or the name a request names (with the lists that refer to it), what a body makes
//        echoed back, a sign-in's token, bytes, or a fixture as it is.
//  PIN:  THE REQUEST DECIDES THE ANSWER. A post asked for by its id is that post, a post's comments are its own, the
//        last page is short and the one after it empty; a screen that taps through the mock sees what it tapped.

import Foundation

struct RoutePlanner {
    let shape: Shape
    let world: World
    let renderer: Renderer
    var pageSize = 10

    /// A route that lists items of a type: its method and its items.
    struct Listing {
        var method: ClientMethod
        var item: String
        var itemsKey: String?
    }

    /// Every method's plan, in the methods' order.
    func plans() -> [RoutePlan] {
        let methods = shape.api.methods
        var plans: [RoutePlan?] = Array(repeating: nil, count: methods.count)
        var listings: [Listing] = []
        for (index, method) in methods.enumerated() {
            if let list = listPlan(method) {
                plans[index] = .list(list)
                if let base = Shape.base(list.item) { listings.append(Listing(method: method, item: base, itemsKey: list.itemsKey)) }
            }
        }
        for (index, method) in methods.enumerated() where plans[index] == nil {
            plans[index] = otherPlan(method, listings: listings)
        }
        return plans.map { $0 ?? .nothing }
    }

    // MARK: - Lists

    func listPlan(_ method: ClientMethod) -> RoutePlan.List? {
        guard case .json(let answer) = method.answer else { return nil }
        var item: TypeRef, itemsKey: String?
        var paging = RoutePlan.Paging.none
        if let plan = method.paging {
            item = plan.item
            itemsKey = plan.itemsField.flatMap { name in Shape.base(answer).flatMap { shape.field(name, of: $0) }.map(shape.key) }
            if plan.next == .number {
                paging = .page(plan.marker.wire)
            } else {
                var next: String?
                if case .field(let name, _) = plan.next { next = Shape.base(answer).flatMap { shape.field(name, of: $0) }.map(shape.key) }
                paging = .cursor(plan.marker.wire, id: idPath(of: plan.item) ?? [], next: next)
            }
        } else {
            guard method.endpoint.method == "GET", method.query.allSatisfy({ !$0.required }) else { return nil }
            if case .array(let element) = answer.unwrapped {
                item = element
            } else if let base = Shape.base(answer), shape.kind(of: base) == .view, let entity = shape.entity(base) {
                let lists = entity.fields.filter { Shape.isList($0.type) && [.record, .view].contains(shape.kind(of: Shape.base($0.type) ?? "")) }
                let records = entity.fields.filter { !Shape.isList($0.type) && [.record, .view].contains(shape.kind(of: Shape.base($0.type) ?? "")) }
                guard lists.count == 1, records.isEmpty, let field = lists.first, case .array(let element) = field.type.unwrapped else { return nil }
                item = element
                itemsKey = shape.key(field)
            } else {
                return nil
            }
            // A path parameter narrows a list (an account's statuses); one with none is the whole list.
            if !method.path.isEmpty, method.path.allSatisfy({ filterPath(for: $0, in: method, item: item) == nil }) { return nil }
        }
        guard let base = Shape.base(item), let primary = primaryRecord(of: base) else { return nil }
        let indices = order(primary)
        let items: [JSONValue] = indices.map { index in
            shape.kind(of: base) == .record ? renderer.record(base, index) : renderer.view(base, [(primary, index)])
        }

        // The query: what narrows, what searches, what orders.
        var filters: [RoutePlan.Filter] = [], search: [String] = [], sort: RoutePlan.Sort?
        let marker = method.paging?.marker.wire, limit = method.paging?.limit?.wire
            ?? method.query.first { ["limit", "perpage", "pagesize", "count"].contains(SwiftName.normalized($0.wire)) }?.wire
        for argument in method.path + method.query where argument.wire != marker && argument.wire != limit {
            let word = SwiftName.normalized(argument.wire)
            if ["q", "query", "search", "term", "keyword", "keywords", "text"].contains(word) {
                search.append(argument.wire)
            } else if ["sort", "order", "sortby", "orderby", "sorttype", "ordering"].contains(word), let enumName = Shape.base(argument.type),
                      shape.kind(of: enumName) == .choice {
                sort = sortPlan(argument.wire, choice: enumName, item: base)
            } else if let path = filterPath(for: argument, in: method, item: item) {
                filters.append(filter(argument.wire, path: path, items: items))
            }
        }

        var envelope = itemsKey == nil ? JSONValue.array([]) : renderer.render(answer)
        let totals = itemsKey == nil ? [] : (Shape.base(answer).flatMap(shape.entity)?.fields ?? []).filter { field in
            ["total", "totalcount", "count", "totalresults", "totalitems", "results"].contains(SwiftName.normalized(field.name))
                && field.type.unwrapped == .named("Int")
        }.map(shape.key)
        for key in totals { envelope.set(key, .int(items.count)) }
        var pages: [JSONValue] = []
        let size = pageSize
        let chunks = stride(from: 0, to: max(items.count, 1), by: size).map { Array(items[$0..<min($0 + size, items.count)]) }
        for (number, chunk) in chunks.enumerated() {
            guard let key = itemsKey else { pages.append(.array(chunk)); continue }
            var page = envelope
            page.set(key, .array(chunk))
            if case .cursor(_, let id, let next?) = paging {
                let last = number < chunks.count - 1 ? chunk.last.flatMap { $0[path: id] } : nil
                page.set(next, last ?? .null)
            }
            pages.append(page)
        }
        return RoutePlan.List(pages: pages, type: answer, item: item, itemsKey: itemsKey, paging: paging, limit: limit, size: size,
                              filters: filters, search: search, sort: sort, totals: totals)
    }

    /// The order a list shows a type's records in: the content as a busy front page does (what is liked and recent
    /// first), replies and the rest newest first, people and groups busiest first.
    func order(_ type: String) -> [Int] {
        let records = world.all(type)
        if shape.contents.contains(type) {
            let hot = records.map { record -> Double in
                let hours = max(0, world.anchor.timeIntervalSince(record.date) / 3_600)
                return Double(record.upvotes - record.downvotes + 1) / pow(hours + 2, 1.4)
            }
            return records.indices.sorted { hot[$0] == hot[$1] ? $0 > $1 : hot[$0] > hot[$1] }
        }
        if type == shape.person || shape.groups.contains(type) {
            return records.indices.sorted { records[$0].popularity == records[$1].popularity ? $0 < $1 : records[$0].popularity > records[$1].popularity }
        }
        return records.indices.sorted { records[$0].date == records[$1].date ? $0 > $1 : records[$0].date > records[$1].date }
    }

    /// The path to the value an item holds for `argument`: the id of the record it names (`community_id` →
    /// `post.community_id`), or the field of its name.
    func filterPath(for argument: ClientMethod.Argument, in method: ClientMethod, item: TypeRef) -> [String]? {
        guard let base = Shape.base(item), let primary = primaryRecord(of: base) else { return nil }
        var target: String?
        if argument.wire == "id" || SwiftName.normalized(argument.wire) == "id" {
            // `/accounts/{id}/statuses`: the segment before the parameter names the record.
            let segments = method.endpoint.path.split(separator: "/").map(String.init)
            if let at = segments.firstIndex(of: "{\(argument.wire)}"), at > 0 {
                let word = SwiftName.normalized(segments[at - 1])
                target = shape.records.first { SwiftName.normalized($0) == word || SwiftName.normalized(SwiftName.plural($0)) == word }
            }
        } else if let stem = Shape.idStem(argument.name, plural: false), let entity = shape.entity(primary) {
            target = Shape.referenced(stem, in: entity, records: shape.records, person: shape.person)
        }
        if let target { return idPath(to: target, in: base) }
        // A field of the item's own record by the parameter's name (`?course=main`).
        if let field = shape.entity(primary)?.fields.first(where: { shape.key($0) == argument.wire }), !Shape.isList(field.type) {
            return base == primary ? [shape.key(field)] : primaryField(of: base).map { [shape.key($0), shape.key(field)] }
        }
        return nil
    }

    /// The path in an item of `item` (a record or a view) to the id of the record of `target` it holds or names.
    func idPath(to target: String, in item: String) -> [String]? {
        guard let idKey = idKey(of: target) else { return nil }
        if shape.kind(of: item) == .record {
            if item == target { return [idKey] }
            return refPath(to: target, in: item)
        }
        guard let entity = shape.entity(item) else { return nil }
        let holding = entity.fields.filter { shape.role($0, of: item) == .record(target) }
        if let field = holding.first(where: { SwiftName.normalized($0.name) == SwiftName.normalized(target) }) ?? holding.first {
            return [shape.key(field), idKey]
        }
        if let primary = primaryField(of: item), case .record(let type) = shape.role(primary, of: item), let path = refPath(to: target, in: type) {
            return [shape.key(primary)] + path
        }
        return nil
    }

    /// The path in a record of `type` to the id of the record of `target` it refers to.
    private func refPath(to target: String, in type: String) -> [String]? {
        guard let entity = shape.entity(type) else { return nil }
        if let field = entity.fields.first(where: { shape.role($0, of: type) == .reference(target) }) { return [shape.key(field)] }
        if let field = entity.fields.first(where: { shape.role($0, of: type) == .record(target) }), let idKey = idKey(of: target) {
            return [shape.key(field), idKey]
        }
        return nil
    }

    /// The path in an item to its own id: a record's `id`, a view's record's.
    func idPath(of item: TypeRef) -> [String]? {
        guard let base = Shape.base(item), let primary = primaryRecord(of: base), let idKey = idKey(of: primary) else { return nil }
        if base == primary { return [idKey] }
        return primaryField(of: base).map { [shape.key($0), idKey] }
    }

    private func idKey(of type: String) -> String? {
        shape.entity(type)?.fields.first { $0.name == "id" }.map(shape.key)
    }

    private func filter(_ parameter: String, path: [String], items: [JSONValue]) -> RoutePlan.Filter {
        var tally: [String: (value: JSONValue, count: Int)] = [:]
        for item in items {
            guard let value = item[path: path], let text = value.text else { continue }
            tally[text, default: (value, 0)].count += 1
        }
        let best = tally.values.filter { $0.count < items.count }.max { $0.count == $1.count ? $0.value.text ?? "" > $1.value.text ?? "" : $0.count < $1.count }
            ?? tally.values.first
        return RoutePlan.Filter(parameter: parameter, path: path, sample: best?.value, matches: best?.count ?? 0)
    }

    /// How a sort's values order the list: newest, oldest, most loved, most replied.
    private func sortPlan(_ parameter: String, choice: String, item: String) -> RoutePlan.Sort? {
        guard let entity = shape.entity(choice), let primary = primaryRecord(of: item) else { return nil }
        let prefix = item == primary ? [] : primaryField(of: item).map { [shape.key($0)] } ?? []
        let created = shape.field(of: primary, where: { $0 == .created }).map { prefix + [shape.key($0)] }
        var score: [String]?, replies: [String]?
        if let field = shape.field(of: primary, where: { $0 == .score }) {
            score = prefix + [shape.key(field)]
        } else if let view = shape.entity(item) {
            for field in view.fields {
                guard case .composite(let name) = shape.role(field, of: item) else { continue }
                if score == nil, let inner = shape.field(of: name, where: { $0 == .score }) { score = [shape.key(field), shape.key(inner)] }
                if replies == nil, let inner = shape.entity(name)?.fields.first(where: {
                    if case .count(let word) = shape.role($0, of: name) { return word.hasPrefix("comment") || word.hasPrefix("repl") || word.hasPrefix("child") }
                    return false
                }) { replies = [shape.key(field), shape.key(inner)] }
            }
        }
        var orders: [(value: String, path: [String], descending: Bool)] = []
        for item in entity.cases {
            guard let value = shape.raw(item, of: entity).text else { continue }
            let word = SwiftName.normalized(value)
            if word.contains("comment") || word.contains("repl") || word.contains("discuss"), let replies {
                orders.append((value, replies, true))
            } else if word.hasPrefix("new") || word.contains("latest") || word.contains("recent"), let created {
                orders.append((value, created, true))
            } else if word.hasPrefix("old"), let created {
                orders.append((value, created, false))
            } else if word.hasPrefix("top") || word.contains("best") || word.hasPrefix("most") || word.contains("score"), let score {
                orders.append((value, score, true))
            }
        }
        return orders.isEmpty ? nil : RoutePlan.Sort(parameter: parameter, orders: orders)
    }

    // MARK: - Everything else

    func otherPlan(_ method: ClientMethod, listings: [Listing]) -> RoutePlan {
        switch method.answer {
        case .nothing: return .nothing
        case .data: return .picture
        case .text: return .text(method.tokenField != nil ? renderer.token : "OK")
        case .json(let answer):
            if method.tokenField != nil { return .fixture(renderer.render(answer), type: answer) }
            if method.endpoint.method == "GET", let lookup = lookupPlan(method, answer: answer, listings: listings) { return .lookup(lookup) }
            if ["POST", "PUT", "PATCH"].contains(method.endpoint.method), let body = method.body, let plan = writePlan(method, answer: answer, body: body, listings: listings) {
                return plan
            }
            // One item with nothing to find it by: the signed-in person for an account, else the first.
            var context: Renderer.Context = []
            if let found = found(in: answer), let primary = found.primary, primary == shape.person { context = [(primary, world.me)] }
            return .fixture(renderer.render(answer, context), type: answer)
        }
    }

    /// The one item `answer` is about: where it is in the answer (`post_view`), its type, and its record type. A view
    /// that is one record with what goes with it (`PostView`) is the item itself.
    func found(in answer: TypeRef) -> (path: [String], type: String, primary: String?)? {
        guard let base = Shape.base(answer), !Shape.isList(answer) else { return nil }
        switch shape.kind(of: base) {
        case .record:
            return ([], base, base)
        case .view:
            if isViewOfOne(base), let primary = primaryRecord(of: base) { return ([], base, primary) }
            guard let entity = shape.entity(base) else { return nil }
            for field in entity.fields where !Shape.isList(field.type) {
                guard let inner = Shape.base(field.type) else { continue }
                if shape.kind(of: inner) == .record { return ([shape.key(field)], inner, inner) }
                if shape.kind(of: inner) == .view, let primary = primaryRecord(of: inner) { return ([shape.key(field)], inner, primary) }
            }
            return nil
        default:
            return nil
        }
    }

    /// Whether a view is one record with what goes with it: its first field is a record named for its type
    /// (`post: Post`).
    private func isViewOfOne(_ view: String) -> Bool {
        guard let first = shape.entity(view)?.fields.first, case .record(let type) = shape.role(first, of: view) else { return false }
        return SwiftName.normalized(first.name) == SwiftName.normalized(type)
    }

    func lookupPlan(_ method: ClientMethod, answer: TypeRef, listings: [Listing]) -> RoutePlan.Lookup? {
        guard let found = found(in: answer), let primary = found.primary else { return nil }
        let candidates: [(RoutePlan.Key, String)] = method.path.map { (.path($0.wire), $0.wire) } + method.query.filter(\.required).map { (.query($0.wire), $0.wire) }
        for (key, wire) in candidates {
            guard let field = keyField(wire, of: primary) else { continue }
            let match = found.type == primary ? [shape.key(field)] : (primaryField(of: found.type).map { [shape.key($0), shape.key(field)] } ?? [])
            guard !match.isEmpty else { continue }
            let items = source(for: found.type, primary: primary, listings: listings)
            let response = found.path.isEmpty ? nil : renderer.render(answer, [(primary, 0)])
            let related = relatedLists(in: answer, found: found, primary: primary, listings: listings)
            let sample = world.record(primary, 0).flatMap { $0.values[field.name] ?? ($0.id.isNull ? nil : $0.id) } ?? .null
            return RoutePlan.Lookup(key: key, items: items, match: match, response: response, type: answer, place: found.path,
                                    related: related, sample: sample)
        }
        return nil
    }

    /// The field of `type` a request's `wire` value names: its id for `id` or `<type>_id`, its handle for a name.
    private func keyField(_ wire: String, of type: String) -> Field? {
        guard let entity = shape.entity(type) else { return nil }
        let word = SwiftName.normalized(wire)
        if word == "id" || word == SwiftName.normalized(type) + "id" { return entity.fields.first { $0.name == "id" } }
        if ["name", "username", "handle", "slug", "acct", "login", "screenname"].contains(word) {
            return entity.fields.first { shape.role($0, of: type) == .handle } ?? entity.fields.first { SwiftName.normalized($0.name) == word }
        }
        return entity.fields.first { shape.key($0) == wire }
    }

    /// Where the items of `type` are: a list route of them, a list route whose items hold one, or its own.
    private func source(for type: String, primary: String, listings: [Listing]) -> RoutePlan.Items {
        if let listing = listings.first(where: { $0.item == type }) {
            return .route(listing.method.endpoint.method, listing.method.endpoint.path, at: nil)
        }
        for listing in listings {
            guard let entity = shape.entity(listing.item), shape.kind(of: listing.item) == .view else { continue }
            if let field = entity.fields.first(where: { Shape.base($0.type) == type && !Shape.isList($0.type) }) {
                return .route(listing.method.endpoint.method, listing.method.endpoint.path, at: [shape.key(field)])
            }
        }
        let indices = order(primary)
        let items = indices.map { index in shape.kind(of: type) == .record ? renderer.record(type, index) : renderer.view(type, [(primary, index)]) }
        return .own(items, type: .named(type))
    }

    /// The lists in a lookup's answer that belong with the item found: a person's posts and comments.
    private func relatedLists(in answer: TypeRef, found: (path: [String], type: String, primary: String?), primary: String,
                              listings: [Listing]) -> [RoutePlan.Related] {
        guard let base = Shape.base(answer), let entity = shape.entity(base), !found.path.isEmpty, let idKey = idKey(of: primary) else { return [] }
        let to = found.type == primary ? [idKey] : (primaryField(of: found.type).map { [shape.key($0), idKey] } ?? [])
        var related: [RoutePlan.Related] = []
        for field in entity.fields where Shape.isList(field.type) {
            guard let element = Shape.base(field.type), [.record, .view].contains(shape.kind(of: element)),
                  let match = idPath(to: primary, in: element), let elementPrimary = primaryRecord(of: element) else { continue }
            let items = source(for: element, primary: elementPrimary, listings: listings)
            related.append(RoutePlan.Related(place: [shape.key(field)], items: items, match: match, to: to, limit: 20))
        }
        return related
    }

    func writePlan(_ method: ClientMethod, answer: TypeRef, body: TypeRef, listings: [Listing]) -> RoutePlan? {
        guard let found = found(in: answer), let primary = found.primary, let bodyType = Shape.base(body), let bodyEntity = shape.entity(bodyType) else { return nil }
        // A body that names an existing record of the answer's type (a vote on a post): that record.
        for field in bodyEntity.fields {
            guard let stem = Shape.idStem(field.name, plural: false), SwiftName.upperCamel(stem) == primary,
                  let idField = shape.entity(primary)?.fields.first(where: { $0.name == "id" }) else { continue }
            let match = found.type == primary ? [shape.key(idField)] : (primaryField(of: found.type).map { [shape.key($0), shape.key(idField)] } ?? [])
            let items = source(for: found.type, primary: primary, listings: listings)
            let response = found.path.isEmpty ? nil : renderer.render(answer, [(primary, 0)])
            let sample = world.record(primary, 0)?.id ?? .null
            return .lookup(RoutePlan.Lookup(key: .body(shape.key(field)), items: items, match: match, response: response, type: answer,
                                            place: found.path, related: [], sample: sample))
        }
        // A body that makes one: the answer with the body's values over a record by the signed-in person.
        let mine = world.all(primary).last { $0.author == world.me }?.index ?? world.all(primary).last?.index ?? 0
        let response = renderer.render(answer, [(primary, mine)])
        let place = found.type == primary ? found.path : (primaryField(of: found.type).map { found.path + [shape.key($0)] } ?? found.path)
        let id = idKey(of: primary)
        let dates = (shape.entity(primary)?.fields ?? []).filter { shape.role($0, of: primary) == .created }.map(shape.key)
        var joins: [RoutePlan.Join] = []
        for field in bodyEntity.fields {
            guard let stem = Shape.idStem(field.name, plural: false),
                  let target = Shape.referenced(stem, in: bodyEntity, records: shape.records, person: shape.person), target != primary,
                  let targetID = idKey(of: target) else { continue }
            let holder = found.type == primary ? nil : shape.entity(found.type)?.fields.first { shape.role($0, of: found.type) == .record(target) }
            guard let holder else { continue }
            let items = source(for: target, primary: target, listings: listings)
            joins.append(RoutePlan.Join(body: shape.key(field), items: items, match: [targetID], place: found.path + [shape.key(holder)]))
        }
        return .echo(RoutePlan.Echo(response: response, type: answer, place: place, id: id, dates: dates, joins: joins))
    }

    // MARK: - Views

    func primaryRecord(of type: String) -> String? {
        shape.kind(of: type) == .record ? type : renderer.primaryRecord(of: type)
    }

    func primaryField(of view: String) -> Field? { renderer.primaryField(of: view) }
}
