# Testing MocksAgent

How `mocks` is tested: its own suite, and its gated build of real output, run on a Mac against an app made by the
installed `granite` and `network` runners, exactly as Craft calls them. Everything runs on mock backend responses;
nothing reaches a live server.

## The suite

```
swift test                                            # the record, the schema, the shapes, the world, the answers,
                                                      # the checks of a model's answers, the files, the pictures
MOCKS_BUILD=1 swift test --filter MocksBuildTests     # the output built and run for real (gated, a few minutes)
MOCKS_BUILD=1 MOCKS_ARTIFACTS=<folder> swift test --filter MocksBuildTests   # and keep the feed's PNG there
```

## The gated build

*2026-11-01 · MacBook Pro M4 Max, macOS 27, Xcode 27.1, Swift 6.4 · both gated tests 72 s with warm caches, about 3 minutes cold*

1. **The app**: `granite` makes the project `Hearth` (`make: project`), then `network` writes `Packages/LemmyKit`, a
   Lemmy-like API (a login that keeps a JWT, posts paged and narrowed by community, a post by id, comments paged and
   narrowed by post, a person by name, communities, a community by name, a vote, a delete), linked into the project.
   Both through the installed runners, one JSON line in from inside the app's folder.
2. **The mock**: `mocks` with the theme "a cozy recipe-sharing community" and `posts: 30`, `comments: 90`,
   `people: 18`, on a scripted host model (`Tests/MocksAgentTests/Support/Kitchen.swift`) whose first batch of posts
   is wrong twice over (a post with no title, one in a community that does not exist). The agent asked 23 times;
   3 asks were asked again with the reasons (the bad batch, then two titles already taken), and nothing fell back to
   word lists. 21 files written.
3. **macOS**: `swift test` of `LemmyKit`: 30 tests, 0 failures (network's own and the 7 `MockFixtureTests`).
4. **iOS**: `xcodebuild -scheme LemmyKit -destination 'generic/platform=iOS Simulator' build` succeeded; then
   `xcodebuild test … -only-testing:LemmyKitTests/MockFixtureTests` on a simulator that was shut down (shut down
   again after): 7 tests, 0 failures, `** TEST SUCCEEDED **`. Among them every picture loads through `URLSession` from
   its `data:` URL and reads as a `UIImage`: `AsyncImage` loads through the shared `URLSession`.
5. **The feed**: a small package beside the app loads page 1 and page 2 through `LemmyClient.mock()`
   (`posts(page:limit: 3)`: ids `[74088, 74082, 74079]`, then `[74073, 74077, 74084]`), loads their 9 pictures through
   `URLSession`, and draws a feed with `ImageRenderer` (860×2954). Then an `AsyncImage` in an offscreen window is given
   the first picture's `data:` URL and reaches `.success`: `asyncimage: loaded data:image/png;base64,iVBORw0K…`.

6. **Two other shapes of API**: `network` writes a Mastodon-like client (string ids, an account in each status,
   attachments a status owns, a home timeline paged by `max_id` and the `Link` header, an account's statuses narrowed
   by the path's `{id}`) and a recipe one (exact keys, a page envelope with a total, no people); `mocks` runs with no
   model (word lists); `swift test` of each: MastodonKit 23 tests and RecipeKit 21, 0 failures, their mock tests among
   them.

## Prompts run on this Mac

Setup: MacBook Pro M4 Max (128 GB), macOS 27, Xcode 27.1, Craft built from `main`, the model Craft loads
(`rao-studios/Qwen3-Coder-Next-REAP-48B-A3B-mlx-4bit`), permission mode bypass, the agent installed from this repository
with `craft agents add`. The app is Hearth, made over earlier prompts by `$granite`, `$design`, `$assets` and
`$network` (its client package `Packages/HearthKit`); each prompt below runs on the app as those left it.

## Regime runs on Margin

What this agent made in the regime's runs on Margin (`TESTING-REGIME.md`), written by `regime.sh publish` from each run's records: the call, what it made of what it expected, and what the run measured.

### replay-2026-11-03-2-t1-2

*2026-11-04 · Qwen3-Coder-Next-REAP-48B-A3B-mlx-4bit · baseline · expand on · 64k window · stage P0 · max_rows 4 · Craft 6e950df3619c+dirty (committed as a7bbf02) · Frigate c5b68d76f0b7 · granite 4210ca9 · loom bcf0c85 · mocks 3bea47d · network dbac458 · screenshots 22186ba · replay of turn 1 of 2026-11-03-2*

**Calls** (made / refused / corrected): 1 / 0 / 0 · **made of expected**: 5 of 5 (100%) · **asks of the model**: 30 (15,864 tokens)

**The call** (t1):

```json
{
  "counts": [
    "posts: 40",
    "comments: 120",
    "people: 20",
    "communities: 6"
  ],
  "package": "Packages/MarginKit",
  "scenarios": [
    "normal",
    "empty",
    "failing",
    "unauthorized",
    "slow"
  ],
  "theme": "a book-reading community: readers sharing thoughts on books they are reading, with posts about chapters and comments that thread through discussions"
}
```

**Its bars**: mocks_decodes pass (43/43) · mocks_counts pass ({'comments': 120, 'communities': 6, 'people': 20, 'posts': 40}) · mocks_stems pass (40) · mocks_threads pass (31) · feed_draws_light **fail** (0) · feed_draws_dark **fail** (0)

![Outcome card for replay-2026-11-03-2-t1-2](Docs/Testing/l3-replay-2026-11-03-2-t1-2-card.png)
*Outcome card for replay-2026-11-03-2-t1-2*
