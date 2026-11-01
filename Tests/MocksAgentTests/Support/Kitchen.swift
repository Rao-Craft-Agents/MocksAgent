import Foundation
@testable import MocksAgent

/// A cozy recipe-sharing community, as a host's model would write it: the people, the communities, the posts and
/// the replies the gated build's scripted model answers with. Its first batch of posts is wrong twice over (a post
/// with no title, one in a community that does not exist), so the agent must ask again.
enum Kitchen {
    static let theme = "a cozy recipe-sharing community: home cooks posting weeknight dinners, bakes, ferments and their grandmothers' recipes"

    static let people: [(handle: String, name: String, bio: String?)] = [
        ("maya_bakes", "Maya Okafor", "Weekend baker, weekday soup person. Sourdough starter named Gerald."),
        ("theo.simmers", "Theo Lindqvist", "Line cook turned home cook. Will talk about stock for hours."),
        ("amara_k", "Amara Haddad", nil),
        ("jonas_ferments", "Jonas Moreau", "Three crocks of kraut on the go at all times."),
        ("priya.cooks", "Priya Iyer", "Dal, dosa and whatever the farmers market had on Saturday."),
        ("mateo_r", "Mateo Reyes", "Cast iron collector. Ask me about seasoning."),
        ("hana_s", "Hana Sato", "Tiny kitchen, big pots."),
        ("felixbakes", "Felix Novak", nil),
        ("noor_eats", "Noor Ibrahim", "Grandma's recipes, written down before they're lost."),
        ("elias.k", "Elias Kowalski", "Pierogi apologist."),
        ("sofia_v", "Sofia Varga", "Learning to cook one disaster at a time."),
        ("kenji_n", "Kenji Nakamura", "Weeknight ramen, weekend bread."),
        ("lena.h", "Lena Holm", "Cardamom in everything."),
        ("omar_cooks", "Omar Mensah", "Jollof diplomat. Pepper sauce optimist."),
        ("ines_f", "Inês Ferreira", "Custard tarts are a personality."),
        ("ravi.b", "Ravi Brennan", nil),
        ("clara_m", "Clara Marsh", "Pastry chef on my days off from nursing."),
        ("tomas_c", "Tomás Castillo", "Soup is a meal. I will not be taking questions."),
    ]

    static let communities: [(handle: String, title: String, about: String)] = [
        ("baking", "Baking", "Bread, cakes and pastry, and the occasional glorious failure. Crumb shots welcome."),
        ("weeknight", "Weeknight Dinners", "On the table in under forty minutes, with what's already in the cupboard."),
        ("ferments", "Ferments & Pickles", "Kimchi, kraut, kefir and anything else that bubbles on purpose."),
        ("soupseason", "Soup Season", "Pots of soup, stews and broths, and the bread you dunk in them."),
        ("plantkitchen", "Plant Kitchen", "Vegetables first: meatless cooking nobody misses the meat in."),
        ("castiron", "Cast Iron", "Seasoning, rescuing and cooking in pans that will outlive us all."),
        ("grandmasrecipes", "Grandma's Recipes", "Handwritten cards, stained notebooks and the dishes behind them."),
        ("sweettooth", "Sweet Tooth", "Cookies, tarts, puddings and other reasons to save room."),
    ]

    static let posts: [(community: String, title: String, body: String)] = [
        ("baking", "My sourdough finally has an open crumb!", "Six weeks of dense bricks and I think I've cracked it. Two things changed:\n\n- I let the bulk ferment go until the dough was **jiggly and domed**, not by the clock\n- Shaped tighter, then 14 hours in the fridge\n\nBaked in a dutch oven at 250°C, lid off after 20 minutes. Gerald the starter is very proud."),
        ("weeknight", "15-minute miso butter noodles", "When I can't face cooking: noodles, a spoon of white miso, butter, a splash of the pasta water and a fistful of spring onions. Chilli crisp if you have it. That's it, that's the post."),
        ("ferments", "Kimchi day three: is this much fizz normal?", "Opened the jar to burp it and it hissed like a soda. Smells sour and garlicky, no fuzz. My kitchen is about 24°C. Should I move it to the fridge now or let it keep going?"),
        ("soupseason", "Roasted tomato soup with a grilled cheese, obviously", "Roasted two trays of tomatoes with a whole head of garlic, blitzed with stock and a little cream. The grilled cheese is sourdough with sharp cheddar and a scrape of mustard. Rainy Sunday sorted."),
        ("plantkitchen", "Crispy chickpeas that actually stay crispy", "The trick for me was drying them **properly**: tea towel, then 10 minutes in a low oven before the oil goes on. Then 220°C for 25 minutes, shaking twice. Smoked paprika and lemon zest at the end."),
        ("castiron", "Rescued a rusty skillet from a yard sale for $4", "Vinegar soak, steel wool, then four thin coats of oil at 230°C. It's not perfect but eggs slide around already. Can't believe someone was going to throw this out."),
        ("grandmasrecipes", "Nana's apple cake, from the card in her handwriting", "She wrote \"a cup of apples, more if they're small\" and \"bake until it smells right\". After three tries I think I've decoded it: 180°C for about 50 minutes. Tastes exactly like her kitchen."),
        ("sweettooth", "Brown butter chocolate chip cookies", "Browned the butter, let it cool to soft, then rested the dough overnight. The difference is **ridiculous**: toffee-ish and chewy in the middle. Flaky salt on top is not optional."),
        ("weeknight", "What's your go-to dinner when you're too tired to think?", "Mine is eggs on rice with whatever greens are wilting in the fridge and a lot of soy sauce. Curious what everyone else falls back on."),
        ("baking", "Focaccia with whatever was left in the garden", "Cherry tomatoes, the last of the rosemary and some very sad-looking spring onions. Dimpled it with oily fingers and baked at 220°C. The edges are the best part."),
        ("ferments", "First batch of sauerkraut: 2% salt, four weeks", "Shredded one big cabbage, 2% salt by weight, massaged until it was swimming in brine. Kept it weighed down under a bag of water. Four weeks later it's tangy and still crunchy."),
        ("soupseason", "Leek and potato soup for under five dollars", "Three leeks, four potatoes, an onion, a stock cube and butter. Sweat the leeks low and slow for 15 minutes; that's where the flavour comes from. Makes six bowls."),
        ("plantkitchen", "Mushroom stroganoff that converted my meat-loving dad", "Two kinds of mushrooms, browned hard in batches so they don't steam. Paprika, a splash of soy, mustard and sour cream at the end. Over buttered egg noodles."),
        ("castiron", "Is it okay to cook tomato sauce in cast iron?", "Everyone online says no, my grandmother did it every Sunday for forty years. What's the actual answer?"),
        ("grandmasrecipes", "Dziadek's pierogi, finally written down", "Potato and farmer's cheese filling, a soft dough with sour cream in it. We made 120 of them on Saturday and froze most. The trick is pinching the edges **twice**."),
        ("sweettooth", "Lemon olive oil cake, no mixer needed", "One bowl, a whisk, and about ten minutes of work. The olive oil keeps it moist for days. Glazed with lemon juice and powdered sugar."),
        ("weeknight", "Sheet-pan gnocchi with peppers and sausage", "Shelf-stable gnocchi go straight onto the tray, no boiling. 25 minutes at 220°C and everything gets crispy. Handful of basil and parmesan at the end."),
        ("baking", "How do you get a crispy bottom on pizza at home?", "My crust is always pale and a bit soft underneath, and I don't have a stone. Would a cast iron pan or a steel make the biggest difference?"),
        ("ferments", "Hot honey that I accidentally fermented", "Left chillies in honey on the counter and it started bubbling. Two weeks later it's the best thing in the fridge: hot honey with a funky, almost fruity edge."),
        ("soupseason", "Chicken stock from a week of freezer scraps", "Onion ends, carrot peels, parsley stems and two chicken carcasses. Six hours at a bare simmer. Four litres of the good stuff, set like jelly in the fridge."),
        ("plantkitchen", "Coconut dal for a crowd", "Red lentils, coconut milk, and a tarka of mustard seeds, cumin and curry leaves poured over at the end. Fed twelve people for about the price of a pizza."),
        ("grandmasrecipes", "My grandmother's jollof, measured for the first time", "She never measured anything, so I watched and weighed everything as she went. The base is a lot of blended peppers cooked down until the oil splits. Writing it all up below."),
        ("sweettooth", "Pastéis de nata at home: worth the effort?", "Laminating the dough took all afternoon, but the custard is easy. They came out blistered and wobbly in the middle. Next time I'm buying puff pastry and keeping my weekend."),
        ("castiron", "Smash burgers on a cast iron griddle", "Ball of beef, very hot pan, smash it flat with a spatula and parchment, salt, don't touch it for 90 seconds. American cheese, pickles, toasted bun. Too good."),
        ("weeknight", "Fridge-cleanout fried rice, no recipe", "Day-old rice, the last two eggs, half an onion, frozen peas and a lone sausage. Hot wok, rice in first to toast. Soy, sesame oil, white pepper. Done in ten."),
        ("baking", "Cinnamon cardamom buns for a slow Saturday", "Swedish-style knots with lots of cardamom in the dough and the filling. Brushed with sugar syrup as soon as they came out. The whole flat smells incredible."),
        ("soupseason", "Ribollita: the soup that's better on day two", "Cannellini beans, cavolo nero, carrot, celery and stale bread to thicken it. Reheated the next day with a glug of good olive oil on top."),
        ("plantkitchen", "Charred broccoli with chilli crisp and lemon", "Cut it into big flat pieces so there's more surface to char. Hot oven, 20 minutes. Chilli crisp, lemon juice and a pinch of flaky salt. I could eat the whole tray."),
        ("ferments", "Water kefir grains looking for a new home", "My grains have tripled and I'm running out of jars. Happy to post some to anyone here who wants to start. Just ask below!"),
        ("sweettooth", "Burnt Basque cheesecake, cracked and proud", "Very hot oven, scorched top, creamy almost-runny middle. Lined the tin with two sheets of crumpled parchment. The crack is part of the charm."),
    ]

    static let openers = [
        "This looks incredible. Saving it for the weekend.", "What temperature did you use?", "How long did the whole thing take, start to finish?",
        "Made this last night and my partner asked for it again tonight.", "That colour! What did you do differently this time?",
        "Bookmarked. My grandmother made something very similar.", "Did you use fresh or dried herbs?", "Trying this tonight, will report back.",
        "Is there a way to make this ahead and reheat it?", "Okay, now I'm hungry at 11pm. Thanks.",
        "I'd add a squeeze of lemon right at the end, but that's just me.", "Any tips for doing this without a stand mixer?",
        "Can you share the measurements? I'm terrible at eyeballing.", "Mine never comes out looking this good.",
        "What flour do you use?", "Love that you wrote it all down. Recipes like this disappear otherwise.",
        "Would this work with gluten-free flour?", "How did you store the leftovers?", "The patience this takes. Respect.",
        "Saving this for the next rainy day.",
    ]
    static let answers = [
        "250°C for the first 20 minutes, then 230°C with the lid off.", "About two hours, but most of it is waiting.",
        "Thank you! The trick was letting it rest longer than I thought.", "Same here, she never measured anything either.",
        "It freezes really well, just reheat it gently.", "I used dried, about a third of the amount.",
        "Yes! I've done it with a wooden spoon and a lot of patience.", "Added the measurements to the post.",
        "Just a regular supermarket bread flour, nothing fancy.", "I tried it with a gluten-free blend: a bit crumbly but still good.",
        "Airtight tin, and it was gone in two days anyway.", "Lemon is a great call, adding that next time.",
        "Honestly, mine didn't either the first four tries.", "Seconding this, it really does make a difference.",
    ]
    static let followUps = [
        "Good to know, thanks!", "Ha, same. Mine are usually 'rustic'.", "That makes sense, I always rush that part.",
        "Doing this on Saturday then.", "Will try that, thank you.", "This thread is why I love this place.", "Agreed, the rest is the secret.",
        "Oh nice, I didn't know it froze well.",
    ]

    /// Who answers whom in a thread of `count`: an index of an earlier reply, or nil for the post.
    static func shape(_ count: Int) -> [Int?] {
        let pattern: [Int?] = [nil, 0, 1, nil, 3, nil, 5, 6, nil, nil, 9, nil]
        return (0..<count).map { $0 < pattern.count ? pattern[$0] : nil }
    }

    private final class Cursor: @unchecked Sendable {
        let lock = NSLock()
        var people = 0, communities = 0, posts = 0, replies = 0, badPostsSent = false
    }

    /// The scripted model of the community.
    static func model() -> FakeHostModel {
        let cursor = Cursor()
        return FakeHostModel { ask, _ in
            guard let schema = JSONValue.parse(ask.schema), case .array(let required)? = schema["required"],
                  case .string(let key)? = required.first else { return Data("{}".utf8) }
            if key == "threads" { return threads(ask.user, cursor) }
            let list = schema["properties"]?[key]
            guard case .int(let count)? = list?["minItems"], case .object(let fields)? = list?["items"]?["properties"] else { return Data("{}".utf8) }
            let names = fields.map(\.key)
            var groups: [String] = []
            for (_, value) in fields { if case .array(let values)? = value["enum"], value["description"] == nil { groups = values.compactMap(\.text) } }
            return cursor.lock.withLock {
                var items: [JSONValue] = []
                for number in 0..<count {
                    var item: [(key: String, value: JSONValue)] = []
                    switch key {
                    case "people", "persons":
                        let person = people[cursor.people % people.count]; cursor.people += 1
                        for name in names {
                            switch name {
                            case "name": item.append((name, .string(person.handle)))
                            case "displayName": item.append((name, .string(person.name)))
                            case "bio": item.append((name, person.bio.map(JSONValue.string) ?? .null))
                            default: break
                            }
                        }
                    case "communities":
                        let community = communities[cursor.communities % communities.count]; cursor.communities += 1
                        for name in names {
                            switch name {
                            case "name": item.append((name, .string(community.handle)))
                            case "title": item.append((name, .string(community.title)))
                            case "description": item.append((name, .string(community.about)))
                            default: break
                            }
                        }
                    default:
                        let post = posts[cursor.posts % posts.count]; cursor.posts += 1
                        let bad = !cursor.badPostsSent && (number == 1 || number == 3)
                        for name in names {
                            switch name {
                            case "name" where bad && number == 1: break
                            case "name": item.append((name, .string(post.title)))
                            case "body": item.append((name, .string(post.body)))
                            case _ where !groups.isEmpty && fields.first(where: { $0.key == name })?.value["enum"] != nil:
                                let community = bad && number == 3 ? "bread" : (groups.contains(post.community) ? post.community : groups[0])
                                item.append((name, .string(community)))
                            default: break
                            }
                        }
                    }
                    items.append(.object(item))
                }
                if key == "posts" { cursor.badPostsSent = true }
                return Data(JSONValue.object([(key, .array(items))]).compact.utf8)
            }
        }
    }

    /// Threads for the posts a prompt lists (`1. "Title" by maya_bakes: …` then `5 comments`).
    private static func threads(_ user: String, _ cursor: Cursor) -> Data {
        var asked: [(number: Int, count: Int)] = []
        var number: Int?
        for line in user.split(separator: "\n") {
            let text = line.trimmingCharacters(in: .whitespaces)
            if let dot = text.firstIndex(of: "."), let value = Int(text[..<dot]), text.dropFirst(text.distance(from: text.startIndex, to: dot) + 1).hasPrefix(" \"") {
                number = value
            } else if let current = number, let count = Int(text.split(separator: " ").first ?? ""), text.split(separator: " ").count == 2 {
                asked.append((current, count))
                number = nil
            }
        }
        return cursor.lock.withLock {
            let threads: [JSONValue] = asked.map { parent in
                var replies: [JSONValue] = [], picked = [0, 0, 0]
                let targets = shape(parent.count)
                for (index, target) in targets.enumerated() {
                    let depth = target.map { targets[$0] == nil ? 1 : 2 } ?? 0
                    let pool = depth == 0 ? openers : depth == 1 ? answers : followUps
                    let text = pool[(cursor.replies + picked[depth]) % pool.count]
                    picked[depth] += 1
                    replies.append(.object([("id", .int(index + 1)), ("replyTo", target.map { .int($0 + 1) } ?? .null), ("text", .string(text))]))
                }
                cursor.replies += 5
                return .object([("post", .int(parent.number)), ("comments", .array(replies))])
            }
            return Data(JSONValue.object([("threads", .array(threads))]).compact.utf8)
        }
    }
}
