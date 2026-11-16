# PROTEST PARTY v0.3 — Product and design brief

## Product promise
A social comedy party game in which players join ridiculous fictional movements, debate low-stakes civic nonsense, rally with crowds, watch the city react, and collect expressive cosmetics. The experience should be understandable within one minute and offer a new social beat every round.

## v0.3 core loop
1. Spawn in the civic plaza and meet faction NPCs.
2. Vote for one of three curated fictional causes.
3. Join a short structured debate using preset positions.
4. Join a faction and its randomly assigned coalition.
5. Lead chants during the rally; a server-selected crowd incident interrupts the event.
6. A faction may betray its coalition during the rally, changing coalition scoring.
7. The winning cause changes the plaza's lighting or decoration.
8. Players vote in Town Hall for one of three temporary city rules.
9. Earn server-calculated coins/XP, progress a daily challenge, and buy/equip cosmetics.

## v0.3 systems

### Faction NPCs
- Pigeon Union: "Wings, wages, crumbs."
- Printer Resistance: "Paper jams are a cry for help."
- Department of Unnecessary Rules: "Form 88-B to request a form."
- Snack Council: "No crumb left behind."

NPCs have authored dialogue and a lightweight procedural head-bob animation. They are built from simple Parts to avoid external asset dependencies. Replace the procedural block rigs with original rigged characters and authored animation assets after art direction and device profiling.

### Debate and Town Hall
Debates remain curated A/B prompts. Audience members can react at three physical pads (clap, laugh, side-eye); reaction counts are server-owned and a Debate MVP is selected from participants on the winning side (or all reactors on a tie). Town Hall offers three fixed rules: Double Hype Hour, Pigeon Parade Route, and Mandatory Confetti Break. Votes are server-counted and only accepted in the correct phase. No user-submitted text is accepted.

### Dynamic incidents and city consequences
Crowd incidents are selected from a curated catalog and spawn temporary visual props (paperwork, congress podium, buffering beacon, or snack crate) that are removed when the incident expires. The winning cause changes lighting or adds a decorative city prop for the following cycle. Town Hall rules have gameplay or visual effects. These are intentionally bounded, non-destructive world modifiers.

### Alliances and betrayal
Four factions are paired into two server-generated coalitions for a rally. A scripted betrayal can switch one faction's coalition mid-round. Faction and coalition Hype totals determine the displayed MVP; no player-to-player attacks or targeted harassment are part of this system.

### Player movements and banners
Players can join one of four curated movements and equip preset cosmetic banners. Free-form slogan submission is intentionally excluded from v0.3. If introduced later, it must use Roblox TextService filtering, server-side validation, rate limits, reporting, and a safe fallback when filtering fails.

### Cosmetic economy
Earnable items are cosmetic-only: cardboard placard, neon megaphone, pigeon hat, paper crown, spectrum banner, ink trail, main-character badge, and tiny gavel. Purchases use server-owned catalog prices and profile balances. No Robux products are included in this milestone.

### Daily challenge
One UTC-day challenge rotates deterministically among chants, debates, and rally participation. Progress, claim status, and date are stored in the player's profile. Claiming is one-time per UTC day.

## Art and quality direction
- Palette: charcoal/navy civic architecture, lime accents, violet debate spaces, warm faction-specific highlights.
- Silhouette: plaza hub, visible debate stage, eastern Town Hall, western cosmetic shop, faction desks, rally stations, daily board.
- Humour target: fictional bureaucracy, NPC behaviour, technology annoyances and absurd civic systems—not protected identities or real-world tragedies.
- Avoid copied meme images, unlicensed music, recognizable third-party characters, placeholder lorem ipsum, and generic repeated dialogue.

## Performance direction
The v0.3 world uses anchored Parts and a small number of scripted NPCs. Avoid unbounded particle emitters, per-frame loops, huge transparent parts, and excessive moving assemblies. Profile on low-end mobile devices before adding high-density crowds. For production, use StreamingEnabled configured in Studio properties rather than forcing it from scripts.

## Success metrics
Measure D1 and D7 retention, first-session completion of the first rally, percentage of players who join a faction, debate participation, daily challenge completion, cosmetic shop conversion, average session length, crash/error rate, and player-reported frustration. Compare cohorts before and after each release; do not treat raw session length or purchases as a substitute for player satisfaction.
