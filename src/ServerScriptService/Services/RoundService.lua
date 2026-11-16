--!strict
-- Server-authoritative round, town-hall, shop, faction and daily challenge orchestration.
local Players=game:GetService("Players")
local Workspace=game:GetService("Workspace")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Shared=ReplicatedStorage:WaitForChild("Shared")
local Config=require(Shared:WaitForChild("GameConfig"))
local Catalog=require(Shared:WaitForChild("ContentCatalog"))
local WorldBuilder=require(script.Parent:WaitForChild("WorldBuilder"))
local DebateCommunityService=require(script.Parent:WaitForChild("DebateCommunityService"))
local WeeklyChampionshipService=require(script.Parent:WaitForChild("WeeklyChampionshipService"))
local RoundService={}
local Profiles: any; local StateRemote: RemoteEvent; local VoteRemote: RemoteEvent; local DebateRemote: RemoteEvent
local state: any={phase="Starting",endsAt=Workspace:GetServerTimeNow()+5}
local options={}; local cause:any=nil; local debate:any=nil
local votes:{[number]:string}={}; local debateVotes:{[number]:string}={}; local hallVotes:{[number]:string}={}; local reactionScores:{[number]:number}={}; local reactionCounts:any={clap=0,laugh=0,sideeye=0}
local hype:{[number]:number}={}; local chantActions:{[number]:number}={}; local lastChant:{[number]:number}={}; local requestAt:{[any]:number}={}
local worldData:any
local activeTownHallRule:any=nil
local factionAlliance:{[string]:string}={}
local allianceNames:{[string]:string}={}
local random=Random.new()
local function now() return Workspace:GetServerTimeNow() end
local function utcDate() return os.date("!%Y-%m-%d") end
local function dailyChallenge(): any
 local day=os.date("!*t").yday
 return Catalog.DailyChallenges[((day-1)%#Catalog.DailyChallenges)+1]
end
local function dailyPayload(player: Player): any
 local d=dailyChallenge(); local profile=Profiles.GetDaily(player,d.id,utcDate())
 return {id=d.id,title=d.title,detail=d.detail,target=d.target,progress=profile and profile.progress or 0,claimed=profile and profile.claimed or false,coins=d.coins,xp=d.xp}
end
local function countMap(source:any, allowed:{string}):any
 local counts={}; for _,id in ipairs(allowed) do counts[id]=0 end
 for _,value in pairs(source) do if counts[value]~=nil then counts[value]+=1 end end
 return counts
end
local function hallCounts() return countMap(hallVotes,{"A","B","C"}) end
local function sendProfile(player: Player)
 local data=Profiles.GetData(player); if not data then return end
 StateRemote:FireClient(player,{kind="Profile",coins=data.Coins,xp=data.XP,level=data.Level,daily=dailyPayload(player),equipped=data.EquippedCosmetic,owned=data.OwnedCosmetics})
 StateRemote:FireClient(player,state)
end
local function publish(phase:string,duration:number,extra:any?)
 state={kind="Phase",phase=phase,endsAt=now()+duration,season=Catalog.GetSeason().name,cause=if cause then {id=cause.id,title=cause.title,shortTitle=cause.shortTitle} else nil}
 if type(extra)=="table" then for k,v in pairs(extra) do state[k]=v end end
 StateRemote:FireAllClients(state)
end
local function validPlayer(player:Player):boolean return player.Parent==Players and Profiles.IsLoaded(player) end
local function proximity(player:Player, instance:Instance, maxDistance:number):boolean
 local char=player.Character; local root=char and char:FindFirstChild("HumanoidRootPart")
 return root~=nil and root:IsA("BasePart") and instance:IsA("BasePart") and (root.Position-instance.Position).Magnitude<=maxDistance
end
local function dailyProgress(player:Player,kind:string,amount:number)
 local d=dailyChallenge(); if d.kind~=kind then return end
 local progress,changed=Profiles.ProgressDaily(player,kind,amount,d.id,utcDate())
 if changed then StateRemote:FireClient(player,{kind="DailyProgress",daily=dailyPayload(player)}) end
end
local function onCauseVote(player:Player,id:any)
 if state.phase~="Voting" or not validPlayer(player) or type(id)~="string" or #id>48 then return end
 local t=os.clock(); if requestAt[player.UserId] and t-requestAt[player.UserId]<.35 then return end; requestAt[player.UserId]=t
 for _,item in ipairs(options) do if item.id==id then votes[player.UserId]=id; state.voteCounts=countMap(votes,(function() local a={} for _,o in ipairs(options) do table.insert(a,o.id) end return a end)()); StateRemote:FireAllClients(state); return end end
end
local function onDebateVote(player:Player,side:any)
 if state.phase~="Debate" or not validPlayer(player) or (side~="A" and side~="B") then return end
 local t=os.clock(); if requestAt[player.UserId] and t-requestAt[player.UserId]<.45 then return end; requestAt[player.UserId]=t
 debateVotes[player.UserId]=side; state.debateCounts=countMap(debateVotes,{"A","B"}); StateRemote:FireAllClients(state)
end
local function onTownHallVote(player:Player,side:string)
 if state.phase~="TownHall" or not validPlayer(player) or (side~="A" and side~="B" and side~="C") then return end
 local t=os.clock(); if requestAt[player.UserId] and t-requestAt[player.UserId]<.5 then return end; requestAt[player.UserId]=t
 hallVotes[player.UserId]=side; state.townHallCounts=hallCounts(); StateRemote:FireAllClients(state)
end
local function createAlliances(): any
 local ids={}; for _,f in ipairs(Catalog.Factions) do table.insert(ids,f.id) end
 for i=#ids,2,-1 do local j=random:NextInteger(1,i); ids[i],ids[j]=ids[j],ids[i] end
 factionAlliance={A="A",B="A",C="B",D="B"}; allianceNames={A="THE CRUMB COALITION",B="THE PAPERWORK PACT"}
 factionAlliance[ids[1]]="A"; factionAlliance[ids[2]]="A"; factionAlliance[ids[3]]="B"; factionAlliance[ids[4]]="B"
 return {{id="A",name=allianceNames.A,factions={ids[1],ids[2]}},{id="B",name=allianceNames.B,factions={ids[3],ids[4]}}}
end

local function chooseCause():any
 local counts={}; for _,o in ipairs(options) do counts[o.id]=0 end
 for _,id in pairs(votes) do if counts[id]~=nil then counts[id]+=1 end end
 local max=-1; local leaders={}
 for _,o in ipairs(options) do local n=counts[o.id] or 0; if n>max then max=n; leaders={o} elseif n==max then table.insert(leaders,o) end end
 return leaders[random:NextInteger(1,#leaders)]
end
local function chooseDebateWinner():string
 local c=countMap(debateVotes,{"A","B"}); return if c.A>c.B then "A" elseif c.B>c.A then "B" else "TIE"
end
local function chooseDebateMVP(winner:string): (string, number?)
 local best=0; local candidates={}
 for _,p in ipairs(Players:GetPlayers()) do
  local side=debateVotes[p.UserId]; local score=reactionScores[p.UserId] or 0
  if score>0 and (winner=="TIE" or side==winner) then
   local candidate={name=p.DisplayName,userId=p.UserId}
   if score>best then best=score; candidates={candidate} elseif score==best then table.insert(candidates,candidate) end
  end
 end
 if #candidates==0 then return "No audience MVP",nil end
 local selected=candidates[random:NextInteger(1,#candidates)]
 return selected.name,selected.userId
end
local function onDebateReaction(player:Player,reactionId:string,promptObj:ProximityPrompt)
 if state.phase~="Debate" or not validPlayer(player) or not proximity(player,promptObj.Parent,14) then return end
 if reactionId~="clap" and reactionId~="laugh" and reactionId~="sideeye" then return end
 local t=os.clock(); local key="reaction_"..player.UserId
 if requestAt[key] and t-requestAt[key]<1.25 then return end
 if (reactionScores[player.UserId] or 0)>=3 then return end
 requestAt[key]=t; reactionScores[player.UserId]=(reactionScores[player.UserId] or 0)+1
 reactionCounts[reactionId]+=1; state.debateReactions=table.clone(reactionCounts); StateRemote:FireAllClients(state)
end
local function rewardParticipants(debateWinner: string, debateMVPUserId: number?)
 local results={}; local factionTotals={}; local allianceTotals={}
 for _,p in ipairs(Players:GetPlayers()) do
  local n=hype[p.UserId] or 0; local debated=debateVotes[p.UserId]~=nil
  if validPlayer(p) and (n>0 or debated) then
   local coins=(if n>0 then Config.Rewards.ParticipationCoins+n*Config.Rewards.CoinsPerHype else 0)+(if debated then Config.Rewards.DebateCoins else 0)
   local factionWarPoints=n
   local xp=(if n>0 then Config.Rewards.ParticipationXP+n*Config.Rewards.XPPerHype else 0)+(if debated then Config.Rewards.DebateXP else 0)
   local gotC=Profiles.AddCoins(p,coins); local gotX=Profiles.AddXP(p,xp)
   if n>0 then Profiles.IncrementStat(p,"RoundsPlayed",1); Profiles.IncrementStat(p,"TotalHype",n); Profiles.IncrementStat(p,"Chants",n); dailyProgress(p,"rounds",1); dailyProgress(p,"chants",chantActions[p.UserId] or 0) end
   if debated then
    Profiles.IncrementStat(p,"DebatesJoined",1); dailyProgress(p,"debates",1)
    local reputation=3
    if debateWinner~="TIE" and debateVotes[p.UserId]==debateWinner then reputation+=2; Profiles.IncrementStat(p,"DebateWins",1) end
    Profiles.AddDebateReputation(p,reputation)
    local weeklyPoints = 3 + (if debateWinner~="TIE" and debateVotes[p.UserId]==debateWinner then 2 else 0) + (if p.UserId==debateMVPUserId then 3 else 0)
    factionWarPoints+=weeklyPoints
    WeeklyChampionshipService.Award(p,weeklyPoints)
   end
   local faction=p:GetAttribute("FactionId"); if type(faction)=="string" then
    factionTotals[faction]=(factionTotals[faction] or 0)+factionWarPoints
    local alliance=factionAlliance[faction]; if alliance then allianceTotals[alliance]=(allianceTotals[alliance] or 0)+n end
   end
   StateRemote:FireClient(p,{kind="Reward",coins=gotC,xp=gotX,hype=n,debateReputation=(Profiles.GetData(p) and Profiles.GetData(p).Stats.DebateReputation) or 0})
   table.insert(results,{userId=p.UserId,hype=n,coins=gotC})
  end
 end
 table.sort(results,function(a,b) return a.hype>b.hype end)
 local leader="No faction reached quorum"; local high=0
 for id,total in pairs(factionTotals) do if total>high then high=total; local f=Catalog.GetFaction(id); leader=f and f.name or id end end
 local allianceLeader="No coalition reached quorum"; high=0
 for id,total in pairs(allianceTotals) do if total>high then high=total; allianceLeader=allianceNames[id] or id end end
 return results,leader,allianceLeader,factionTotals
end
local function applyCosmetic(player:Player, cosmeticId:string)
 local character=player.Character; if not character then return end
 local old=character:FindFirstChild("PP_Cosmetic"); if old then old:Destroy() end
 local oldTrail=character:FindFirstChild("PP_InkTrailAttachment",true); if oldTrail then oldTrail:Destroy() end
 local folder=Instance.new("Folder"); folder.Name="PP_Cosmetic"; folder.Parent=character
 local head=character:FindFirstChild("Head")
 local torso=character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
 local hand=character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
 local left=character:FindFirstChild("LeftHand") or character:FindFirstChild("Left Arm")
 local function attach(base:Instance?,name:string,size:Vector3,offset:CFrame,color:Color3,material:Enum.Material?)
  if not base or not base:IsA("BasePart") then return end
  local p=Instance.new("Part"); p.Name=name; p.Size=size; p.Color=color; p.Material=material or Enum.Material.SmoothPlastic; p.CanCollide=false; p.CanTouch=false; p.CanQuery=false; p.Massless=true; p.CFrame=base.CFrame*offset; p.Parent=folder
  local weld=Instance.new("WeldConstraint"); weld.Part0=base; weld.Part1=p; weld.Parent=p
 end
 if cosmeticId=="pigeon_hat" then attach(head,"TinyPigeonHat",Vector3.new(1.7,.45,1.2),CFrame.new(0,1.05,0),Color3.fromRGB(150,150,160))
 elseif cosmeticId=="paper_crown" then
  attach(head,"PaperCrown",Vector3.new(1.8,.3,1.4),CFrame.new(0,1.02,0),Color3.fromRGB(245,204,85),Enum.Material.Metal)
  for i=-1,1 do attach(head,"CrownPoint"..i,Vector3.new(.22,.65,.25),CFrame.new(i*.52,1.4,0),Color3.fromRGB(255,222,110),Enum.Material.Metal) end
 elseif cosmeticId=="neon_megaphone" then attach(hand,"NeonMegaphone",Vector3.new(.55,1.1,.55),CFrame.new(0,-.1,-.45),GameConfig.UI.Accent,Enum.Material.Neon)
 elseif cosmeticId=="rainbow_banner" then attach(torso,"SpectrumBanner",Vector3.new(1.7,2.2,.18),CFrame.new(0,.1,.75),GameConfig.UI.Secondary,Enum.Material.Neon)
 elseif cosmeticId=="tiny_gavel" then attach(hand,"TinyGavel",Vector3.new(.35,.9,.35),CFrame.new(0,0,-.35),Color3.fromRGB(165,112,72),Enum.Material.Wood)
 elseif cosmeticId=="ink_trail" and torso and torso:IsA("BasePart") then
  local a=Instance.new("Attachment"); a.Name="PP_InkTrailAttachment"; a.Parent=torso
  local emitter=Instance.new("ParticleEmitter"); emitter.Name="InkTrail"; emitter.Texture="rbxasset://textures/particles/sparkles_main.dds"; emitter.Rate=3; emitter.Lifetime=NumberRange.new(.4,.8); emitter.Speed=NumberRange.new(.2,.8); emitter.Parent=a
 elseif cosmeticId=="dramatic_pose" and head and head:IsA("BasePart") then
  local gui=Instance.new("BillboardGui"); gui.Name="MainCharacterBadge"; gui.Size=UDim2.fromOffset(150,34); gui.StudsOffset=Vector3.new(0,2.5,0); gui.AlwaysOnTop=true; gui.Parent=folder
  local text=Instance.new("TextLabel"); text.Size=UDim2.fromScale(1,1); text.BackgroundTransparency=1; text.Text="✦ MAIN CHARACTER ✦"; text.TextColor3=GameConfig.UI.Accent; text.Font=Enum.Font.GothamBlack; text.TextScaled=true; text.Parent=gui; gui.Adornee=head
 elseif cosmeticId=="basic_sign" then attach(left,"CardboardPlacard",Vector3.new(1.1,1.4,.12),CFrame.new(0,.35,-.55),Color3.fromRGB(190,160,110),Enum.Material.Wood)
 end
 player:SetAttribute("EquippedCosmetic",cosmeticId)
end

local function handleShop(player:Player,itemId:string,promptObj:ProximityPrompt)
 if not validPlayer(player) or not proximity(player,promptObj.Parent,15) then return end
 local t=os.clock(); local key="shop_"..player.UserId; if requestAt[key] and t-requestAt[key]<1 then return end; requestAt[key]=t
 local item=Catalog.GetCosmetic(itemId); if not item then return end
 local ok,status=Profiles.PurchaseCosmetic(player,item.id,item.price)
 local data=Profiles.GetData(player)
 if ok and data then applyCosmetic(player,data.EquippedCosmetic) end
 StateRemote:FireClient(player,{kind="ShopResult",ok=ok,status=status,item=item.name,coins=data and data.Coins or 0,equipped=data and data.EquippedCosmetic or "basic_sign",owned=data and data.OwnedCosmetics or {}})
end
local function handleFaction(player:Player,factionId:string,promptObj:ProximityPrompt)
 if not validPlayer(player) or not proximity(player,promptObj.Parent,15) then return end
 local t=os.clock(); local key="faction_"..player.UserId; if requestAt[key] and t-requestAt[key]<2 then return end; requestAt[key]=t
 local f=Catalog.GetFaction(factionId); if not f then return end
 local old=player:GetAttribute("FactionId"); if old~=factionId then player:SetAttribute("FactionId",factionId); Profiles.IncrementStat(player,"FactionJoins",1) end
 StateRemote:FireClient(player,{kind="FactionJoined",name=f.name,motto=f.motto})
end
local function handleDaily(player:Player,promptObj:ProximityPrompt)
 if not validPlayer(player) or not proximity(player,promptObj.Parent,18) then return end
 local d=dailyChallenge(); local ok,status=Profiles.ClaimDaily(player,d.id,utcDate(),d.target,d.coins,d.xp)
 local data=Profiles.GetData(player)
 StateRemote:FireClient(player,{kind="DailyClaim",ok=ok,status=status,daily=dailyPayload(player),coins=data and data.Coins or 0,xp=data and data.XP or 0,level=data and data.Level or 1})
end
local function applyTownHall():any
 local counts=hallCounts(); local winner="TIE"; local high=-1; local leaders={}
 for _,side in ipairs({"A","B","C"}) do local n=counts[side] or 0; if n>high then high=n; leaders={side} elseif n==high then table.insert(leaders,side) end end
 if #leaders>0 then winner=leaders[random:NextInteger(1,#leaders)] end
 local idx=if winner=="A" then 1 elseif winner=="B" then 2 else 3
 local rule=Catalog.TownHallRules[idx]
 return {winner=winner,rule=rule,counts=counts}
end
function RoundService.AwardHype(player:Player,station:BasePart)
 if state.phase~="Rally" or not validPlayer(player) or not proximity(player,station,Config.Round.StationMaxDistance+2) then return end
 local char=player.Character; local hum=char and char:FindFirstChildOfClass("Humanoid"); if not hum or hum.Health<=0 then return end
 local t=os.clock(); if t-(lastChant[player.UserId] or 0)<Config.Round.HypeCooldownSeconds then return end
 local n=hype[player.UserId] or 0; if n>=Config.Round.MaxHypePerPlayer then return end
 local gain=if activeTownHallRule and activeTownHallRule.id=="double_hype" then 2 else 1
 local newValue=math.min(Config.Round.MaxHypePerPlayer,n+gain)
 lastChant[player.UserId]=t; hype[player.UserId]=newValue; chantActions[player.UserId]=(chantActions[player.UserId] or 0)+1
 StateRemote:FireClient(player,{kind="Hype",value=newValue,maximum=Config.Round.MaxHypePerPlayer})
end
function RoundService.Start(profileService:any,stateRemote:RemoteEvent,voteRemote:RemoteEvent,debateRemote:RemoteEvent,world:any,socialSystems:any?)
 Profiles=profileService; StateRemote=stateRemote; VoteRemote=voteRemote; DebateRemote=debateRemote; worldData=world
 VoteRemote.OnServerEvent:Connect(onCauseVote); DebateRemote.OnServerEvent:Connect(onDebateVote)
 for _,pr in ipairs(world.hype) do pr.Triggered:Connect(function(p) local parent=pr.Parent; if parent and parent:IsA("BasePart") then RoundService.AwardHype(p,parent) end end) end
 for _,entry in ipairs(world.shop) do entry.prompt.Triggered:Connect(function(p) handleShop(p,entry.itemId,entry.prompt) end) end
 for _,entry in ipairs(world.factions) do entry.prompt.Triggered:Connect(function(p) handleFaction(p,entry.factionId,entry.prompt) end) end
 for _,entry in ipairs(world.reactions) do entry.prompt.Triggered:Connect(function(p) onDebateReaction(p,entry.reactionId,entry.prompt) end) end
 world.townHallA.Triggered:Connect(function(p) if proximity(p,world.townHallA.Parent,16) then onTownHallVote(p,"A") end end)
 world.townHallB.Triggered:Connect(function(p) if proximity(p,world.townHallB.Parent,16) then onTownHallVote(p,"B") end end)
 world.townHallC.Triggered:Connect(function(p) if proximity(p,world.townHallC.Parent,16) then onTownHallVote(p,"C") end end)
 world.daily.Triggered:Connect(function(p) handleDaily(p,world.daily) end)
 local function bindPlayer(p:Player)
  if p:GetAttribute("PPRoundBound") then return end
  p:SetAttribute("PPRoundBound",true)
  p.CharacterAdded:Connect(function() task.wait(.5); local data=Profiles.GetData(p); if data then applyCosmetic(p,data.EquippedCosmetic) end end)
  task.spawn(function() local untilAt=os.clock()+Config.ProfileLoadTimeoutSeconds+5; while p.Parent==Players and not Profiles.IsLoaded(p) and os.clock()<untilAt do task.wait(.2) end; if p.Parent==Players then sendProfile(p); local data=Profiles.GetData(p); if data and p.Character then applyCosmetic(p,data.EquippedCosmetic) end end end)
 end
 Players.PlayerAdded:Connect(bindPlayer)
 for _,existingPlayer in ipairs(Players:GetPlayers()) do bindPlayer(existingPlayer) end
 Players.PlayerRemoving:Connect(function(p) hype[p.UserId]=nil; chantActions[p.UserId]=nil; votes[p.UserId]=nil; debateVotes[p.UserId]=nil; hallVotes[p.UserId]=nil; reactionScores[p.UserId]=nil; lastChant[p.UserId]=nil; requestAt[p.UserId]=nil; requestAt["shop_"..p.UserId]=nil; requestAt["faction_"..p.UserId]=nil; requestAt["reaction_"..p.UserId]=nil end)
 task.spawn(function()
  while true do
   cause=nil; debate=nil; options={}; votes={}; debateVotes={}; hallVotes={}; hype={}; chantActions={}; reactionScores={}; reactionCounts={clap=0,laugh=0,sideeye=0}
   publish("Intermission",Config.Round.IntermissionSeconds,{heading="THE PLAZA IS OPEN",description=if activeTownHallRule then "CITY RULE ACTIVE: "..activeTownHallRule.title else "Four factions. One city. Absolutely no competent leadership."})
   task.wait(Config.Round.IntermissionSeconds)
   options=Catalog.GetRandomOptions(3,random); votes={}
   publish("Voting",Config.Round.VotingSeconds,{heading="WHAT ARE WE MAD ABOUT TODAY?",description="Vote for a fictional cause. Democracy has a megaphone.",options=options,voteCounts={}})
   task.wait(Config.Round.VotingSeconds); cause=chooseCause(); local scheduledDebate=if socialSystems and type(socialSystems.GetScheduledDebate)=="function" then socialSystems.GetScheduledDebate() else nil; debate=scheduledDebate or DebateCommunityService.GetNextPublicTopic() or Catalog.GetRandomDebate(random); debateVotes={}
   publish("Debate",Config.Round.DebateSeconds,{heading="THE PLAZA DEBATE",description="Debate the idea, never the person.",debate={id=debate.id,prompt=debate.prompt,sideA=debate.sideA,sideB=debate.sideB,context=debate.context},debateCounts={A=0,B=0},debateReactions=reactionCounts})
   task.wait(Config.Round.DebateSeconds); local debateWinner=chooseDebateWinner(); local debateMVP,debateMVPUserId=chooseDebateMVP(debateWinner)
   local alliances=createAlliances()
   publish("Rally",Config.Round.RallySeconds,{heading="THE RALLY IS LIVE",description="Lead chants, meet your faction, and watch the city get weird.",debateWinner=debateWinner,debateMVP=debateMVP,debateReactions=reactionCounts,crowdEvent=nil,alliances=alliances})
   local event=Catalog.CrowdEvents[random:NextInteger(1,#Catalog.CrowdEvents)]
   task.delay(math.max(8,Config.Round.RallySeconds*.35),function() if state.phase=="Rally" then WorldBuilder.ShowCrowdEvent(worldData,event); state.crowdEvent={id=event.id,title=event.title,detail=event.detail,endsAt=now()+event.duration}; StateRemote:FireAllClients(state); task.delay(event.duration,function() if state.phase=="Rally" then WorldBuilder.ClearCrowdEvent(worldData); state.crowdEvent=nil; StateRemote:FireAllClients(state) end end) end end)
   task.delay(math.max(12,Config.Round.RallySeconds*.62),function()
    if state.phase=="Rally" then
     local factions=Catalog.Factions; local traitor=factions[random:NextInteger(1,#factions)]; local old=factionAlliance[traitor.id] or "A"; local newSide=if old=="A" then "B" else "A"
     factionAlliance[traitor.id]=newSide
     state.betrayal={faction=traitor.name,from=allianceNames[old],to=allianceNames[newSide]}; StateRemote:FireAllClients(state)
    end
   end)
   task.wait(Config.Round.RallySeconds)
   WorldBuilder.ClearCrowdEvent(worldData)
   local rewards,factionLeader,allianceLeader,factionTotals=rewardParticipants(debateWinner,debateMVPUserId)
   if socialSystems and type(socialSystems.OnRoundResults)=="function" then socialSystems.OnRoundResults(factionTotals,debateMVPUserId,debateWinner,debate and debate.prompt or nil,debate and debate.id or nil,debateVotes) end
   WorldBuilder.ApplyConsequence(worldData,cause)
   publish("Results",Config.Round.ResultsSeconds,{heading="THE PLAZA HAS SPOKEN",description=cause.title,rewards=rewards,debateWinner=debateWinner,debateMVP=debateMVP,factionLeader=factionLeader,allianceLeader=allianceLeader})
   task.wait(Config.Round.ResultsSeconds)
   hallVotes={}; publish("TownHall",Config.Round.TownHallSeconds,{heading="TOWN HALL: CHANGE THE CITY",description="A: DOUBLE HYPE · B: PIGEON PARADE · C: CONFETTI BREAK. Use the three voting pads.",townHallOptions=Catalog.TownHallRules,townHallCounts={A=0,B=0,C=0}})
   task.wait(Config.Round.TownHallSeconds); local outcome=applyTownHall()
   activeTownHallRule=outcome.rule
   WorldBuilder.ApplyTownHallRule(worldData,outcome.rule)
   publish("TownHallResults",6,{heading="THE CITY HAS A NEW RULE",description=outcome.rule.title,townHallWinner=outcome.winner,townHallRule=outcome.rule,townHallCounts=outcome.counts})
   task.wait(6)
  end
 end)
end
return RoundService
