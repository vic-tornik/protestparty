--!strict
-- Weekly global standings use OrderedDataStore. Lifetime reputation remains in player profiles.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local WeeklyChampionshipService = {}

local function weekKey(): string
	local now=os.time(); local day=tonumber(os.date("!%w")) or 0
	local weekStart=math.floor(now/86400)*86400-((day+6)%7)*86400
	return os.date("!%Y_%W",weekStart)
end

local function playerStore()
	return DataStoreService:GetOrderedDataStore("PP_DebateWeek_" .. weekKey())
end

function WeeklyChampionshipService.Award(player: Player, points: number)
	if points <= 0 or points > 20 or points % 1 ~= 0 then return end
	task.spawn(function()
		local ok, err = pcall(function()
			playerStore():IncrementAsync(tostring(player.UserId), points)
		end)
		if not ok then warn("[WeeklyChampionshipService] Weekly award deferred by DataStore: " .. tostring(err)) end
	end)
end

function WeeklyChampionshipService.GetTop(): {any}
	local output = {week = weekKey(), players = {}}
	local ok, pages = pcall(function() return playerStore():GetSortedAsync(false, 10) end)
	if ok and pages then
		for _, entry in ipairs(pages:GetCurrentPage()) do
			local userId = tonumber(entry.key)
			local name = "Debater"
			if userId then
				local nameOk, resolved = pcall(function() return Players:GetNameFromUserIdAsync(userId) end)
				if nameOk then name = resolved end
			end
			table.insert(output.players, {userId=userId, name=name, points=tonumber(entry.value) or 0})
		end
	end
	return output
end

return WeeklyChampionshipService
