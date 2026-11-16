# Security model — v0.3

## Trust boundary
The client renders UI and sends intent only. The server owns phase, vote acceptance, faction membership, shop prices, currency, XP, Hype, daily progress, claims, city rules, alliance assignment, and betrayal outcomes.

## Validated interactions
- Cause vote: active Voting phase, loaded player profile, bounded string, membership in the three currently offered IDs, per-user rate limit.
- Debate vote: active Debate phase, loaded profile, A/B allowlist, per-user rate limit.
- Town Hall vote: active TownHall phase, loaded profile, A/B/C allowlist, per-user rate limit and server-side proximity prompt validation.
- Chant: Rally phase, loaded profile, correct station in the generated world, character root within range, living Humanoid, cooldown, and per-round cap.
- Cosmetic purchase: item ID resolved from the server catalog, price taken from server catalog (never client-supplied), profile loaded, prompt proximity, request cooldown, wallet check, and ownership check.
- Faction join: faction ID resolved from server catalog, profile loaded, prompt proximity and cooldown.
- Daily claim: server-selected challenge, server-tracked progress, UTC date, and one-time claim flag.

## Abuse cases to test
- Fire every RemoteEvent with malformed types, oversized strings, invalid IDs, or calls during the wrong phase.
- Trigger prompts from outside activation distance or with a dead character.
- Repeatedly activate a shop prompt, including when the player has insufficient Coins or already owns the item.
- Attempt to claim daily rewards repeatedly, across reconnects, and across UTC midnight.
- Rejoin multiple servers rapidly to test session lease contention.
- Manipulate local UI, attributes, and client-side values; confirm server profile values remain authoritative.
- Teleport or speed-hack to reach stations; the server distance check must reject remote activation, but this is not a complete movement anti-cheat.

## Explicit limitations
- This is not a completed penetration test, moderation audit, or Roblox certification.
- Roblox character physics and client network ownership require additional movement validation if competitive movement rewards are introduced.
- Faction and debate chat use Roblox's native chat moderation. Do not add free-form player slogans without TextService filtering and reporting/moderation workflows.
- No custom asset IDs, external HTTP calls, trading, Robux purchase receipts, or cross-server matchmaking are present in this build.


## Community debate user-generated content (v0.4)

- Topic text is accepted only by the server and must be 12–100 characters after whitespace normalization.
- The server calls Roblox `TextService:FilterStringAsync` with `PublicChat` context and `GetNonChatStringForBroadcastAsync` before any player-visible display. If filtering errors, returns empty text, or yields a filtered `#` string, submission is rejected. Never broadcast raw input as a fallback.
- Public queue submissions are rate-limited per player, deduplicated, capped at 20 pending topics per server, and are visible only within the current live server. The top-supported pending topic can become that server's next round debate.
- Public support votes are one per player per topic. Three distinct reports remove a pending topic from the local queue; this threshold is a coarse abuse control, not human moderation. Roblox moderation and reporting remain necessary.
- Private topics are also filtered before display. Private rooms use short-lived six-character invite codes, are capped at eight players and 20 active rooms per server, and expire after 50 seconds. Votes are accepted only from room members.
- User-generated topics, votes, and private-room history are memory-only. They are not persisted to player profiles.
- Review Roblox policy and test TextService behavior in a published test experience before release.


## v0.5 debate reputation and categories

Debate reputation is server-owned profile data and must only be changed through server-side validation. It is not a client-supplied value, currency, or purchase balance. Public topic categories are a fixed allowlist (`Everyday`, `Technology`, `Factions`, `Wildcard`); unknown values resolve to `Everyday`. Global moderation and cross-server topic aggregation are not implemented in v0.5.


## v0.7.0 social and moderation controls

- Party membership, leader authority, invite resolution, invite expiry, and member cap are server-owned. Parties are same-server only and ephemeral.
- Feature votes and reports are deduplicated by UserId/topic in MemoryStore. The five-vote community nomination threshold is not Sybil-resistant; do not treat it as proof of broad consensus.
- Moderation actions and queue/audit reads require a server-side UserId allowlist. Client visibility is cosmetic and is not authorization.
- Moderation audit history is durable DataStore data but is not tamper-proof. DataStore failures can interrupt audit writes; operators must monitor warnings and reconcile state.
- Weekly faction cup scoring is server awarded; clients cannot submit score values.


## v0.8 social systems

- The SocialSystems RemoteEvent accepts action identifiers and bounded inputs only. Server checks player load state, per-player request throttle, party membership, proximity, title unlocks, and moderator allowlist membership.
- Report, bio, and moderator-note text is filtered with Roblox TextService before persistence. The staff dashboard is allowlist-only.
- Case assignment targets must be in the moderator allowlist. Appeals must come from the reported UserId and only reopen resolved cases.
- Predictions are keyed by UserId and updated through MemoryStore UpdateAsync. A cross-server event marker makes the first eligible debate result canonical.
- Social reputation, badges, faction points, party reputation, and territory are computed on the server; clients cannot submit reward values.
- Remaining risks: alternate accounts can influence predictions; MemoryStore/MessagingService quotas and outages can delay global event operations; movement spoofing is not comprehensively mitigated; case audit is bounded and operational rather than tamper-proof.
