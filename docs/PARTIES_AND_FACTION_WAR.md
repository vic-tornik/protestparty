# Parties and Faction War — v0.8.0

## Party operations

- Same-server parties support up to six players, 45-second invitations, accept/leave, leader transfer, and leader kick.
- Party roster and invitations remain ephemeral. Party chat and cross-server party teleport are not included.
- The leader can start a coordinated protest challenge. Every current party member must join within 120 seconds and within 70 studs of the leader.
- Completion grants a group achievement, player social reputation/history, a Party Captain badge for the leader, and persistent club reputation.
- Party protest contributes points to the leader's faction war score. A five-minute cooldown prevents rapid challenge farming.

## Faction War bracket

- Weekly semifinal fixtures: Pigeon Union vs Printer Resistance; Department of Unnecessary Rules vs Snack Council.
- Semifinal winners lock after Wednesday 18:00 UTC from accumulated weekly faction scores; a 30-second schedule worker advances the bracket even if no round ends at that boundary.
- The final is scheduled for Friday 18:00 UTC. During the final event window, every server presents the same finalist-versus-finalist debate; the first canonical result decides the trophy. A tie falls back to accumulated finalist score.
- If no round is processed at the scheduled time, the final prompt remains active until the first eligible later event window.
- The winning faction receives one weekly plaza territory and a trophy record. The plaza banner, faction flags, trophy pedestal, and NPC dialogue reflect the result.
- Semifinals are score-based; the final is a scheduled debate, not a reserved tournament server or shared vote tally. Semi-final ties favor the first-listed faction.
- Faction scores receive debate participation/win/MVP points and completed party-protest points.

## Data stores

- `PP_PartyReputation_v1`: durable creator-club reputation.
- `PP_FactionWar_v1`: bracket, territory, and trophy. `PP_FactionWarScores_<YYYY_WW>` OrderedDataStores hold weekly faction points.
- Existing player profile schema remains v3. Social reputation and identity are separate from Coins and XP.

See `docs/V0_8_SOCIAL_SYSTEMS.md` for the full architecture and operational limitations.
