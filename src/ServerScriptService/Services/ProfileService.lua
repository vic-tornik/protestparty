--!strict
-- Server-only player profiles with session locking, schema migration, retries, and safe shutdown.
-- Never rename the LIVE data store or change the User_<UserId> key pattern for routine updates.
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))

local ProfileService = {}

local CURRENT_SCHEMA = GameConfig.ProfileSchemaVersion
local STORE_NAME = if RunService:IsStudio() then GameConfig.DataStoreNameStudio else GameConfig.DataStoreNameLive
local Store = DataStoreService:GetDataStore(STORE_NAME)
local SESSION_ID = if game.JobId ~= "" then game.JobId else ("studio:" .. HttpService:GenerateGUID(false))

local sessions: {[number]: any} = {}
local loadInProgress: {[number]: boolean} = {}

local DEFAULT_DATA = {
	Coins = 0,
	XP = 0,
	Level = 1,
	OwnedCosmetics = { basic_sign = true },
	EquippedCosmetic = "basic_sign",
	Stats = {
		RoundsPlayed = 0,
		TotalHype = 0,
		Chants = 0,
        DebatesJoined = 0,
        DailyClaims = 0,
        FactionJoins = 0,
        DebateReputation = 0,
        DebateWins = 0,
	},
	Daily = { date = "", challengeId = "", progress = 0, claimed = false },
	Settings = {
		MusicEnabled = true,
		EffectsEnabled = true,
	},
	_meta = {
		schemaVersion = CURRENT_SCHEMA,
		sessionId = nil,
		leaseExpiresAt = 0,
		updatedAt = 0,
		revision = 0,
	},
}

local ALLOWED_STATS = {
	RoundsPlayed = true,
	TotalHype = true,
	Chants = true,
    DebatesJoined = true,
    DailyClaims = true,
    FactionJoins = true,
    DebateReputation = true,
    DebateWins = true,
}

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, child in pairs(value) do
		copy[key] = deepCopy(child)
	end
	return copy
end

local function safeNonNegativeInteger(value: any, fallback: number): number
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return fallback
	end
	return math.clamp(math.floor(value), 0, 1_000_000_000)
end

local function makeDefaultProfile(): any
	return deepCopy(DEFAULT_DATA)
end

local function migrateAndNormalize(raw: any): (any?, string?)
	if type(raw) ~= "table" then
		return nil, "corrupt_profile"
	end

	local data = deepCopy(raw)
	local meta = if type(data._meta) == "table" then data._meta else {}
	local schemaVersion = safeNonNegativeInteger(meta.schemaVersion, 0)

	if schemaVersion > CURRENT_SCHEMA then
		return nil, "future_schema"
	end

	-- Version 0 is the original unversioned shape. Keep recognized values and add defaults.
	while schemaVersion < CURRENT_SCHEMA do
		if schemaVersion == 0 then
			if data.Coins == nil and data.Money ~= nil then data.Coins = data.Money end
			data.Money = nil
			schemaVersion = 1
		elseif schemaVersion == 1 then
            -- v0.3 additive migration: preserve all existing balances, inventory and stats.
            if type(data.Daily) ~= "table" then data.Daily = {date="", challengeId="", progress=0, claimed=false} end
            schemaVersion = 2
        elseif schemaVersion == 2 then
            -- v0.5 additive migration: debate standing is separate from spendable currency.
            if type(data.Stats) ~= "table" then data.Stats = {} end
            if data.Stats.DebateReputation == nil then data.Stats.DebateReputation = 0 end
            if data.Stats.DebateWins == nil then data.Stats.DebateWins = 0 end
            schemaVersion = 3
		else return nil, "missing_migration" end
	end

	local defaults = makeDefaultProfile()
	data.Coins = safeNonNegativeInteger(data.Coins, defaults.Coins)
	data.XP = safeNonNegativeInteger(data.XP, defaults.XP)
	data.Level = math.max(1, safeNonNegativeInteger(data.Level, defaults.Level))

	if type(data.OwnedCosmetics) ~= "table" then
		data.OwnedCosmetics = defaults.OwnedCosmetics
	end
	data.OwnedCosmetics.basic_sign = true
	if type(data.EquippedCosmetic) ~= "string" or not data.OwnedCosmetics[data.EquippedCosmetic] then
		data.EquippedCosmetic = defaults.EquippedCosmetic
	end

	if type(data.Stats) ~= "table" then data.Stats = {} end
	for statName, _ in pairs(ALLOWED_STATS) do
		data.Stats[statName] = safeNonNegativeInteger(data.Stats[statName], 0)
	end

    if type(data.Daily) ~= "table" then data.Daily = {} end
    if type(data.Daily.date) ~= "string" then data.Daily.date = "" end
    if type(data.Daily.challengeId) ~= "string" then data.Daily.challengeId = "" end
    data.Daily.progress = safeNonNegativeInteger(data.Daily.progress, 0)
    if type(data.Daily.claimed) ~= "boolean" then data.Daily.claimed = false end
	if type(data.Settings) ~= "table" then data.Settings = {} end
	if type(data.Settings.MusicEnabled) ~= "boolean" then data.Settings.MusicEnabled = true end
	if type(data.Settings.EffectsEnabled) ~= "boolean" then data.Settings.EffectsEnabled = true end

	data._meta = {
		schemaVersion = CURRENT_SCHEMA,
		sessionId = meta.sessionId,
		leaseExpiresAt = safeNonNegativeInteger(meta.leaseExpiresAt, 0),
		updatedAt = safeNonNegativeInteger(meta.updatedAt, 0),
		revision = safeNonNegativeInteger(meta.revision, 0),
	}
	return data, nil
end

local function keyFor(player: Player): string
	return "User_" .. tostring(player.UserId)
end

local function updateLeaderstats(player: Player, data: any)
	player:SetAttribute("ProfileLoaded", true)
	player:SetAttribute("Coins", data.Coins)
	player:SetAttribute("XP", data.XP)
	player:SetAttribute("Level", data.Level)

	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end
	local coins = leaderstats:FindFirstChild("Coins") :: IntValue?
	if not coins then
		coins = Instance.new("IntValue")
		coins.Name = "Coins"
		coins.Parent = leaderstats
	end
	coins.Value = data.Coins
	local level = leaderstats:FindFirstChild("Level") :: IntValue?
	if not level then
		level = Instance.new("IntValue")
		level.Name = "Level"
		level.Parent = leaderstats
	end
	level.Value = data.Level
end

local function backoff(attempt: number)
	local delaySeconds = math.min(8, 2 ^ math.max(0, attempt - 1))
	task.wait(delaySeconds + (math.random() * 0.35))
end

function ProfileService.IsLoaded(player: Player): boolean
	return sessions[player.UserId] ~= nil and player:GetAttribute("ProfileLoaded") == true
end

function ProfileService.GetData(player: Player): any?
	local session = sessions[player.UserId]
	if not session or session.lost then return nil end
	return session.data
end

function ProfileService.Load(player: Player): (boolean, string?)
	local userId = player.UserId
	if sessions[userId] then return true, nil end
	if loadInProgress[userId] then
		local waitStarted = os.clock()
		while loadInProgress[userId] and not sessions[userId] and (os.clock() - waitStarted) < (GameConfig.ProfileLoadTimeoutSeconds + 5) do
			task.wait(0.1)
		end
		if sessions[userId] then return true, nil end
		return false, "load_failed"
	end
	loadInProgress[userId] = true

	local startedAt = os.clock()
	local attempt = 0
	local finalReason: string? = nil

	while player.Parent == Players and (os.clock() - startedAt) < GameConfig.ProfileLoadTimeoutSeconds do
		attempt += 1
		local callbackReason: string? = nil
		local now = os.time()
		local success, result = pcall(function()
			return Store:UpdateAsync(keyFor(player), function(oldValue)
				local data
				if oldValue == nil then
					data = makeDefaultProfile()
				else
					local migrationError
					data, migrationError = migrateAndNormalize(oldValue)
					if not data then
						callbackReason = migrationError or "invalid_profile"
						return nil
					end
				end

				local meta = data._meta
				local currentOwner = meta.sessionId
				local leaseExpiresAt = tonumber(meta.leaseExpiresAt) or 0
				if currentOwner and currentOwner ~= SESSION_ID and leaseExpiresAt > now then
					callbackReason = "session_locked"
					return nil
				end

				meta.sessionId = SESSION_ID
				meta.leaseExpiresAt = now + GameConfig.ProfileLockSeconds
				meta.updatedAt = now
				return data
			end)
		end)

		if success and type(result) == "table" and type(result._meta) == "table" and result._meta.sessionId == SESSION_ID then
			if player.Parent ~= Players then
				-- The player left while the DataStore request yielded. Release only this session's lease.
				pcall(function()
					Store:UpdateAsync(keyFor(player), function(oldValue)
						if type(oldValue) ~= "table" or type(oldValue._meta) ~= "table" or oldValue._meta.sessionId ~= SESSION_ID then return nil end
						local released = deepCopy(oldValue)
						released._meta.sessionId = nil
						released._meta.leaseExpiresAt = 0
						return released
					end)
				end)
				loadInProgress[userId] = nil
				return false, "player_left"
			end
			local normalized, reason = migrateAndNormalize(result)
			if normalized then
				sessions[userId] = {
					data = normalized,
					busy = false,
					lost = false,
					lastSaveAt = os.clock(),
				}
				updateLeaderstats(player, normalized)
				loadInProgress[userId] = nil
				return true, nil
			end
			finalReason = reason
		elseif callbackReason == "future_schema" or callbackReason == "corrupt_profile" or callbackReason == "missing_migration" then
			finalReason = callbackReason
			break
		elseif callbackReason == "session_locked" then
			finalReason = "session_locked"
		elseif not success then
			finalReason = "datastore_unavailable"
			warn(string.format("[ProfileService] Load attempt %d failed for %d: %s", attempt, userId, tostring(result)))
		else
			finalReason = callbackReason or "profile_not_acquired"
		end

		backoff(attempt)
	end

	loadInProgress[userId] = nil
	if finalReason == "future_schema" or finalReason == "corrupt_profile" or finalReason == "missing_migration" then
		warn(string.format("[ProfileService] Refusing unsafe profile load for %d (%s). No default overwrite attempted.", userId, finalReason))
	end
	return false, finalReason or "load_timeout"
end

local function saveInternal(player: Player, releaseLock: boolean): boolean
	local userId = player.UserId
	local session = sessions[userId]
	if not session or session.lost then return false end

	local waitStarted = os.clock()
	while session.busy and (os.clock() - waitStarted) < 8 do
		task.wait(0.1)
	end
	-- Another save may have released and removed this session while we waited.
	if sessions[userId] ~= session or session.lost then return false end
	if session.busy then return false end
	session.busy = true

	local snapshot = deepCopy(session.data)
	local attempt = 0
	local saved = false
	local lockLost = false
	local errorText: string? = nil

	while attempt < GameConfig.ProfileMaxSaveRetries and not saved do
		attempt += 1
		lockLost = false
		local success, result = pcall(function()
			return Store:UpdateAsync(keyFor(player), function(oldValue)
				if type(oldValue) ~= "table" or type(oldValue._meta) ~= "table" then
					lockLost = true
					return nil
				end
				if oldValue._meta.sessionId ~= SESSION_ID then
					lockLost = true
					return nil
				end

				local oldRevision = safeNonNegativeInteger(oldValue._meta.revision, 0)
				snapshot._meta = {
					schemaVersion = CURRENT_SCHEMA,
					sessionId = if releaseLock then nil else SESSION_ID,
					leaseExpiresAt = if releaseLock then 0 else (os.time() + GameConfig.ProfileLockSeconds),
					updatedAt = os.time(),
					revision = oldRevision + 1,
				}
				return snapshot
			end)
		end)

		if success and type(result) == "table" then
			saved = true
			session.lastSaveAt = os.clock()
		else
			errorText = tostring(result)
			if lockLost then break end
			if not success then warn(string.format("[ProfileService] Save attempt %d failed for %d: %s", attempt, userId, errorText)) end
			if attempt < GameConfig.ProfileMaxSaveRetries then backoff(attempt) end
		end
	end

	session.busy = false
	if lockLost then
		session.lost = true
		warn(string.format("[ProfileService] Session lock lost for %d. Refusing further writes.", userId))
		if player.Parent == Players then
			player:Kick("Your data session changed. Please rejoin so your progress stays safe.")
		end
		return false
	end

	if saved and releaseLock then
		sessions[userId] = nil
	elseif not saved then
		warn(string.format("[ProfileService] Could not safely save %d. The lock will expire rather than risk overwriting another session. %s", userId, errorText or ""))
	end
	return saved
end

function ProfileService.Save(player: Player, releaseLock: boolean?): boolean
	return saveInternal(player, releaseLock == true)
end

function ProfileService.AddCoins(player: Player, amount: number): number
	local data = ProfileService.GetData(player)
	if not data or type(amount) ~= "number" or amount <= 0 or amount ~= amount then return 0 end
	local granted = math.min(math.floor(amount), GameConfig.Rewards.MaxCoins - data.Coins)
	if granted <= 0 then return 0 end
	data.Coins += granted
	updateLeaderstats(player, data)
	return granted
end

function ProfileService.AddXP(player: Player, amount: number): number
	local data = ProfileService.GetData(player)
	if not data or type(amount) ~= "number" or amount <= 0 or amount ~= amount then return 0 end
	local granted = math.min(math.floor(amount), GameConfig.Rewards.MaxXP - data.XP)
	if granted <= 0 then return 0 end
	data.XP += granted
	data.Level = math.floor(data.XP / 100) + 1
	updateLeaderstats(player, data)
	return granted
end

function ProfileService.IncrementStat(player: Player, statName: string, amount: number)
	local data = ProfileService.GetData(player)
	if not data or not ALLOWED_STATS[statName] then return end
	if type(amount) ~= "number" or amount <= 0 or amount ~= amount then return end
	data.Stats[statName] = math.min(1_000_000_000, data.Stats[statName] + math.floor(amount))
end

function ProfileService.AddDebateReputation(player: Player, amount: number): number
    local data = ProfileService.GetData(player)
    if not data or type(amount) ~= "number" or amount <= 0 or amount ~= amount or amount == math.huge then return 0 end
    local current = safeNonNegativeInteger(data.Stats.DebateReputation, 0)
    data.Stats.DebateReputation = math.clamp(current + math.floor(amount), 0, 1_000_000_000)
    updateLeaderstats(player, data)
    return data.Stats.DebateReputation
end


function ProfileService.PurchaseCosmetic(player: Player, cosmeticId: string, price: number): (boolean, string)
 local data = ProfileService.GetData(player)
 if not data or type(cosmeticId) ~= "string" or #cosmeticId > 48 then return false, "profile_unavailable" end
 if data.OwnedCosmetics[cosmeticId] then data.EquippedCosmetic = cosmeticId; return true, "equipped" end
 if type(price) ~= "number" or price < 0 or price > GameConfig.Shop.MaxPrice or price % 1 ~= 0 then return false, "invalid_price" end
 if data.Coins < price then return false, "not_enough_coins" end
 data.Coins -= price
 data.OwnedCosmetics[cosmeticId] = true
 data.EquippedCosmetic = cosmeticId
 updateLeaderstats(player, data)
 return true, "purchased"
end

function ProfileService.EquipCosmetic(player: Player, cosmeticId: string): boolean
 local data = ProfileService.GetData(player)
 if not data or type(cosmeticId) ~= "string" or not data.OwnedCosmetics[cosmeticId] then return false end
 data.EquippedCosmetic = cosmeticId
 return true
end

function ProfileService.GetDaily(player: Player, challengeId: string, utcDate: string): any?
 local data = ProfileService.GetData(player)
 if not data then return nil end
 if data.Daily.date ~= utcDate then
  data.Daily = {date=utcDate, challengeId=challengeId, progress=0, claimed=false}
 elseif data.Daily.challengeId == "" then data.Daily.challengeId = challengeId end
 return data.Daily
end

function ProfileService.ProgressDaily(player: Player, kind: string, amount: number, challengeId: string, utcDate: string): (number, boolean)
 local daily = ProfileService.GetDaily(player, challengeId, utcDate)
 if not daily or daily.claimed or type(amount) ~= "number" or amount <= 0 then return 0, false end
 if daily.challengeId ~= challengeId then return daily.progress, false end
 daily.progress = math.min(100000, daily.progress + math.floor(amount))
 return daily.progress, true
end

function ProfileService.ClaimDaily(player: Player, challengeId: string, utcDate: string, target: number, coins: number, xp: number): (boolean, string)
 local data = ProfileService.GetData(player)
 if not data then return false, "profile_unavailable" end
 local daily = ProfileService.GetDaily(player, challengeId, utcDate)
 if not daily or daily.claimed or daily.progress < target then return false, "not_complete" end
 daily.claimed = true
 ProfileService.AddCoins(player, coins)
 ProfileService.AddXP(player, xp)
 ProfileService.IncrementStat(player, "DailyClaims", 1)
 return true, "claimed"
end

function ProfileService.StartAutosave()
	task.spawn(function()
		while true do
			task.wait(GameConfig.ProfileAutosaveSeconds + math.random(0, 8))
			for _, player in ipairs(Players:GetPlayers()) do
				if sessions[player.UserId] then
					task.spawn(function()
						-- Spread writes across a short jitter window to avoid synchronized server bursts.
						task.wait(math.random() * 12)
						if player.Parent == Players and sessions[player.UserId] then
							saveInternal(player, false)
						end
					end)
				end
			end
		end
	end)
end

function ProfileService.ReleaseAll()
	local pending = 0
	for _, player in ipairs(Players:GetPlayers()) do
		if sessions[player.UserId] then
			pending += 1
			task.spawn(function()
				saveInternal(player, true)
				pending -= 1
			end)
		end
	end
	local deadline = os.clock() + 25
	while pending > 0 and os.clock() < deadline do
		task.wait(0.1)
	end
end

return ProfileService
