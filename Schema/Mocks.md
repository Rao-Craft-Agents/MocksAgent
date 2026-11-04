# craft-agent/1 · mocks

Writes realistic mock backend responses into an app's API client package — believable people, posts, threads, pictures and pages, scenarios that fail on purpose, and `.mock()` — so screens, previews and tests run with no server.

mocks's copy of Craft's agent standard (`craft-agent/1`, Craft's `Schema/Agent.md`), written by
`craft agents schema mocks` from its record. Everything above **Changes** is written again each time; Changes is
mocks's own log.

| File | What it holds |
| --- | --- |
| [`mocks.input.schema.json`](mocks.input.schema.json) | What it takes, as JSON Schema |
| [`mocks.answer.schema.json`](mocks.answer.schema.json) | What it answers: `granite-answer/1` with its own kinds |

## What it takes

| Field | Required | What it is |
| --- | --- | --- |
| `package` | no | the client package's folder, relative to the project (`Packages/RecipeKit`); found by its api.json when left out |
| `theme` | no | what the app is and how it sounds, which the records are written in: `a cozy recipe-sharing community: home cooks posting what they made` |
| `counts` | no | how many records of a type, one line each: `posts: 40`, `comments: 120`, `people: 20`; 24 posts, three replies a post, 16 people and 8 groups when left out |
| `scenarios` | no | the scenarios the package's tests prove: normal, empty, failing, unauthorized, slow; every one when left out |
| `endpoints` | no | endpoint lines over the package's own, in network's line, for an endpoint the package's api.json lacks |
| `entities` | no | entity lines over the package's own, in the models line |
| `seed` | no | a number the picks are made from; the same seed and words make the same fixtures |
| `rounds` | no | how many answers the model may give one batch; 3 when left out |

`directory` is filled by Craft with the project folder. The person's request and the host's model are offered
beside the call, never in it.

## What it makes

| Kind | What | Into | Never |
| --- | --- | --- | --- |
| `client` | the client's mock: `.mock()`, a transport that answers every endpoint in the process from fixtures | `Packages/*/Sources/*/Mocks/*` | the client itself, or the app's screens |
| `fixture` | believable records the mock answers with: people, posts, threads, pictures, pages, scenarios that fail on purpose | `Packages/*/Sources/*/Mocks/Fixtures/*`, `Packages/*/mocks.json` |  |
| `test` | tests that every fixture decodes as the client's types | `Packages/*/Tests/*` |  |

## What it answers

A `granite-answer/1` answer (Granite's `Schema/GraniteAgent.md` §4.2): `paths`, `made` against `expected` by kind and
name, `problems` for what it could only do in part, `payloads` for files that keep a standard of their own, and its
own keys beside them. Craft measures each call by what it made of what it expected.

## How it refuses

With an `AgentRefusal`: a kind and reasons, each with its fix. `input` and `call` are the call's to correct; `build`,
`device`, `reach`, `model` and `host` what stood in the way; `answer` and `parse` its own bug.

## Changes

Each change made to make this agent more precise, dated, with the regime run that measured it and what it
made of what it was asked before and after (`TESTING.md`). Newest first.

### 2026-11-04 · answer `granite-answer/1`: records against counts

mocks answers one `fixture` per entity with the count it wrote against the count asked, the `client` and the `test`. A word-list fallback is a `problem`, and its asks of the model are in the answer's frame, no longer a fixed 0. (3bea47d)

Measured: not yet. Answers before this were pre-standard, so there is no precision to compare; the next regime chain on Margin is the first measure.

### 2026-11-04 · refuse a title that opens as another does

`mocks_stems` failed every regime cycle on Margin (2026-11-03/04): five pairs of titles opened with the same four words. A title whose first four words another title has is now refused and asked again. (89612cf)

Measured: not yet. Answers before this were pre-standard, so there is no precision to compare; the next regime chain on Margin is the first measure.
