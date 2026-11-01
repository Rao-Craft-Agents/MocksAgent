//  WHAT: What the records say when no model is offered: names, bios, groups, titles, bodies and replies for a few
//        kinds of place, varied and deterministic. Never "Sample title": a screen on these still reads like people.
//  PIN:  A MODEL WRITES BETTER. These are the floor, not the goal; a call without a model says so in its notes.

import Foundation

enum WordLists {
    static let firstNames = ["Maya", "Theo", "Amara", "Jonas", "Priya", "Mateo", "Hana", "Felix", "Noor", "Elias", "Sofia", "Kenji",
                             "Lena", "Omar", "Ines", "Ravi", "Clara", "Tomas", "Aiko", "Luca", "Zara", "Owen", "Mira", "Diego",
                             "Freya", "Sami", "Nadia", "Oskar", "Leila", "Arjun", "Greta", "Kwame", "Elif", "Hugo", "Yara", "Milo",
                             "Rosa", "Idris", "Vera", "Caleb", "Anya", "Ezra", "Lucia", "Emeka", "Ruth", "Kai", "Selin", "Malik"]
    static let lastNames = ["Okafor", "Lindqvist", "Haddad", "Moreau", "Tanaka", "Reyes", "Novak", "Achterberg", "Mensah", "Kowalski",
                            "Ferreira", "Iyer", "Brennan", "Castillo", "Nakamura", "Osei", "Varga", "Delacroix", "Sato", "Fontaine",
                            "Ibrahim", "Petrov", "Laurent", "Quinn", "Abiodun", "Marsh", "Rinaldi", "Holm", "Kaur", "Ortega"]
    static let handleSuffixes = ["", "_", "cooks", "writes", "outside", "makes", "reads", "codes", "travels", "draws"]

    struct Place: Sendable {
        var groups: [(handle: String, title: String, about: String)]
        var bios: [String]
        var titles: [String]
        var sentences: [String]
        var replies: [String]
    }

    static func place(_ domain: Theme.Domain) -> Place {
        switch domain {
        case .food: return food
        case .outdoors: return outdoors
        case .tech: return tech
        case .books: return books
        case .general: return general
        }
    }

    static let food = Place(
        groups: [("baking", "Baking", "Breads, cakes, pastry and the occasional disaster. Crumb shots welcome."),
                 ("weeknight", "Weeknight Dinners", "Dinner on the table in under forty minutes, no special trips to the shop."),
                 ("ferments", "Ferments & Pickles", "Kimchi, kraut, kefir, kombucha: anything that bubbles on purpose."),
                 ("soups", "Soup Season", "Pots of soup, stews and broths, and what you serve with them."),
                 ("vegetarian", "Vegetarian Kitchen", "Meatless cooking that nobody misses the meat in."),
                 ("streetfood", "Street Food at Home", "Recreating the stalls and food trucks you miss."),
                 ("castiron", "Cast Iron", "Seasoning, rescuing and cooking in the pans that outlive us."),
                 ("sundaybaking", "Sunday Baking Club", "One recipe a week, baked together, compared on Monday.")],
        bios: ["Weeknight cook, weekend baker. Mostly soups.", "Learning to bake bread one dense loaf at a time.",
               "Home cook in a tiny kitchen. Big opinions about garlic.", "Pickling everything that holds still.",
               "Ex-line cook, now cooking for two small, picky critics.", "I measure with my heart and occasionally a scale.",
               "Vegetarian for ten years, still finding new things to do with beans.", "Cast iron collector, butter enthusiast.",
               "Grandma's recipes, written down before they're lost.", "Dumplings are a love language."],
        titles: ["My first loaf that actually rose", "Weeknight lentil soup that fills you up", "How long do you rest your dough?",
                 "Brown butter changed my cookies", "Fridge-cleanout fried rice, no recipe", "Kimchi day three: is this fizz normal?",
                 "Cast iron rescue: before and after", "The tomato sauce I make every Sunday", "Crispy chickpeas, finally crispy",
                 "What's your go-to dinner when you're tired?", "Focaccia with whatever was in the garden", "Miso butter noodles in 15 minutes",
                 "A slow-roasted pork shoulder for a crowd", "Is a stand mixer worth it for bread?", "Lemon olive oil cake, no mixer needed",
                 "Dumpling folding practice night", "Overnight oats that don't taste like paste", "Charred broccoli with chilli crisp",
                 "The best cheap knife you've owned", "Pickled red onions on everything this week", "Mushroom stroganoff for a rainy day",
                 "Banana bread with too many bananas", "Homemade stock from a week of scraps", "Shakshuka for a lazy brunch",
                 "Proofing in a cold kitchen: any tricks?", "Sheet-pan gnocchi with peppers", "My grandmother's apple cake",
                 "Sourdough discard crackers", "Smash burgers on the griddle", "Coconut dal for a crowd"],
        sentences: ["I followed the recipe almost exactly, except I used half whole wheat flour.",
                    "The trick was letting it rest overnight in the fridge.", "It took three tries, but this one finally worked.",
                    "Next time I'd add more garlic, and I already used a lot.", "My kitchen runs cold, so everything took longer than the recipe said.",
                    "I doubled the batch and froze half for next week.", "Served it with crusty bread and a squeeze of lemon.",
                    "The kids asked for seconds, which never happens.", "I swapped the cream for coconut milk and nobody noticed.",
                    "Toasting the spices first made a huge difference.", "If you try it, don't skip the salt at the end.",
                    "It's not pretty, but it's the best thing I've made this month.", "Recipe below, measurements are approximate.",
                    "Happy to answer questions if anyone wants to try it."],
        replies: ["This looks amazing. Saving it for the weekend.", "What flour did you use?", "I make something similar but with smoked paprika.",
                  "That crumb is beautiful.", "How long did it take start to finish?", "Trying this tonight, will report back.",
                  "Did you cover it while it baked?", "My grandmother made this exactly the same way.", "Same here, the overnight rest is everything.",
                  "Oh, good idea with the lemon.", "Made it, loved it, adding chilli next time.", "Can this be made a day ahead?",
                  "Mine came out flat, any idea why?", "Probably the starter, give it another feed first.", "Thanks, that worked!",
                  "Seconding this.", "Bookmarked.", "Ha, mine never looks this tidy."]
    )

    static let outdoors = Place(
        groups: [("trails", "Trail Reports", "Conditions, closures and the best views, as recent as you can make them."),
                 ("camping", "Camping", "Tents, stoves, sites and the stars you saw."),
                 ("birding", "Birding", "What you saw, where, and the ones that got away."),
                 ("gardening", "Gardening", "Beds, balconies and allotments."),
                 ("cycling", "Cycling", "Commutes, gravel loops and long Sunday rides."),
                 ("photography", "Outdoor Photography", "Light, weather and the patience to wait for both.")],
        bios: ["Weekend hiker, weekday map reader.", "Chasing waterfalls within two hours of home.", "Birds, mostly. Sometimes ferns.",
               "Balcony gardener with ambitions.", "Commuting by bike since 2014.", "Always one more ridge."],
        titles: ["Trail report: the ridge loop after the rain", "First overnight trip with the kids", "Spotted a heron at the reservoir",
                 "What's in your day pack?", "Tomatoes finally ripening in October", "Gravel loop with almost no traffic",
                 "Best lightweight stove for two?", "Fog over the valley this morning", "Is the north trail still closed?",
                 "Wildflowers are out early this year", "My first century ride", "Tips for camping in the shoulder season"],
        sentences: ["We started at dawn and had the trail to ourselves until noon.", "The last mile is steep but the view is worth it.",
                    "Parking filled up by nine, so go early.", "Bring more water than you think.", "The creek crossing was knee deep after the rain.",
                    "I packed too much food, as usual.", "Light was perfect for about twenty minutes."],
        replies: ["Thanks for the report!", "How muddy was it?", "Great shot.", "Adding this to my list.", "Was it busy?",
                  "We did it last month, loved it.", "Good to know about the parking.", "Which map did you use?"]
    )

    static let tech = Place(
        groups: [("swift", "Swift", "The language, its tools and the code people write with it."),
                 ("homelab", "Homelab", "Servers in closets and the people who love them."),
                 ("opensource", "Open Source", "Projects, maintainers and the work of keeping them going."),
                 ("design", "Interface Design", "Screens, type and the details that make software feel right."),
                 ("career", "Developer Careers", "Interviews, teams, and work that lasts."),
                 ("showcase", "Show and Tell", "Things you built, finished or not.")],
        bios: ["iOS developer, tea drinker.", "Building small tools for small teams.", "Maintainer of a few things you may have used.",
               "Designer who learned to code.", "Writing about software and the people who make it.", "Retired sysadmin, unretired homelabber."],
        titles: ["Finally moved my side project to Swift 6", "What's in your homelab right now?", "A small library for parsing dates",
                 "How do you review a huge pull request?", "Show and tell: a menu bar app for timers", "Accessibility checks we run on every screen",
                 "Lessons from maintaining a library for five years", "Async sequences finally clicked for me", "Favourite debugging trick?",
                 "Moving from a monolith one module at a time", "My dotfiles, cleaned up", "Design review checklist that actually works"],
        sentences: ["It took a weekend, mostly fixing warnings I had ignored for years.", "The tests caught two real bugs along the way.",
                    "Happy to share the code if anyone is curious.", "I wrote up what worked and what didn't.",
                    "Performance is better than I expected.", "Feedback welcome, it's still rough around the edges."],
        replies: ["Nice write-up.", "Did you hit any problems with the migration?", "Starred.", "We do something similar at work.",
                  "How are you handling errors?", "This is really clean.", "Thanks, bookmarking this.", "Which version are you on?"]
    )

    static let books = Place(
        groups: [("bookclub", "Book Club", "One book a month, read together."), ("poetry", "Poetry", "Poems you love and poems you wrote."),
                 ("scifi", "Science Fiction", "Ships, futures and the people in them."), ("classics", "Classics", "Old books, read again."),
                 ("nonfiction", "Nonfiction", "History, science, memoir."), ("writing", "Writing Desk", "Drafts, routines and finishing things.")],
        bios: ["Always reading three books at once.", "Librarian by day.", "Poetry, mostly.", "Slowly reading every Booker winner.",
               "Writing my first novel, very slowly.", "Secondhand bookshop regular."],
        titles: ["Finished it at 2am and regret nothing", "What are you reading this week?", "A poem I keep coming back to",
                 "Books that changed how you think", "Our next book club pick", "Audiobooks count, change my mind",
                 "The best opening line you've read", "Reading slump, send help", "A short story collection worth your time"],
        sentences: ["I didn't expect the ending at all.", "The middle drags a little, but stay with it.", "It reads beautifully aloud.",
                    "I've been recommending it to everyone.", "I underlined half of chapter three."],
        replies: ["Adding it to my list.", "Loved this one too.", "No spoilers please, I'm halfway!", "The ending got me.",
                  "Have you read their earlier book?", "Great pick."]
    )

    static let general = Place(
        groups: [("neighborhood", "Neighborhood", "News, questions and lost cats from around here."),
                 ("photography", "Photography", "Pictures you took and how you took them."),
                 ("boardgames", "Board Games", "What's on the table this week."),
                 ("music", "Music", "What you're listening to, playing or recording."),
                 ("diy", "DIY", "Fixing, building and making do."),
                 ("pets", "Pets", "The animals who run our lives."),
                 ("askanything", "Ask Anything", "No question too small."),
                 ("goodnews", "Good News", "Small wins worth sharing.")],
        bios: ["Here for the good threads.", "Amateur photographer, professional procrastinator.", "Board game collector.",
               "Fixing things around the house, slowly.", "Two cats, one very opinionated.", "New to the neighborhood!",
               "Mostly lurking, sometimes helpful.", "Music teacher and record collector."],
        titles: ["Found a great little bookshop on the corner", "What game got you into board games?", "Morning light from the bridge",
                 "Fixed the wobbly table, finally", "Our cat learned to open doors", "Album recommendations for a long drive?",
                 "Small win: ran my first 5k", "Is the farmers market still on Saturdays?", "First attempt at film photography",
                 "What's a skill you learned this year?", "The street fair was lovely this year", "Restored an old radio"],
        sentences: ["It took longer than I'd like to admit.", "Honestly better than I expected.", "Sharing in case it helps someone.",
                    "Would love to hear what you think.", "A neighbour pointed me to it last week.", "Pictures don't do it justice."],
        replies: ["Love this!", "Where is this?", "Great news.", "Congrats!", "Thanks for sharing.", "We should do a meetup.",
                  "Same thing happened to me.", "This made my day."]
    )
}
