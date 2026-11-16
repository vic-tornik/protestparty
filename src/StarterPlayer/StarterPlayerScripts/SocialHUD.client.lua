--!strict
-- Integrated social hub for v0.8.0. All actions are requests; the server validates and persists them.
local Players=game:GetService("Players")
local TweenService=game:GetService("TweenService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local player=Players.LocalPlayer
local remotes=ReplicatedStorage:WaitForChild("Remotes")
local social=remotes:WaitForChild("SocialSystems") :: RemoteEvent
local state=remotes:WaitForChild("StateUpdate") :: RemoteEvent
local gui=Instance.new("ScreenGui"); gui.Name="SocialSystemsHUD"; gui.ResetOnSpawn=false; gui.IgnoreGuiInset=false; gui.Parent=player:WaitForChild("PlayerGui")
local accent=Color3.fromRGB(191,255,64); local panelColor=Color3.fromRGB(23,26,37); local muted=Color3.fromRGB(174,180,194)
local function corner(parent: Instance, radius: number) local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,radius); c.Parent=parent end
local function text(parent: Instance, value: string, size: number, bold: boolean?): TextLabel
 local l=Instance.new("TextLabel"); l.BackgroundTransparency=1; l.Text=value; l.TextColor3=Color3.fromRGB(245,247,250); l.Font=if bold then Enum.Font.GothamBold else Enum.Font.Gotham; l.TextSize=size; l.TextWrapped=true; l.TextXAlignment=Enum.TextXAlignment.Left; l.Parent=parent; return l
end
local function button(parent: Instance, label: string, callback: ()->(), width: number?): TextButton
 local b=Instance.new("TextButton"); b.Size=UDim2.new(0,width or 124,0,34); b.BackgroundColor3=Color3.fromRGB(42,47,63); b.TextColor3=Color3.fromRGB(246,247,250); b.Font=Enum.Font.GothamMedium; b.TextSize=12; b.Text=label; b.AutoButtonColor=true; b.Parent=parent; corner(b,8); b.Activated:Connect(callback); return b
end
local function input(parent: Instance, placeholder: string): TextBox
 local box=Instance.new("TextBox"); box.Size=UDim2.new(1,0,0,32); box.BackgroundColor3=Color3.fromRGB(35,39,53); box.TextColor3=Color3.fromRGB(245,247,250); box.PlaceholderColor3=muted; box.PlaceholderText=placeholder; box.Font=Enum.Font.Gotham; box.TextSize=12; box.ClearTextOnFocus=false; box.Text=""; box.Parent=parent; corner(box,7); return box
end
local toggle=button(gui,"SOCIAL HUB",function() end,132); toggle.AnchorPoint=Vector2.new(1,0); toggle.Position=UDim2.new(1,-18,0,18); toggle.BackgroundColor3=accent; toggle.TextColor3=Color3.fromRGB(20,22,30)
local panel=Instance.new("Frame"); panel.Name="SocialPanel"; panel.Size=UDim2.fromOffset(360,510); panel.AnchorPoint=Vector2.new(1,0); panel.Position=UDim2.new(1,-18,0,60); panel.BackgroundColor3=panelColor; panel.Visible=false; panel.Parent=gui; corner(panel,14)
local stroke=Instance.new("UIStroke"); stroke.Color=Color3.fromRGB(72,79,101); stroke.Transparency=.25; stroke.Parent=panel
local sizeConstraint=Instance.new("UISizeConstraint"); sizeConstraint.MinSize=Vector2.new(280,360); sizeConstraint.MaxSize=Vector2.new(420,620); sizeConstraint.Parent=panel
local camera=workspace.CurrentCamera
local function resizePanel() if not camera then return end; local viewport=camera.ViewportSize; if viewport.X<420 then panel.Size=UDim2.new(1,-24,0,math.max(360,math.min(510,viewport.Y-100))); panel.Position=UDim2.new(1,-12,0,60) else panel.Size=UDim2.fromOffset(360,510); panel.Position=UDim2.new(1,-18,0,60) end end
resizePanel(); if camera then camera:GetPropertyChangedSignal("ViewportSize"):Connect(resizePanel) end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function() camera=workspace.CurrentCamera; resizePanel(); if camera then camera:GetPropertyChangedSignal("ViewportSize"):Connect(resizePanel) end end)
local title=text(panel,"THE CIVIC NETWORK",18,true); title.Position=UDim2.fromOffset(16,12); title.Size=UDim2.new(1,-32,0,26)
local subtitle=text(panel,"PARTIES · FACTIONS · IDENTITY · EVENTS",10); subtitle.TextColor3=muted; subtitle.Position=UDim2.fromOffset(16,38); subtitle.Size=UDim2.new(1,-32,0,18)
local scroll=Instance.new("ScrollingFrame"); scroll.Position=UDim2.fromOffset(12,64); scroll.Size=UDim2.new(1,-24,1,-76); scroll.BackgroundTransparency=1; scroll.BorderSizePixel=0; scroll.ScrollBarThickness=4; scroll.CanvasSize=UDim2.new(); scroll.AutomaticCanvasSize=Enum.AutomaticSize.Y; scroll.Parent=panel
local layout=Instance.new("UIListLayout"); layout.Padding=UDim.new(0,7); layout.SortOrder=Enum.SortOrder.LayoutOrder; layout.Parent=scroll
local padding=Instance.new("UIPadding"); padding.PaddingBottom=UDim.new(0,10); padding.Parent=scroll
local function section(name: string)
 local label=text(scroll,name,12,true); label.TextColor3=accent; label.Size=UDim2.new(1,-4,0,22)
end
local function row()
 local f=Instance.new("Frame"); f.Size=UDim2.new(1,-4,0,36); f.BackgroundTransparency=1; f.Parent=scroll
 local l=Instance.new("UIListLayout"); l.FillDirection=Enum.FillDirection.Horizontal; l.Padding=UDim.new(0,6); l.Parent=f; return f
end
local status=text(scroll,"Welcome. Your actions are validated by the game server.",11); status.Size=UDim2.new(1,-4,0,44); status.TextColor3=muted
local function notice(value: string) status.Text=value end
local function prettyList(values: {any}): string local output={}; for _,value in ipairs(values or {}) do table.insert(output,string.upper(string.gsub(tostring(value),"_"," "))) end; return table.concat(output,", ") end

local banner=Instance.new("Frame"); banner.Name="ChampionshipBroadcastBanner"; banner.AnchorPoint=Vector2.new(.5,0); banner.Size=UDim2.new(1,-32,0,62); banner.Position=UDim2.new(.5,0,0,-76); banner.BackgroundColor3=Color3.fromRGB(25,29,42); banner.Visible=false; banner.Parent=gui; corner(banner,12)
local bannerConstraint=Instance.new("UISizeConstraint"); bannerConstraint.MaxSize=Vector2.new(520,62); bannerConstraint.MinSize=Vector2.new(250,62); bannerConstraint.Parent=banner
local bannerStroke=Instance.new("UIStroke"); bannerStroke.Color=accent; bannerStroke.Transparency=.15; bannerStroke.Thickness=1.4; bannerStroke.Parent=banner
local bannerText=text(banner,"THE PLAZA HAS A NEW STORY",14,true); bannerText.Position=UDim2.fromOffset(14,8); bannerText.Size=UDim2.new(1,-28,1,-16); bannerText.TextXAlignment=Enum.TextXAlignment.Center
local bannerSequence=0
local function showBroadcast(message: string)
 bannerSequence+=1; local sequence=bannerSequence; bannerText.Text=message; banner.Visible=true; banner.Position=UDim2.new(.5,0,0,-76)
 TweenService:Create(banner,TweenInfo.new(.35,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{Position=UDim2.new(.5,0,0,14)}):Play()
 task.delay(7,function() if sequence~=bannerSequence then return end; local tween=TweenService:Create(banner,TweenInfo.new(.3,Enum.EasingStyle.Quad,Enum.EasingDirection.In),{Position=UDim2.new(.5,0,0,-76)}); tween:Play(); tween.Completed:Wait(); if sequence==bannerSequence then banner.Visible=false end end)
end
section("PARTY OPERATIONS")
local r=row(); button(r,"Start protest",function() social:FireServer("StartPartyProtest") end); button(r,"Join protest",function() social:FireServer("JoinPartyProtest") end)
r=row(); button(r,"Party reputation",function() social:FireServer("GetParty") end)
section("FACTION WAR")
r=row(); button(r,"View bracket",function() social:FireServer("GetWar") end); button(r,"World standings",function() social:FireServer("GetWar") end)
local warLabel=text(scroll,"Faction war data has not been loaded.",11); warLabel.Size=UDim2.new(1,-4,0,150); warLabel.TextColor3=muted
section("PLAYER IDENTITY")
r=row(); button(r,"My profile",function() social:FireServer("GetIdentity") end); button(r,"Daily event",function() social:FireServer("GetEvent") end)
local profileLabel=text(scroll,"Profile: reputation, title, badges and achievements.",11); profileLabel.Size=UDim2.new(1,-4,0,130); profileLabel.TextColor3=muted
local profileUserBox=input(scroll,"Public profile UserId (blank = you)"); r=row(); button(r,"View profile",function() local id=tonumber(profileUserBox.Text); social:FireServer("GetIdentity",id) end)
r=row(); button(r,"Title: MVP",function() social:FireServer("SetTitle","Audience MVP") end); button(r,"Title: Captain",function() social:FireServer("SetTitle","Party Captain") end)
r=row(); button(r,"Title: Champion",function() social:FireServer("SetTitle","Faction Champion") end); button(r,"Title: Oracle",function() social:FireServer("SetTitle","Civic Oracle") end)
local bioBox=input(scroll,"Profile bio (100 characters, filtered)"); r=row(); button(r,"Save bio",function() social:FireServer("SetBio",bioBox.Text) end)
section("SPECTATOR PREDICTIONS")
local predictAButton=button(row(),"Predict A",function() social:FireServer("Predict","A") end); local predictBButton=button(row(),"Predict B",function() social:FireServer("Predict","B") end); predictAButton.TextSize=10; predictBButton.TextSize=10
local eventLabel=text(scroll,"Predictions close 30 minutes after the scheduled event begins.",11); eventLabel.Size=UDim2.new(1,-4,0,145); eventLabel.TextColor3=muted
section("PLAYER REPORT")
local targetBox=input(scroll,"Reported player's UserId"); local reasonBox=input(scroll,"Short reason (no personal information)")
r=row(); button(r,"Submit report",function() local id=tonumber(targetBox.Text); if not id then notice("Enter a valid numeric UserId."); return end; social:FireServer("ReportPlayer",id,reasonBox.Text) end,150)
local staffElements={}
local function staffOnly(instance: GuiObject): GuiObject instance.Visible=false; table.insert(staffElements,instance); return instance end
local staffButton=staffOnly(button(scroll,"Open staff dashboard",function() social:FireServer("GetStaffDashboard") end,190))
local caseList=staffOnly(Instance.new("Frame")); caseList.Name="CaseList"; caseList.Size=UDim2.new(1,-4,0,0); caseList.AutomaticSize=Enum.AutomaticSize.Y; caseList.BackgroundTransparency=1; caseList.Parent=scroll
local caseListLayout=Instance.new("UIListLayout"); caseListLayout.Padding=UDim.new(0,5); caseListLayout.SortOrder=Enum.SortOrder.LayoutOrder; caseListLayout.Parent=caseList
local caseLabel=staffOnly(text(scroll,"Staff case queue appears here when authorized.",10)); caseLabel.Size=UDim2.new(1,-4,0,150); caseLabel.TextColor3=muted
local caseIdBox=staffOnly(input(scroll,"Case ID")); local assignUserBox=staffOnly(input(scroll,"Moderator UserId (blank = me)")); local noteBox=staffOnly(input(scroll,"Internal note / appeal text"))
r=staffOnly(row()); button(r,"Assign to me",function() social:FireServer("AssignCase",caseIdBox.Text,player.UserId) end); button(r,"Assign by UserId",function() local id=tonumber(assignUserBox.Text); social:FireServer("AssignCase",caseIdBox.Text,id or player.UserId) end)
r=staffOnly(row()); button(r,"Add staff note",function() social:FireServer("AddCaseNote",caseIdBox.Text,noteBox.Text) end)
r=staffOnly(row()); button(r,"Resolve case",function() social:FireServer("ResolveCase",caseIdBox.Text) end); button(r,"Submit appeal",function() social:FireServer("AppealCase",caseIdBox.Text,noteBox.Text) end)
r=staffOnly(row()); button(r,"Accept appeal",function() social:FireServer("DecideAppeal",caseIdBox.Text,true) end); button(r,"Reject appeal",function() social:FireServer("DecideAppeal",caseIdBox.Text,false) end)
toggle.Activated:Connect(function() panel.Visible=not panel.Visible; if panel.Visible then social:FireServer("GetWar"); task.delay(.5,function() if panel.Visible then social:FireServer("GetIdentity") end end); task.delay(1,function() if panel.Visible then social:FireServer("GetEvent") end end) end end)
state.OnClientEvent:Connect(function(data)
 if type(data)~="table" then return end
 if data.kind=="ModeratorAccess" then for _,element in ipairs(staffElements) do element.Visible=data.enabled==true end
 elseif data.kind=="WorldNotice" then local message=tostring(data.text or "The plaza has changed."); notice(message); showBroadcast(message)
 elseif data.kind=="ChampionshipBroadcast" then local payload=data.data or {}; local message=tostring(payload.title or "GLOBAL DEBATE BROADCAST").."  ·  "..tostring(payload.winner or payload.topic or (payload.announcement and "THE EVENT IS LIVE") or "RESULTS ARE IN")..(payload.mvpName and (" · MVP "..tostring(payload.mvpName)) or ""); notice(message); showBroadcast(message)
 elseif data.kind=="FactionWarUpdate" then local war=data.data or {}; local lines={"WEEK "..tostring(war.week),"BRACKET: "..tostring(war.bracket and war.bracket.phase or "PENDING")}; for _,f in ipairs(war.factions or {}) do table.insert(lines,f.name.." · "..tostring(f.score).." pts") end; if not war.scoresAvailable then table.insert(lines,"SCORES TEMPORARILY UNAVAILABLE") end; warLabel.Text=table.concat(lines,"\n") end
end)
social.OnClientEvent:Connect(function(kind,data)
 if kind=="Notice" then notice(tostring(data))
 elseif kind=="PartyChallenge" then notice(tostring(data.title).." — "..tostring(data.detail))
 elseif kind=="PartyAchievement" then notice("Achievement unlocked: "..tostring(data.name).." · +"..tostring(data.reputation).." reputation")
 elseif kind=="FactionWar" then
  local lines={"WEEK "..tostring(data.week),"BRACKET: "..tostring(data.bracket and data.bracket.phase or "PENDING"),"FINAL: "..tostring(data.bracket and data.bracket.finalSchedule or "TBD")..(data.bracket and data.bracket.finalAt and (" · "..os.date("!%Y-%m-%d %H:%M",data.bracket.finalAt)) or "")}
  if data.bracketAvailable==false then table.insert(lines,"BRACKET STATE TEMPORARILY UNAVAILABLE") end
  if data.bracket and data.bracket.final then table.insert(lines,"FINALISTS: "..tostring(data.bracket.final.a).." vs "..tostring(data.bracket.final.b)) end
  for _,f in ipairs(data.factions or {}) do table.insert(lines,f.name.." · "..tostring(f.score).." pts"..(f.territory and " · TERRITORY" or "")) end
  if data.bracket and data.bracket.fixtures then for _,fixture in ipairs(data.bracket.fixtures) do table.insert(lines,"SEMI: "..tostring(fixture.a).." vs "..tostring(fixture.b).." · "..tostring(fixture.winner or "PENDING")) end end
  if data.trophy then table.insert(lines,"TROPHY: "..tostring(data.trophy.faction)) end
  if not data.scoresAvailable then table.insert(lines,"SCORES TEMPORARILY UNAVAILABLE") end
  warLabel.Text=table.concat(lines,"\n")
 elseif kind=="PublicProfile" then
  local history={}; for i=1,math.min(3,#(data.history or {})) do table.insert(history,tostring(data.history[i].event)) end
  profileLabel.Text=string.format("%s\n%s · Reputation %s\nBio: %s\nBadges: %s\nAchievements: %s\nHistory: %s",tostring(data.name),tostring(data.title),tostring(data.reputation),tostring(data.bio),prettyList(data.badges or {}),prettyList(data.achievements or {}),table.concat(history," · "))
 elseif kind=="PartySummary" then
  notice("Party members: "..tostring(#(data.party.members or {})).." · Party reputation: "..tostring(data.reputation)..(data.available and "" or " · DATASTORE UNAVAILABLE"))
 elseif kind=="GlobalEvent" then
  local e=data.event or {}; local debate=data.debate or {}; local predictions=data.predictions or {}; local predictionOpen=e.predictionOpen==true; predictAButton.Active=predictionOpen; predictBButton.Active=predictionOpen; predictAButton.AutoButtonColor=predictionOpen; predictBButton.AutoButtonColor=predictionOpen; predictAButton.Text=(predictionOpen and "PREDICT A · " or "CLOSED · ")..string.sub(tostring(debate.sideA or "SIDE A"),1,22); predictBButton.Text=(predictionOpen and "PREDICT B · " or "CLOSED · ")..string.sub(tostring(debate.sideB or "SIDE B"),1,22); eventLabel.Text=string.format("%s\n%s\n%s\nA: %s\nB: %s\nStarts: %s UTC · Predictions close: %s UTC\nVotes — A: %s · B: %s",tostring(e.title),tostring(e.phase),tostring(debate.prompt or "Scheduled debate topic pending"),tostring(debate.sideA or "SIDE A"),tostring(debate.sideB or "SIDE B"),os.date("!%Y-%m-%d %H:%M",e.startsAt or os.time()),os.date("!%H:%M",e.predictionClosesAt or os.time()),tostring(predictions.A or 0),tostring(predictions.B or 0))..(predictions.result and ("\nRESULT: "..tostring(predictions.result)) or "")..(predictions.myPrediction and ("\nYOUR PREDICTION: "..tostring(predictions.myPrediction)) or "")..(data.predictionsAvailable==false and "\nPREDICTION SERVICE UNAVAILABLE" or "")
 elseif kind=="StaffDashboard" then
  for _,child in ipairs(caseList:GetChildren()) do if child:IsA("TextButton") then child:Destroy() end end
  if not data.available then caseLabel.Text="STAFF QUEUE TEMPORARILY UNAVAILABLE. Durable case records were not deleted."; return end
  local cases=data.cases or {}; caseLabel.Text="STAFF CASE QUEUE · "..tostring(#cases).." cases · select a case to inspect details"
  for _,case in ipairs(cases) do
   local item=Instance.new("TextButton"); item.Size=UDim2.new(1,0,0,34); item.BackgroundColor3=Color3.fromRGB(39,44,59); item.TextColor3=Color3.fromRGB(245,247,250); item.Font=Enum.Font.GothamMedium; item.TextSize=10; item.TextXAlignment=Enum.TextXAlignment.Left; item.Text=string.upper(tostring(case.status)).." · "..string.sub(tostring(case.id),1,14).."… · target "..tostring(case.target); item.Parent=caseList; corner(item,7)
   item.Activated:Connect(function()
    caseIdBox.Text=tostring(case.id); local audit={}; for i=math.max(1,#(case.audit or {})-3),#(case.audit or {}) do local entry=case.audit[i]; table.insert(audit,tostring(entry.action).." by "..tostring(entry.actor)) end
    local notes={}; for i=math.max(1,#(case.notes or {})-2),#(case.notes or {}) do local entry=case.notes[i]; table.insert(notes,tostring(entry.by)..": "..tostring(entry.text)) end
    local appeals={}; for _,entry in ipairs(case.appeals or {}) do table.insert(appeals,tostring(entry.status)..": "..tostring(entry.text)) end
    caseLabel.Text=string.format("%s\nReporter: %s · Target: %s\nReason: %s\nAssigned: %s\nNotes: %s\nAppeals: %s\nAudit: %s",tostring(case.status),tostring(case.reporter),tostring(case.target),tostring(case.reason),tostring(case.assignedTo or "unassigned"),table.concat(notes," | "),table.concat(appeals," | "),table.concat(audit," · "))
   end)
  end
 end
end)
