# Changelog

## 0.8.0 — Integrated social systems and evolving world

- Connected coordinated party protests to group achievements, persistent club reputation, player social reputation, and faction-war scoring.
- Replaced the earlier daily round-robin faction cup with a weekly four-faction semifinal/final bracket, scheduled UTC phase gates, territory control, and a trophy record.
- Added public identity profiles, filtered bios, unlockable titles, badges, achievements, bounded reputation history, and avatar title labels.
- Added a daily 18:00 UTC global debate event window, one-per-user spectator predictions, canonical event claiming, and cross-server broadcast.
- Added durable player-report cases, allowlisted staff assignment, filtered internal notes, appeals, appeal decisions, and bounded case audit history.
- Added plaza faction flags, a trophy pedestal, NPC territory dialogue, and server-wide result announcements.
- Added the Social Hub client panel and mobile-width resizing.
- Preserved player profile schema v3 and existing player DataStore names/key format; new systems use isolated stores.
- Static audit expanded. Luau compilation, Studio runtime, multi-server, mobile/controller, exploit, and penetration testing remain outstanding.

## 0.7.0 — Social parties, faction cup, and accountable moderation

- Added same-server parties for up to six players: create, invite by in-server username/display name, accept, leave, leader transfer, and leader kick.
- Added a weekly faction-versus-faction cup with deterministic UTC daily fixtures and persistent weekly faction standings.
- Added one-person-one-vote community feature nominations. Five unique voters mark a pending topic community-approved; moderators must still approve it before it becomes featured.
- Added a cross-server moderation review queue after three unique reports, plus moderator-only feature/remove/restore actions.
- Added per-topic persistent moderation audit history (last 50 actions), including moderator UserId, action, prior/new status, and UTC timestamp.
- Preserved profile schema v3 and existing DataStore names/key format.

## 0.6.0 — Global debate network and competitive season foundation

- Added cross-server debate discovery using MemoryStore sorted maps and MessagingService refresh notifications.
- Added global support voting, report deduplication, topic TTL, trending sort, featured-topic priority, and atomic topic claiming before round selection.
- Added moderator-only Feature / Remove / Restore actions, gated by configured Roblox UserIds.
- Added player-created category tags with server-side character/length validation and Roblox TextService filtering.
- Added weekly global debate leaderboard and weekly faction standings using week-scoped OrderedDataStores.
- Added weekly points for debate participation, winning side, and Debate MVP; lifetime reputation remains a separate profile statistic.

## 0.5.0

- Added persistent Debate Reputation and lifetime Debate Wins.
- Added cinematic plaza lighting and HUD refresh.
- Added curated community debate categories and responsive layout.

## 0.4.0

- Added public and private community debate submission, filtering, voting, and reporting.
