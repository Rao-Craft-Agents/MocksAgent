//  WHAT: What one field of an API's type holds, as the mock backend fills it: an id, a reference to another record,
//        a handle, a title, a body, a picture, a page's address, a date, a count, a flag. Read off the field's name,
//        its type, its doc and the fields beside it.

import Foundation

enum FieldRole: Equatable, Sendable {
    /// The record's own id.
    case id
    /// The id of a record of the type: `creatorID` names a Person, `postID` a Post.
    case reference(String)
    /// The ids of several records of the type: `mediaIDs`.
    case references(String)
    /// The id of the record of its own type it answers: a reply's `parentID`, a status's `inReplyToID`.
    case parent
    /// A record of the type, in place: a status's `account`.
    case record(String)
    /// Records of the type, in place: a status's `mediaAttachments`.
    case records(String)
    /// A struct without an id, made from what it sits in: a post's `counts`.
    case composite(String)
    /// Several of them: a recipe's `steps`.
    case composites(String)
    /// One case of a plain enum.
    case choice(String)
    /// An enum whose cases carry values.
    case carrier(String)
    /// A unique name a URL or a mention uses: a person's `name` beside a `displayName`, a `username`, a slug.
    case handle
    /// The name a person goes by.
    case displayName
    /// What a record is called: a title, a headline, a thing's name.
    case title
    /// Long text: a post's body, a comment's content.
    case body(TextFormat)
    /// A line or two about the record: a bio, a description, an about.
    case summary(TextFormat)
    /// A content warning: empty for most records.
    case warning
    case email
    /// A password, a secret, a token: something a mock never shows for real.
    case secret
    /// A picture's address.
    case image(ImageSubject)
    /// An address to read elsewhere: a link post's link, a website.
    case link
    /// The record's own page: `actorID`, an account's `url`, a `uri`.
    case page
    /// When it was made, when it changed, or another moment.
    case created
    case updated
    case moment
    /// How many of something there are: `comments`, `followersCount`, `childCount`.
    case count(String)
    case score
    case upvotes
    case downvotes
    /// The vote the signed-in person gave: mostly none.
    case vote
    /// A thread's path (`0.12.40`) and depth.
    case path
    case depth
    /// A yes or no, and what it usually is.
    case flag(Bool)
    /// A number the record's own content decides: minutes, servings, a price, a rating.
    case number
    case language
    case color
    case uuid
    case data
    /// Short text of no kind this reads: a label, a code.
    case text
    /// Anything else of the type: a list of strings, a dictionary.
    case other
}
