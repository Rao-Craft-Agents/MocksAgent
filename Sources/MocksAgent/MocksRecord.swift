import GraniteAgents

/// The mocks agent's place in Granite's roster: an app that links this package finds the `mocks` agent by this
/// record, with nothing listed by hand.
@used @section("__DATA_CONST,__granite")
let mocksRecord: GraniteRoster.Record = { GraniteRoster.record(MocksAgent.self) }
