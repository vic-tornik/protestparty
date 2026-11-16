# Data persistence and v0.3 migration

## Stable production identity
- Production DataStore: `ProtestParty_PlayerData_LIVE`
- Studio DataStore: `ProtestParty_PlayerData_STUDIO`
- Key format: `User_<UserId>`
- Access pattern: server-only `UpdateAsync`, in-memory profile, session lease, autosave, save on leave, and shutdown release.

Do not rename the live store or key format for a normal content/code update. Use a dedicated test experience for Studio API access.

## Schema change
v0.2 used profile schema 1. v0.3 uses schema 2. The migration is additive and retains Coins, XP, Level, OwnedCosmetics, EquippedCosmetic, Stats, and Settings. It adds:

```lua
Daily = {
    date = "YYYY-MM-DD", -- UTC date
    challengeId = "daily_chants",
    progress = 0,
    claimed = false,
}
```

The stat allowlist adds `DailyClaims` and `FactionJoins`. Missing fields receive safe defaults. A profile with a future schema or corrupt shape is not replaced with a blank profile; the existing safe-load failure behaviour remains.

## Daily challenge semantics
- Challenge rotation is deterministic by UTC day-of-year.
- Progress is stored in the same player profile.
- A new UTC date resets only the Daily subrecord, not currency, XP, inventory, or other stats.
- Claim state is marked before reward application in the same server execution path; the reward is issued only once for that profile/day.
- This is a single-server in-memory mutation protected by the profile session lease. If daily reward processing later becomes asynchronous or cross-server, use an idempotent transaction ledger.

## Cosmetic semantics
- Cosmetic IDs and prices are defined in the server-shared catalog but purchases are performed only by server code.
- Existing `basic_sign` ownership is preserved.
- New items are added to `OwnedCosmetics` only after a validated purchase and balance check.
- The equipped ID is persisted; the server renders its visual attachment on character spawn and after purchase.

## Operational safeguards
1. Snapshot/backup production data before any storage-code change.
2. Test migration against copied v0.2 fixtures in a private test experience.
3. Verify old balances and inventory remain byte-for-byte equivalent where fields are unchanged.
4. Test two simultaneous sessions for one account and confirm the session lease prevents a second owner.
5. Simulate DataStore failures and verify the server does not create a blank replacement profile.
6. Publish the code update only after the migration and rollback plan are approved.

No persistence design can guarantee zero loss during every platform outage, process termination, or untested deployment. The code reduces risk; the release gate and backup process remain mandatory.


## v0.4 data compatibility

v0.4 does not change the player profile schema, DataStore names, or `User_<UserId>` key format. Community topic submissions, support votes, reports, private room codes, and private debate votes are server-memory state only. They reset when the server shuts down and do not require a profile migration. Existing profile schema remains version 2.


## v0.5 schema 3 addition

The v0.5 migration advances schema 2 to schema 3 additively. It adds `Stats.DebateReputation` and `Stats.DebateWins`, defaulting to zero. It does not rename the DataStore, change the `User_<UserId>` key format, reset Coins/XP, replace inventory, or delete Daily progress. DebateReputation is a non-spendable standing metric; it must never be accepted from a client or treated as currency. Back up production data and test migration against copied profiles before release.


## v0.7.0 storage additions

- No player profile schema migration. Existing schema v3, store names, and `User_<UserId>` keys remain unchanged.
- Parties and invites are in-memory only and are lost on server shutdown.
- v0.7 faction cup stores are legacy and no longer written by v0.8. The active weekly bracket uses `PP_FactionWar_v1`.
- `PP_DebateModerationReview_v1` is an expiring MemoryStore review queue. `PP_DebateModerationAudit_v1` is a DataStore keyed by topic and retains the last 50 moderation actions.
- `PP_DebateFeaturedVotes_v1` stores per-user feature nomination markers and per-topic vote counts with the topic TTL.


## v0.8.0 isolated social stores

The existing player profile remains schema v3. v0.8 adds separate stores so Coins, XP, inventory, daily challenges, and lifetime stats are not rewritten by social feature changes:

- `PP_SocialIdentity_v1`: per-UserId public profile, filtered bio, title, badges, achievements, social reputation, and bounded history.
- `PP_PartyReputation_v1`: persistent club reputation keyed by creator club key.
- `PP_FactionWar_v1`: semifinal/final bracket, territory, and trophy. `PP_FactionWarScores_<YYYY_WW>` OrderedDataStores hold faction points by week.
- `PP_EventPredictions_v1`: MemoryStore hash map for daily spectator predictions (24-hour TTL).
- `PP_GlobalEventMarkers_v1`: MemoryStore idempotency markers for event announcements/results.
- `PP_ModerationCases_v1`: durable GUID-keyed reports, assignments, notes, appeals, and bounded audit entries.
- `PP_ModerationCaseQueue_v1`: expiring MemoryStore staff queue index (7-day TTL); it does not own the case record.

Do not rename these namespaces or change the existing player data store/key pattern without a versioned migration plan. DataStore operations can fail or throttle; test with a private place and test data.
