--!strict
-- v0.8 integrated social layer. Server-authoritative; all durable writes are guarded and bounded.
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local MessagingService = game:GetService("MessagingService")
local TextService = game:GetService("TextService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Catalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ContentCatalog"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))

local Service = {}
local IdentityStore = DataStoreService:GetDataStore("PP_SocialIdentity_v1")
local WarStore = DataStoreService:GetDataStore("PP_FactionWar_v1")
local CaseStore = DataStoreService:GetDataStore("PP_ModerationCases_v1")
local PartyReputationStore = DataStoreService:GetDataStore("PP_PartyReputation_v1")
local PredictionMap = MemoryStoreService:GetHashMap("PP_EventPredictions_v1")
local remote: RemoteEvent
local stateRemote: RemoteEvent
local partyService: any
local identityCache: {[number]: any} = {}
local identityCacheAt: {[number]: number} = {}
local requestAt: {[number]: number} = {}
local activeChallenges: {[string]: any} = {}
local warCache: any = nil
local warCacheAt = 0
local MAX_NOTE = 240
local MAX_REASON = 180
local function utcDay(): number return tonumber(os.date("!%w")) or 0 end
local function weekStartTimestamp(): number local now=os.time(); local dayStart=math.floor(now/86400)*86400; return dayStart-((utcDay()+6)%7)*86400 end
local function weekKey(): string return os.date("!%Y_W%W",weekStartTimestamp()) end
local function factionScoreStore() return DataStoreService:GetOrderedDataStore("PP_FactionWarScores_"..weekKey()) end
local function safeString(v: any, max: number): string? if type(v) ~= "string" then return nil end; local s=string.gsub(v,"[%c]"," "); s=string.sub(s,1,max); if string.match(s,"%S") == nil then return nil end; return s end
local function valid(player: Player): boolean return player.Parent==Players and player:GetAttribute("ProfileLoaded")==true end
local function moderator(player: Player): boolean for _,id in ipairs(Config.ModeratorUserIds or {}) do if id==player.UserId then return true end end; return false end
local function throttle(player: Player, key: string, seconds: number): boolean local k=key..":"..player.UserId; local t=os.clock(); if t-(requestAt[k] or 0)<seconds then return false end; requestAt[k]=t; return true end
local function send(player: Player, kind: string, data: any) remote:FireClient(player,kind,data) end
local function defaultIdentity(userId: number): any return {userId=userId,title="New Voice",bio="",badges={},achievements={},reputation=0,history={},updatedAt=os.time()} end
local function identity(userId: number): any
 if identityCache[userId] and os.clock()-(identityCacheAt[userId] or 0)<30 then return identityCache[userId] end
 local ok,data=pcall(function() return IdentityStore:GetAsync("u:"..userId) end)
 local value=if ok and type(data)=="table" then data else defaultIdentity(userId)
 value.userId=userId; value.badges=if type(value.badges)=="table" then value.badges else {}; value.achievements=if type(value.achievements)=="table" then value.achievements else {}; value.history=if type(value.history)=="table" then value.history else {}
 if ok then identityCache[userId]=value; identityCacheAt[userId]=os.clock() end
 return value
end
local function mutateIdentity(userId: number, callback: (any)->())
 local ok,result=pcall(function() return IdentityStore:UpdateAsync("u:"..userId,function(old)
  local data=if type(old)=="table" then old else defaultIdentity(userId); data.badges=if type(data.badges)=="table" then data.badges else {}; data.achievements=if type(data.achievements)=="table" then data.achievements else {}; data.history=if type(data.history)=="table" then data.history else {}; callback(data); data.userId=userId; data.updatedAt=os.time(); return data
 end) end)
 if ok and type(result)=="table" then identityCache[userId]=result; identityCacheAt[userId]=os.clock(); return true,result end
 warn("[SocialSystems] Identity persistence failed for "..userId..": "..tostring(result)); return false,nil
end
local function addHistory(data: any, event: string, amount: number)
 table.insert(data.history,1,{event=event,amount=amount,at=os.time()}); while #data.history>20 do table.remove(data.history) end
end
local function getParty(player: Player): any?
 if not partyService or type(partyService.GetPartySnapshot)~="function" then return nil end
 return partyService.GetPartySnapshot(player)
end
local function partyMembers(player: Player): {Player}
 local result={}; local snap=getParty(player); if not snap or type(snap.members)~="table" then return result end
 for _,member in ipairs(snap.members) do local p=Players:GetPlayerByUserId(member.userId); if p then table.insert(result,p) end end
 return result
end
local function filteredText(player: Player, raw: string): string?
 local ok,filter=pcall(function() return TextService:FilterStringAsync(raw,player.UserId) end); if not ok or not filter then return nil end
 local success,text=pcall(function() return filter:GetNonChatStringForBroadcastAsync() end); if not success then return nil end
 return text
end
local function currentEvent(): any
 local now=os.time(); local dayStart=math.floor(now/86400)*86400
 -- Daily global debate window: 18:00 UTC, with a 30-minute prediction window.
 local starts=dayStart+18*3600
 local eventId="global:"..os.date("!%Y%m%d",starts)
 return {id=eventId,title="THE DAILY GLOBAL DEBATE",startsAt=starts,endsAt=starts+2*3600,predictionClosesAt=starts+1800,phase=if now<starts then "UPCOMING" elseif now<starts+2*3600 then "LIVE WINDOW" else "COMPLETE"}
end
local SCHEDULED_DEBATES={
 {prompt="Should pigeons receive formal voting rights in the city council?",sideA="YES: GIVE THE BIRDS A BALLOT",sideB="NO: THEY ALREADY CONTROL THE ROOFS",context="The city is reviewing representation after a pigeon repeatedly won an unopposed rooftop election."},
 {prompt="Should every printer be required to explain its paper jams?",sideA="YES: ACCOUNTABILITY FOR ALL MACHINES",sideB="NO: THE JAM IS A PRIVATE MATTER",context="A printer has jammed during a live council meeting and refuses to provide a statement."},
 {prompt="Should the city replace all queues with a single enormous queue?",sideA="YES: ONE QUEUE TO RULE THEM ALL",sideB="NO: KEEP THE QUEUES SEPARATE",context="The Department of Unnecessary Rules claims one queue would simplify every queue-related process."},
 {prompt="Should the last slice of pizza be decided by public referendum?",sideA="YES: LET THE PEOPLE DECIDE",sideB="NO: THE SLICE HAS ALREADY CHOSEN ME",context="A heated dispute over the final slice has delayed the weekly town hall."},
 {prompt="Should all city announcements be delivered by dramatic trumpet?",sideA="YES: MAKE EVERY UPDATE LEGENDARY",sideB="NO: PLEASE USE A NORMAL VOICE",context="The mayor's new announcement system has caused three false emergencies and one standing ovation."},
 {prompt="Should umbrellas be licensed before they are allowed indoors?",sideA="YES: REGULATE THE DRIP",sideB="NO: LET UMBRELLAS LIVE",context="A suspiciously large umbrella has been accused of blocking the entire recreation zone."},
 {prompt="Should the city introduce a four-day weekend every week?",sideA="YES: THIS IS BASIC CIVIC PROGRESS",sideB="NO: WE WOULD NEVER FINISH THE FORMS",context="The council must decide whether productivity can survive a permanent long weekend."},
}
local function defaultWarState(): any
 local factions={}; for _,f in ipairs(Catalog.Factions) do table.insert(factions,f.id) end
 local weekStart=weekStartTimestamp()
 local semifinalAt=weekStart+2*86400+18*3600; local finalAt=weekStart+4*86400+18*3600
 return {week=weekKey(),territories={},bracket={phase="SEMIFINALS",fixtures={{a=factions[1],b=factions[2],winner=nil},{a=factions[3],b=factions[4],winner=nil}},final=nil,semifinalAt=semifinalAt,finalAt=finalAt,finalSchedule="FRIDAY 18:00 UTC"},lastUpdated=os.time()}
end
local function readBracketState(): (any, boolean)
 local ok,data=pcall(function() return WarStore:GetAsync("week:"..weekKey()) end)
 if ok and type(data)=="table" then
  data.bracket=if type(data.bracket)=="table" then data.bracket else defaultWarState().bracket
  local defaults=defaultWarState().bracket; data.bracket.finalAt=data.bracket.finalAt or defaults.finalAt; data.bracket.semifinalAt=data.bracket.semifinalAt or defaults.semifinalAt; data.bracket.finalSchedule=data.bracket.finalSchedule or defaults.finalSchedule
  data.territories=if type(data.territories)=="table" then data.territories else {}
  return data,true
 end
 if ok then return defaultWarState(),true end
 return defaultWarState(),false
end
local function readFactionScores(): ({[string]: number}, boolean)
 local scores={}
 local ok,pages=pcall(function() return factionScoreStore():GetSortedAsync(false,4) end)
 if not ok or not pages then return scores,false end
 for _,entry in ipairs(pages:GetCurrentPage()) do scores[tostring(entry.key)]=tonumber(entry.value) or 0 end
 for _,f in ipairs(Catalog.Factions) do if scores[f.id]==nil then scores[f.id]=0 end end
 return scores,true
end
local function getWarState(): any
 if warCache and warCache.week==weekKey() and os.clock()-warCacheAt<5 then return warCache end
 local data,bracketAvailable=readBracketState(); local scores,scoresAvailable=readFactionScores(); data.scores=scores; data.bracketAvailable=bracketAvailable; data.scoresAvailable=scoresAvailable; warCache=data; warCacheAt=os.clock(); return data
end
local function saveWar(callback: (any)->())
 local ok,result=pcall(function() return WarStore:UpdateAsync("week:"..weekKey(),function(old)
  local data=if type(old)=="table" then old else defaultWarState(); callback(data); data.week=weekKey(); data.lastUpdated=os.time(); return data
 end) end)
 if not ok then warn("[SocialSystems] War bracket write failed: "..tostring(result)); warCache=nil; return nil end
 warCache=nil; return result
end
local function publicWar(): any
 local data=getWarState(); local rows={}; for _,f in ipairs(Catalog.Factions) do table.insert(rows,{id=f.id,name=f.name,score=tonumber(data.scores and data.scores[f.id]) or 0,territory=(data.territories and data.territories[f.id])==true}) end
 table.sort(rows,function(a,b) return a.score>b.score end)
 return {week=weekKey(),factions=rows,bracket=data.bracket,territories=data.territories or {},trophy=data.trophy,scoresAvailable=data.scoresAvailable==true,bracketAvailable=data.bracketAvailable==true}
end
local function createCase(player: Player, targetUserId: number, rawReason: string): string?
 local reason=filteredText(player,rawReason); if not reason then return nil end
 local caseId="case_"..HttpService:GenerateGUID(false)
 local case={id=caseId,reporter=player.UserId,target=targetUserId,reason=reason,status="OPEN",assignedTo=nil,notes={},appeals={},audit={{actor=player.UserId,action="CASE_CREATED",at=os.time()}},createdAt=os.time(),updatedAt=os.time()}
 local ok,err=pcall(function() CaseStore:SetAsync(caseId,case) end); if not ok then warn("[SocialSystems] Case creation failed: "..tostring(err)); return nil end
 return caseId
end
local function validCaseId(value: any): boolean return type(value)=="string" and #value<=48 and string.sub(value,1,5)=="case_" end
local function getCase(caseId: string): any?
 local ok,data=pcall(function() return CaseStore:GetAsync(caseId) end); return if ok and type(data)=="table" then data else nil
end
local function updateCase(caseId: string, actorId: number, action: string, callback: (any)->boolean): (boolean, any?)
 local operationId=HttpService:GenerateGUID(false)
 local ok,result=pcall(function() return CaseStore:UpdateAsync(caseId,function(old)
  if type(old)~="table" then return nil end
  if not callback(old) then return old end
  old.audit=old.audit or {}; table.insert(old.audit,{id=operationId,actor=actorId,action=action,at=os.time()}); while #old.audit>40 do table.remove(old.audit,1) end
  old.updatedAt=os.time(); return old
 end) end)
 local applied=false
 if ok and type(result)=="table" and type(result.audit)=="table" then for _,entry in ipairs(result.audit) do if entry.id==operationId then applied=true; break end end end
 return ok and applied,result
end
local function pushCaseDashboard(player: Player)
 if not moderator(player) then return end
 local queue={}; -- bounded known case IDs are indexed by MemoryStore for operational review.
 local map=MemoryStoreService:GetSortedMap("PP_ModerationCaseQueue_v1")
 local ok,pages=pcall(function() return map:GetRangeAsync(Enum.SortDirection.Descending,30) end)
 if ok and pages then for _,entry in ipairs(pages) do local case=getCase(tostring(entry.key)); if case then table.insert(queue,case) end end end
 send(player,"StaffDashboard",{cases=queue,available=ok,moderators=Config.ModeratorUserIds or {}})
end
local function queueCase(caseId: string): boolean
 local ok,err=pcall(function() MemoryStoreService:GetSortedMap("PP_ModerationCaseQueue_v1"):SetAsync(caseId,os.time(),7*86400) end)
 if not ok then warn("[SocialSystems] Case queue indexing failed for "..caseId..": "..tostring(err)) end
 return ok
end
local function onPartyAction(player: Player, action: string)
 local snap=getParty(player); if not snap then send(player,"Notice","Create or join a party first."); return end
 local members=partyMembers(player); local key=tostring(snap.partyId); local challenge=activeChallenges[key]
 if action=="StartPartyProtest" then
  if snap.leader~=player.UserId then send(player,"Notice","Only the party leader can start a coordinated protest."); return end
  if #members<2 then send(player,"Notice","Invite at least one other player to your party."); return end
  if challenge and challenge.expiresAt>os.time() then send(player,"Notice","Your party already has an active challenge."); return end
  local clubId=tostring(snap.clubId or snap.partyId); local token=HttpService:GenerateGUID(false)
  local reserved,record=pcall(function() return PartyReputationStore:UpdateAsync(clubId,function(old) local data=if type(old)=="table" then old else {reputation=tonumber(old) or 0,lastChallengeAt=0}; if os.time()-(tonumber(data.lastChallengeAt) or 0)<300 then return data end; data.lastChallengeAt=os.time(); data.lastChallengeToken=token; return data end) end)
  if not reserved or type(record)~="table" or record.lastChallengeToken~=token then send(player,"Notice","Your party protest challenge is on cooldown or persistence is unavailable."); return end
  activeChallenges[key]={expiresAt=os.time()+120,joined={},partyId=key,leader=player.UserId,completed=false}
  for _,member in ipairs(members) do send(member,"PartyChallenge",{title="COORDINATED PROTEST",detail="Gather with your party and join the rally within 2 minutes.",expiresAt=os.time()+120}) end
 elseif action=="JoinPartyProtest" then
  if not challenge or challenge.expiresAt<os.time() or challenge.completed then send(player,"Notice","No active party protest."); return end
  local char=player.Character; local root=char and char:FindFirstChild("HumanoidRootPart"); local leader=Players:GetPlayerByUserId(challenge.leader); local lchar=leader and leader.Character; local lroot=lchar and lchar:FindFirstChild("HumanoidRootPart")
  if not root or not lroot or (root.Position-lroot.Position).Magnitude>70 then send(player,"Notice","Move within 70 studs of your party leader."); return end
  challenge.joined[player.UserId]=true
  local joined=0; for _,member in ipairs(members) do if challenge.joined[member.UserId] then joined+=1 end end
  send(player,"Notice","You joined the coordinated protest ("..joined.."/"..#members.." party members).")
  if joined>=#members and not challenge.completed then
   challenge.completed=true; activeChallenges[key]=nil
   for _,member in ipairs(members) do
    local ok,data=mutateIdentity(member.UserId,function(profile) profile.reputation=math.min(100000,(tonumber(profile.reputation) or 0)+5); if not table.find(profile.achievements,"coordinated_protest") then table.insert(profile.achievements,"coordinated_protest") end; if member.UserId==snap.leader and not table.find(profile.badges,"party_captain") then table.insert(profile.badges,"party_captain"); if not table.find(profile.achievements,"party_captain") then table.insert(profile.achievements,"party_captain") end end; addHistory(profile,"Coordinated party protest",5) end)
    if ok then send(member,"PartyAchievement",{name="THE POWER OF NO",reputation=5}) end
   end
   local clubId=tostring(snap.clubId or snap.partyId); local clubOk,clubValue=pcall(function() return PartyReputationStore:UpdateAsync(clubId,function(old) local data=if type(old)=="table" then old else {reputation=tonumber(old) or 0,lastChallengeAt=0}; data.reputation=(tonumber(data.reputation) or 0)+5; return data end) end)
   local faction=player:GetAttribute("FactionId"); if type(faction)=="string" and Catalog.GetFaction(faction) then local scoreOk,scoreErr=pcall(function() factionScoreStore():IncrementAsync(faction,10) end); if not scoreOk then warn("[SocialSystems] Party faction score failed: "..tostring(scoreErr)) end; warCache=nil end
   stateRemote:FireAllClients({kind="WorldNotice",text="A coordinated protest has shaken the plaza. The factions are watching. Party reputation: "..tostring(if clubOk and type(clubValue)=="table" then clubValue.reputation else "unavailable")})
  end
 end
end
local function awardBadge(userId: number, badgeId: string, title: string, reputation: number)
 local cached=identityCache[userId]; if cached and table.find(cached.badges,badgeId) then return end
 mutateIdentity(userId,function(profile)
  if table.find(profile.badges,badgeId) then return end
  profile.reputation=math.min(100000,(tonumber(profile.reputation) or 0)+reputation)
  table.insert(profile.badges,badgeId)
  if not table.find(profile.achievements,title) then table.insert(profile.achievements,title) end
  addHistory(profile,title,reputation)
 end)
end
function Service.RefreshTournamentSchedule(): boolean
 local snapshot=getWarState(); local bracket=snapshot.bracket or defaultWarState().bracket
 if snapshot.bracketAvailable~=true or snapshot.scoresAvailable~=true or bracket.phase~="SEMIFINALS" then return false end
 local day=utcDay(); local hour=tonumber(os.date("!%H")) or 0
 if not (day>3 or (day==3 and hour>=18)) then return false end
 local winners={}
 for _,fixture in ipairs(bracket.fixtures or {}) do table.insert(winners,if (snapshot.scores[fixture.a] or 0)>=(snapshot.scores[fixture.b] or 0) then fixture.a else fixture.b) end
 if #winners~=2 then return false end
 local saved=saveWar(function(data)
  data.bracket=data.bracket or defaultWarState().bracket
  if data.bracket.phase=="SEMIFINALS" then
   for index,fixture in ipairs(data.bracket.fixtures or {}) do fixture.winner=winners[index] end
   data.bracket.phase="FINAL"; data.bracket.final={a=winners[1],b=winners[2],winner=nil}
  end
 end)
 return saved~=nil
end
local function broadcastGlobalEventResult(eventData: any)
 if type(eventData)~="table" or not eventData.eventId then return end
 local marker=MemoryStoreService:GetHashMap("PP_GlobalEventMarkers_v1"); local token=HttpService:GenerateGUID(false); local key="broadcast:"..eventData.eventId
 local claimed,result=pcall(function() return marker:UpdateAsync(key,function(old) if old then return old end; return token end,24*3600) end)
 if not claimed or result~=token then return end
 local mvpPlayer=eventData.mvpUserId and Players:GetPlayerByUserId(eventData.mvpUserId)
 local message={eventId=eventData.eventId,winner=eventData.result,mvpUserId=eventData.mvpUserId,mvpName=if mvpPlayer then mvpPlayer.DisplayName else "Audience MVP",topic=eventData.topic,debateId=eventData.debateId}
 stateRemote:FireAllClients({kind="ChampionshipBroadcast",data=message})
 local published=false
 for attempt=1,3 do published=pcall(function() MessagingService:PublishAsync("PP_GlobalDebateBroadcast_v1",message) end); if published then break end; task.wait(2) end
 if not published then pcall(function() marker:RemoveAsync(key) end); warn("[SocialSystems] Global debate result saved but cross-server broadcast could not be delivered for "..tostring(eventData.eventId)) end
end
local function recordGlobalEventResult(event: any, debateWinner: string?, debateMVPUserId: number?, topicPrompt: string?, debateId: string?, debateParticipants: {[number]: string}?): any?
 if debateWinner~="A" and debateWinner~="B" and debateWinner~="TIE" then return nil end
 if os.time()<event.startsAt or os.time()>event.endsAt+600 then
  local readOk,existing=pcall(function() return PredictionMap:GetAsync(event.id) end)
  if readOk and type(existing)=="table" and existing.result then existing.eventId=event.id; task.spawn(broadcastGlobalEventResult,existing); return existing end
  return nil
 end
 local marker=MemoryStoreService:GetHashMap("PP_GlobalEventMarkers_v1"); local token=HttpService:GenerateGUID(false)
 local claimed,result=pcall(function() return marker:UpdateAsync("result:"..event.id,function(old) if old then return old end; return token end,24*3600) end)
 if not claimed then return nil end
 local eventData=nil
 if result==token then
  local saved,updated=pcall(function() return PredictionMap:UpdateAsync(event.id,function(old)
   local data=if type(old)=="table" then old else {votes={}}
   data.votes=data.votes or {}; local excluded=0
   for userId in pairs(debateParticipants or {}) do if data.votes[tostring(userId)] then data.votes[tostring(userId)]=nil; excluded+=1 end end
   data.A=0; data.B=0; for _,side in pairs(data.votes) do if side=="A" then data.A+=1 elseif side=="B" then data.B+=1 end end
   data.excludedParticipants=excluded
   data.result=debateWinner; data.resultAt=os.time(); data.mvpUserId=debateMVPUserId; data.topic=topicPrompt or "A global debate concluded."; data.debateId=debateId
   return data
  end,24*3600) end)
  if not saved then pcall(function() marker:RemoveAsync("result:"..event.id) end); return nil end
  eventData=updated
 else
  for attempt=1,3 do
   local readOk,existing=pcall(function() return PredictionMap:GetAsync(event.id) end)
   if readOk and type(existing)=="table" and existing.result then eventData=existing; break end
   task.wait(.25)
  end
 end
 if eventData then eventData.eventId=event.id; task.spawn(broadcastGlobalEventResult,eventData) end
 return eventData
end
function Service.OnRoundResults(factionPoints: {[string]: number}, debateMVPUserId: number?, debateWinner: string?, topicPrompt: string?, debateId: string?, debateParticipants: {[number]: string}?)
 for faction,points in pairs(factionPoints) do
  if type(faction)=="string" and Catalog.GetFaction(faction) and type(points)=="number" and points>0 then
   local scoreOk,scoreErr=pcall(function() factionScoreStore():IncrementAsync(faction,math.clamp(math.floor(points),0,100)) end)
   if not scoreOk then warn("[SocialSystems] Faction score failed for "..faction..": "..tostring(scoreErr)) end
  end
 end
 warCache=nil
 Service.RefreshTournamentSchedule()
 local event=currentEvent(); local eventResult=recordGlobalEventResult(event,debateWinner,debateMVPUserId,topicPrompt,debateId,debateParticipants)
 if eventResult and type(eventResult.votes)=="table" and (eventResult.result=="A" or eventResult.result=="B") then for _,candidate in ipairs(Players:GetPlayers()) do if eventResult.votes[tostring(candidate.UserId)]==eventResult.result then task.spawn(awardBadge,candidate.UserId,"oracle_predictor","Civic Oracle",3) end end end
 local snapshot=getWarState(); local bracket=snapshot.bracket or defaultWarState().bracket
 local day=utcDay(); local hour=tonumber(os.date("!%H")) or 0
 local finalDue=(day>5 or (day==5 and hour>=18))
 if snapshot.bracketAvailable==true and finalDue and bracket.phase=="FINAL" and bracket.final and debateId=="factionfinal:"..weekKey() and eventResult and eventResult.debateId=="factionfinal:"..weekKey() then
  local finalistA,finalistB=bracket.final.a,bracket.final.b
  local canonicalWinner=eventResult.result
  local finalWinner=if canonicalWinner=="A" then finalistA elseif canonicalWinner=="B" then finalistB elseif snapshot.scoresAvailable and (snapshot.scores[finalistA] or 0)>=(snapshot.scores[finalistB] or 0) then finalistA elseif snapshot.scoresAvailable then finalistB else nil
  if finalWinner then saveWar(function(data)
   data.bracket=data.bracket or defaultWarState().bracket
   if data.bracket.phase=="FINAL" and data.bracket.final then data.bracket.final.winner=finalWinner; data.bracket.phase="COMPLETE"; data.territories={}; data.territories[finalWinner]=true; data.trophy={faction=finalWinner,week=weekKey(),awardedAt=os.time(),finalDebateId=debateId,eventId=event.id} end
  end) end
 end
 if debateMVPUserId then awardBadge(debateMVPUserId,"audience_mvp","Audience MVP",10) end
 local war=publicWar(); stateRemote:FireAllClients({kind="FactionWarUpdate",data=war})
 if war.bracket and war.bracket.phase=="COMPLETE" and war.bracket.final and war.bracket.final.winner then
  local winner=war.bracket.final.winner; local winnerFaction=Catalog.GetFaction(winner); local winnerName=if winnerFaction then winnerFaction.name else winner
  for _,p in ipairs(Players:GetPlayers()) do if p:GetAttribute("FactionId")==winner then awardBadge(p.UserId,"faction_champion","Faction Champion",15) end end
  local marker=MemoryStoreService:GetHashMap("PP_GlobalEventMarkers_v1"); local token=HttpService:GenerateGUID(false)
  local claimed,claimResult=pcall(function() return marker:UpdateAsync("faction:"..war.week,function(old) if old then return old end; return token end,14*86400) end)
  if claimed and claimResult==token then
   stateRemote:FireAllClients({kind="ChampionshipBroadcast",data={title="FACTION WAR CHAMPIONS",winner=winnerName,trophy=war.trophy}})
   local published=pcall(function() MessagingService:PublishAsync("PP_SocialWorldUpdate_v1",{kind="TERRITORY",week=war.week,winner=winnerName}) end)
   if not published then pcall(function() marker:RemoveAsync("faction:"..war.week) end) end
  end
 end
 Service.ApplyWorldEvolution()
end
function Service.GetWarState(): any
 Service.RefreshTournamentSchedule()
 return publicWar()
end
function Service.GetEventPreview(): any
 Service.RefreshTournamentSchedule()
 local event=currentEvent(); local war=publicWar(); local bracket=war.bracket
 local finalIsScheduled=bracket and bracket.phase=="FINAL" and bracket.final and bracket.finalAt and event.startsAt>=bracket.finalAt and war.bracketAvailable
 local finalAlreadyPlayed=bracket and bracket.phase=="COMPLETE" and bracket.final and war.trophy and war.trophy.eventId==event.id
 if bracket and bracket.final and (finalIsScheduled or finalAlreadyPlayed) and war.bracketAvailable then
  local finalistA,finalistB=bracket.final.a,bracket.final.b
  local factionA=finalistA and Catalog.GetFaction(finalistA); local factionB=finalistB and Catalog.GetFaction(finalistB)
  if factionA and factionB then return {id="factionfinal:"..weekKey(),prompt="Which faction deserves control of the plaza this week?",sideA=factionA.name,sideB=factionB.name,context="The semifinal winners face off in the scheduled Faction War final. The winning side claims the plaza territory and the weekly trophy.",category="Faction War Final",eventId=event.id} end
 end
 local dayOfYear=tonumber(os.date("!%j",event.startsAt)) or 1; local topic=SCHEDULED_DEBATES[((dayOfYear-1)%#SCHEDULED_DEBATES)+1]
 return {id=event.id,prompt=topic.prompt,sideA=topic.sideA,sideB=topic.sideB,context=topic.context,category="Global Event"}
end
function Service.GetScheduledDebate(): any?
 local event=currentEvent(); local now=os.time()
 if now<event.startsAt or now>event.endsAt then return nil end
 return Service.GetEventPreview()
end
function Service.ApplyWorldEvolution()
 local war=publicWar(); if not war.bracketAvailable then return end; local folder=workspace:FindFirstChild("ProtestPartyWorld"); if not folder then return end
 local owner=nil; for _,f in ipairs(war.factions) do if f.territory then owner=f.id end end
 local plaza=folder:FindFirstChild("PlazaTerritoryBanner")
 if not plaza then local p=Instance.new("Part"); p.Name="PlazaTerritoryBanner"; p.Anchored=true; p.CanCollide=false; p.CanTouch=false; p.Size=Vector3.new(18,.5,2); p.Position=Vector3.new(0,9,-71); p.Material=Enum.Material.Neon; p.Parent=folder; plaza=p end
 local factionColors={pigeon_union=Color3.fromRGB(160,160,170),printer_resistance=Color3.fromRGB(120,170,255),bureaucracy=Color3.fromRGB(190,150,90),snack_council=Color3.fromRGB(255,145,100)}
 if plaza:IsA("BasePart") then plaza.Color=if owner then factionColors[owner] or Config.UI.Accent else Config.UI.Accent end end
 local bannerGui=plaza:FindFirstChild("TerritoryLabel")
 if not bannerGui then local g=Instance.new("BillboardGui"); g.Name="TerritoryLabel"; g.Size=UDim2.fromOffset(300,46); g.StudsOffset=Vector3.new(0,2.5,0); g.AlwaysOnTop=true; g.MaxDistance=260; g.Parent=plaza; bannerGui=g; local l=Instance.new("TextLabel"); l.Name="Label"; l.Size=UDim2.fromScale(1,1); l.BackgroundTransparency=1; l.TextColor3=Color3.fromRGB(245,247,250); l.TextStrokeTransparency=.4; l.Font=Enum.Font.GothamBlack; l.TextScaled=true; l.Parent=g end
 local bannerText=bannerGui and bannerGui:FindFirstChild("Label"); if bannerText and bannerText:IsA("TextLabel") then bannerText.Text=if owner then string.upper(ownerName).." TERRITORY" else "UNCLAIMED PLAZA" end
 for i,f in ipairs(Catalog.Factions) do
  local flagName="TerritoryFlag_"..f.id; local flag=folder:FindFirstChild(flagName)
  if not flag then local p=Instance.new("Part"); p.Name=flagName; p.Size=Vector3.new(5,.4,1); p.Position=Vector3.new(-104+(i-1)*69,7,-120); p.Anchored=true; p.CanCollide=false; p.CanTouch=false; p.Parent=folder; flag=p end
  if flag:IsA("BasePart") then flag.Color=factionColors[f.id] or Config.UI.Accent; flag.Transparency=if owner==f.id then 0 else .72 end end
 end
 local trophy=folder:FindFirstChild("FactionWarTrophy")
 if not trophy then local t=Instance.new("Part"); t.Name="FactionWarTrophy"; t.Size=Vector3.new(2,5,2); t.Position=Vector3.new(0,3,-82); t.Anchored=true; t.CanCollide=false; t.CanTouch=false; t.Material=Enum.Material.Metal; t.Color=Color3.fromRGB(245,204,85); t.Parent=folder; trophy=t end
 if trophy:IsA("BasePart") then trophy.Transparency=if owner then 0 else 0.55 end
 local trophyGui=trophy:FindFirstChild("CupLabel")
 if not trophyGui then local g=Instance.new("BillboardGui"); g.Name="CupLabel"; g.Size=UDim2.fromOffset(220,54); g.StudsOffset=Vector3.new(0,3,0); g.AlwaysOnTop=true; g.Parent=trophy; trophyGui=g; local l=Instance.new("TextLabel"); l.Name="Label"; l.Size=UDim2.fromScale(1,1); l.BackgroundTransparency=1; l.TextColor3=Color3.fromRGB(255,230,150); l.Font=Enum.Font.GothamBlack; l.TextScaled=true; l.Parent=g end
 local trophyText=trophyGui and trophyGui:FindFirstChild("Label"); if trophyText and trophyText:IsA("TextLabel") then trophyText.Text=if owner then string.upper(ownerName).." WAR CHAMPIONS" else "FACTION WAR" end
 for _,npc in ipairs(folder:GetChildren()) do
  if string.sub(npc.Name,1,4)=="NPC_" then local head=npc:FindFirstChild("Head"); local gui=head and head:FindFirstChild("WorldLabel"); local subtitle=gui and gui:FindFirstChild("Subtitle"); if subtitle and subtitle:IsA("TextLabel") then npc:SetAttribute("TerritoryDialogue",if owner then "The "..tostring(owner).." faction currently holds the plaza." else "The plaza is awaiting its next champion." end) end end
 end
end
local function applyOverheadTitle(player: Player, title: string)
 local character=player.Character; local head=character and character:FindFirstChild("Head")
 if not head or not head:IsA("BasePart") then return end
 local old=head:FindFirstChild("SocialTitle"); if old then old:Destroy() end
 if title=="New Voice" then return end
 local gui=Instance.new("BillboardGui"); gui.Name="SocialTitle"; gui.Size=UDim2.fromOffset(180,28); gui.StudsOffset=Vector3.new(0,2.8,0); gui.AlwaysOnTop=true; gui.MaxDistance=65; gui.Parent=head
 local label=Instance.new("TextLabel"); label.Size=UDim2.fromScale(1,1); label.BackgroundTransparency=1; label.Text=string.upper(title); label.TextColor3=Config.UI.Accent; label.TextStrokeTransparency=.45; label.Font=Enum.Font.GothamBold; label.TextScaled=true; label.Parent=gui
end
function Service.Start(socialRemote: RemoteEvent, state: RemoteEvent, parties: any)
 remote=socialRemote; stateRemote=state; partyService=parties
 remote.OnServerEvent:Connect(function(player,action,value,extra)
  if type(action)~="string" or not valid(player) or not throttle(player,"social",0.45) then return end
  if action=="GetIdentity" then
   local target=player.UserId; if type(value)=="number" and value==value and value>=1 and value<=9007199254740991 then target=math.floor(value) end
   local profile=identity(target); local p=Players:GetPlayerByUserId(target)
   send(player,"PublicProfile",{userId=target,name=if p then p.DisplayName else "Player "..target,title=profile.title,bio=profile.bio,badges=profile.badges,achievements=profile.achievements,reputation=profile.reputation,history=profile.history})
  elseif action=="SetTitle" then
   if not throttle(player,"title",2) then return end
   local title=safeString(value,32); if not title then return end
   local profile=identity(player.UserId); local titleBadges={ ["New Voice"]=nil,["Audience MVP"]="audience_mvp",["Party Captain"]="party_captain",["Faction Champion"]="faction_champion",["Civic Oracle"]="oracle_predictor" }
   local required=titleBadges[title]
   if titleBadges[title]==nil and title~="New Voice" or (required and not table.find(profile.badges,required)) then send(player,"Notice","That title has not been unlocked."); return end
   local ok=mutateIdentity(player.UserId,function(data) data.title=title end); if ok then applyOverheadTitle(player,title) end; send(player,"Notice",if ok then "Title updated." else "Could not save title.")
  elseif action=="StartPartyProtest" or action=="JoinPartyProtest" then onPartyAction(player,action)
  elseif action=="GetWar" then send(player,"FactionWar",publicWar())
  elseif action=="GetParty" then
   if not throttle(player,"party_read",3) then return end
   local snap=getParty(player); if not snap then send(player,"Notice","You are not in a party."); return end
   local ok,record=pcall(function() return PartyReputationStore:GetAsync(tostring(snap.clubId or snap.partyId)) end)
   local reputation=if ok and type(record)=="table" then tonumber(record.reputation) or 0 elseif ok then tonumber(record) or 0 else 0
   send(player,"PartySummary",{party=snap,reputation=reputation,available=ok})
  elseif action=="SetBio" then
   if not throttle(player,"bio",30) then send(player,"Notice","Please wait before changing your bio again."); return end
   local bio=safeString(value,100); if not bio then return end
   local filtered=filteredText(player,bio); if not filtered then send(player,"Notice","Bio was rejected by text filtering."); return end
   local ok=mutateIdentity(player.UserId,function(profile) profile.bio=filtered end); send(player,"Notice",if ok then "Profile bio updated." else "Could not save bio.")
  elseif action=="GetEvent" then
   if not throttle(player,"event_read",5) then return end
   local event=currentEvent(); local ok,predictions=pcall(function() return PredictionMap:GetAsync(event.id) end)
   local summary={A=0,B=0,result=nil,myPrediction=nil}
   if ok and type(predictions)=="table" then summary.A=tonumber(predictions.A) or 0; summary.B=tonumber(predictions.B) or 0; summary.result=predictions.result; if type(predictions.votes)=="table" then summary.myPrediction=predictions.votes[tostring(player.UserId)] end end
   send(player,"GlobalEvent",{event=event,debate=Service.GetEventPreview(),predictions=summary,predictionsAvailable=ok})
  elseif action=="Predict" then
   local event=currentEvent(); if os.time()>=event.predictionClosesAt or (value~="A" and value~="B") then send(player,"Notice","Predictions are closed or the selection is invalid."); return end
   local markerKey="vote:"..event.id..":"..tostring(player.UserId); local token=HttpService:GenerateGUID(false)
   local claimed,claimResult=pcall(function() return PredictionMap:UpdateAsync(markerKey,function(old) if old then return old end; return token end,24*3600) end)
   if not claimed or claimResult~=token then send(player,"Notice","You have already submitted a prediction for this event."); return end
   local ok,updated=pcall(function() return PredictionMap:UpdateAsync(event.id,function(old) local data=if type(old)=="table" then old else {votes={}}; data.votes=data.votes or {}; local count=0; for _ in pairs(data.votes) do count+=1 end; if data.votes[tostring(player.UserId)] or count>=300 then return data end; data.votes[tostring(player.UserId)]=value; data.A=0; data.B=0; for _,side in pairs(data.votes) do if side=="A" then data.A+=1 elseif side=="B" then data.B+=1 end end; return data end,24*3600) end)
   local accepted=ok and type(updated)=="table" and type(updated.votes)=="table" and updated.votes[tostring(player.UserId)]==value
   if not accepted then pcall(function() PredictionMap:RemoveAsync(markerKey) end) end
   send(player,"Notice",if accepted then "Prediction recorded." elseif ok then "The event prediction limit has been reached." else "Prediction service is temporarily unavailable.")
  elseif action=="ReportPlayer" then
   if not throttle(player,"report",20) then send(player,"Notice","Please wait before submitting another report."); return end
   local target=tonumber(value); local reason=safeString(extra,MAX_REASON); if not target or target<=0 or target%1~=0 or target==math.huge or target==-math.huge or target==player.UserId or not reason then return end
   local caseId=createCase(player,math.floor(target),reason); if caseId then local queued=queueCase(caseId); send(player,"Notice",if queued then "Report submitted. Case "..caseId else "Report saved but staff queue indexing is delayed. Save case ID: "..caseId) else send(player,"Notice","Report could not be submitted.") end
  elseif action=="GetStaffDashboard" then if moderator(player) and throttle(player,"staff_read",5) then pushCaseDashboard(player) end
  elseif action=="AssignCase" then
   if not throttle(player,"case_action",2) then return end
   if not moderator(player) or not validCaseId(value) or type(extra)~="number" or extra~=extra or extra<1 or extra>9007199254740991 or extra%1~=0 then return end
   local allowedAssignee=false; for _,uid in ipairs(Config.ModeratorUserIds or {}) do if uid==math.floor(extra) then allowedAssignee=true end end; if not allowedAssignee then return end
   local ok=updateCase(value,player.UserId,"ASSIGNED",function(case) if case.status=="RESOLVED" or case.status=="APPEAL_ACCEPTED" or case.status=="APPEAL_REJECTED" then return false end; case.assignedTo=math.floor(extra); if case.status=="OPEN" then case.status="IN_REVIEW" end; table.insert(case.notes,{by=player.UserId,text="Case assigned",at=os.time()}); return true end); send(player,"Notice",if ok then "Case assigned." else "Assignment failed."); pushCaseDashboard(player)
  elseif action=="AddCaseNote" then
   if not throttle(player,"case_action",2) then return end
   local note=safeString(extra,MAX_NOTE); if not moderator(player) or not validCaseId(value) or not note then return end
   local filtered=filteredText(player,note); if not filtered then return end
   local ok=updateCase(value,player.UserId,"NOTE_ADDED",function(case) table.insert(case.notes,{by=player.UserId,text=filtered,at=os.time()}); while #case.notes>30 do table.remove(case.notes,1) end; return true end); send(player,"Notice",if ok then "Internal note saved." else "Note could not be saved."); pushCaseDashboard(player)
  elseif action=="ResolveCase" then
   if not throttle(player,"case_action",2) then return end
   if not moderator(player) or not validCaseId(value) then return end
   local ok=updateCase(value,player.UserId,"RESOLVED",function(case) if case.status~="OPEN" and case.status~="IN_REVIEW" then return false end; case.status="RESOLVED"; case.resolvedBy=player.UserId; case.resolvedAt=os.time(); return true end); send(player,"Notice",if ok then "Case resolved." else "Resolution failed."); pushCaseDashboard(player)
  elseif action=="DecideAppeal" then
   if not throttle(player,"case_action",2) then return end
   if not moderator(player) or not validCaseId(value) or type(extra)~="boolean" then return end
   local ok=updateCase(value,player.UserId,if extra then "APPEAL_ACCEPTED" else "APPEAL_REJECTED",function(case) if case.status~="APPEALED" then return false end; case.status=if extra then "APPEAL_ACCEPTED" else "APPEAL_REJECTED"; case.appealDecisionBy=player.UserId; case.appealDecisionAt=os.time(); local last=case.appeals and case.appeals[#case.appeals]; if last then last.status=if extra then "ACCEPTED" else "REJECTED" end; return true end); send(player,"Notice",if ok then "Appeal decision saved." else "Appeal decision failed."); pushCaseDashboard(player)
  elseif action=="AppealCase" then
   if not throttle(player,"appeal",10) then return end
   local appeal=safeString(extra,MAX_REASON); if not validCaseId(value) or not appeal then return end
   local filtered=filteredText(player,appeal); if not filtered then return end
   local ok=updateCase(value,player.UserId,"APPEAL_SUBMITTED",function(case) if case.target~=player.UserId or case.status~="RESOLVED" then return false end; case.appeals=case.appeals or {}; table.insert(case.appeals,{by=player.UserId,text=filtered,at=os.time(),status="OPEN"}); case.status="APPEALED"; return true end); local queued=if ok then queueCase(value) else false; send(player,"Notice",if ok and queued then "Appeal submitted for staff review." elseif ok then "Appeal saved but staff queue indexing is delayed." else "Appeal could not be submitted.")
  end
 end)
 local boundPlayers: {[number]: boolean} = {}
 local function bindPlayer(player: Player)
  if boundPlayers[player.UserId] then return end; boundPlayers[player.UserId]=true
  task.spawn(function()
   local deadline=os.clock()+120
   while player.Parent==Players and not valid(player) and os.clock()<deadline do task.wait(.5) end
   if not valid(player) then boundPlayers[player.UserId]=nil; return end
   local profile=identity(player.UserId)
   send(player,"IdentitySummary",{title=profile.title,reputation=profile.reputation,badges=profile.badges})
   send(player,"GlobalEvent",{event=currentEvent(),debate=Service.GetEventPreview()})
   for offset=0,1 do
    local eventDate=os.date("!%Y%m%d",os.time()-offset*86400); local eventId="global:"..eventDate
    local eventOk,eventData=pcall(function() return PredictionMap:GetAsync(eventId) end)
    if eventOk and type(eventData)=="table" and eventData.result and eventData.votes and eventData.votes[tostring(player.UserId)]==eventData.result then task.spawn(awardBadge,player.UserId,"oracle_predictor","Civic Oracle",3) end
   end
   if player.Character then applyOverheadTitle(player,profile.title) end
   player.CharacterAdded:Connect(function() task.wait(.5); local latest=identity(player.UserId); applyOverheadTitle(player,latest.title) end)
  end)
 end
 Players.PlayerAdded:Connect(bindPlayer)
 Players.PlayerRemoving:Connect(function(player) boundPlayers[player.UserId]=nil; identityCache[player.UserId]=nil; identityCacheAt[player.UserId]=nil; for key in pairs(requestAt) do if string.find(key,":"..player.UserId,1,true) then requestAt[key]=nil end end end)
 for _,player in ipairs(Players:GetPlayers()) do bindPlayer(player) end
 pcall(function() MessagingService:SubscribeAsync("PP_SocialWorldUpdate_v1",function(message)
  local data=message.Data
  task.spawn(function()
   warCache=nil; Service.ApplyWorldEvolution(); stateRemote:FireAllClients({kind="FactionWarUpdate",data=publicWar()})
   if type(data)=="table" and data.kind=="TERRITORY" then
    stateRemote:FireAllClients({kind="ChampionshipBroadcast",data={title="FACTION WAR CHAMPIONS",winner=data.winner}})
    stateRemote:FireAllClients({kind="WorldNotice",text="The plaza territory has changed across the city."})
   end
  end)
 end) end)
 pcall(function() MessagingService:SubscribeAsync("PP_GlobalDebateBroadcast_v1",function(message)
  local data=message.Data
  if type(data)=="table" and data.eventId and (data.winner=="A" or data.winner=="B") then
   task.spawn(function()
    local ok,eventData=pcall(function() return PredictionMap:GetAsync(data.eventId) end)
    if ok and type(eventData)=="table" and type(eventData.votes)=="table" then
     for _,candidate in ipairs(Players:GetPlayers()) do if eventData.votes[tostring(candidate.UserId)]==data.winner then task.spawn(awardBadge,candidate.UserId,"oracle_predictor","Civic Oracle",3) end end
    end
   end)
  end
  stateRemote:FireAllClients({kind="ChampionshipBroadcast",data=data})
 end) end)
 task.spawn(function()
  while true do for key,challenge in pairs(activeChallenges) do if challenge.expiresAt<os.time() then activeChallenges[key]=nil end end; task.wait(30) end
 end)
 task.spawn(function()
  while true do Service.RefreshTournamentSchedule(); task.wait(30) end
 end)
 task.spawn(function()
  local announced={}
  while true do
   local event=currentEvent()
   if os.time()>=event.startsAt and os.time()<event.endsAt and not announced[event.id] then
    announced[event.id]=true
    local marker=MemoryStoreService:GetHashMap("PP_GlobalEventMarkers_v1")
    local token=HttpService:GenerateGUID(false)
    local ok,result=pcall(function() return marker:UpdateAsync("start:"..event.id,function(old) if old then return old end; return token end,3*3600) end)
    if not ok then announced[event.id]=nil elseif result==token then local published=pcall(function() MessagingService:PublishAsync("PP_GlobalDebateBroadcast_v1",{eventId=event.id,announcement=true,title=event.title,startsAt=event.startsAt}) end); if not published then pcall(function() marker:RemoveAsync("start:"..event.id) end); announced[event.id]=nil end end
   end
   task.wait(15)
  end
 end)
 Service.ApplyWorldEvolution()
end
return Service
