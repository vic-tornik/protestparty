--!strict
local GameConfig = {
 ExperienceName = "PROTEST PARTY", Version = "0.8.0",
 DataStoreNameStudio = "ProtestParty_PlayerData_STUDIO", DataStoreNameLive = "ProtestParty_PlayerData_LIVE",
 ProfileSchemaVersion = 3,
 -- Add Roblox UserIds here before enabling the in-game moderation console. Empty by default.
 ModeratorUserIds = {},
 ProfileAutosaveSeconds = 60, ProfileLockSeconds = 180, ProfileLoadTimeoutSeconds = 100, ProfileMaxSaveRetries = 3,
 Round = { IntermissionSeconds=12, VotingSeconds=15, DebateSeconds=22, RallySeconds=75, ResultsSeconds=10, TownHallSeconds=14, MaxHypePerPlayer=30, HypeCooldownSeconds=2.5, StationMaxDistance=16 },
 Rewards = { ParticipationCoins=8, CoinsPerHype=2, ParticipationXP=10, DebateCoins=4, DebateXP=5, XPPerHype=3, MaxCoins=1000000000, MaxXP=1000000000 },
 World = { GroundSize=Vector3.new(300,2,300), StationCount=4, StationSpacing=18 },
 Shop = { MaxPrice=2500 },
 UI = { Accent=Color3.fromRGB(191,255,64), Secondary=Color3.fromRGB(169,119,255), Background=Color3.fromRGB(20,22,30), Panel=Color3.fromRGB(31,34,45), Text=Color3.fromRGB(246,247,250), Muted=Color3.fromRGB(174,180,194) },
}
return GameConfig
