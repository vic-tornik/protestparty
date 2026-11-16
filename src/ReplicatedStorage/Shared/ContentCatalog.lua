--!strict
-- Curated, original, fictional content. Do not place real-world political campaigns,
-- copyrighted slogans, unlicensed characters, or unlicensed meme images/audio here.
local ContentCatalog = {}

ContentCatalog.Seasons = {
	launch_01 = {
		name = "THE GREAT NOPE",
		description = "A city-wide campaign against things that are mildly, spectacularly annoying.",
		accent = "lime",
	},
	season_02 = {
		name = "THE INTERNET IS ON BREAK",
		description = "A future content pack about buffering, notifications, and suspiciously smart fridges.",
		accent = "violet",
	},
}

ContentCatalog.ActiveSeason = "launch_01"

ContentCatalog.Causes = {
	{ id = "ban_mondays", shortTitle = "BAN MONDAYS", title = "BAN MONDAYS FROM HAVING MONDAYS", detail = "The calendar has had enough chances." },
	{ id = "pigeon_rent", shortTitle = "PIGEON RENT", title = "MAKE PIGEONS PAY RENT", detail = "They own the whole plaza and contribute nothing." },
	{ id = "free_nugget", shortTitle = "FREE THE NUGGET", title = "FREE THE LAST NUGGET", detail = "It has been in the freezer since the patch notes." },
	{ id = "printer_rights", shortTitle = "PRINTER RIGHTS", title = "PRINTERS MUST STOP SCREAMING", detail = "One paper jam. Three business days of trauma." },
	{ id = "loading_comp", shortTitle = "LOADING COMP", title = "LOADING SCREENS OWE US COMPENSATION", detail = "We have seen the spinning wheel long enough." },
	{ id = "sock_solo", shortTitle = "FIND THE SOCK", title = "FIND THE MISSING SOCK", detail = "The washing machine is a suspect, not a witness." },
	{ id = "nap_rights", shortTitle = "NAP RIGHTS", title = "DECLARE A UNIVERSAL NAP BREAK", detail = "The pillows have prepared a statement." },
	{ id = "wifi_manners", shortTitle = "WI-FI MANNERS", title = "WI-FI MUST GIVE A WARNING BEFORE DISCONNECTING", detail = "A tiny heads-up would be appreciated." },
	{ id = "homework_dlc", shortTitle = "NO HOMEWORK DLC", title = "HOMEWORK DOES NOT NEED DLC", detail = "The base game is already too expensive in time." },
	{ id = "npc_union", shortTitle = "NPC RIGHTS", title = "NPCs DESERVE BETTER DIALOGUE", detail = "They have said the same thing for 400 years." },
	{ id = "water_bottle", shortTitle = "LOST WATER", title = "WATER BOTTLES MUST STOP VANISHING", detail = "Check the desk. Check again. It is gone." },
	{ id = "queue_skip", shortTitle = "QUEUE REFORM", title = "LET THE QUEUE MOVE AT HUMAN SPEED", detail = "The line has developed its own ecosystem." },
	{ id = "caps_lock", shortTitle = "CAPS LOCK CURFEW", title = "CAPS LOCK NEEDS A CURFEW", detail = "The keyboard has been shouting since Tuesday." },
	{ id = "fridge_light", shortTitle = "FRIDGE EVIDENCE", title = "THE FRIDGE LIGHT KNOWS TOO MUCH", detail = "Every time we open the door, the story changes." },
	{ id = "autocorrect", shortTitle = "AUTOCORRECT APOLOGY", title = "AUTOCORRECT MUST ISSUE AN APOLOGY", detail = "It changed one word and started a whole incident." },
	{ id = "charger_side", shortTitle = "CHARGER RIGHTS", title = "CHARGERS MUST HAVE A CORRECT SIDE", detail = "Three flips is not a user experience." },
	{ id = "group_chat", shortTitle = "GROUP CHAT BREAK", title = "THE GROUP CHAT NEEDS A COOLDOWN", detail = "One message became 287 notifications." },
	{ id = "alarm_clock", shortTitle = "ALARM NEGOTIATIONS", title = "ALARM CLOCKS MUST NEGOTIATE", detail = "We request five more minutes and a written reply." },
	{ id = "last_fry", shortTitle = "LAST FRY LAWYER", title = "THE LAST FRY DESERVES A LAWYER", detail = "No one should face a table of hungry witnesses alone." },
	{ id = "elevator_music", shortTitle = "ELEVATOR REMIX", title = "ELEVATOR MUSIC NEEDS A REMIX", detail = "The lift has been playing the same three notes." },
	{ id = "update_loop", shortTitle = "UPDATE THE UPDATE", title = "UPDATES MUST NOT NEED ANOTHER UPDATE", detail = "The patch notes have patch notes." },
	{ id = "browser_tabs", shortTitle = "TAB RENT", title = "BROWSER TABS MUST PAY RENT", detail = "Forty-seven tabs and not one knows why it is open." },
	{ id = "mute_button", shortTitle = "MUTE MEANS MUTE", title = "THE MUTE BUTTON MUST ACTUALLY MUTE", detail = "A button should not be a philosophical suggestion." },
	{ id = "vending_receipt", shortTitle = "VENDING RECEIPTS", title = "VENDING MACHINES MUST SHOW RECEIPTS", detail = "The snack has been paid for. The snack must appear." },
	{ id = "umbrella_rain", shortTitle = "UMBRELLA DUTY", title = "UMBRELLAS MUST WAIT FOR THE RAIN", detail = "They vanish on sunny days and resign during storms." },
	{ id = "cloud_privacy", shortTitle = "CLOUD PRIVACY", title = "CLOUDS MUST DISCLOSE THEIR PLANS", detail = "A suspicious shadow has crossed the plaza." },
	{ id = "remote_control", shortTitle = "REMOTE RETURN", title = "THE REMOTE MUST STOP TELEPORTING", detail = "It was here five seconds ago. We have witnesses." },
	{ id = "spacebar", shortTitle = "SPACEBAR UNION", title = "THE SPACEBAR DESERVES A BREAK", detail = "It carries every sentence and receives no applause." },
	{ id = "meeting", shortTitle = "MEETING REFUND", title = "MEETINGS MUST HAVE A REFUND POLICY", detail = "This could have been a two-line notice." },
	{ id = "snack_tax", shortTitle = "SNACK TAX AUDIT", title = "SNACKS MUST NOT DISAPPEAR FROM SHARED DESKS", detail = "The crumbs are evidence. The culprit is still online." },
}


-- Inclusive satire: jokes target fictional bureaucracy, absurd rules, and institutions,
-- never women, LGBTQ+ people, or any protected identity.
local inclusiveCauses = {
 { id = "equal_npc_pay", shortTitle = "NPC PAY GAP", title = "EQUAL PAY FOR EVERY NPC INTERN", detail = "The quest giver has been unpaid since the tutorial launched.", theme = "Fairness" },
 { id = "rainbow_cones", shortTitle = "RAINBOW CONES", title = "EVERY TRAFFIC CONE DESERVES ALL SEVEN COLOURS", detail = "The grey cones have requested a more colourful workplace.", theme = "Pride" },
 { id = "avatar_entrances", shortTitle = "DRAMATIC ENTRANCES", title = "EVERY AVATAR GETS A DRAMATIC ENTRANCE", detail = "Main-character energy should not be locked behind a preset.", theme = "Expression" },
 { id = "pronoun_robots", shortTitle = "ROBOT PRONOUN PATCH", title = "THE ROBOT MAYOR NEEDS A PRONOUN SETTINGS MENU", detail = "The settings menu has been stuck on loading for six seasons.", theme = "Identity" },
 { id = "equal_queue", shortTitle = "QUEUE EQUALITY", title = "EQUAL QUEUE TIMES FOR ALL AVATARS", detail = "The VIP line has somehow become longer than the normal line.", theme = "Fairness" },
 { id = "pink_toolbox", shortTitle = "PINK TOOLBOX", title = "THE TOOLBOX COLOUR PICKER MUST HAVE MORE THAN TWO OPTIONS", detail = "The design department has discovered the colour wheel.", theme = "Expression" },
 { id = "no_mascot_gate", shortTitle = "MASCOT ACCESS", title = "COSTUMED MASCOTS DESERVE THE SAME ELEVATOR", detail = "The elevator says it is not rated for this much fabulousness.", theme = "Access" },
 { id = "all_avatar_sizes", shortTitle = "AVATAR OPTIONS", title = "THE CHARACTER CREATOR NEEDS MORE SILHOUETTES", detail = "The mannequin department has one job and 400 identical torsos.", theme = "Expression" },
 { id = "equal_quest_credit", shortTitle = "QUEST CREDIT", title = "EVERY TEAMMATE GETS CREDIT FOR THE GROUP QUEST", detail = "One player pressed the button. Everyone else did the emotional support.", theme = "Fairness" },
 { id = "rainbow_escalator", shortTitle = "RAINBOW ESCALATOR", title = "THE ESCALATOR MUST DISPLAY ALL SEVEN COLOURS", detail = "Facilities says the purple step is still in beta.", theme = "Pride" },
 { id = "npc_maternity_break", shortTitle = "NPC BREAK ROOM", title = "NPC WORKERS NEED A BREAK ROOM WITH ACTUAL CHAIRS", detail = "The break room currently contains one decorative cactus.", theme = "Fairness" },
 { id = "unisex_robot_bathroom", shortTitle = "ROBOT RESTROOM", title = "THE ROBOT FACILITY NEEDS A UNIVERSAL RESTROOM SIGN", detail = "The robots have filed 900 tickets about the confusing arrows.", theme = "Access" },
 { id = "equal_emote_slots", shortTitle = "EMOTE EQUALITY", title = "EVERY PLAYER GETS THE SAME NUMBER OF EMOTE SLOTS", detail = "The default dance has been doing unpaid overtime.", theme = "Fairness" },
 { id = "no_gendered_toasters", shortTitle = "TOASTER SETTINGS", title = "THE TOASTER MUST STOP ASSIGNING ITSELF A PERSONALITY TYPE", detail = "It keeps calling itself the bread king. HR is investigating.", theme = "Identity" },
 { id = "inclusive_group_photo", shortTitle = "GROUP PHOTO", title = "NO ONE GETS LEFT OUT OF THE SERVER GROUP PHOTO", detail = "The photographer keeps cropping out the person holding the camera.", theme = "Access" },
 { id = "equal_giggle", shortTitle = "GIGGLE RIGHTS", title = "ALL AVATARS GET ACCESS TO THE SAME GIGGLE ANIMATION", detail = "The premium giggle has become a public infrastructure issue.", theme = "Fairness" },
 { id = "accessible_obby", shortTitle = "OBBY OPTIONS", title = "THE OBBY NEEDS MORE THAN ONE WAY TO REACH THE CHECKPOINT", detail = "The ramp is under construction. The stairs are unionizing.", theme = "Access" },
 { id = "all_pride_flags", shortTitle = "BANNER PALETTE", title = "THE PLAZA BANNER EDITOR NEEDS A BIGGER COLOUR PALETTE", detail = "The art intern has been given three crayons and a deadline.", theme = "Pride" },
 { id = "equal_voice_lines", shortTitle = "VOICE LINE AUDIT", title = "EVERY NPC GETS MORE THAN ONE VOICE LINE", detail = "The shopkeeper has repeated 'welcome' since the dawn of time.", theme = "Expression" },
 { id = "no_default_hero", shortTitle = "HERO OPTIONS", title = "THE HERO TITLE SHOULD NOT BE RESERVED FOR ONE AVATAR TYPE", detail = "The prophecy has been sent back for a rewrite.", theme = "Fairness" },
}
for _, cause in ipairs(inclusiveCauses) do table.insert(ContentCatalog.Causes, cause) end

-- Structured, preset debate cards. No player-written arguments or free-text submissions.
ContentCatalog.Debates = {
 { id = "equal_npc_pay", prompt = "SHOULD THE NPC OFFICE PUBLISH ITS PAY SCALE?", sideA = "YES: TRANSPARENCY IS A PUBLIC SERVICE", sideB = "NO: THE ACCOUNTANT IS A PIGEON WITH A CALCULATOR", context = "A fictional workplace fairness debate. The joke is the town's terrible administration." },
 { id = "pride_plaza", prompt = "SHOULD THE PLAZA HOST A RAINBOW-THEMED CELEBRATION?", sideA = "YES: THE PLAZA COULD USE MORE COLOUR", sideB = "ONLY IF THE PIGEONS APPROVE THE PALETTE", context = "A cheerful fictional celebration debate. No player identity is up for debate." },
 { id = "avatar_pronouns", prompt = "SHOULD THE AVATAR CREATOR ADD A PRONOUN DISPLAY OPTION?", sideA = "YES: LET PLAYERS CUSTOMIZE THEIR PROFILE", sideB = "YES, BUT THE SETTINGS MENU NEEDS A SEARCH BAR FIRST", context = "Both sides support player choice; the argument is about the UI implementation." },
 { id = "unpaid_labor", prompt = "SHOULD NPCs GET CREDIT FOR ALL THEIR INVISIBLE WORK?", sideA = "YES: THE QUEST DOES NOT COMPLETE ITSELF", sideB = "YES, BUT THE CREDIT SHOULD BE PAID IN SNACKS", context = "A silly debate about recognizing fictional workers." },
 { id = "npc_union", prompt = "SHOULD NPCs GET PAID IN ACTUAL COINS?", sideA = "YES: THEY KEEP THE WHOLE WORLD RUNNING", sideB = "NO: THEY ALREADY GET UNLIMITED DIALOGUE", context = "A fictional workplace debate about the town's endlessly employed NPCs." },
 { id = "rainbow_cones", prompt = "SHOULD EVERY TRAFFIC CONE GET A RAINBOW REPAINT?", sideA = "YES: COLOUR MAKES THE PLAZA BETTER", sideB = "NO: THE CONES HAVE A STRICT ORANGE BRAND GUIDE", context = "A silly design-budget dispute. All players and identities are welcome." },
 { id = "emote_slots", prompt = "SHOULD EVERYONE GET 12 EMOTE SLOTS?", sideA = "YES: EXPRESSION SHOULD BE FOR EVERYONE", sideB = "NO: THE SERVER CAN ONLY HANDLE 11 DANCES", context = "A debate about game design and a suspiciously fragile dance server." },
 { id = "nap_break", prompt = "SHOULD THE PLAZA HAVE A MANDATORY NAP BREAK?", sideA = "YES: REST IS A HUMAN RIGHT (AND A NPC RIGHT)", sideB = "NO: THE PIGEONS WILL TAKE OVER", context = "A harmless argument about the plaza schedule." },
 { id = "equal_quest", prompt = "SHOULD EVERY TEAMMATE GET FULL QUEST CREDIT?", sideA = "YES: TEAMWORK MEANS EVERYONE COUNTS", sideB = "NO: THE BUTTON PRESSER GETS A TROPHY", context = "A fictional co-op game balance debate." },
 { id = "toaster_pronouns", prompt = "SHOULD THE MAYOR'S TOASTER HAVE A SETTINGS MENU?", sideA = "YES: LET THE TOASTER DEFINE ITS SETTINGS", sideB = "NO: IT HAS 4 BUTTONS AND THEY ALL SAY BAGEL", context = "A surreal settings-menu debate; the joke is the toaster's bureaucracy, not identity." },
 { id = "accessible_obby", prompt = "SHOULD EVERY OBBY HAVE MULTIPLE ROUTES?", sideA = "YES: MORE WAYS TO PLAY IS BETTER", sideB = "NO: THE ONE LADDER IS A CLASSIC", context = "A playful accessibility and level-design discussion." },
 { id = "group_photo", prompt = "WHO SHOULD TAKE THE SERVER GROUP PHOTO?", sideA = "THE PLAYER WITH THE BIGGEST HAT", sideB = "THE PLAYER WHO ISN'T IN THE PHOTO YET", context = "A ridiculous civic photography committee hearing." },
 { id = "pigeon_tax", prompt = "SHOULD PIGEONS PAY RENT FOR THE PLAZA?", sideA = "YES: THEY OCCUPY 80% OF THE BENCHES", sideB = "NO: THEY PROVIDE FREE SECURITY", context = "The pigeons have declined to comment." },
 { id = "dramatic_entrance", prompt = "SHOULD EVERY PLAYER GET A DRAMATIC ENTRANCE?", sideA = "YES: EVERYONE IS THE MAIN CHARACTER", sideB = "NO: THE DOOR BUDGET IS ALREADY GONE", context = "A debate about theatrics and municipal spending." },
 { id = "printer_union", prompt = "SHOULD PRINTERS BE ALLOWED TO JOIN THE NPC UNION?", sideA = "YES: THEY SUFFER PAPER JAMS TOO", sideB = "NO: THEY KEEP EATING THE CONTRACTS", context = "A dispute between two fictional departments." },
 { id = "snack_tax", prompt = "SHOULD THE LAST FRY BE TAXED?", sideA = "YES: FUND THE PUBLIC NUGGET RESERVE", sideB = "NO: THE LAST FRY IS SACRED", context = "A snack-based policy debate with no real-world stakes." },
}

function ContentCatalog.GetRandomDebate(random: Random?): any
 local rng = random or Random.new()
 return ContentCatalog.Debates[rng:NextInteger(1, #ContentCatalog.Debates)]
end

ContentCatalog.CauseById = {}
for _, cause in ipairs(ContentCatalog.Causes) do
	ContentCatalog.CauseById[cause.id] = cause
end

function ContentCatalog.GetSeason()
	return ContentCatalog.Seasons[ContentCatalog.ActiveSeason] or ContentCatalog.Seasons.launch_01
end

function ContentCatalog.GetRandomOptions(count: number, random: Random?): {any}
	local rng = random or Random.new()
	local pool = table.clone(ContentCatalog.Causes)
	local options = {}
	local wanted = math.min(count, #pool)
	for _ = 1, wanted do
		local index = rng:NextInteger(1, #pool)
		table.insert(options, table.remove(pool, index))
	end
	return options
end


-- v0.3: original city factions, daily objectives, town-hall rules and cosmetic catalog.
ContentCatalog.Factions = {
 {id="pigeon_union", name="PIGEON UNION", motto="Wings, wages, crumbs.", dialogue={"We demand fair crumbs.","Coos are not a payment method.","The plaza is technically our roof."}},
 {id="printer_resistance", name="PRINTER RESISTANCE", motto="Paper jams are a cry for help.", dialogue={"The ink has seen things.","We reject duplex oppression.","Have you tried turning the mayor off and on?"}},
 {id="bureaucracy", name="DEPARTMENT OF UNNECESSARY RULES", motto="Form 88-B to request a form.", dialogue={"Your complaint is missing a complaint.","Please queue to receive a queue number.","We have escalated this to a pigeon."}},
 {id="snack_council", name="SNACK COUNCIL", motto="No crumb left behind.", dialogue={"The last fry has legal representation.","Snack equality is a serious matter.","We meet at the vending machine."}},
}
ContentCatalog.Cosmetics = {
 {id="basic_sign", name="Cardboard Classic", kind="placard", price=0, description="A dependable rectangle of civic outrage."},
 {id="neon_megaphone", name="Neon Megaphone", kind="megaphone", price=180, description="Visible from three departments away."},
 {id="pigeon_hat", name="Tiny Pigeon Hat", kind="hat", price=260, description="Union-approved headwear."},
 {id="paper_crown", name="Paper Crown", kind="hat", price=320, description="Mayor of absolutely nothing."},
 {id="rainbow_banner", name="Spectrum Banner", kind="banner", price=220, description="A colourful banner for a colourful plaza."},
 {id="ink_trail", name="Ink Cloud Trail", kind="trail", price=450, description="Printer Resistance tested. Printer approved."},
 {id="dramatic_pose", name="Main Character Pose", kind="emote", price=500, description="A pause for cinematic importance."},
 {id="tiny_gavel", name="Tiny Gavel", kind="prop", price=390, description="Order! The pigeon is speaking."},
}
ContentCatalog.TownHallRules = {
 {id="double_hype", title="DOUBLE HYPE HOUR", detail="Chants grant +1 bonus Hype this round."},
 {id="pigeon_parade", title="PIGEON PARADE ROUTE", detail="Pigeons occupy the central plaza. No gameplay penalty."},
 {id="confetti_break", title="MANDATORY CONFETTI BREAK", detail="The plaza celebrates with extra confetti."},
}
ContentCatalog.CrowdEvents = {
 {id="paper_storm", title="PAPER JAM STORM", detail="Loose paperwork sweeps through the plaza.", duration=18},
 {id="pigeon_congress", title="EMERGENCY PIGEON CONGRESS", detail="The Pigeon Union has called an unscheduled meeting.", duration=18},
 {id="buffering", title="CITY-WIDE BUFFERING", detail="The city is thinking very hard. Keep chanting.", duration=15},
 {id="snack_drop", title="SNACK EMERGENCY", detail="A suspicious snack shipment has arrived.", duration=18},
}
ContentCatalog.DailyChallenges = {
 {id="daily_chants", title="PUBLIC SPEAKING (LOUDLY)", detail="Lead 5 chants today.", target=5, kind="chants", coins=75, xp=35},
 {id="daily_debate", title="CIVIC DISCOURSE", detail="Join 1 debate today.", target=1, kind="debates", coins=60, xp=30},
 {id="daily_rounds", title="SHOW UP TO THE NONSENSE", detail="Participate in 2 rallies today.", target=2, kind="rounds", coins=90, xp=40},
}
function ContentCatalog.GetCosmetic(id: string): any?
 for _, item in ipairs(ContentCatalog.Cosmetics) do if item.id == id then return item end end
 return nil
end
function ContentCatalog.GetFaction(id: string): any?
 for _, item in ipairs(ContentCatalog.Factions) do if item.id == id then return item end end
 return nil
end

return ContentCatalog
