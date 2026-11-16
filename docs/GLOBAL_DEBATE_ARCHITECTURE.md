# Global debate architecture — v0.8.0

## Services

- `DebateCommunityService`: validates/filter user-submitted text, routes remote actions, and coordinates community UI updates.
- `GlobalDebateService`: MemoryStore topic index, support votes, feature nominations, report queue, moderator actions, and DataStore audit history.
- `WeeklyChampionshipService`: weekly player OrderedDataStore standings.
- `SocialSystemsService`: weekly faction semifinal/final bracket, party-linked faction scoring, territory/trophy, and scheduled global debate event broadcast.
- `PartyService`: server-authoritative same-server parties and expiring invitations.
- `RoundService`: awards weekly player points and passes server-calculated faction results into Faction War.

## Topic lifecycle

1. Player proposes a topic and category.
2. `DebateCommunityService` validates length/characters and filters text using Roblox TextService.
3. `GlobalDebateService` writes the topic to a three-day MemoryStore sorted map.
4. Players can support the topic and nominate it for featuring. Each UserId can vote once per topic per TTL.
5. Five unique feature nominations set `communityApproved=true`.
6. Three unique reports enqueue the topic for moderator review; reports do not auto-remove it.
7. A configured moderator can Feature a community-approved topic, Remove it, or Restore it. Actions append a per-topic DataStore audit entry.
8. The next eligible global debate is claimed atomically before a server uses it in a round.

## Moderation storage

- Topic index: `PP_GlobalDebates_v1` MemoryStore SortedMap, three-day TTL.
- Report and support markers: `PP_GlobalDebateReports_v1` MemoryStore HashMap.
- Feature vote markers/counts: `PP_DebateFeaturedVotes_v1` MemoryStore HashMap.
- Review queue: `PP_DebateModerationReview_v1` MemoryStore SortedMap, topic TTL.
- Audit: `PP_DebateModerationAudit_v1` DataStore, one key per topic, latest 50 actions retained.

## Faction War and scheduled global debate

Faction War uses `PP_FactionWar_v1` for weekly points, semifinals, final, territory, and trophy. The daily global debate event window starts at 18:00 UTC; predictions use `PP_EventPredictions_v1` MemoryStore and the canonical event result is claimed through `PP_GlobalEventMarkers_v1`. See `docs/V0_8_SOCIAL_SYSTEMS.md`.
