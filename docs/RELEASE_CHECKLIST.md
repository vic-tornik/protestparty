# Release and rollback checklist

## Current v0.8.0 release gates

- [ ] Snapshot production DataStore state and publish to a private test experience first.
- [ ] Verify player profile schema v3 and the existing player DataStore name/key format remain unchanged.
- [ ] Run `python tests/static_audit.py` and retain the complete output with the build.
- [ ] Run Luau analysis/compile checks with the team's Roblox Studio/Rojo toolchain.
- [ ] Enable API Services only in the private test experience and validate all new store namespaces with disposable test data.
- [ ] Test 2–6 client party challenges, proximity, living-character checks, party leadership changes, cooldown, and reputation persistence.
- [ ] Test semifinal schedule lock, scheduled finalist debate, canonical cross-server final result, tie handling, trophy idempotency, and plaza/NPC refresh.
- [ ] Verify public profile fields, filtered bio, title unlocks, achievements, badge idempotency, reputation history bounds, and respawn title rendering.
- [ ] Verify one prediction per UserId, exclusion of canonical debate voters from spectator tallies, 300-voter cap, correct predictor rewards, and result broadcasts across at least two servers.
- [ ] Test reports, case queue TTL, moderator assignment allowlist, filtered notes, appeals, decisions, and audit persistence under DataStore failures.
- [ ] Verify non-moderators cannot see staff controls and cannot invoke staff actions through remotes.
- [ ] Test Social Hub at 320px, 360px, 390px, tablet, desktop, touch, and controller navigation.
- [ ] Review DataStore budgets, MemoryStore quotas, MessagingService quotas, retention expectations, and operational monitoring.
- [ ] Confirm no unfiltered free-form text or unlicensed assets were introduced.

## Rollback

v0.8.0 does not migrate or rewrite the existing player profile schema. It adds separate social identity, party reputation, Faction War, event prediction, and moderation-case stores. Rolling code back to v0.7.0 should leave the existing profile schema intact, but v0.7.0 will not read or display v0.8 social data. Do not delete or reset the new stores during a code rollback. Re-enable v0.8-compatible code or use a tested forward-fix to restore those features. Never overwrite newer records with older snapshots unless incident response explicitly establishes that this is safe.

## v0.7.0 historical release gates

- [ ] Verify Party remote authorization, invite expiry, six-player cap, leader-only kick/invite, leader transfer, and same-server scope with 2–6 clients.
- [ ] Verify the legacy v0.7 UTC faction fixture only when reproducing that historical build; v0.8 replaces it with the weekly Faction War bracket.
- [ ] Verify community feature nomination deduplication and five-UserId threshold; confirm moderators alone can publish featured topics.
- [ ] Verify report queue threshold, review actions, restore flow, and per-topic audit history.
- [ ] Exercise DataStore throttling/failure and reconcile audit state before retrying any moderation action.
- [ ] Run Luau analysis/compile and Studio runtime tests; static audit is not a substitute.
