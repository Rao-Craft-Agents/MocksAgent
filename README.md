# MocksAgent

See an app full of life before its server exists. Say what the app is and how it sounds, and `mocks` gives its
screens, previews, tests and screenshots a community to show: people with handles and faces, the groups they post in,
posts in the app's own voice, and comment threads with depth. A mock backend answers every endpoint of the app's API
in the process, and the same client turns to the live API when the mock is off.

## What you can ask

```
$mocks give the app a cozy recipe-sharing community: home cooks posting weeknight dinners, bakes and ferments
$mocks believable data for Margin until the server exists: readers, their book clubs, 40 posts and 120 comments
$mocks a pantry tracker shared by housemates for PantryKit, its tests proving the normal, empty and failing states
```

Craft writes the call from your request, shows it on its agent map as `mocks-1`, and builds and tests what it writes
with the turn.

## What you get

- **A community to look at.** People, groups, posts and threads whose counts agree, a few busy authors, votes and a
  pinned post, dated over the last three weeks and moved forward with time, so the newest post always looks fresh.
- **Every endpoint answered.** Lists that page and end, queries that narrow and search, an item found by the id asked
  for, a body echoed back into what it makes, and a sign-in's token.
- **Pictures that load.** Eighteen drawn pictures of faces, dishes and places, served as `data:` URLs that
  `AsyncImage` and `URLSession` load on iOS and macOS.
- **The states to prove.** `RecipeClient.mock()` for previews, and `.failing`, `.empty`, `.unauthorized` and `.slow`
  for the rest, with tests that every fixture decodes, every endpoint answers, pages end and each scenario fails as it
  should.
- **One switch for the app.** `RecipeClient.current` is the mock in previews, in tests and in a launch with
  `-mock YES`, and the live API otherwise, so UI tests and screenshots run on the same data.

## How it works

- It reads the API from the client package `network` wrote (its names, keys, dates, paging and tokens), and refuses a
  call it cannot honour with every reason, writing nothing.
- Craft's model writes the words from your theme in small batches. Each answer is checked against the API's types
  (every field and its type, handles and titles unique, a post in a community that exists, replies that answer
  earlier ones) and asked again with what was wrong; with no model offered, it uses word lists.
- Every count is counted from the records it made, and the same seed and words make the same fixtures; a later call
  keeps the theme and the seed.
- Every file is parsed with `swiftc -parse` before any lands, and what it makes is built and tested with the turn.

## Works well with

`mocks` follows `network`: it writes into the client package `network` made, and is called again when `network`
changes the API. Where `network`'s `.preview` client answers every endpoint with one sample, `mocks` gives the pages
`granite` makes and the screens `loom` writes a community to show. The app's own types come from `models`.

## Get it

In Craft, install Mocks from the Agent Store, or run
`craft agents add https://github.com/Rao-Craft-Agents/MocksAgent.git`, then say `$mocks` in a request.

## Requirements

- A Mac on macOS 14 or later, with Xcode.
- An API client package in the project written by `network`, under `Packages/` and found by its `api.json`.
- The mock answers in the app's own process on iOS and macOS; nothing reaches a server.
- MIT licensed.

## For developers

What a call takes and answers, what it writes into the client package and how the mock is made are in the
[reference](Docs/Reference.md). The agent standard it follows is [Schema/Mocks.md](Schema/Mocks.md), and how it is
measured is [TESTING.md](TESTING.md).
