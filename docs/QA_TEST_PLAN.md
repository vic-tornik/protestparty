# QA test plan — v0.3

## Automated/static checks
Run:

```bash
python tests/static_audit.py
```

This verifies source structure and selected safeguards. It does not compile Luau or execute Roblox APIs.

## Roblox Studio multi-client tests
Use a private test experience and Studio's **Test > Start** with at least 2 clients (preferably 4). Verify:

1. New players load default profiles and existing v0.2 test profiles migrate to schema 2 without balance/inventory reset.
2. Voting counts update consistently for all clients; invalid IDs and votes outside Voting are ignored.
3. Debate A/B counts update and invalid side values are ignored.
4. Town Hall A/B/C pads count one current choice per player; changing choice replaces the previous vote.
5. Debate reaction pads count clap/laugh/side-eye actions, enforce the per-player cap, and select a Debate MVP without accepting client-supplied scores.
5. Each faction NPC shows changing authored dialogue and its head-bob animation; joining updates the player's faction attribute.
6. Random alliances are announced; faction Hype contributes to coalition totals; betrayal switches one faction's coalition and is reflected in the result.
7. Crowd incident appears mid-rally and clears before the next phase.
8. The winning cause updates the plaza banner and the appropriate decorative/lighting consequence.
9. Town Hall rule affects the next rally: Double Hype caps at the normal max; parade/confetti decoration is bounded and removed/replaced by the next rule.
10. Shop purchases deduct the catalog price once, reject insufficient funds, persist ownership/equip selection, and visually attach the selected cosmetic after respawn.
11. Daily challenge progress tracks only the selected daily objective, persists after rejoin, resets on UTC date change, and cannot be claimed twice.
12. Mobile touch prompts and HUD remain usable at narrow resolutions; controller prompt support works.
13. A player leaving during every phase does not cause errors or duplicate rewards.

## Adversarial tests
- Fire cause/debate remotes with nil, tables, numbers, oversized strings, invalid IDs, and rapid requests.
- Trigger all ProximityPrompts from beyond range and with dead characters.
- Attempt purchases for unknown IDs and repeated prompt activation.
- Attempt daily claim before completion and repeated claims after success.
- Rejoin in a second server while a profile session is active.
- Simulate DataStore throttling/failure in a test environment and verify safe failure rather than blank-profile overwrite.

## Performance and device matrix
Test one low-end Android device, one mid-range Android device, one iOS device if available, and desktop. Observe memory, network receive/send, frame time, part count, UI scaling, prompt responsiveness, and respawn cleanup. The procedural crowd/NPC design is intentionally small; do not add large crowds until performance is measured.

## Release gates
No public release until Studio runtime, multi-client, persistence migration, mobile, and exploit tests pass. Record test build ID, tester, device, server output, reproduction steps, and severity for every defect.


## v0.4 community debate tests

1. Submit a valid public topic; verify every client in the same server sees only the filtered version.
2. Submit 11-character and 101-character topics; verify rejection.
3. Submit the same topic twice; verify duplicate rejection.
4. Submit repeatedly inside 75 seconds; verify cooldown.
5. Cause TextService filtering to fail in a controlled test; verify raw text is never displayed.
6. Vote to boost a public topic from multiple clients; verify one vote per player and ordering by support.
7. Report a pending topic from three distinct accounts; verify removal. One account must not satisfy the threshold multiple times.
8. Verify selected community topics become the next round debate in that server.
9. Create a private room; join with a valid code from another client; verify a wrong code, expired code, eighth/ninth participant boundary, and non-member vote are rejected.
10. Verify private votes are server-counted, results are sent only to room members, and the room expires after 50 seconds.
11. Verify topic creation and support votes do not award Coins or XP.
12. Shut down/restart the server; verify community queue and rooms reset while player profile data remains intact.
13. Test the composer at phone, tablet, desktop, and controller input sizes; verify it does not obstruct critical gameplay UI.


## v0.5 visual and profile checks

- Verify v2 profiles migrate to v3 with all prior Coins, XP, cosmetics, Daily state, and Stats unchanged; new debate stats default to zero.
- Verify DebateReputation cannot be modified by a client remote and is never spendable in the shop.
- Submit topics in each curated category and attempt an arbitrary category value; the server must fall back to Everyday.
- Test HUD at 1920×1080, 1366×768, 800×600, 390×844, and with gamepad navigation. Confirm the topic composer, category, queue, and private-room controls do not overlap or become inaccessible.
- Inspect night lighting on low graphics settings and mobile; disable or reduce post effects if frame time regresses.
- Confirm skyline/lighting effects do not obstruct paths, prompts, spawn, or line of sight.

## Not yet implemented in v0.5

Cross-server global topic storage/discovery, global trending score, community feature approval, weekly championship scheduling, faction tournament brackets, and moderator dashboard require separate MemoryStore/MessagingService/OrderedDataStore and permission design plus abuse-case testing. Do not market these as live features until their implementation and cross-server tests are complete.


## v0.7.0 party, tournament, and moderation tests

- Party: create; invite by exact username and display name; accept; verify six-player cap; verify leader-only invite/kick; verify leave and leader transfer; verify disconnect cleanup; verify invitations expire after 45 seconds.
- Party remote abuse: attempt invites from non-leaders, invalid names, non-string payloads, repeated requests, accepting expired invitations, and joining while already in a party.
- Faction War: verify weekly semifinal/final schedule, points from debates and party activities, territory/trophy, and cross-server updates.
- Community featured nomination: verify one vote per UserId/topic; verify four votes do not approve and five unique votes do; verify moderator Feature is rejected before community approval.
- Moderation: verify three unique reports enqueue a topic without auto-removal; verify non-moderators cannot read the queue or audit; verify Feature/Remove/Restore actions; verify audit records actor, action, old/new status, and timestamp.
- DataStore failure: simulate audit write failure and confirm warning appears; inspect the topic's current status before any retry.
- UI: verify party panel and debate network panel do not overlap on phone, tablet, and desktop; verify moderator controls are hidden for non-moderators.


## v0.8 integrated social test matrix

### Party activities
- Create a two-to-six member party, invite, accept, and start a coordinated protest.
- Verify each member must join within 120 seconds and within 70 studs of the leader.
- Test leader departure, member departure during challenge, expired challenge, repeated completion, DataStore failure, and party recreation under the same creator.
- Verify club reputation persists while party membership remains ephemeral.

### Faction war and world evolution
- Verify weekly score increments from debate participation and coordinated party protests.
- Test semifinals before/after Wednesday 18:00 UTC and final before/after Friday 18:00 UTC. Verify the Friday prompt displays the same two finalist factions on all test servers and that the canonical result and trophy winner agree.
- Verify tie-break behavior, territory owner, trophy record, plaza banner, flags, NPC subtitle reaction, and cross-server world refresh after restart.
- Confirm the bracket does not award a second trophy/reputation repeatedly after completion.

### Identity and events
- Test profile reads for self and another UserId, filtered bio persistence, invalid title selection, title unlocks, avatar respawn, badge idempotency, and history cap.
- Test daily event start, prediction close, duplicate prediction replacement, event result claim from two servers, correct predictor badge, and broadcast delivery.
- Verify the first eligible result only is canonical; simulate MemoryStore/MessagingService errors. Confirm clients receive aggregate prediction counts and only their own prediction, never the full voter ledger. Verify players who cast a debate A/B vote in the canonical server are excluded from the spectator tally and badge awards. Test the 300-voter cap.

### Moderation operations
- Test player report creation, invalid/self target, filtered report text, GUID collision resistance, queue expiry, case durability, moderator allowlist, assignment to allowed/disallowed IDs, filtered notes, resolve, appeal by target, appeal by non-target, and repeated appeal.
- Verify every successful case mutation appends an actor/action/time audit entry.
- Verify a failed DataStore write never produces a success message.

### UI and input devices
- Test Social Hub at 320, 360, 390, 768, and 1920 pixel viewport widths, portrait and landscape, touch, mouse, and controller.
- Confirm long case/profile text scrolls and buttons remain reachable.
