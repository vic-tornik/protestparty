# v0.8.0 — Integrated Social & World Systems

## Design contract

v0.8 connects parties, faction competition, player identity, scheduled debate events, moderation cases, and the evolving plaza. All rewards and permissions are computed by the server. New social data is isolated from the existing player profile schema and store/key format.

## Party activities and reputation

- Same-server parties support up to six members. Invitations expire after 45 seconds; party membership and invites remain ephemeral.
- The leader can start a coordinated protest challenge. Every current party member must join within 120 seconds and be within 70 studs of the leader.
- A challenge has a persistent five-minute cooldown reserved atomically in `PP_PartyReputation_v1`. The party's club reputation is keyed by its creator's stable club key, so recreating a party under that creator reuses its reputation.
- Completion awards each current party member +5 social reputation, a `coordinated_protest` achievement, and a bounded history entry. The leader can unlock the `party_captain` badge.
- A completed protest adds 10 points to the leader's current faction score. The challenge completion is guarded against duplicate completion in a server.
- A persistent party roster, cross-server invites, party teleport, and party chat are not included.

## Faction War bracket, finals, territory, trophy

- `PP_FactionWar_v1` stores the weekly bracket, territory, and trophy. `PP_FactionWarScores_<YYYY_WW>` OrderedDataStores hold per-faction weekly points to avoid a single hot score key.
- Semifinals: Pigeon Union vs Printer Resistance; Department of Unnecessary Rules vs Snack Council.
- Semifinal winners are locked after Wednesday 18:00 UTC from accumulated faction points. A 30-second schedule worker advances the phase even when no round ends at that exact time.
- The final is scheduled for Friday 18:00 UTC. During the final event window, every server presents the same finalist-versus-finalist debate. The first canonical final debate result determines the trophy: side A awards finalist A, side B awards finalist B, and a tie falls back to accumulated finalist score.
- If no round is processed at the scheduled time, the final prompt remains active until the first eligible later event window. The bracket stores exact UTC semifinal/final timestamps.
- The winning faction receives one weekly plaza territory and a trophy record. Plaza banner, faction flags, trophy pedestal, and NPC dialogue react to the winner; MessagingService refreshes the world and scoreboard across servers.
- This is a score-based semifinal plus a scheduled debate final, not a reserved tournament server or a single shared vote tally. Each server runs its own local debate; the first eligible result is canonical. Semi-final tie-breaks favor the first-listed faction.
- Territory is currently one plaza control point. Multiple districts, season-history browsing, and reserved tournament instances are future work.

## Player identity

- `PP_SocialIdentity_v1` stores a public title, filtered bio, badges, achievements, social reputation, and the latest 20 reputation-history entries.
- Titles are validated against unlocked badges and render above the player's avatar. Available titles include New Voice, Audience MVP, Party Captain, Faction Champion, and Civic Oracle.
- Public profile lookup accepts a Roblox UserId and exposes only the fields listed above.
- Badge unlocks currently include Audience MVP, Party Captain, Faction Champion, and Civic Oracle. Badges are idempotent; the same badge does not repeatedly grant reputation.
- Social identity remains separate from Coins, XP, inventory, and the existing schema-v3 player profile.

## Scheduled global debate events

- A daily global debate window begins at 18:00 UTC and lasts two hours. Predictions close 30 minutes after the scheduled start.
- All servers use the same deterministic, date-rotated fictional prompt during the window. On Faction War final day, the sides become the two finalist factions.
- Predictions are one per UserId, stored in `PP_EventPredictions_v1` MemoryStore data with a 24-hour TTL. Players who cast an A/B debate vote in the canonical result server are excluded from the spectator prediction tally. Clients receive only aggregate A/B counts, the result, and their own prediction; the server retains the spectator voter ledger for result processing. The per-event vote payload is capped at 300 participants to bound MemoryStore item size; larger events require a sharded counter/voter-index design.
- The first completed eligible A/B/TIE result is atomically claimed as the canonical daily event result. The canonical result is stored with its debate ID so a generic event result cannot accidentally decide a Faction War final.
- Correct predictors can unlock Civic Oracle. Online predictors are awarded immediately on the result broadcast; offline predictors are checked when they next join while the event record remains available.
- Result announcements and MVP details are broadcast across servers using MessagingService. Audience MVP is based on the existing server-side debate audience scoring.
- This is a shared-prompt cross-server event, not a synchronized global match instance with one participant roster or one aggregated vote tally. Each server still runs its own local debate; the first eligible result is canonical.

## Moderation operations

- Player reports create durable GUID-keyed cases in `PP_ModerationCases_v1`. Report text, player bios, appeals, and moderator notes are filtered through Roblox TextService before persistence.
- `PP_ModerationCaseQueue_v1` is a seven-day MemoryStore queue index; the durable case record is stored separately and is not deleted when the index expires.
- Allowlisted moderators can view a selectable in-game case list, assign cases to themselves or another allowlisted moderator by UserId, add filtered internal notes, and resolve open/in-review cases.
- A reported player can appeal a resolved case. Appeals reopen the case as `APPEALED`; moderators can accept or reject an appeal.
- Each successful case mutation appends an actor/action/time audit entry. The case retains the latest 40 audit actions, up to 30 notes, and appeal submissions.
- The staff dashboard is an in-game staff panel, not a browser-based portal. `GameConfig.ModeratorUserIds` is empty by default and must be populated with trusted numeric Roblox UserIds in the private build. The case system records reports and review outcomes; it does not automatically suspend, ban, or otherwise punish players.

## Storage namespaces

| Store | Purpose | Retention / scope |
|---|---|---|
| `PP_SocialIdentity_v1` | Public identity, titles, badges, achievements, reputation history | Durable per UserId |
| `PP_PartyReputation_v1` | Club reputation and protest cooldown | Durable per creator club key |
| `PP_FactionWar_v1` | Bracket, territory, trophy | One key per UTC week |
| `PP_FactionWarScores_<YYYY_WW>` | Per-faction weekly points | OrderedDataStore, one per UTC week |
| `PP_EventPredictions_v1` | Event votes and canonical result | MemoryStore, 24-hour TTL |
| `PP_GlobalEventMarkers_v1` | Cross-server event start/result claims | MemoryStore, expiring markers |
| `PP_ModerationCases_v1` | Durable moderation cases, notes, appeals, audit | Durable per case GUID |
| `PP_ModerationCaseQueue_v1` | Staff queue index | MemoryStore, seven-day TTL |

## Security and reliability notes

- All social RemoteEvent actions require a loaded player, server-side rate limiting, strict input validation, and server-side authorization.
- Titles, reputation, badges, achievements, tournament points, party completion, and moderation permissions are never accepted from client-supplied reward fields.
- `UpdateAsync` callbacks are non-yielding. Do not add network calls, task waits, or other yielding operations inside these callbacks.
- DataStore, OrderedDataStore, MemoryStore, TextService, and MessagingService operations are guarded. Failed score reads prevent bracket advancement; failed case queue indexing is logged while the durable case remains.
- MessagingService and MemoryStore have quotas and transient failure modes. Alternate accounts can still influence predictions; the 300-vote cap bounds the current single-item design but is not Sybil resistance.

## Operational test requirements

1. Use a private test experience with API Services enabled; never test writes against production player data.
2. Start 2–6 Roblox Studio clients to test party challenge completion, leader/member departure, cooldown reservation, and party recreation under the same creator.
3. Use two published private test servers to verify a single canonical event result, correct predictor awards, Faction War final consistency, and cross-server broadcast/world refresh.
4. Verify UTC bracket phase boundaries around Wednesday and Friday 18:00 UTC, including server restarts, score-store failures, and missed schedule windows.
5. Test profile lookup for online/offline UserIds, filtered bios, title unlock enforcement, badge idempotency, and overhead-title respawn behaviour.
6. Configure moderator UserIds in a private build; test assignment to allowed/disallowed IDs, filtered notes, resolution, appeals by the wrong UserId, appeal decisions, case queue expiry, and DataStore failures.
7. Test 320px, 360px, 390px, tablet, desktop, touch, and controller navigation in Studio. The UI has not yet been visually verified at those sizes.

## Explicit non-claims

This release has not been Luau-compiled, run in Roblox Studio, load-tested across live servers, penetration-tested, exploit-tested, or certified. The Python static audit verifies selected source invariants only.
