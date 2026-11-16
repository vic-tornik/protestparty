--!strict
-- Server-authoritative same-server social parties. Party state is ephemeral; no profile schema change.
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local PartyService = {}
local MAX_MEMBERS = 6
local INVITE_TTL = 45
local parties: {[string]: any} = {}
local membership: {[number]: string} = {}
local invites: {[number]: {[number]: number}} = {}
local requestAt: {[number]: number} = {}
local inviteAt: {[number]: number} = {}
local remote: RemoteEvent
local function partyFor(player: Player): any? local id=membership[player.UserId]; return if id then parties[id] else nil end
local function snapshot(party: any): any
 local members={}; for userId in pairs(party.members) do local p=Players:GetPlayerByUserId(userId); if p then table.insert(members,{userId=userId,name=p.DisplayName,isLeader=userId==party.leader}) end end
 table.sort(members,function(a,b) if a.isLeader then return true elseif b.isLeader then return false end return a.name<b.name end)
 return {partyId=party.id,clubId=party.clubId,leader=party.leader,members=members,maxMembers=MAX_MEMBERS}
end
local function push(party: any)
 local data=snapshot(party); for userId in pairs(party.members) do local p=Players:GetPlayerByUserId(userId); if p then remote:FireClient(p,"PartyState",data) end end
end
local function allowed(player: Player): boolean
 if player.Parent~=Players or player:GetAttribute("ProfileLoaded")~=true then return false end
 local now=os.clock(); if now-(requestAt[player.UserId] or 0)<0.35 then return false end; requestAt[player.UserId]=now; return true
end
function PartyService.GetPartySnapshot(player: Player): any?
 local party=partyFor(player)
 return if party then snapshot(party) else nil
end
function PartyService.GetPartyMembers(player: Player): {number}
 local party=partyFor(player); local ids={}
 if party then for userId in pairs(party.members) do table.insert(ids,userId) end end
 return ids
end
local function removeMember(party: any,userId: number)
 party.members[userId]=nil; membership[userId]=nil
 local count=0; for _ in pairs(party.members) do count+=1 end
 if count==0 then parties[party.id]=nil
 elseif party.leader==userId then for nextId in pairs(party.members) do party.leader=nextId; break end end
 if parties[party.id] then push(party) end
end
function PartyService.Start(partyRemote: RemoteEvent)
 remote=partyRemote
 remote.OnServerEvent:Connect(function(player,action,targetUserId)
  if type(action)~="string" or not allowed(player) then return end
  if action=="Create" then
   if partyFor(player) then return end
   local id="party_"..HttpService:GenerateGUID(false)
   local party={id=id,clubId="club_"..tostring(player.UserId),leader=player.UserId,members={[player.UserId]=true},createdAt=os.time()}; parties[id]=party; membership[player.UserId]=id; push(party)
  elseif action=="Invite" then
   local party=partyFor(player); if not party or party.leader~=player.UserId or type(targetUserId)~="string" or #targetUserId<2 or #targetUserId>32 then return end
   if os.clock()-(inviteAt[player.UserId] or 0)<5 then remote:FireClient(player,"PartyNotice","Wait before sending another invite."); return end
   inviteAt[player.UserId]=os.clock()
   local target: Player? = nil; local query=string.lower(targetUserId)
   for _,candidate in ipairs(Players:GetPlayers()) do if candidate~=player and (string.lower(candidate.Name)==query or string.lower(candidate.DisplayName)==query) then target=candidate; break end end
   if not target or partyFor(target) then return end
   local count=0; for _ in pairs(party.members) do count+=1 end; if count>=MAX_MEMBERS then return end
   invites[target.UserId]=invites[target.UserId] or {}; invites[target.UserId][player.UserId]=os.time()+INVITE_TTL
   remote:FireClient(target,"PartyInvite",{fromUserId=player.UserId,fromName=player.DisplayName,expiresAt=os.time()+INVITE_TTL})
   remote:FireClient(player,"PartyNotice","Invite sent to "..target.DisplayName..".")
  elseif action=="Accept" then
   if type(targetUserId)~="number" or partyFor(player) then return end
   local inviter=math.floor(targetUserId); local expiry=invites[player.UserId] and invites[player.UserId][inviter]
   if not expiry or expiry<os.time() then return end
   invites[player.UserId][inviter]=nil
   local inviterPlayer=Players:GetPlayerByUserId(inviter); local party=if inviterPlayer then partyFor(inviterPlayer) else nil
   if not party then return end
   local count=0; for _ in pairs(party.members) do count+=1 end; if count>=MAX_MEMBERS then return end
   party.members[player.UserId]=true; membership[player.UserId]=party.id; push(party)
  elseif action=="Leave" then
   local party=partyFor(player); if party then removeMember(party,player.UserId); remote:FireClient(player,"PartyState",nil) end
  elseif action=="Kick" then
   local party=partyFor(player); if not party or party.leader~=player.UserId or type(targetUserId)~="string" then return end
   local query=string.lower(targetUserId); local targetId=nil
   for memberId in pairs(party.members) do local member=Players:GetPlayerByUserId(memberId); if member and memberId~=player.UserId and (string.lower(member.Name)==query or string.lower(member.DisplayName)==query) then targetId=memberId; break end end
   if not targetId then return end
   local target=Players:GetPlayerByUserId(targetId); removeMember(party,targetId); if target then remote:FireClient(target,"PartyState",nil); remote:FireClient(target,"PartyNotice","You were removed from the party.") end
  elseif action=="Get" then
   local party=partyFor(player); remote:FireClient(player,"PartyState",if party then snapshot(party) else nil)
  end
 end)
 Players.PlayerRemoving:Connect(function(player)
  local party=partyFor(player); if party then removeMember(party,player.UserId) end
  membership[player.UserId]=nil; invites[player.UserId]=nil; requestAt[player.UserId]=nil; inviteAt[player.UserId]=nil
  for _,byInviter in pairs(invites) do byInviter[player.UserId]=nil end
 end)
end
return PartyService
