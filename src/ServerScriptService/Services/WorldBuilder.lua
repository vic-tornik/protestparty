--!strict
-- Procedural v0.3 plaza. All geometry is lightweight Parts; replace with authored meshes after profiling.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local Catalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ContentCatalog"))
local WorldBuilder = {}

local function part(parent: Instance, name: string, size: Vector3, pos: Vector3, color: Color3, material: Enum.Material?): Part
 local p=Instance.new("Part"); p.Name=name; p.Size=size; p.Position=pos; p.Anchored=true; p.Color=color; p.Material=material or Enum.Material.SmoothPlastic; p.TopSurface=Enum.SurfaceType.Smooth; p.BottomSurface=Enum.SurfaceType.Smooth; p.Parent=parent; return p
end
local function label(parent: Instance, title: string, subtitle: string, color: Color3?)
 local gui=Instance.new("BillboardGui"); gui.Name="WorldLabel"; gui.Size=UDim2.fromOffset(260,76); gui.StudsOffset=Vector3.new(0,4.5,0); gui.AlwaysOnTop=true; gui.MaxDistance=110; gui.Parent=parent
 local a=Instance.new("TextLabel"); a.Name="Title"; a.BackgroundTransparency=1; a.Size=UDim2.fromScale(1,.55); a.Font=Enum.Font.GothamBlack; a.Text=title; a.TextColor3=color or GameConfig.UI.Accent; a.TextScaled=true; a.Parent=gui
 local b=Instance.new("TextLabel"); b.Name="Subtitle"; b.BackgroundTransparency=1; b.Position=UDim2.fromScale(0,.55); b.Size=UDim2.fromScale(1,.4); b.Font=Enum.Font.GothamMedium; b.Text=subtitle; b.TextColor3=GameConfig.UI.Text; b.TextScaled=true; b.Parent=gui
end
local function prompt(parent: BasePart, name: string, action: string, object: string, distance: number?): ProximityPrompt
 local p=Instance.new("ProximityPrompt"); p.Name=name; p.ActionText=action; p.ObjectText=object; p.KeyboardKeyCode=Enum.KeyCode.E; p.GamepadKeyCode=Enum.KeyCode.ButtonX; p.HoldDuration=0; p.MaxActivationDistance=distance or 12; p.RequiresLineOfSight=false; p.Parent=parent; return p
end
local function npc(parent: Instance, id: string, display: string, subtitle: string, position: Vector3, tint: Color3, dialogue: {string}, promptName: string, promptAction: string): (BasePart, ProximityPrompt)
 local model=Instance.new("Model"); model.Name="NPC_"..id; model.Parent=parent
 local torso=part(model,"Torso",Vector3.new(3,3.4,1.5),position,tint,Enum.Material.SmoothPlastic); torso.CanCollide=false
 local head=part(model,"Head",Vector3.new(2.1,2.1,2.1),position+Vector3.new(0,2.55,0),Color3.fromRGB(238,202,164)); head.Shape=Enum.PartType.Ball; head.CanCollide=false
 local face=Instance.new("Decal"); face.Name="Face"; face.Texture="rbxasset://textures/face.png"; face.Face=Enum.NormalId.Front; face.Parent=head
 label(head,display,subtitle,tint)
 local pr=prompt(torso,promptName,promptAction,display,12)
 local index=0
 task.spawn(function()
  while model.Parent do
   index=index%#dialogue+1
   local gui=head:FindFirstChild("WorldLabel"); local sub=gui and gui:FindFirstChild("Subtitle")
   if sub then sub.Text=model:GetAttribute("TerritoryDialogue") or dialogue[index] end
   local base=head.Position
   local up=TweenService:Create(head,TweenInfo.new(1.2,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),{Position=base+Vector3.new(0,.35,0)})
   up:Play(); up.Completed:Wait()
   if not model.Parent then break end
   local down=TweenService:Create(head,TweenInfo.new(1.2,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),{Position=base}); down:Play(); down.Completed:Wait()
   task.wait(3.5)
  end
 end)
 return torso,pr
end

function WorldBuilder.Build(): any
 local old=Workspace:FindFirstChild("ProtestPartyWorld"); if old then old:Destroy() end
 local world=Instance.new("Folder"); world.Name="ProtestPartyWorld"; world.Parent=Workspace
 -- v0.5 art direction: cinematic civic-night plaza with restrained neon and readable silhouettes.
 for _,effectName in ipairs({"ProtestAtmosphere","ProtestBloom","ProtestColorGrade","ProtestDepthOfField"}) do
  local oldEffect=Lighting:FindFirstChild(effectName); if oldEffect then oldEffect:Destroy() end
 end
 local atmosphere=Instance.new("Atmosphere"); atmosphere.Name="ProtestAtmosphere"; atmosphere.Density=0.28; atmosphere.Offset=0.12; atmosphere.Color=Color3.fromRGB(166,177,220); atmosphere.Decay=Color3.fromRGB(63,55,94); atmosphere.Glare=0.18; atmosphere.Haze=1.1; atmosphere.Parent=Lighting
 local bloom=Instance.new("BloomEffect"); bloom.Name="ProtestBloom"; bloom.Intensity=0.28; bloom.Size=24; bloom.Threshold=1.35; bloom.Parent=Lighting
 local grade=Instance.new("ColorCorrectionEffect"); grade.Name="ProtestColorGrade"; grade.Brightness=-0.025; grade.Contrast=0.12; grade.Saturation=-0.08; grade.TintColor=Color3.fromRGB(218,220,255); grade.Parent=Lighting
 Lighting.Technology=Enum.Technology.Future
 -- Distant skyline silhouettes make the plaza feel like a city, not a floating arena.
 local skyline=Instance.new("Folder"); skyline.Name="DistantSkyline"; skyline.Parent=world
 for i=1,13 do
  local x=(i-7)*34; local height=26+((i*17)%43)
  local tower=part(skyline,"Tower_"..i,Vector3.new(18,height,16),Vector3.new(x,height/2-0.2,-178),Color3.fromRGB(27,30,44),Enum.Material.Concrete)
  tower.CanCollide=true
  local strip=part(skyline,"TowerLight_"..i,Vector3.new(0.35,height*0.72,0.35),Vector3.new(x-7,height*0.48,-169.7),if i%3==0 then GameConfig.UI.Secondary else GameConfig.UI.Accent,Enum.Material.Neon)
  strip.CanCollide=false; strip.Transparency=0.22
 end
 -- Layered plaza floor rings create a clear focal route toward the debate stage.
 local approach=part(world,"CivicApproachGlow",Vector3.new(2,0.18,82),Vector3.new(0,0.12,3),GameConfig.UI.Accent,Enum.Material.Neon); approach.CanCollide=false; approach.Transparency=0.42
 local ground=part(world,"Plaza",GameConfig.World.GroundSize,Vector3.new(0,-1,0),Color3.fromRGB(38,42,54),Enum.Material.Asphalt); ground.Locked=true
 -- Distinct zones and paths
 part(world,"SpawnTerrace",Vector3.new(44,1,30),Vector3.new(0,0,112),Color3.fromRGB(66,70,88),Enum.Material.Slate)
 local spawn=Instance.new("SpawnLocation"); spawn.Name="MainSpawn"; spawn.Size=Vector3.new(10,1,10); spawn.Position=Vector3.new(0,1,112); spawn.Anchored=true; spawn.Neutral=true; spawn.Duration=0; spawn.Parent=world
 part(world,"MainWalkway",Vector3.new(18,.3,115),Vector3.new(0,.1,36),Color3.fromRGB(76,80,98),Enum.Material.Concrete)
 -- Civic square, debate stage and town hall
 part(world,"StageBase",Vector3.new(62,3,24),Vector3.new(0,1,-58),Color3.fromRGB(31,34,46),Enum.Material.Metal)
 local wall=part(world,"StageBackdrop",Vector3.new(62,22,2),Vector3.new(0,13,-72),Color3.fromRGB(25,27,39),Enum.Material.Slate); label(wall,"THE GREAT NOPE","CIVIC NONSENSE DEPARTMENT")
 local stageTrim=part(world,"StageTrim",Vector3.new(62,0.5,2.4),Vector3.new(0,2.0,-70.7),GameConfig.UI.Accent,Enum.Material.Neon); stageTrim.CanCollide=false
 for i=-1,1 do
  local lamp=Instance.new("Part"); lamp.Name="StageSpotlight_"..i; lamp.Shape=Enum.PartType.Ball; lamp.Size=Vector3.new(1.4,1.4,1.4); lamp.Position=Vector3.new(i*22,23,-67); lamp.Anchored=true; lamp.Material=Enum.Material.Neon; lamp.Color=if i==0 then GameConfig.UI.Accent else GameConfig.UI.Secondary; lamp.CanCollide=false; lamp.Parent=world
  local light=Instance.new("PointLight"); light.Color=lamp.Color; light.Brightness=1.6; light.Range=34; light.Parent=lamp
 end
 local debate=part(world,"DebateArena",Vector3.new(54,1,34),Vector3.new(0,.1,-14),Color3.fromRGB(76,62,112),Enum.Material.Slate); label(debate,"DEBATE ARENA","LOUD IDEAS. SOFT LANDINGS.",GameConfig.UI.Secondary)
 local globalBoard=part(world,"GlobalDebateBoard",Vector3.new(38,13,1.2),Vector3.new(50,7.5,-14),Color3.fromRGB(24,28,42),Enum.Material.Metal)
 label(globalBoard,"GLOBAL DEBATE NETWORK","TRENDING TOPICS  ·  WEEKLY CHAMPIONSHIPS  ·  FACTION STANDINGS",GameConfig.UI.Accent)
 local boardTrim=part(world,"GlobalDebateBoardTrim",Vector3.new(38.5,.35,1.5),Vector3.new(50,1.0,-14),GameConfig.UI.Secondary,Enum.Material.Neon); boardTrim.CanCollide=false
 local reactionPrompts={}
 local reactions={{id="clap",title="CLAP",color=Color3.fromRGB(255,210,90)},{id="laugh",title="LAUGH",color=Color3.fromRGB(191,255,64)},{id="sideeye",title="SIDE-EYE",color=Color3.fromRGB(169,119,255)}}
 for i,reaction in ipairs(reactions) do
  local pad=part(world,"Reaction_"..reaction.id,Vector3.new(7,2,7),Vector3.new(-18+(i-1)*18,2,8),reaction.color,Enum.Material.Neon)
  label(pad,reaction.title,"AUDIENCE REACTION",reaction.color)
  table.insert(reactionPrompts,{prompt=prompt(pad,"React_"..reaction.id,"React","Debate audience",12),reactionId=reaction.id})
 end
 local hall=part(world,"TownHall",Vector3.new(34,1,24),Vector3.new(88,.1,35),Color3.fromRGB(66,72,91),Enum.Material.Slate); label(hall,"TOWN HALL","VOTE ON THE NEXT CITY RULE")
 local voteA=part(world,"TownHallVoteA",Vector3.new(8,3,8),Vector3.new(80,2,22),GameConfig.UI.Accent,Enum.Material.Neon); label(voteA,"OPTION A","VOTE HERE"); local hallA=prompt(voteA,"TownHallA","Vote A","Town Hall",14)
 local voteB=part(world,"TownHallVoteB",Vector3.new(8,3,8),Vector3.new(96,2,22),GameConfig.UI.Secondary,Enum.Material.Neon); label(voteB,"OPTION B","VOTE HERE"); local hallB=prompt(voteB,"TownHallB","Vote B","Town Hall",14)
 local voteC=part(world,"TownHallVoteC",Vector3.new(8,3,8),Vector3.new(88,2,48),Color3.fromRGB(255,170,90),Enum.Material.Neon); label(voteC,"OPTION C","VOTE HERE"); local hallC=prompt(voteC,"TownHallC","Vote C","Town Hall",14)
 -- Cosmetic shop stands
 local shop=part(world,"CosmeticShop",Vector3.new(30,1,22),Vector3.new(-88,.1,35),Color3.fromRGB(62,78,79),Enum.Material.Slate); label(shop,"THE NONSENSE BOUTIQUE","COSMETICS. ZERO POWER ADVANTAGE.")
 local shopPrompts={}
 for i,item in ipairs(Catalog.Cosmetics) do
  local col=(i-1)%4; local row=math.floor((i-1)/4)
  local stand=part(world,"Shop_"..item.id,Vector3.new(5,2,5),Vector3.new(-101+col*9,2,25+row*12),if i%2==0 then GameConfig.UI.Secondary else GameConfig.UI.Accent,Enum.Material.Neon)
  label(stand,item.name,tostring(item.price).." COINS")
  table.insert(shopPrompts,{prompt=prompt(stand,"Buy_"..item.id,"Buy / Equip",item.name,12),itemId=item.id})
 end
 -- Four faction desks and animated original NPCs
 local factionPrompts={}
 local positions={Vector3.new(-104,2,-48),Vector3.new(-36,2,-104),Vector3.new(36,2,-104),Vector3.new(104,2,-48)}
 local colors={Color3.fromRGB(160,160,170),Color3.fromRGB(120,170,255),Color3.fromRGB(190,150,90),Color3.fromRGB(255,145,100)}
 for i,faction in ipairs(Catalog.Factions) do
  local pos=positions[i]; local desk=part(world,"FactionDesk_"..faction.id,Vector3.new(18,1,12),pos+Vector3.new(0,-1,0),Color3.fromRGB(51,55,69),Enum.Material.WoodPlanks)
  local _,pr=npc(world,faction.id,faction.name,faction.motto,pos+Vector3.new(0,2,0),colors[i],faction.dialogue,"Join_"..faction.id,"Join movement")
  table.insert(factionPrompts,{prompt=pr,factionId=faction.id})
 end
 -- Daily board
 local dailyBoard=part(world,"DailyBoard",Vector3.new(18,12,1),Vector3.new(0,7,84),Color3.fromRGB(35,39,53),Enum.Material.Metal); label(dailyBoard,"DAILY NONSENSE","Complete a challenge. Claim your reward.")
 local dailyPrompt=prompt(dailyBoard,"ClaimDaily","Claim reward","Daily challenge",15)
 -- Megaphone stations
 local hypePrompts={}; local stations=Instance.new("Folder"); stations.Name="HypeStations"; stations.Parent=world
 for i=1,GameConfig.World.StationCount do
  local x=(i-((GameConfig.World.StationCount+1)/2))*GameConfig.World.StationSpacing
  local st=part(stations,"MegaphoneStation_"..i,Vector3.new(7,2,7),Vector3.new(x,2,-39),if i%2==0 then GameConfig.UI.Secondary else GameConfig.UI.Accent,Enum.Material.Neon)
  label(st,"GET LOUD","Press E / tap to chant"); table.insert(hypePrompts,prompt(st,"ChantPrompt","Lead a chant","Megaphone station",GameConfig.Round.StationMaxDistance))
 end
 -- Civic consequence props, changed by RoundService between rounds
 local consequence=Instance.new("Folder"); consequence.Name="CityConsequence"; consequence.Parent=world
 local banner=part(consequence,"ConsequenceBanner",Vector3.new(42,8,1),Vector3.new(0,7,-88),Color3.fromRGB(48,54,70)); banner.Transparency=.12; label(banner,"CITY POLICY: PENDING","The winning cause will change the plaza.")
 -- Mood lighting
 Lighting.ClockTime=19.1; Lighting.Brightness=1.8; Lighting.Ambient=Color3.fromRGB(79,83,115); Lighting.OutdoorAmbient=Color3.fromRGB(102,108,150)
 return {hype=hypePrompts, shop=shopPrompts, factions=factionPrompts, reactions=reactionPrompts, townHallA=hallA, townHallB=hallB, townHallC=hallC, daily=dailyPrompt, consequence=consequence}
end

function WorldBuilder.ApplyConsequence(worldData: any, cause: any)
 local folder=worldData and worldData.consequence; if not folder then return end
 local oldPerch=folder:FindFirstChild("PigeonPerch"); if oldPerch then oldPerch:Destroy() end
 Lighting.ClockTime=17.2; Lighting.Ambient=Color3.fromRGB(95,98,120)
 local banner=folder:FindFirstChild("ConsequenceBanner")
 if banner and banner:IsA("BasePart") then
  local gui=banner:FindFirstChild("WorldLabel")
  local title=gui and gui:FindFirstChild("Title"); local subtitle=gui and gui:FindFirstChild("Subtitle")
  if title and title:IsA("TextLabel") then title.Text="CITY POLICY: "..string.upper(cause.shortTitle or cause.title) end
  if subtitle and subtitle:IsA("TextLabel") then subtitle.Text="The city is now dealing with the consequences." end
 end
 -- Cause-specific visual consequence: a Monday ban flips the plaza clock to a weekend-like blue hour;
 -- pigeon policy adds a visible municipal perch. All changes are decorative and reversible.
 if cause.id=="ban_mondays" then Lighting.ClockTime=19.4; Lighting.Ambient=Color3.fromRGB(90,105,150)
 elseif cause.id=="pigeon_rent" then
  if not folder:FindFirstChild("PigeonPerch") then local perch=part(folder,"PigeonPerch",Vector3.new(28,2,5),Vector3.new(0,2,-98),Color3.fromRGB(135,130,120),Enum.Material.Wood); perch:SetAttribute("DecorativeOnly",true) end
 elseif cause.id=="printer_rights" then Lighting.ClockTime=16.1; Lighting.Ambient=Color3.fromRGB(120,95,95)
 else Lighting.ClockTime=17.2; Lighting.Ambient=Color3.fromRGB(95,98,120) end
end

function WorldBuilder.ShowCrowdEvent(worldData: any, event: any)
 local folder=worldData and worldData.consequence; if not folder then return end
 local old=folder:FindFirstChild("CrowdEventVisual"); if old then old:Destroy() end
 local fx=Instance.new("Folder"); fx.Name="CrowdEventVisual"; fx.Parent=folder
 if event.id=="paper_storm" then
  for i=1,10 do
   local sheet=part(fx,"LooseForm_"..i,Vector3.new(2.2,.12,1.5),Vector3.new(math.sin(i*2)*25,4+(i%3),-28+i*4),Color3.fromRGB(235,232,215),Enum.Material.SmoothPlastic)
   sheet.Orientation=Vector3.new(0,i*29,i*13); sheet.CanCollide=false
  end
 elseif event.id=="pigeon_congress" then
  local podium=part(fx,"PigeonPodium",Vector3.new(10,4,8),Vector3.new(35,2,-20),Color3.fromRGB(140,135,125),Enum.Material.Wood)
  label(podium,"EMERGENCY CONGRESS","THE PIGEONS HAVE THE FLOOR.",Color3.fromRGB(220,220,220))
 elseif event.id=="buffering" then
  local ring=part(fx,"BufferingBeacon",Vector3.new(8,.5,8),Vector3.new(0,1,-20),Color3.fromRGB(169,119,255),Enum.Material.Neon)
  ring.Shape=Enum.PartType.Cylinder; ring.Transparency=.25; ring.CanCollide=false
  label(ring,"BUFFERING...","THE CITY IS THINKING.",GameConfig.UI.Secondary)
 elseif event.id=="snack_drop" then
  local crate=part(fx,"SnackCrate",Vector3.new(8,6,8),Vector3.new(-35,3,-20),Color3.fromRGB(183,130,75),Enum.Material.Wood)
  label(crate,"SNACK DROP","UNCLAIMED NUGGETS. PROBABLY.",Color3.fromRGB(255,220,145))
 end
end

function WorldBuilder.ClearCrowdEvent(worldData: any)
 local folder=worldData and worldData.consequence; local old=folder and folder:FindFirstChild("CrowdEventVisual")
 if old then old:Destroy() end
end

function WorldBuilder.ApplyTownHallRule(worldData: any, rule: any)
 local folder=worldData and worldData.consequence; if not folder then return end
 local old=folder:FindFirstChild("TownHallEffect"); if old then old:Destroy() end
 local fx=Instance.new("Folder"); fx.Name="TownHallEffect"; fx.Parent=folder
 if rule.id=="pigeon_parade" then
  local route=part(fx,"ParadeRoute",Vector3.new(5,.35,72),Vector3.new(0,.4,-22),Color3.fromRGB(160,160,170),Enum.Material.Neon); route.Transparency=.25; route.CanCollide=false
 elseif rule.id=="confetti_break" then
  for i=1,18 do
   local x=((i%6)-2.5)*9; local z=-58+math.floor((i-1)/6)*13
   local confetti=part(fx,"ConfettiMarker_"..i,Vector3.new(1.4,.3,1.4),Vector3.new(x,5+(i%3),z),if i%2==0 then GameConfig.UI.Accent else GameConfig.UI.Secondary,Enum.Material.Neon)
   confetti.CanCollide=false
  end
 end
end
return WorldBuilder
