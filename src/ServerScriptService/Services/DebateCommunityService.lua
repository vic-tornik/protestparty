--!strict
-- Community debate topics. All user text is filtered on the server before any broadcast.
-- Public proposals are server-local and expire with the server; private rooms use short-lived codes.
local Players = game:GetService("Players")
local TextService = game:GetService("TextService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("GameConfig"))
local GlobalDebateService = require(script.Parent:WaitForChild("GlobalDebateService"))
local WeeklyChampionshipService = require(script.Parent:WaitForChild("WeeklyChampionshipService"))
local SocialSystemsService = require(script.Parent:WaitForChild("SocialSystemsService"))

local Service = {}
local stateRemote: RemoteEvent
local communityRemote: RemoteEvent
local publicQueue: {any} = {}
local lastSubmit: {[number]: number} = {}
local lastPrivateCreate: {[number]: number} = {}
local lastVoteRequest: {[number]: number} = {}
local lastReportRequest: {[number]: number} = {}
local lastPrivateVoteRequest: {[number]: number} = {}
local lastWeeklyRequest: {[number]: number} = {}
local lastTournamentRequest: {[number]: number} = {}
local lastRefreshRequest: {[number]: number} = {}
local lastModerateRequest: {[number]: number} = {}
local reports: {[string]: {[number]: boolean}} = {}
local rooms: {[string]: any} = {}
local playerRoom: {[number]: string} = {}
local MAX_QUEUE = 20
local ALLOWED_CATEGORIES = {Everyday=true, Technology=true, Factions=true, Wildcard=true}
local MAX_TOPIC_LENGTH = 100
local MIN_TOPIC_LENGTH = 12
local SUBMIT_COOLDOWN = 75
local ROOM_SECONDS = 50

local function validPlayer(player: Player): boolean
	return player.Parent == Players and player:GetAttribute("ProfileLoaded") == true
end

local function cleanTopic(input: any): string?
	if type(input) ~= "string" then return nil end
	local topic = string.gsub(input, "[%c]", " ")
	topic = string.gsub(topic, "%s+", " ")
	topic = string.gsub(topic, "^%s*(.-)%s*$", "%1")
	if #topic < MIN_TOPIC_LENGTH or #topic > MAX_TOPIC_LENGTH then return nil end
	return topic
end

local function filterForBroadcast(player: Player, raw: string): string?
	local ok, result = pcall(function()
		local filterResult = TextService:FilterStringAsync(raw, player.UserId, Enum.TextFilterContext.PublicChat)
		return filterResult:GetNonChatStringForBroadcastAsync()
	end)
	if not ok or type(result) ~= "string" or result == "" then return nil end
	if string.find(result, "#", 1, true) then return nil end
	return result
end

local function cleanCategory(player: Player, rawCategory: any): string?
	if type(rawCategory) ~= "string" then return "Everyday" end
	local category = string.gsub(rawCategory, "%s+", " ")
	category = string.gsub(category, "^%s*(.-)%s*$", "%1")
	if ALLOWED_CATEGORIES[category] then return category end
	if #category < 3 or #category > 18 or not string.match(category, "^[%w%s]+$") then return nil end
	local ok, filtered = pcall(function()
		local result = TextService:FilterStringAsync(category, player.UserId, Enum.TextFilterContext.PublicChat)
		return result:GetNonChatStringForBroadcastAsync()
	end)
	if not ok or type(filtered) ~= "string" or filtered == "" or string.find(filtered, "#", 1, true) then return nil end
	return filtered
end

local function publicSnapshot()
	local globalTopics = GlobalDebateService.GetTrending()
	if #globalTopics > 0 then return globalTopics end
	local list = {}
	for i, item in ipairs(publicQueue) do
		if i > 8 then break end
		table.insert(list, {id=item.id, topic=item.topic, category=item.category or "Everyday", votes=item.votes, creator=item.creator})
	end
	return list
end

local function broadcastPublic(message: string?)
	stateRemote:FireAllClients({kind="CommunityDebates", publicTopics=publicSnapshot(), notice=message})
end

local function removePublicTopic(topicId: string)
	for i, item in ipairs(publicQueue) do
		if item.id == topicId then table.remove(publicQueue, i); reports[topicId] = nil; break end
	end
end

local function createPublic(player: Player, raw: any, rawCategory: any)
	if not validPlayer(player) then return end
	local now = os.clock()
	if now - (lastSubmit[player.UserId] or 0) < SUBMIT_COOLDOWN then
		stateRemote:FireClient(player, {kind="CommunityNotice", text="Please wait before proposing another topic."}); return
	end
	lastSubmit[player.UserId] = now
	if #publicQueue >= MAX_QUEUE then
		stateRemote:FireClient(player, {kind="CommunityNotice", text="The public topic queue is full. Try again after a debate."}); return
	end
	local clean = cleanTopic(raw)
	if not clean then
		stateRemote:FireClient(player, {kind="CommunityNotice", text="Topics must be 12–100 characters."}); return
	end
	local filtered = filterForBroadcast(player, clean)
	if not filtered then
		stateRemote:FireClient(player, {kind="CommunityNotice", text="Roblox could not approve that topic. Please rephrase it."}); return
	end
	local normalized = string.lower(filtered)
	for _, item in ipairs(publicQueue) do
		if string.lower(item.topic) == normalized then
			stateRemote:FireClient(player, {kind="CommunityNotice", text="That topic is already in the public queue."}); return
		end
	end
	local category = cleanCategory(player, rawCategory)
	if not category then stateRemote:FireClient(player,{kind="CommunityNotice",text="Categories must be 3–18 safe letters/numbers. Rephrase if Roblox filtering rejects it."}); return end
	local globalOk, globalError = GlobalDebateService.Submit(filtered, category, player.UserId, player.DisplayName)
	if not globalOk and (globalError == "duplicate" or globalError == "global_cooldown") then
		stateRemote:FireClient(player,{kind="CommunityNotice",text=if globalError == "duplicate" then "That topic already exists in the global debate feed." else "Global submission cooldown active. Please wait before trying again."})
		return
	end
	-- Keep a local fallback only for infrastructure failures; never bypass a global rate limit.
	if not globalOk then
		table.insert(publicQueue, {id=HttpService:GenerateGUID(false), topic=filtered, category=category, votes=0, voterIds={}, creator=player.DisplayName, createdAt=os.time()})
	end
	broadcastPublic(if globalOk then "Topic published to the global debate network." else "Global network unavailable; topic is queued in this server only.")
	stateRemote:FireClient(player, {kind="CommunityNotice", text=if globalOk then "Your topic entered the global debate network!" else "Global network unavailable. Your topic is queued locally."})
end

local function createPrivate(player: Player, raw: any)
	if not validPlayer(player) then return end
	if os.clock()-(lastPrivateCreate[player.UserId] or 0)<20 then stateRemote:FireClient(player,{kind="CommunityNotice",text="Wait before creating another private room."}); return end
	lastPrivateCreate[player.UserId]=os.clock()
	local roomCount=0; for _ in pairs(rooms) do roomCount+=1 end
	if roomCount>=20 then stateRemote:FireClient(player,{kind="CommunityNotice",text="Private debate capacity is full. Try again shortly."}); return end
	local clean = cleanTopic(raw)
	if not clean then stateRemote:FireClient(player,{kind="CommunityNotice",text="Topics must be 12–100 characters."}); return end
	local filtered = filterForBroadcast(player, clean)
	if not filtered then stateRemote:FireClient(player,{kind="CommunityNotice",text="Roblox could not approve that topic. Please rephrase it."}); return end
	if playerRoom[player.UserId] then stateRemote:FireClient(player,{kind="CommunityNotice",text="Leave your current private debate first."}); return end
	local code = string.upper(string.sub(string.gsub(HttpService:GenerateGUID(false), "-", ""), 1, 6))
	while rooms[code] do code=string.upper(string.sub(string.gsub(HttpService:GenerateGUID(false), "-", ""), 1, 6)) end
	rooms[code] = {code=code, topic=filtered, host=player.UserId, members={[player.UserId]=true}, votes={}, createdAt=os.clock(), endsAt=os.clock()+ROOM_SECONDS, closed=false}
	playerRoom[player.UserId] = code
	stateRemote:FireClient(player,{kind="PrivateDebate",code=code,topic=filtered,endsAt=workspace:GetServerTimeNow()+ROOM_SECONDS,counts={A=0,B=0},host=true})
	task.delay(ROOM_SECONDS, function()
		local room = rooms[code]
		if not room or room.closed then return end
		room.closed = true
		local a,b=0,0; for _,side in pairs(room.votes) do if side=="A" then a+=1 elseif side=="B" then b+=1 end end
		for userId in pairs(room.members) do
			local member=Players:GetPlayerByUserId(userId)
			if member then stateRemote:FireClient(member,{kind="PrivateDebateResult",topic=room.topic,a=a,b=b,winner=if a>b then "A" elseif b>a then "B" else "TIE"}) end
			playerRoom[userId]=nil
		end
		rooms[code]=nil
	end)
end

local function joinPrivate(player: Player, rawCode: any)
	if not validPlayer(player) or type(rawCode)~="string" then return end
	local code=string.upper(string.gsub(rawCode,"%s+",""))
	if #code~=6 or playerRoom[player.UserId] then stateRemote:FireClient(player,{kind="CommunityNotice",text="Invalid code or you are already in a private debate."}); return end
	local room=rooms[code]
	if not room or room.closed or os.clock()>=room.endsAt then stateRemote:FireClient(player,{kind="CommunityNotice",text="That private debate has ended or does not exist."}); return end
	local memberCount=0; for _ in pairs(room.members) do memberCount+=1 end
	if memberCount>=8 then stateRemote:FireClient(player,{kind="CommunityNotice",text="Private debates are limited to eight players."}); return end
	room.members[player.UserId]=true; playerRoom[player.UserId]=code
	local a,b=0,0; for _,side in pairs(room.votes) do if side=="A" then a+=1 elseif side=="B" then b+=1 end end
	stateRemote:FireClient(player,{kind="PrivateDebate",code=code,topic=room.topic,endsAt=workspace:GetServerTimeNow()+math.max(0,room.endsAt-os.clock()),counts={A=a,B=b},host=false})
end

local function privateVote(player: Player, code: any, side: any)
	if not validPlayer(player) or type(code)~="string" or (side~="A" and side~="B") then return end
	local now = os.clock(); if now-(lastPrivateVoteRequest[player.UserId] or 0)<0.35 then return end; lastPrivateVoteRequest[player.UserId]=now
	local room=rooms[code]
	if not room or room.closed or not room.members[player.UserId] or os.clock()>=room.endsAt then return end
	room.votes[player.UserId]=side
	local a,b=0,0; for _,v in pairs(room.votes) do if v=="A" then a+=1 elseif v=="B" then b+=1 end end
	for userId in pairs(room.members) do local member=Players:GetPlayerByUserId(userId); if member then stateRemote:FireClient(member,{kind="PrivateDebateCounts",a=a,b=b}) end end
end

local function voteTopic(player: Player, topicId: any)
	if not validPlayer(player) or type(topicId)~="string" then return end
	local now = os.clock(); if now-(lastVoteRequest[player.UserId] or 0)<0.5 then return end; lastVoteRequest[player.UserId]=now
	if string.sub(topicId, 1, 6) == "topic_" then
		if GlobalDebateService.Vote(topicId, player.UserId) then broadcastPublic("Global topic support updated across servers.") end
		return
	end
	for _,item in ipairs(publicQueue) do
		if item.id==topicId then
			item.voterIds=item.voterIds or {}
			if not item.voterIds[player.UserId] then item.voterIds[player.UserId]=true; item.votes+=1; broadcastPublic("A public topic received an audience vote.") end
			return
		end
	end
end

local function reportTopic(player: Player, topicId: any)
	if not validPlayer(player) or type(topicId)~="string" then return end
	local now = os.clock(); if now-(lastReportRequest[player.UserId] or 0)<1 then return end; lastReportRequest[player.UserId]=now
	if string.sub(topicId, 1, 6) == "topic_" then
		local accepted, count = GlobalDebateService.Report(topicId, player.UserId)
		stateRemote:FireClient(player,{kind="CommunityNotice",text=if accepted then "Global report received. A moderator can review the topic." else "You have already reported this topic or the report service is unavailable."})
		if count >= 3 then broadcastPublic("A global topic has reached the moderation review threshold.") end
		return
	end
	local found=false
	for _,item in ipairs(publicQueue) do if item.id==topicId then found=true break end end
	if not found then return end
	reports[topicId]=reports[topicId] or {}
	if reports[topicId][player.UserId] then return end
	reports[topicId][player.UserId]=true
	local count=0; for _ in pairs(reports[topicId]) do count+=1 end
	if count>=3 then removePublicTopic(topicId); broadcastPublic("A topic was removed after multiple player reports.") end
	stateRemote:FireClient(player,{kind="CommunityNotice",text="Report received. Reports are reviewed by the server moderation threshold."})
end

function Service.GetNextPublicTopic(): any?
	local globalPick = GlobalDebateService.GetNextFeaturedOrTrending()
	if globalPick then return globalPick end
	if #publicQueue==0 then return nil end
	table.sort(publicQueue,function(a,b) return a.votes>b.votes end)
	local selected=table.remove(publicQueue,1)
	broadcastPublic("A community topic was selected for the next public debate.")
	return {id="community_"..selected.id,prompt=selected.topic,sideA="SUPPORT THE MOTION",sideB="OPPOSE THE MOTION",context="Community-submitted topic. Debate the idea, never the person."}
end


local function isModerator(player: Player): boolean
	for _, userId in ipairs(Config.ModeratorUserIds or {}) do
		if userId == player.UserId then return true end
	end
	return false
end

local function moderateTopic(player: Player, topicId: any, action: any)
	if not validPlayer(player) or not isModerator(player) or type(topicId) ~= "string" or type(action) ~= "string" then return end
	local now = os.clock(); if now-(lastModerateRequest[player.UserId] or 0)<1 then return end; lastModerateRequest[player.UserId]=now
	if GlobalDebateService.Moderate(topicId, action, player.UserId) then
		stateRemote:FireClient(player, {kind="CommunityNotice", text="Moderation action applied: " .. action})
		broadcastPublic("The global debate board was updated by moderation.")
	else
		stateRemote:FireClient(player, {kind="CommunityNotice", text="Moderation action failed. Refresh and try again."})
	end
end

function Service.Start(remote: RemoteEvent, state: RemoteEvent)
	communityRemote=remote; stateRemote=state
	GlobalDebateService.Start(function() broadcastPublic("Global debate topics refreshed across servers.") end)
	communityRemote.OnServerEvent:Connect(function(player, action, value, extra)
		if type(action)~="string" then return end
		if action=="CreatePublic" then createPublic(player,value,extra)
		elseif action=="CreatePrivate" then createPrivate(player,value)
		elseif action=="JoinPrivate" then joinPrivate(player,value)
		elseif action=="PrivateVote" then privateVote(player,value,extra)
		elseif action=="ReportTopic" then reportTopic(player,value)
		elseif action=="VoteTopic" then voteTopic(player,value)
		elseif action=="ModerateTopic" then moderateTopic(player,value,extra)
		elseif action=="VoteFeatured" then
            if not validPlayer(player) or type(value)~="string" then return end
            local now=os.clock(); if now-(lastVoteRequest[player.UserId] or 0)<1 then return end; lastVoteRequest[player.UserId]=now
            local accepted,count=GlobalDebateService.VoteFeatured(value,player.UserId)
            stateRemote:FireClient(player,{kind="CommunityNotice",text=if accepted then "Community feature vote recorded · "..tostring(count).." votes" else "You already voted or the feature-vote service is unavailable."})
            if count>=5 then broadcastPublic("A topic has reached the community feature threshold and is eligible for moderator approval.") end
        elseif action=="GetModerationQueue" then
            if not validPlayer(player) or not isModerator(player) then return end
            local now=os.clock(); if now-(lastModerateRequest[player.UserId] or 0)<2 then return end; lastModerateRequest[player.UserId]=now
            stateRemote:FireClient(player,{kind="ModerationQueue",items=GlobalDebateService.GetReviewQueue()})
        elseif action=="GetModerationAudit" then
            if not validPlayer(player) or not isModerator(player) or type(value)~="string" then return end
            local now=os.clock(); if now-(lastModerateRequest[player.UserId] or 0)<2 then return end; lastModerateRequest[player.UserId]=now
            stateRemote:FireClient(player,{kind="ModerationAudit",topicId=value,entries=GlobalDebateService.GetAudit(value)})
		elseif action=="RefreshGlobal" then
			if not validPlayer(player) then return end
			local now=os.clock(); if now-(lastRefreshRequest[player.UserId] or 0)<8 then return end; lastRefreshRequest[player.UserId]=now
			stateRemote:FireClient(player,{kind="CommunityDebates",publicTopics=publicSnapshot(),notice="GLOBAL DEBATE NETWORK · LIVE DISCOVERY"})
		elseif action=="GetTournament" then
            if not validPlayer(player) then return end
            local now=os.clock(); if now-(lastTournamentRequest[player.UserId] or 0)<5 then return end; lastTournamentRequest[player.UserId]=now
            stateRemote:FireClient(player,{kind="FactionWar",data=SocialSystemsService.GetWarState()})
		elseif action=="GetWeekly" then
			if not validPlayer(player) then return end
			local now=os.clock(); if now-(lastWeeklyRequest[player.UserId] or 0)<30 then return end; lastWeeklyRequest[player.UserId]=now
			stateRemote:FireClient(player,{kind="WeeklyChampionship",data=WeeklyChampionshipService.GetTop()})
		end
	end)
	Players.PlayerAdded:Connect(function(player)
		task.delay(2,function() if player.Parent==Players then stateRemote:FireClient(player,{kind="CommunityDebates",publicTopics=publicSnapshot()}) end end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastSubmit[player.UserId]=nil
		lastPrivateCreate[player.UserId]=nil
		lastVoteRequest[player.UserId]=nil
		lastReportRequest[player.UserId]=nil
		lastPrivateVoteRequest[player.UserId]=nil
		lastWeeklyRequest[player.UserId]=nil
		lastTournamentRequest[player.UserId]=nil
		lastRefreshRequest[player.UserId]=nil
		lastModerateRequest[player.UserId]=nil
		local code=playerRoom[player.UserId]
		if code and rooms[code] then rooms[code].members[player.UserId]=nil; rooms[code].votes[player.UserId]=nil end
		playerRoom[player.UserId]=nil
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		if isModerator(player) then stateRemote:FireClient(player,{kind="ModeratorAccess",enabled=true}) end
	end
	Players.PlayerAdded:Connect(function(player)
		task.delay(3,function() if player.Parent==Players and isModerator(player) then stateRemote:FireClient(player,{kind="ModeratorAccess",enabled=true}) end end)
	end)
	broadcastPublic("Global debate network online. Discover topics submitted across servers.")
end
return Service
