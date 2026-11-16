--!strict
-- Single server entry point. All progression and reward authority stays under ServerScriptService.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Services = script.Parent:WaitForChild("Services")
local ProfileService = require(Services:WaitForChild("ProfileService"))
local WorldBuilder = require(Services:WaitForChild("WorldBuilder"))
local RoundService = require(Services:WaitForChild("RoundService"))
local DebateCommunityService = require(Services:WaitForChild("DebateCommunityService"))
local PartyService = require(Services:WaitForChild("PartyService"))
local SocialSystemsService = require(Services:WaitForChild("SocialSystemsService"))

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end

local function getOrCreateRemote(name: string): RemoteEvent
	local existing = remotes:FindFirstChild(name)
	if existing and existing:IsA("RemoteEvent") then return existing end
	if existing then existing:Destroy() end
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = remotes
	return remote
end

local stateRemote = getOrCreateRemote("StateUpdate")
local voteRemote = getOrCreateRemote("VoteCause")
local debateVoteRemote = getOrCreateRemote("VoteDebate")
local communityDebateRemote = getOrCreateRemote("DebateCommunity")
local partyRemote = getOrCreateRemote("Party")
local socialRemote = getOrCreateRemote("SocialSystems")
local worldData = WorldBuilder.Build()

ProfileService.StartAutosave()
DebateCommunityService.Start(communityDebateRemote, stateRemote)
PartyService.Start(partyRemote)
SocialSystemsService.Start(socialRemote, stateRemote, PartyService)
RoundService.Start(ProfileService, stateRemote, voteRemote, debateVoteRemote, worldData, SocialSystemsService)

local function loadPlayer(player: Player)
	player:SetAttribute("ProfileLoaded", false)
	local success, reason = ProfileService.Load(player)
	if not success then
		warn(string.format("[Bootstrap] Safe profile load failed for %d (%s). Kicking to prevent blank-profile overwrite.", player.UserId, tostring(reason)))
		if player.Parent == Players then
			player:Kick("We could not safely load your saved data. Please rejoin in a moment; your existing progress was not replaced.")
		end
	end
end

Players.PlayerAdded:Connect(function(player)
	task.spawn(loadPlayer, player)
end)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(loadPlayer, player)
end

Players.PlayerRemoving:Connect(function(player)
	task.spawn(function()
		ProfileService.Save(player, true)
	end)
end)

game:BindToClose(function()
	ProfileService.ReleaseAll()
end)
