# Moderation Review and Audit — v0.7.0

## Review queue

- Global topic reports are deduplicated by `(UserId, topicId)` in MemoryStore.
- Three unique reports enqueue a topic in `PP_DebateModerationReview_v1`.
- The review queue is ephemeral and expires with the topic TTL; the topic itself remains in the global topic index until expiry or moderator action.
- Reports do not automatically delete or hide a topic. A moderator makes the decision.

## Community approval

- A player may cast one feature nomination per topic.
- Five unique UserIds set `communityApproved=true`.
- Community approval is not a moderation decision. The moderator's Feature action checks that approval flag.
- This is not resistant to alternate-account voting. Production eligibility should include account age, session age, and playtime gates.

## Moderator actions and audit

- Moderator authorization is a server-side allowlist in `GameConfig.ModeratorUserIds`.
- Actions: `Feature`, `Remove`, and `Restore`.
- Audit records include actor UserId, action, previous status, new status, and Unix UTC timestamp.
- Audit is stored in `PP_DebateModerationAudit_v1`, keyed by topic, with the most recent 50 actions retained.
- DataStore failure can prevent an audit append even if the MemoryStore status update succeeded. This is logged. The system is not tamper-proof; operators must monitor logs and verify audit state after service errors.

## Required live tests

- Verify normal players cannot request the moderation queue or audit history.
- Verify non-allowlisted UserIds cannot execute moderator actions by firing remotes directly.
- Verify duplicate reports from one account count once.
- Verify three unique reports enqueue a topic but do not auto-remove it.
- Verify five unique feature votes mark a topic community-approved, and fewer than five do not.
- Verify `Feature` fails without community approval.
- Verify `Remove` and `Restore` update status and append audit records.
- Simulate DataStore throttling in a test environment and inspect server warnings and final state.


## v0.8 player-report cases

The global topic review queue remains separate from the v0.8 player-report case workflow. Player reports create GUID-keyed durable records in `PP_ModerationCases_v1`; `PP_ModerationCaseQueue_v1` is only a seven-day MemoryStore index. Allowlisted staff can assign, add filtered notes, resolve, and decide appeals. A reported player can appeal a resolved case; the case re-enters the queue with status `APPEALED`. Each successful case mutation appends an actor/action/time audit item (latest 40). This is an in-game staff panel and does not automatically sanction users.
