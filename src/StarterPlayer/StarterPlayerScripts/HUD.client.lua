--!strict
-- Lightweight responsive HUD. No client-side rewards, progression, or authoritative game state.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local stateRemote = remotes:WaitForChild("StateUpdate") :: RemoteEvent
local voteRemote = remotes:WaitForChild("VoteCause") :: RemoteEvent
local debateVoteRemote = remotes:WaitForChild("VoteDebate") :: RemoteEvent
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))

local currentState: any = nil
local profile = { coins = 0, xp = 0, level = 1 }
local currentHype = 0
local maximumHype = 30
local selectedVote: string? = nil
local selectedDebateSide: string? = nil

local gui = Instance.new("ScreenGui")
gui.Name = "ProtestPartyHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.DisplayOrder = 20
gui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.Name = "MainPanel"
panel.AnchorPoint = Vector2.new(0.5, 0)
panel.Position = UDim2.new(0.5, 0, 0, 16)
panel.Size = UDim2.new(0.92, 0, 0, 198)
panel.BackgroundColor3 = GameConfig.UI.Background
panel.BackgroundTransparency = 0.04
panel.BorderSizePixel = 0
panel.Parent = gui

local sizeConstraint = Instance.new("UISizeConstraint")
sizeConstraint.MinSize = Vector2.new(290, 198)
sizeConstraint.MaxSize = Vector2.new(680, 198)
sizeConstraint.Parent = panel
local panelScale = Instance.new("UIScale"); panelScale.Scale = 1; panelScale.Parent = panel

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 16)
corner.Parent = panel
local panelGradient = Instance.new("UIGradient")
panelGradient.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromRGB(34,38,55)), ColorSequenceKeypoint.new(1, Color3.fromRGB(17,19,29))})
panelGradient.Rotation = 90
panelGradient.Parent = panel

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(74, 79, 98)
stroke.Thickness = 1
stroke.Transparency = 0.25
stroke.Parent = panel
local topAccent = Instance.new("Frame")
topAccent.Name = "AccentRule"; topAccent.BorderSizePixel = 0; topAccent.BackgroundColor3 = GameConfig.UI.Accent
 topAccent.Position = UDim2.fromOffset(16, 0); topAccent.Size = UDim2.new(0, 74, 0, 3); topAccent.Parent = panel
local accentCorner = Instance.new("UICorner"); accentCorner.CornerRadius = UDim.new(1,0); accentCorner.Parent = topAccent

local header = Instance.new("TextLabel")
header.Name = "Brand"
header.BackgroundTransparency = 1
header.Position = UDim2.fromOffset(18, 12)
header.Size = UDim2.new(0.6, -18, 0, 22)
header.Font = Enum.Font.GothamBlack
header.Text = "PROTEST PARTY  /  THE GREAT NOPE"
header.TextColor3 = GameConfig.UI.Accent
header.TextXAlignment = Enum.TextXAlignment.Left
header.TextSize = 14
header.TextTruncate = Enum.TextTruncate.AtEnd
header.Parent = panel

local wallet = Instance.new("TextLabel")
wallet.Name = "Wallet"
wallet.BackgroundTransparency = 1
wallet.AnchorPoint = Vector2.new(1, 0)
wallet.Position = UDim2.new(1, -18, 0, 12)
wallet.Size = UDim2.new(0.4, -18, 0, 22)
wallet.Font = Enum.Font.GothamBold
wallet.Text = "0 COINS  ·  LV 1"
wallet.TextColor3 = GameConfig.UI.Text
wallet.TextXAlignment = Enum.TextXAlignment.Right
wallet.TextSize = 13
wallet.TextTruncate = Enum.TextTruncate.AtEnd
wallet.Parent = panel

local phaseLabel = Instance.new("TextLabel")
phaseLabel.Name = "Phase"
phaseLabel.BackgroundTransparency = 1
phaseLabel.Position = UDim2.fromOffset(18, 42)
phaseLabel.Size = UDim2.new(1, -118, 0, 28)
phaseLabel.Font = Enum.Font.GothamBlack
phaseLabel.Text = "CONNECTING TO THE PLAZA..."
phaseLabel.TextColor3 = GameConfig.UI.Text
phaseLabel.TextXAlignment = Enum.TextXAlignment.Left
phaseLabel.TextSize = 20
phaseLabel.TextTruncate = Enum.TextTruncate.AtEnd
phaseLabel.Parent = panel

local description = Instance.new("TextLabel")
description.Name = "Description"
description.BackgroundTransparency = 1
description.Position = UDim2.fromOffset(18, 72)
description.Size = UDim2.new(1, -36, 0, 20)
description.Font = Enum.Font.GothamMedium
description.Text = "One moment. The pigeons are reviewing the paperwork."
description.TextColor3 = GameConfig.UI.Muted
description.TextXAlignment = Enum.TextXAlignment.Left
description.TextSize = 12
description.TextTruncate = Enum.TextTruncate.AtEnd
description.Parent = panel

local timer = Instance.new("TextLabel")
timer.Name = "Timer"
timer.BackgroundTransparency = 1
timer.AnchorPoint = Vector2.new(1, 0)
timer.Position = UDim2.new(1, -18, 0, 42)
timer.Size = UDim2.fromOffset(70, 26)
timer.Font = Enum.Font.GothamBold
timer.Text = "--"
timer.TextColor3 = GameConfig.UI.Secondary
timer.TextXAlignment = Enum.TextXAlignment.Right
timer.TextSize = 17
timer.Parent = panel

local buttonHolder = Instance.new("Frame")
buttonHolder.Name = "VoteButtons"
buttonHolder.BackgroundTransparency = 1
buttonHolder.Position = UDim2.fromOffset(18, 103)
buttonHolder.Size = UDim2.new(1, -36, 0, 44)
buttonHolder.Parent = panel

local buttonLayout = Instance.new("UIListLayout")
buttonLayout.FillDirection = Enum.FillDirection.Horizontal
buttonLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
buttonLayout.VerticalAlignment = Enum.VerticalAlignment.Center
buttonLayout.Padding = UDim.new(0, 8)
buttonLayout.SortOrder = Enum.SortOrder.LayoutOrder
buttonLayout.Parent = buttonHolder

local hypeLabel = Instance.new("TextLabel")
hypeLabel.Name = "Hype"
hypeLabel.BackgroundTransparency = 1
hypeLabel.AnchorPoint = Vector2.new(1, 1)
hypeLabel.Position = UDim2.new(1, -18, 1, -9)
hypeLabel.Size = UDim2.fromOffset(180, 18)
hypeLabel.Font = Enum.Font.GothamBold
hypeLabel.Text = "HYPE  0 / 30"
hypeLabel.TextColor3 = GameConfig.UI.Accent
hypeLabel.TextXAlignment = Enum.TextXAlignment.Right
hypeLabel.TextSize = 11
hypeLabel.Parent = panel

local dailyLabel = Instance.new("TextLabel")
dailyLabel.Name = "DailyChallenge"
dailyLabel.BackgroundTransparency = 1
dailyLabel.Position = UDim2.fromOffset(18, 151)
dailyLabel.Size = UDim2.new(1, -36, 0, 18)
dailyLabel.Font = Enum.Font.GothamMedium
dailyLabel.Text = "DAILY: Visit the Daily Board"
dailyLabel.TextColor3 = GameConfig.UI.Muted
dailyLabel.TextXAlignment = Enum.TextXAlignment.Left
dailyLabel.TextSize = 11
dailyLabel.TextTruncate = Enum.TextTruncate.AtEnd
dailyLabel.Parent = panel

local toast = Instance.new("TextLabel")
toast.Name = "Toast"
toast.AnchorPoint = Vector2.new(0.5, 0)
toast.Position = UDim2.new(0.5, 0, 0, 204)
toast.Size = UDim2.new(0.86, 0, 0, 36)
toast.BackgroundColor3 = GameConfig.UI.Panel
toast.BackgroundTransparency = 1
toast.TextTransparency = 1
toast.Text = ""
toast.TextColor3 = GameConfig.UI.Accent
toast.Font = Enum.Font.GothamBold
toast.TextSize = 14
toast.Parent = gui
local toastCorner = Instance.new("UICorner")
toastCorner.CornerRadius = UDim.new(0, 10)
toastCorner.Parent = toast

local function updateWallet()
	wallet.Text = string.format("%s COINS  ·  LV %s", tostring(profile.coins), tostring(profile.level))
end

local function updateDaily(daily: any)
 if type(daily) ~= "table" then return end
 local status = if daily.claimed then "CLAIMED" else string.format("%d/%d", tonumber(daily.progress) or 0, tonumber(daily.target) or 1)
 dailyLabel.Text = string.format("DAILY: %s  ·  %s", tostring(daily.title or "CHALLENGE"), status)
end

local function clearVoteButtons()
	for _, child in ipairs(buttonHolder:GetChildren()) do
		if child:IsA("TextButton") then child:Destroy() end
	end
end

local function showToast(message: string)
	toast.Text = message
	TweenService:Create(toast, TweenInfo.new(0.18), { BackgroundTransparency = 0.08, TextTransparency = 0 }):Play()
	task.delay(2.8, function()
		TweenService:Create(toast, TweenInfo.new(0.35), { BackgroundTransparency = 1, TextTransparency = 1 }):Play()
	end)
end

local function renderVoteButtons(options: {any}, counts: {[string]: number}?)
	clearVoteButtons()
	for index, option in ipairs(options) do
		local button = Instance.new("TextButton")
		button.Name = "Vote_" .. tostring(option.id)
		button.LayoutOrder = index
		button.Size = UDim2.new(1 / math.max(1, #options), -6, 1, 0)
		button.BackgroundColor3 = if selectedVote == option.id then GameConfig.UI.Accent else GameConfig.UI.Panel
		button.TextColor3 = if selectedVote == option.id then Color3.fromRGB(20, 22, 30) else GameConfig.UI.Text
		button.Font = Enum.Font.GothamBold
		button.TextSize = 11
		button.TextWrapped = true
		button.Text = string.format("%s\n%d VOTES", option.shortTitle or option.title, (counts and counts[option.id]) or 0)
		button.AutoButtonColor = true
		button.Parent = buttonHolder
		local buttonCorner = Instance.new("UICorner")
		buttonCorner.CornerRadius = UDim.new(0, 10)
		buttonCorner.Parent = button
		button.Activated:Connect(function()
			selectedVote = option.id
			voteRemote:FireServer(option.id)
			for _, other in ipairs(buttonHolder:GetChildren()) do
				if other:IsA("TextButton") then
					local active = other.Name == button.Name
					other.BackgroundColor3 = if active then GameConfig.UI.Accent else GameConfig.UI.Panel
					other.TextColor3 = if active then Color3.fromRGB(20, 22, 30) else GameConfig.UI.Text
				end
			end
		end)
	end
end


local function renderDebate(debate: any, counts: {[string]: number}?)
 clearVoteButtons()
 local choices = {
  { side = "A", label = tostring(debate.sideA or "SIDE A") },
  { side = "B", label = tostring(debate.sideB or "SIDE B") },
 }
 for index, choice in ipairs(choices) do
  local button = Instance.new("TextButton")
  button.Name = "Debate_" .. choice.side
  button.LayoutOrder = index
  button.Size = UDim2.new(0.5, -4, 1, 0)
  button.BackgroundColor3 = if selectedDebateSide == choice.side then GameConfig.UI.Accent else GameConfig.UI.Panel
  button.TextColor3 = if selectedDebateSide == choice.side then Color3.fromRGB(20, 22, 30) else GameConfig.UI.Text
  button.Font = Enum.Font.GothamBold
  button.TextSize = 10
  button.TextWrapped = true
  button.Text = string.format("%s\n%d VOTES", choice.label, (counts and counts[choice.side]) or 0)
  button.Parent = buttonHolder
  local buttonCorner = Instance.new("UICorner")
  buttonCorner.CornerRadius = UDim.new(0, 10)
  buttonCorner.Parent = button
  button.Activated:Connect(function()
   selectedDebateSide = choice.side
   debateVoteRemote:FireServer(choice.side)
   for _, other in ipairs(buttonHolder:GetChildren()) do
    if other:IsA("TextButton") then
     local active = other.Name == button.Name
     other.BackgroundColor3 = if active then GameConfig.UI.Accent else GameConfig.UI.Panel
     other.TextColor3 = if active then Color3.fromRGB(20, 22, 30) else GameConfig.UI.Text
    end
   end
  end)
 end
end

local function renderPhase(payload: any)
	local previousPhase = if currentState then currentState.phase else nil
	currentState = payload
	local phase = tostring(payload.phase or "Unknown")
	if phase ~= previousPhase then selectedVote = nil; selectedDebateSide = nil end
	phaseLabel.Text = tostring(payload.heading or string.upper(phase))
	description.Text = tostring(payload.description or "The plaza is waiting for a sufficiently silly cause.")
	timer.Text = "--"
	clearVoteButtons()

	if phase == "Voting" and type(payload.options) == "table" then
		renderVoteButtons(payload.options, payload.voteCounts)
    elseif phase == "Debate" and type(payload.debate) == "table" then
        phaseLabel.Text = tostring(payload.debate.prompt or payload.heading)
        description.Text = tostring(payload.debate.context or payload.description)
        renderDebate(payload.debate, payload.debateCounts)
	elseif phase == "Rally" then
		description.Text = if payload.debateWinner == "TIE" then "Debate result: TIE. Now take that energy to the rally." else string.format("Debate result: Side %s wins. Now take that energy to the rally.", tostring(payload.debateWinner or "?"))
	elseif phase == "Results" and payload.cause then
		description.Text = tostring(payload.cause.title or payload.description or "The plaza has spoken.")
        if payload.factionLeader then showToast("FACTION MVP: " .. tostring(payload.factionLeader) .. " · ALLIANCE MVP: " .. tostring(payload.allianceLeader or "—")) end
        if payload.debateMVP then showToast("DEBATE MVP: " .. tostring(payload.debateMVP)) end
    elseif phase == "TownHall" then
        local c = payload.townHallCounts or {A=0,B=0,C=0}
        description.Text = string.format("A %d · B %d · C %d  |  A: DOUBLE HYPE · B: PIGEON PARADE · C: CONFETTI", c.A or 0, c.B or 0, c.C or 0)
    elseif phase == "TownHallResults" then
        description.Text = "NEW CITY RULE: " .. tostring(payload.description or "A new policy")
    end
    if type(payload.debateReactions) == "table" then
        local r=payload.debateReactions
        if phase=="Debate" then description.Text=string.format("Audience: 👏 %d  😂 %d  🙄 %d",r.clap or 0,r.laugh or 0,r.sideeye or 0) end
    end
    if type(payload.alliances) == "table" and phase=="Rally" then
        local a=payload.alliances
        if a[1] and a[2] then showToast("COALITIONS: "..tostring(a[1].name).." VS "..tostring(a[2].name)) end
    end
    if type(payload.crowdEvent) == "table" then
        showToast("CITY INCIDENT: " .. tostring(payload.crowdEvent.title) .. " — " .. tostring(payload.crowdEvent.detail))
    end
    if type(payload.betrayal) == "table" then
        showToast("BETRAYAL! " .. tostring(payload.betrayal.faction) .. " LEFT " .. tostring(payload.betrayal.from) .. " FOR " .. tostring(payload.betrayal.to))
    end
end

-- Community debate composer: public is the default; private rooms use short-lived invite codes.
local communityRemote = remotes:WaitForChild("DebateCommunity") :: RemoteEvent
local partyRemote = remotes:WaitForChild("Party") :: RemoteEvent
local communityPanel = Instance.new("Frame")
communityPanel.Name = "CommunityDebatePanel"
communityPanel.AnchorPoint = Vector2.new(1, 1)
communityPanel.Position = UDim2.new(1, -14, 1, -14)
communityPanel.Size = UDim2.fromOffset(340, 466)
communityPanel.BackgroundColor3 = GameConfig.UI.Background
communityPanel.BackgroundTransparency = 0.04
communityPanel.BorderSizePixel = 0
communityPanel.Parent = gui
Instance.new("UICorner", communityPanel).CornerRadius = UDim.new(0, 18)
local communityGradient = Instance.new("UIGradient"); communityGradient.Color = ColorSequence.new(Color3.fromRGB(35,39,58), Color3.fromRGB(16,18,28)); communityGradient.Rotation = 90; communityGradient.Parent = communityPanel
local communityScale = Instance.new("UIScale"); communityScale.Parent = communityPanel
local function updateResponsiveLayout()
 local camera = Workspace.CurrentCamera
 if not camera then return end
 local viewport = camera.ViewportSize
 local compact = viewport.X < 700 or viewport.Y < 560
 communityScale.Scale = if viewport.X < 360 then 0.56 elseif viewport.X < 420 then 0.64 elseif viewport.Y < 500 then 0.72 elseif compact then 0.86 else 1
 communityPanel.Position = if compact then UDim2.new(1, -8, 1, -8) else UDim2.new(1, -16, 1, -16)
 panelScale.Scale = if viewport.Y < 500 then 0.78 elseif viewport.X < 420 then 0.82 elseif compact then 0.9 else 1
end
updateResponsiveLayout()
if Workspace.CurrentCamera then Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateResponsiveLayout) end
local communityStroke = Instance.new("UIStroke", communityPanel)
communityStroke.Color = Color3.fromRGB(74, 79, 98)
communityStroke.Transparency = 0.12
communityStroke.Thickness = 1.25

local function communityLabel(name: string, text: string, y: number, height: number, size: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Name=name; label.BackgroundTransparency=1; label.Position=UDim2.fromOffset(12,y); label.Size=UDim2.new(1,-24,0,height)
	label.Font=Enum.Font.GothamBold; label.TextSize=size; label.TextColor3=GameConfig.UI.Text; label.TextXAlignment=Enum.TextXAlignment.Left
	label.TextYAlignment=Enum.TextYAlignment.Center; label.TextWrapped=true; label.Text=text; label.Parent=communityPanel
	return label
end
local communityTitle=communityLabel("Title","GLOBAL DEBATE NETWORK  ·  LIVE",8,20,13)
communityTitle.TextColor3=GameConfig.UI.Accent
local topicBox=Instance.new("TextBox")
topicBox.Name="TopicInput"; topicBox.Position=UDim2.fromOffset(12,34); topicBox.Size=UDim2.new(1,-24,0,38)
topicBox.BackgroundColor3=GameConfig.UI.Panel; topicBox.TextColor3=GameConfig.UI.Text; topicBox.PlaceholderColor3=GameConfig.UI.Muted
topicBox.PlaceholderText="Write a ridiculous motion (12–100 characters)"; topicBox.Text=""; topicBox.ClearTextOnFocus=false
topicBox.Font=Enum.Font.Gotham; topicBox.TextSize=12; topicBox.TextWrapped=true; topicBox.Parent=communityPanel
Instance.new("UICorner",topicBox).CornerRadius=UDim.new(0,9)
local topicStroke=Instance.new("UIStroke",topicBox); topicStroke.Color=Color3.fromRGB(87,94,122); topicStroke.Transparency=0.45
local function communityButton(name:string,text:string,x:number,y:number,w:number,callback:()->())
	local b=Instance.new("TextButton"); b.Name=name; b.Position=UDim2.fromOffset(x,y); b.Size=UDim2.fromOffset(w,30)
	b.BackgroundColor3=GameConfig.UI.Panel; b.TextColor3=GameConfig.UI.Text; b.Font=Enum.Font.GothamBold; b.TextSize=11; b.Text=text; b.Parent=communityPanel
	Instance.new("UICorner",b).CornerRadius=UDim.new(0,9)
 local border=Instance.new("UIStroke",b); border.Color=Color3.fromRGB(87,94,122); border.Transparency=0.6
 b.AutoButtonColor=true
 b.Activated:Connect(callback); return b
end
local categoryBox=Instance.new("TextBox")
categoryBox.Name="CustomCategory"; categoryBox.Position=UDim2.fromOffset(12,114); categoryBox.Size=UDim2.fromOffset(120,30)
categoryBox.BackgroundColor3=GameConfig.UI.Panel; categoryBox.TextColor3=GameConfig.UI.Text; categoryBox.PlaceholderColor3=GameConfig.UI.Muted
categoryBox.PlaceholderText="CATEGORY (3–18 chars)"; categoryBox.Text="Everyday"; categoryBox.ClearTextOnFocus=false
categoryBox.Font=Enum.Font.GothamBold; categoryBox.TextSize=11; categoryBox.Parent=communityPanel
Instance.new("UICorner",categoryBox).CornerRadius=UDim.new(0,9)
communityButton("SubmitPublic","SUBMIT PUBLIC",12,78,152,function()
	communityRemote:FireServer("CreatePublic",topicBox.Text,categoryBox.Text)
end)
communityButton("CreatePrivate","CREATE PRIVATE",172,78,156,function()
	communityRemote:FireServer("CreatePrivate",topicBox.Text)
end)
communityButton("RefreshGlobal","REFRESH",140,114,80,function()
 communityRemote:FireServer("RefreshGlobal")
end)
communityButton("WeeklyTop","WEEKLY TOP",228,114,100,function()
 communityRemote:FireServer("GetWeekly")
end)
local codeBox=Instance.new("TextBox")
codeBox.Name="PrivateCode"; codeBox.Position=UDim2.fromOffset(12,150); codeBox.Size=UDim2.fromOffset(112,28)
codeBox.BackgroundColor3=GameConfig.UI.Panel; codeBox.TextColor3=GameConfig.UI.Text; codeBox.PlaceholderColor3=GameConfig.UI.Muted
codeBox.PlaceholderText="ROOM CODE"; codeBox.Text=""; codeBox.ClearTextOnFocus=false; codeBox.Font=Enum.Font.GothamBold; codeBox.TextSize=12; codeBox.Parent=communityPanel
Instance.new("UICorner",codeBox).CornerRadius=UDim.new(0,8)
communityButton("JoinPrivate","JOIN PRIVATE",132,150,112,function()
	communityRemote:FireServer("JoinPrivate",codeBox.Text)
end)
local queueLabel=communityLabel("PublicQueue","PUBLIC QUEUE: waiting for community topics...",184,42,10)
queueLabel.TextColor3=GameConfig.UI.Muted
local statusLabel=communityLabel("CommunityStatus","Public topics can become the next server-wide debate.",254,22,9)
statusLabel.TextColor3=GameConfig.UI.Secondary
local selectedPublicTopicId: string? = nil
communityButton("BoostPublicTopic","BOOST TOPIC",12,224,152,function()
	if selectedPublicTopicId then communityRemote:FireServer("VoteTopic",selectedPublicTopicId) end
end)
communityButton("ReportPublicTopic","REPORT TOPIC",172,224,156,function()
	if selectedPublicTopicId then communityRemote:FireServer("ReportTopic",selectedPublicTopicId) end
end)
local privateVoteA=communityButton("PrivateVoteA","SUPPORT",12,274,152,function()
	if communityPanel:GetAttribute("PrivateRoomCode") then communityRemote:FireServer("PrivateVote",communityPanel:GetAttribute("PrivateRoomCode"),"A") end
end)
local privateVoteB=communityButton("PrivateVoteB","OPPOSE",172,274,156,function()
	if communityPanel:GetAttribute("PrivateRoomCode") then communityRemote:FireServer("PrivateVote",communityPanel:GetAttribute("PrivateRoomCode"),"B") end
end)
privateVoteA.Visible=false; privateVoteB.Visible=false
local modFeature=communityButton("ModFeature","FEATURE SELECTED",12,316,152,function()
 if selectedPublicTopicId then communityRemote:FireServer("ModerateTopic",selectedPublicTopicId,"Feature") end
end)
local modRemove=communityButton("ModRemove","REMOVE SELECTED",172,316,156,function()
 if selectedPublicTopicId then communityRemote:FireServer("ModerateTopic",selectedPublicTopicId,"Remove") end
end)
modFeature.Visible=false; modRemove.Visible=false
local modRestore=communityButton("ModRestore","RESTORE SELECTED",12,354,152,function()
 if selectedPublicTopicId then communityRemote:FireServer("ModerateTopic",selectedPublicTopicId,"Restore") end
end)
modRestore.Visible=false
local voteFeaturedButton=communityButton("VoteFeatured","VOTE TO FEATURE",12,390,152,function()
 if selectedPublicTopicId then communityRemote:FireServer("VoteFeatured",selectedPublicTopicId) end
end)
communityButton("OpenTournament","FACTION WAR",172,390,156,function() communityRemote:FireServer("GetTournament") end)
local modQueueButton=communityButton("ModQueue","OPEN REVIEW QUEUE",12,426,152,function() communityRemote:FireServer("GetModerationQueue") end)
local modAuditButton=communityButton("ModAudit","AUDIT SELECTED",172,426,156,function() if selectedPublicTopicId then communityRemote:FireServer("GetModerationAudit",selectedPublicTopicId) end end)
modQueueButton.Visible=false; modAuditButton.Visible=false

local function renderPublicTopics(topics:any)
	if type(topics)~="table" or #topics==0 then selectedPublicTopicId=nil; queueLabel.Text="PUBLIC QUEUE: no player topics yet. Be the first."; return end
	selectedPublicTopicId=topics[1].id
	local lines={"UP NEXT — COMMUNITY TOPICS"}
	for i,item in ipairs(topics) do
		if i>3 then break end
		local featuredTag = item.featured and " ★ FEATURED" or (item.communityApproved and " ✓ COMMUNITY PICK" or "")
		local reportTag = (modFeature.Visible and (tonumber(item.reports) or 0) > 0) and (" · " .. tostring(item.reports) .. " reports") or ""
		table.insert(lines,string.format("%d. [%s]%s %s  ·  %d support%s%s",i,string.upper(tostring(item.category or "Everyday")),featuredTag,tostring(item.topic),tonumber(item.votes) or 0,reportTag,""))
	end
	queueLabel.Text=table.concat(lines,"\n")
end

-- Social party panel: invite by in-server player name, accept incoming invites, and manage membership.
local partyPanel=Instance.new("Frame"); partyPanel.Name="PartyPanel"; partyPanel.AnchorPoint=Vector2.new(0,1); partyPanel.Position=UDim2.new(0,14,1,-14); partyPanel.Size=UDim2.fromOffset(270,168); partyPanel.BackgroundColor3=GameConfig.UI.Background; partyPanel.BackgroundTransparency=0.04; partyPanel.BorderSizePixel=0; partyPanel.Parent=gui
Instance.new("UICorner",partyPanel).CornerRadius=UDim.new(0,14)
local partyStroke=Instance.new("UIStroke",partyPanel); partyStroke.Color=Color3.fromRGB(74,79,98); partyStroke.Transparency=0.18
local partyTitle=Instance.new("TextLabel"); partyTitle.BackgroundTransparency=1; partyTitle.Position=UDim2.fromOffset(12,8); partyTitle.Size=UDim2.new(1,-24,0,20); partyTitle.Font=Enum.Font.GothamBlack; partyTitle.TextSize=12; partyTitle.TextXAlignment=Enum.TextXAlignment.Left; partyTitle.TextColor3=GameConfig.UI.Accent; partyTitle.Text="PARTY · 0/6"; partyTitle.Parent=partyPanel
local partyMembers=Instance.new("TextLabel"); partyMembers.BackgroundTransparency=1; partyMembers.Position=UDim2.fromOffset(12,32); partyMembers.Size=UDim2.new(1,-24,0,48); partyMembers.Font=Enum.Font.Gotham; partyMembers.TextSize=10; partyMembers.TextWrapped=true; partyMembers.TextXAlignment=Enum.TextXAlignment.Left; partyMembers.TextYAlignment=Enum.TextYAlignment.Top; partyMembers.TextColor3=GameConfig.UI.Text; partyMembers.Text="Create a party to squad up with friends."; partyMembers.Parent=partyPanel
local partyUserBox=Instance.new("TextBox"); partyUserBox.Position=UDim2.fromOffset(12,86); partyUserBox.Size=UDim2.fromOffset(112,28); partyUserBox.BackgroundColor3=GameConfig.UI.Panel; partyUserBox.TextColor3=GameConfig.UI.Text; partyUserBox.PlaceholderColor3=GameConfig.UI.Muted; partyUserBox.PlaceholderText="PLAYER NAME (INVITE / KICK)"; partyUserBox.Text=""; partyUserBox.Font=Enum.Font.Gotham; partyUserBox.TextSize=10; partyUserBox.Parent=partyPanel; Instance.new("UICorner",partyUserBox).CornerRadius=UDim.new(0,7)
local function partyButton(name,text,x,w,callback)
 local b=Instance.new("TextButton"); b.Name=name; b.Position=UDim2.fromOffset(x,120); b.Size=UDim2.fromOffset(w,30); b.BackgroundColor3=GameConfig.UI.Panel; b.TextColor3=GameConfig.UI.Text; b.Font=Enum.Font.GothamBold; b.TextSize=9; b.Text=text; b.Parent=partyPanel; Instance.new("UICorner",b).CornerRadius=UDim.new(0,7); b.Activated:Connect(callback); return b
end
partyButton("PartyCreate","CREATE",12,54,function() partyRemote:FireServer("Create") end)
partyButton("PartyInvite","INVITE",72,54,function() if partyUserBox.Text~="" then partyRemote:FireServer("Invite",partyUserBox.Text) end end)
partyButton("PartyKick","KICK",132,54,function() if partyUserBox.Text~="" then partyRemote:FireServer("Kick",partyUserBox.Text) end end)
partyButton("PartyLeave","LEAVE",192,66,function() partyRemote:FireServer("Leave") end)
local partyStatus=Instance.new("TextLabel"); partyStatus.BackgroundTransparency=1; partyStatus.Position=UDim2.fromOffset(12,148); partyStatus.Size=UDim2.new(1,-24,0,14); partyStatus.Font=Enum.Font.Gotham; partyStatus.TextSize=9; partyStatus.TextXAlignment=Enum.TextXAlignment.Left; partyStatus.TextColor3=GameConfig.UI.Secondary; partyStatus.Text="Invite friends using their in-server name."; partyStatus.Parent=partyPanel
local partyScale=Instance.new("UIScale"); partyScale.Parent=partyPanel
local function updatePartyResponsive()
 local camera=Workspace.CurrentCamera; if not camera then return end
 local viewport=camera.ViewportSize
 if viewport.X<700 or viewport.Y<560 then
  partyScale.Scale=if viewport.X<360 then 0.46 elseif viewport.X<420 then 0.5 else 0.68
  partyPanel.Position=UDim2.new(0,8,0,220)
 else
  partyScale.Scale=1
  partyPanel.Position=UDim2.new(0,14,1,-14)
 end
end
updatePartyResponsive()
if Workspace.CurrentCamera then Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updatePartyResponsive) end
partyRemote.OnClientEvent:Connect(function(action,data)
 if action=="PartyState" then
  if not data then partyTitle.Text="PARTY · 0/6"; partyMembers.Text="Create a party to squad up with friends."; return end
  partyTitle.Text="PARTY · "..tostring(#(data.members or {})).."/"..tostring(data.maxMembers or 6)
  local lines={}; for _,m in ipairs(data.members or {}) do table.insert(lines,(m.isLeader and "★ " or "• ")..tostring(m.name)) end; partyMembers.Text=table.concat(lines,"\n")
 elseif action=="PartyInvite" then
  partyStatus.Text="INVITE FROM "..tostring(data.fromName).." · tap ACCEPT below"; partyButton("PartyAccept","ACCEPT",12,246,function() partyRemote:FireServer("Accept",data.fromUserId) end)
 elseif action=="PartyNotice" then partyStatus.Text=tostring(data) end
end)
partyRemote:FireServer("Get")

stateRemote.OnClientEvent:Connect(function(payload: any)
	if type(payload) ~= "table" then return end
	if payload.kind == "CommunityDebates" then
		renderPublicTopics(payload.publicTopics)
		if payload.notice then statusLabel.Text=tostring(payload.notice) end
	elseif payload.kind == "ModeratorAccess" then
		local enabled = payload.enabled == true
		modFeature.Visible = enabled
		modRemove.Visible = enabled
        modRestore.Visible = enabled
        modQueueButton.Visible = enabled
        modAuditButton.Visible = enabled
	elseif payload.kind == "WeeklyChampionship" then
		local data = payload.data or {}
		local lines = {"WEEKLY DEBATE CHAMPIONSHIP  ·  " .. tostring(data.week or "CURRENT")}
		for index, item in ipairs(data.players or {}) do
			if index > 4 then break end
			table.insert(lines, string.format("%d. %s  ·  %d pts", index, tostring(item.name), tonumber(item.points) or 0))
		end
		if #lines == 1 then table.insert(lines, "No ranked debates yet this week. Be the first.") end
		queueLabel.Text = table.concat(lines, "\n")
		statusLabel.Text = "WEEKLY STANDINGS · RESET EVERY UTC MONDAY"
    elseif payload.kind == "FactionWar" then
        local data=payload.data or {}; local bracket=data.bracket or {}; local function factionName(id) for _,faction in ipairs(data.factions or {}) do if faction.id==id then return faction.name end end; return tostring(id) end; local finalists=if bracket.final then string.upper(factionName(bracket.final.a)).." VS "..string.upper(factionName(bracket.final.b)) else "SEMIFINAL WINNERS TBD"; local lines={"FACTION WAR · "..tostring(data.week or "CURRENT"),"BRACKET: "..tostring(bracket.phase or "SEMIFINALS"),"FINAL: "..finalists..(data.trophy and (" · CHAMPION "..factionName(data.trophy.faction)) or "")}
        queueLabel.Text=table.concat(lines,"\n"); statusLabel.Text="FACTION WAR · FRIDAY 18:00 UTC FINAL · DETAILS IN SOCIAL HUB"
    elseif payload.kind == "ModerationQueue" then
        local lines={"MODERATION REVIEW QUEUE"}; local first=nil; for i,item in ipairs(payload.items or {}) do if i>5 then break end; if not first then first=item end; table.insert(lines,string.format("%s · %d REPORTS · %s",tostring(item.id),item.reports or 0,tostring(item.topic))) end
        if first then selectedPublicTopicId=first.id end
        if #lines==1 then table.insert(lines,"No topics currently require review.") end
        queueLabel.Text=table.concat(lines,"\n"); statusLabel.Text="MODERATOR REVIEW · SELECT A TOPIC IN THE FEED TO TAKE ACTION"
    elseif payload.kind == "ModerationAudit" then
        local lines={"MODERATION AUDIT · "..tostring(payload.topicId)}; for i,item in ipairs(payload.entries or {}) do if i>5 then break end; table.insert(lines,string.format("%s · %s · %s",os.date("!%m/%d %H:%M",item.at or 0),tostring(item.action),tostring(item.actorId))) end
        queueLabel.Text=table.concat(lines,"\n"); statusLabel.Text="AUDIT HISTORY · UTC"
	elseif payload.kind == "CommunityNotice" then
		statusLabel.Text=tostring(payload.text or "Community debate updated.")
	elseif payload.kind == "PrivateDebate" then
		communityPanel:SetAttribute("PrivateRoomCode",payload.code)
		codeBox.Text=tostring(payload.code or "")
		statusLabel.Text="PRIVATE ROOM "..tostring(payload.code).." · share this code with friends"
		queueLabel.Text="PRIVATE MOTION: "..tostring(payload.topic)
		privateVoteA.Visible=true; privateVoteB.Visible=true
	elseif payload.kind == "PrivateDebateCounts" then
		statusLabel.Text=string.format("PRIVATE VOTES  ·  SUPPORT %d  ·  OPPOSE %d",payload.a or 0,payload.b or 0)
	elseif payload.kind == "PrivateDebateResult" then
		statusLabel.Text="PRIVATE RESULT: SIDE "..tostring(payload.winner).." WINS"
		communityPanel:SetAttribute("PrivateRoomCode",nil)
		privateVoteA.Visible=false; privateVoteB.Visible=false
	elseif payload.kind == "Profile" then
		profile.coins = tonumber(payload.coins) or 0
		profile.xp = tonumber(payload.xp) or 0
		profile.level = tonumber(payload.level) or 1
		updateWallet()
        updateDaily(payload.daily)
	elseif payload.kind == "Hype" then
		currentHype = math.clamp(tonumber(payload.value) or 0, 0, maximumHype)
		maximumHype = math.max(1, tonumber(payload.maximum) or maximumHype)
		hypeLabel.Text = string.format("HYPE  %d / %d", currentHype, maximumHype)
    elseif payload.kind == "DailyProgress" then
        updateDaily(payload.daily)
    elseif payload.kind == "DailyClaim" then
        profile.coins = tonumber(payload.coins) or profile.coins
        profile.xp = tonumber(payload.xp) or profile.xp
        profile.level = tonumber(payload.level) or profile.level
        updateWallet(); updateDaily(payload.daily)
        showToast(if payload.ok then "DAILY REWARD CLAIMED!" else "DAILY: " .. tostring(payload.status))
    elseif payload.kind == "FactionJoined" then
        showToast("MOVEMENT JOINED: " .. tostring(payload.name) .. " — " .. tostring(payload.motto))
    elseif payload.kind == "ShopResult" then
        profile.coins = tonumber(payload.coins) or profile.coins
        updateWallet()
        showToast((if payload.ok then "SHOP: " else "SHOP: ") .. tostring(payload.status) .. " · " .. tostring(payload.item))
	elseif payload.kind == "Reward" then
		profile.coins += tonumber(payload.coins) or 0
		profile.xp += tonumber(payload.xp) or 0
		profile.level = math.floor(profile.xp / 100) + 1
		updateWallet()
		showToast(string.format("+%s COINS  ·  +%s XP  ·  %s HYPE  ·  DEBATE REP %s", tostring(payload.coins or 0), tostring(payload.xp or 0), tostring(payload.hype or 0), tostring(payload.debateReputation or 0)))
	elseif payload.kind == "Phase" then
		currentHype = 0
		hypeLabel.Text = string.format("HYPE  0 / %d", maximumHype)
		renderPhase(payload)
	end
end)

task.spawn(function()
	while gui.Parent do
		task.wait(0.2)
		if currentState and type(currentState.endsAt) == "number" then
			local remaining = math.max(0, math.ceil(currentState.endsAt - Workspace:GetServerTimeNow()))
			timer.Text = string.format("%02d:%02d", math.floor(remaining / 60), remaining % 60)
		end
		if currentState and currentState.phase == "Voting" and buttonHolder.Parent then
			local counts = currentState.voteCounts
			if type(counts) == "table" then
				for _, button in ipairs(buttonHolder:GetChildren()) do
					if button:IsA("TextButton") then
						local id = string.match(button.Name, "^Vote_(.+)$")
						if id then
							local option
						for _, candidate in ipairs(currentState.options or {}) do
							if candidate.id == id then option = candidate break end
						end
						if option then button.Text = string.format("%s\n%d VOTES", option.shortTitle or option.title, counts[id] or 0) end
						end
					end
				end
			end
		end
	end
end)
