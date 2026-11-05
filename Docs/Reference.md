# MocksAgent reference

How the `mocks` agent is found, what a call takes and answers, what it writes into the client package, how the
mock is made, and how to test it. What it is for is in the [README](../README.md); the agent standard it follows is
in [Schema/Mocks.md](../Schema/Mocks.md).

## How an app finds it

MocksAgent is a `GraniteAgentPackage`, and it carries a record in its binary:

```swift
@used @section("__DATA_CONST,__granite")
let mocksRecord: GraniteRoster.Record = { GraniteRoster.record(MocksAgent.self) }
```

In [Craft](https://github.com/riteshpakala/Craft), install it from the Agent Store or with
`craft agents add https://github.com/Rao-Craft-Agents/MocksAgent.git`, then say `$mocks` in a request:

```
$mocks give the app a cozy recipe-sharing community to show: home cooks posting weeknight dinners, bakes and
ferments, about forty posts with their comment threads
```

The model writes the call; it shows on Craft's agent map as `mocks-1`, and the files it names are built and tested
with the turn.

## What a call takes and answers

| Field | | |
|---|---|---|
| `package` | optional | the client package's folder, `Packages/RecipeKit`; the one under `Packages/` with an `api.json` when left out |
| `theme` | optional | what the app is and how it sounds: the voice the records are written in |
| `counts` | optional | how many records of a type, one line each: `posts: 40`, `comments: 120`, `people: 20` |
| `scenarios` | optional | the scenarios the package's tests prove: `normal`, `empty`, `failing`, `unauthorized`, `slow`; all when left out |
| `endpoints`, `entities` | optional | lines over the package's own `api.json` lines, in network's and the models line |
| `seed` | optional | what the picks are made from: the same seed and words make the same fixtures |
| `rounds` | optional | how many answers the model may give a batch; 3 when left out |
| `directory` | the host's | the folder the host works in; a host fills it and does not show it to a model, and a call whose JSON leaves it out works in the folder the host offers (`AgentHost.directory`) |

The answer is a `MocksResult`: every file written (`path`, `paths`, absolute), the package, the client, the endpoints
answered, how many records of each type, the pictures, whether the host's model wrote the words, and a sentence for
anything else.

## What it writes into the client package

| File | What |
|---|---|
| `Sources/<Kit>/Mocks/<Client>+Mock.swift` | `<Client>.mock(_ scenario: MockScenario = .normal, latency: Duration = .milliseconds(250))`: the client, signed in with a token kept in memory, on the mock backend; and the routes, one a line of the API |
| `Sources/<Kit>/Mocks/Fixtures/<Endpoint>Fixture.swift` | each endpoint's JSON as raw string literals: a list's pages, a lookup's answer and items, what a body makes |
| `Sources/<Kit>/Mocks/MockMode.swift` | `MockMode.isOn` (`-mock YES`, `MOCK=1`, Xcode's previews, a test run; `-mock NO` turns it off; `-mockScenario empty` picks a scenario) and `<Client>.current`, the mock when on and the live client otherwise, settable so a test can put a failing mock in its place |
| `Sources/<Kit>/Mocks/MockServer.swift` and the rest | the transport that answers in the process, `MockScenario`, the routes and their answers, the JSON it cuts, the pictures (`MockImages`), the shared fixtures (`MockFixtures`) |
| `Tests/<Kit>Tests/MockFixtureTests.swift` | every fixture decodes as its type, every endpoint answers through `.mock()`, the item asked for is the one found, pages end, a query narrows its list, every scenario fails as it should, `current` is the mock in a test and can be replaced, every picture loads |
| `mocks.json` | the theme, the seed, the counts and the files, so a later call keeps them and takes away what is gone |

In the app: `RecipeClient.mock()` in a preview, `.mock(.failing)`, `.empty`, `.unauthorized` and `.slow` for the
other states, `(client.transport as? MockServer)?.scenario = .normal` to change one between two calls, and
`RecipeClient.current` in the services, so a launch with `-mock YES` (UI tests, screenshots) runs on the mock.

## How the mock is made

| Step | What |
|---|---|
| Read | the package's `api.json` lines resolved as network resolves them (the client's names, keys, dates, paging, tokens); a call it cannot honour is refused with every reason |
| Shape | each type read as a record (it has an `id`), a view put together from records, a value counted from the record it sits in, or a choice; the people, the groups, the content and its replies found from the API's own names (`creatorID` names the person, `postID` the `Post`) |
| Words | what the records say, written by the host's model from the theme in small batches (ten people, six posts, a dozen replies an ask), each answer checked against the entity lines (every field, its type, a choice in its cases, handles and titles unique, a post's community one that exists, a thread's replies answering earlier ones with depth) and asked again with the reasons; word lists when no model is offered |
| World | ids that grow with time, dates over the last three weeks, authors with a few busy ones, threads whose paths and parent ids agree, votes, a pinned post; every count counted from the world |
| Answers | a paged list cut from every record of its kind (narrowed by the ids a query names, searched, sorted, its envelope's total counted, the next cursor in its field or `Link` header), an item found by the id or name the request names with its lists, a body echoed into what it makes, a sign-in's token |
| Pictures | eighteen drawn with CoreGraphics (faces, dishes, places: soft gradients with a mark, no symbols or text) as base64 PNG, named `mock-image://<name>` in the fixtures and served as `data:` URLs, which `AsyncImage` and `URLSession` load on iOS and macOS |
| Time | every date moved by the time since the fixtures were written, so the newest post is always as fresh as it was then |
| Check | every file staged, parsed with `swiftc -parse`, then moved into the package together |

## Testing

```
swift test                     # the record, the schema, the shapes, the world, the answers, the checks, the files
MOCKS_BUILD=1 swift test       # an app made by the granite and network runners, mocked on a scripted model, the
                               # package's tests run on macOS and an iOS simulator, a SwiftUI feed drawn to a PNG;
                               # a Mastodon-like and a recipe API mocked on word lists, their tests run
```
