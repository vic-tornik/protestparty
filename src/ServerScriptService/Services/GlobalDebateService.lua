--!strict
-- Cross-server community debate index. MemoryStore is ephemeral by design; durable player
-- reputation remains in ProfileService. All calls fail closed when platform services throttle.
local MemoryStoreService = game:GetService("MemoryStoreService")
local MessagingService = game:GetService("MessagingService")
local HttpService = game:GetService("HttpService")

local GlobalDebateService = {}
local TOPIC_TTL = 60 * 60 * 24 * 3
local MAX_FEED = 12
local TOPIC_PREFIX = "topic_"
local TOPIC_MAP = MemoryStoreService:GetSortedMap("PP_GlobalDebates_v1")
local REVIEW_MAP = MemoryStoreService:GetSortedMap("PP_DebateModerationReview_v1")
local FEATURE_VOTE_MAP = MemoryStoreService:GetHashMap("PP_DebateFeaturedVotes_v1")
local DataStoreService = game:GetService("DataStoreService")
local AUDIT_STORE = DataStoreService:GetDataStore("PP_DebateModerationAudit_v1")
local REPORT_MAP = MemoryStoreService:GetHashMap("PP_GlobalDebateReports_v1")
local TOPIC_CHANNEL = "PP_GlobalDebates_Refresh_v1"
local refreshCallback: (() -> ())? = nil
local subscribed = false

local function publishRefresh()
	pcall(function()
		MessagingService:PublishAsync(TOPIC_CHANNEL, {at = os.time(), job = game.JobId})
	end)
end

function GlobalDebateService.Start(onRefresh: () -> ())
	refreshCallback = onRefresh
	if subscribed then return end
	subscribed = true
	local ok, connectionOrError = pcall(function()
		return MessagingService:SubscribeAsync(TOPIC_CHANNEL, function(message)
			local data = message.Data
			if type(data) == "table" and data.job ~= game.JobId and refreshCallback then
				task.spawn(refreshCallback)
			end
		end)
	end)
	if not ok then
		warn("[GlobalDebateService] Cross-server notifications unavailable: " .. tostring(connectionOrError))
	end
end

function GlobalDebateService.Submit(topic: string, category: string, creatorId: number, creatorName: string): (boolean, string?)
	local rateToken = HttpService:GenerateGUID(false)
	local rateOk, rateRecord = pcall(function()
		return REPORT_MAP:UpdateAsync("submit_" .. tostring(creatorId), function(old)
			if type(old) == "table" and os.time() - (tonumber(old.at) or 0) < 75 then return old end
			return {at = os.time(), token = rateToken}
		end, 90)
	end)
	if not rateOk or type(rateRecord) ~= "table" or rateRecord.token ~= rateToken then return false, "global_cooldown" end
	local normalized = string.lower(topic)
	for _, existing in ipairs(GlobalDebateService.GetTrending()) do
		if string.lower(tostring(existing.topic)) == normalized then return false, "duplicate" end
	end
	local id = TOPIC_PREFIX .. HttpService:GenerateGUID(false)
	local record = {
		id = id, topic = topic, category = category, creatorId = creatorId,
		creator = string.sub(creatorName, 1, 32), votes = 0, status = "pending",
		createdAt = os.time(), serverId = game.JobId,
	}
	local ok, err = pcall(function()
		TOPIC_MAP:SetAsync(id, record, TOPIC_TTL, record.createdAt)
	end)
	if not ok then return false, tostring(err) end
	publishRefresh()
	return true, id
end

function GlobalDebateService.GetTrending(): {any}
	local ok, rows = pcall(function()
		return TOPIC_MAP:GetRangeAsync(Enum.SortDirection.Descending, MAX_FEED)
	end)
	if not ok or type(rows) ~= "table" then return {} end
	local result = {}
	for _, row in ipairs(rows) do
		local value = row.value
		if type(value) == "table" and (value.status == "pending" or value.status == "featured") then
			table.insert(result, {
				id = value.id, topic = value.topic, category = value.category,
				votes = tonumber(value.votes) or 0, creator = value.creator,
				reports = tonumber(value.reports) or 0, featured = value.status == "featured", communityApproved = value.communityApproved == true, featureVotes = tonumber(value.featureVotes) or 0, createdAt = value.createdAt,
			})
		end
	end
	table.sort(result, function(a, b)
		if a.featured ~= b.featured then return a.featured end
        if a.communityApproved ~= b.communityApproved then return a.communityApproved end
		if a.votes ~= b.votes then return a.votes > b.votes end
		return (a.createdAt or 0) > (b.createdAt or 0)
	end)
	return result
end

function GlobalDebateService.Vote(topicId: string, userId: number): boolean
	if #topicId > 80 or string.sub(topicId, 1, #TOPIC_PREFIX) ~= TOPIC_PREFIX then return false end
	local voterKey = "voted_" .. tostring(userId) .. "_" .. topicId
	local markerToken = HttpService:GenerateGUID(false)
	local ok, didVote = pcall(function()
		local marker = REPORT_MAP:UpdateAsync(voterKey, function(old)
			if old ~= nil then return old end
			return markerToken
		end, TOPIC_TTL)
		if marker ~= markerToken then return false end
		local updated = TOPIC_MAP:UpdateAsync(topicId, function(old, sortKey)
			if type(old) ~= "table" or (old.status ~= "pending" and old.status ~= "featured") then return nil end
			old.votes = math.min(1000000, (tonumber(old.votes) or 0) + 1)
			local featuredOffset = if old.status == "featured" then 1e15 else 0
			return old, featuredOffset + old.votes * 1e8 + (tonumber(old.createdAt) or 0)
		end, TOPIC_TTL)
		return updated ~= nil
	end)
	if ok and didVote then publishRefresh() end
	return ok and didVote == true
end

function GlobalDebateService.Report(topicId: string, userId: number): (boolean, number)
	if #topicId > 80 or string.sub(topicId, 1, #TOPIC_PREFIX) ~= TOPIC_PREFIX then return false, 0 end
    local initialOk, initialTopic = pcall(function() return TOPIC_MAP:GetAsync(topicId) end)
    if not initialOk or type(initialTopic) ~= "table" or (initialTopic.status ~= "pending" and initialTopic.status ~= "featured") then return false, 0 end
	local reportKey = "report_" .. tostring(userId) .. "_" .. topicId
	local markerToken = HttpService:GenerateGUID(false)
	local ok, count = pcall(function()
		local marker = REPORT_MAP:UpdateAsync(reportKey, function(old)
			if old ~= nil then return old end
			return markerToken
		end, TOPIC_TTL)
		if marker ~= markerToken then return -1 end
		local total = REPORT_MAP:UpdateAsync("count_" .. topicId, function(old)
			return math.min(10000, (tonumber(old) or 0) + 1)
		end, TOPIC_TTL)
		local reportCount = tonumber(total) or 0
		local topic = TOPIC_MAP:UpdateAsync(topicId, function(old, sortKey)
			if type(old) ~= "table" or (old.status ~= "pending" and old.status ~= "featured") then return nil end
			old.reports = reportCount
			return old, sortKey
		end, TOPIC_TTL)
        if reportCount >= 3 and type(topic) == "table" then
            REVIEW_MAP:SetAsync(topicId, {id=topicId, topic=topic.topic, category=topic.category, reports=reportCount, createdAt=topic.createdAt, status=topic.status}, TOPIC_TTL, reportCount * 1e8 + os.time())
        end
		return reportCount
	end)
	if not ok then return false, 0 end
	return count ~= -1, math.max(0, count)
end

function GlobalDebateService.VoteFeatured(topicId: string, userId: number): (boolean, number)
 if #topicId > 80 or string.sub(topicId, 1, #TOPIC_PREFIX) ~= TOPIC_PREFIX then return false, 0 end
 local topicOk, topicRecord = pcall(function() return TOPIC_MAP:GetAsync(topicId) end)
 if not topicOk or type(topicRecord) ~= "table" or topicRecord.status ~= "pending" then return false, 0 end
 local markerKey = "featured_" .. tostring(userId) .. "_" .. topicId
 local token = HttpService:GenerateGUID(false)
 local ok, count = pcall(function()
  local marker = FEATURE_VOTE_MAP:UpdateAsync(markerKey, function(old) if old ~= nil then return old end return token end, TOPIC_TTL)
  if marker ~= token then return -1 end
  local total = FEATURE_VOTE_MAP:UpdateAsync("count_" .. topicId, function(old) return math.min(100000, (tonumber(old) or 0) + 1) end, TOPIC_TTL)
  return tonumber(total) or 0
 end)
 if not ok then return false, 0 end
 local votes = math.max(0, count)
 if votes >= 5 then
  pcall(function() TOPIC_MAP:UpdateAsync(topicId, function(old, sortKey)
   if type(old) ~= "table" or old.status ~= "pending" then return old, sortKey end
   old.communityApproved = true; old.featureVotes = votes
   return old, (tonumber(old.votes) or 0) * 1e8 + (tonumber(old.createdAt) or 0)
  end, TOPIC_TTL) end)
 end
 publishRefresh()
 return count ~= -1, votes
end

function GlobalDebateService.GetReviewQueue(): {any}
 local ok, rows = pcall(function() return REVIEW_MAP:GetRangeAsync(Enum.SortDirection.Descending, 30) end)
 if not ok or type(rows) ~= "table" then return {} end
 local result = {}
 for _, row in ipairs(rows) do
  local value = row.value
  if type(value) == "table" then table.insert(result, {id=value.id, topic=value.topic, category=value.category, reports=tonumber(value.reports) or 0, createdAt=value.createdAt, status=value.status}) end
 end
 return result
end

local function appendAudit(topicId: string, actorId: number, action: string, previousStatus: string, nextStatus: string): boolean
 local entry = {actorId=actorId, action=action, previousStatus=previousStatus, nextStatus=nextStatus, at=os.time()}
 local ok, err = pcall(function()
  AUDIT_STORE:UpdateAsync("topic_" .. topicId, function(old)
   local history = if type(old) == "table" then old else {}
   table.insert(history, entry)
   while #history > 50 do table.remove(history, 1) end
   return history
  end)
 end)
 if not ok then warn("[GlobalDebateService] Audit write failed: " .. tostring(err)) end
 return ok
end

function GlobalDebateService.GetAudit(topicId: string): {any}
 if #topicId > 80 then return {} end
 local ok, value = pcall(function() return AUDIT_STORE:GetAsync("topic_" .. topicId) end)
 return if ok and type(value) == "table" then value else {}
end

function GlobalDebateService.Moderate(topicId: string, action: string, actorId: number): boolean
 if #topicId > 80 or string.sub(topicId, 1, #TOPIC_PREFIX) ~= TOPIC_PREFIX then return false end
 if action ~= "Feature" and action ~= "Remove" and action ~= "Restore" then return false end
 if action == "Feature" then
  local topicOk, topicRecord = pcall(function() return TOPIC_MAP:GetAsync(topicId) end)
  if not topicOk or type(topicRecord) ~= "table" or topicRecord.communityApproved ~= true then return false end
  local featuredCount = 0
  for _, item in ipairs(GlobalDebateService.GetTrending()) do if item.featured then featuredCount += 1 end end
  if featuredCount >= 3 then return false end
 end
 local nextStatus = if action == "Feature" then "featured" elseif action == "Remove" then "removed" else "pending"
 local previousStatus = "unknown"
 local ok, updated = pcall(function()
  return TOPIC_MAP:UpdateAsync(topicId, function(old, sortKey)
   if type(old) ~= "table" then return nil end
   previousStatus = tostring(old.status or "unknown")
   old.status = nextStatus
   if nextStatus == "removed" then return old, -1e15 end
   local featuredOffset = if nextStatus == "featured" then 1e15 else 0
   return old, featuredOffset + (tonumber(old.votes) or 0) * 1e8 + (tonumber(old.createdAt) or 0)
  end, TOPIC_TTL)
 end)
 if not ok or updated == nil then return false end
 if not appendAudit(topicId, actorId, action, previousStatus, nextStatus) then
  warn("[GlobalDebateService] Moderation state changed but audit persistence failed for " .. topicId)
 end
 pcall(function() REVIEW_MAP:RemoveAsync(topicId) end)
 publishRefresh(); return true
end

function GlobalDebateService.GetNextFeaturedOrTrending(): any?
	local topics = GlobalDebateService.GetTrending()
	for pass = 1, 2 do
		for _, item in ipairs(topics) do
			if (pass == 1 and item.featured) or (pass == 2 and not item.featured) then
				local ok, claimed = pcall(function()
					return TOPIC_MAP:UpdateAsync(item.id, function(old, sortKey)
						if type(old) ~= "table" or (old.status ~= "pending" and old.status ~= "featured") then return nil end
						old.status = "used"
						old.usedAt = os.time()
						return old, 0
					end, TOPIC_TTL)
				end)
				if ok and type(claimed) == "table" and claimed.status == "used" then
					publishRefresh()
					return {id = claimed.id, prompt = claimed.topic, sideA = "SUPPORT THE MOTION", sideB = "OPPOSE THE MOTION", context = if item.featured then "Community featured debate. Debate the idea, never the person." else "Global community debate. Debate the idea, never the person."}
				end
			end
		end
	end
	return nil
end

return GlobalDebateService
