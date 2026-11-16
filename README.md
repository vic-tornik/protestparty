# PROTEST PARTY — Roblox experience starter

**Version:** 0.8.0
**Genre:** Social comedy / round-based party / faction roleplay
**Platform:** Roblox (Luau)
**Project format:** Rojo source project

> Development build, not a published, certified, or runtime-verified Roblox experience. Static source checks do not replace Luau analysis, Roblox Studio runtime tests, live multi-server tests, exploit testing, or security review.

## Game premise

A ridiculous city has been taken over by over-serious departments, factions, and NPCs. Players join fictional movements, vote on absurd causes, debate silly policies, rally with crowds, experience unexpected incidents and betrayals, and vote on temporary city rules. The debate network is designed as a repeat-visit social destination, with global topic discovery, community nominations, a weekly Faction War bracket, scheduled global debate finals, and parties.

Humour targets fictional bureaucracy, technology frustrations, NPC behaviour, and everyday absurdity. Inclusive causes can reference fairness, avatar expression, and Pride celebrations without making a protected identity the target of the joke.

## v0.8.0 feature set

### Interconnected party and faction systems
- Same-server parties of up to six players, with 45-second invitations and leader controls.
- Coordinated protest challenge: all current party members join near the leader within 120 seconds.
- Group achievement, player reputation/history rewards, Party Captain badge, and persistent club reputation.
- Weekly four-faction semifinal/final bracket with scheduled UTC phases, territory control, trophy record, and plaza/NPC consequences.
- Faction scores are server-awarded from debate participation and party activities.

### Debate network and community selection
- Cross-server topic discovery through MemoryStore sorted maps and MessagingService refresh notifications.
- Server-filtered topic submissions and custom category tags.
- Global support votes and one-per-user community feature nominations.
- Five unique feature nominations mark a topic community-approved; moderator approval is still required to feature it.
- Global topics are claimed atomically before use in a round.

### Social identity and global events
- Public player profiles with filtered bio, equipped title, badges, achievements, social reputation, and bounded reputation history.
- Selected titles render above player avatars; unlocks include Audience MVP, Party Captain, Faction Champion, and Civic Oracle.
- Daily global debate event window at 18:00 UTC with a shared rotating prompt, one-per-user predictions, audience MVP, and cross-server championship broadcasts.
- The first eligible result is canonical across servers; the Friday Faction War final uses the same finalist prompt and canonical result.

### Moderation operations
- Existing global-topic review queue, community nominations, and per-topic audit history remain.
- Player reports create durable moderation cases with GUIDs, filtered report text, assignments, internal notes, appeals, and bounded audit history.
- Allowlisted moderators use an in-game staff dashboard; appeals from the reported player reopen resolved cases.
- Case records are durable; the MemoryStore queue index expires after seven days. No automatic player punishment is performed.

### World, HUD, and core game
- Civic-night plaza visuals, global debate landmark, debate arena, four original NPC factions, crowd incidents, Town Hall rules, cosmetics, and daily challenges.
- Dark layered HUD with the integrated Social Hub for parties, faction bracket, public profiles, event predictions, reports, and staff case operations.
- Server-authoritative voting, rewards, purchases, party membership, tournament scoring, and moderation permissions.

## Install and run

1. Install Roblox Studio and Rojo (CLI and Studio plugin).
2. Extract the project ZIP to a working folder.
3. Open a terminal in the folder containing `default.project.json`.
4. Run:

   ```bash
   rojo serve default.project.json
   ```

5. Open a **new private test experience** in Roblox Studio and connect the Rojo plugin to the running Rojo server.
6. Verify the Explorer tree contains `ReplicatedStorage/Shared`, `ServerScriptService/Bootstrap.server.lua`, and both `StarterPlayer/StarterPlayerScripts/HUD.client.lua` and `SocialHUD.client.lua`.
7. Press **Play**. Use Studio **Test > Start** with 2–4 clients for party and shared-round testing.
8. Publish a private test build and use at least two live test servers to verify MemoryStore, MessagingService, and cross-server moderation behavior.

## Configuration

Add trusted numeric Roblox UserIds to `ModeratorUserIds` in `src/ReplicatedStorage/Shared/GameConfig.lua`. It is empty by default. Never expose moderator allowlists to clients or accept moderator status from a RemoteEvent payload.

Enable Studio Access to API Services only in a dedicated test experience. Do not use the production place for Studio DataStore testing.

## DataStore safety and migration

- Studio player data store: `ProtestParty_PlayerData_STUDIO`.
- Live player data store: `ProtestParty_PlayerData_LIVE`.
- Player keys remain `User_<UserId>`.
- Profile schema remains **v3** in v0.8.0. Existing Coins, XP, inventory, stats, and daily progress are unchanged; no player-profile migration is required.
- New isolated stores: `PP_SocialIdentity_v1`, `PP_PartyReputation_v1`, `PP_FactionWar_v1`, `PP_FactionWarScores_<YYYY_WW>`, `PP_EventPredictions_v1`, `PP_GlobalEventMarkers_v1`, `PP_ModerationCases_v1`, and `PP_ModerationCaseQueue_v1`.
- Faction War uses `PP_FactionWar_v1` for bracket/territory/trophy state and `PP_FactionWarScores_<YYYY_WW>` OrderedDataStores for faction points.
- Moderation audit uses `PP_DebateModerationAudit_v1`; review queue and feature nomination markers use expiring MemoryStore maps.
- Party membership and invites remain in-memory only; club reputation persists separately by creator club key.
- Back up/snapshot production data before any future migration. Read `docs/DATA_AND_MIGRATIONS.md` before publishing.

## Static checks

Run:

```bash
python tests/static_audit.py
```

The audit checks project structure and selected source safeguards. It is not a Luau compiler, Roblox Studio runtime test, multi-server test, penetration test, or certification.

## Known limitations and production gates

- Parties are same-server only. A server shutdown dissolves parties and outstanding invites.
- Feature nominations require five unique UserIds but are not Sybil-resistant; alternate accounts can influence voting. Consider account-age, playtime, and session eligibility gates before public release.
- Semifinals are score-based; the Friday final is a scheduled finalist debate whose first canonical server result decides the trophy. It is not a reserved tournament server or shared global vote tally. Semi-final ties favor the first-listed faction; a final tie falls back to accumulated finalist score. Territory currently represents one plaza control point.
- The staff console is in-game, not a browser-based portal. Case audit is bounded to 40 operations and the MemoryStore queue index expires after seven days. This system records reports and outcomes but does not automatically punish players.
- MemoryStore is ephemeral and topic data expires. It is not a permanent UGC archive.
- The plaza and NPCs are procedural Part-based prototypes; NPC animation and cosmetics still need authored rigs, meshes, icons, and polish.
- Movement manipulation/teleport anti-cheat is not complete. Do not add movement-based competitive rewards until that is addressed.

Before public release, complete Luau analysis/compilation, Studio runtime, multi-client, multi-server, mobile/controller, DataStore failure, moderation abuse, and exploit tests. See `docs/QA_TEST_PLAN.md`, `docs/SECURITY_MODEL.md`, and `docs/RELEASE_CHECKLIST.md`.

## Documentation

- `docs/V0_8_SOCIAL_SYSTEMS.md`
- `docs/PARTIES_AND_FACTION_WAR.md`
- `docs/MODERATION_REVIEW_AND_AUDIT.md`
- `docs/GLOBAL_DEBATE_ARCHITECTURE.md`
- `docs/DATA_AND_MIGRATIONS.md`
- `docs/SECURITY_MODEL.md`
- `docs/QA_TEST_PLAN.md`
- `docs/RELEASE_CHECKLIST.md`
