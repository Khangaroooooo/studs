--!strict
-- RateLimiter: lightweight per-player min-interval throttle for RemoteEvents.
--
-- The economy remotes are already server-authoritative (the client never sends
-- prices, and funds/ownership are re-checked server-side), so this isn't the
-- primary anti-cheat line — it's defense-in-depth against a scripted client
-- spamming a remote to load the server or fish for races.
--
-- Usage (server):
--   local RateLimiter = require(ReplicatedStorage.RateLimiter)
--   local limiter = RateLimiter.new(0.5) -- min 0.5s between accepted calls
--   remote.OnServerEvent:Connect(function(player, ...)
--       if not limiter:allow(player) then return end
--       ...
--   end)
--
-- Buckets are keyed by UserId and pruned on PlayerRemoving so they don't leak.

local Players = game:GetService("Players")

local RateLimiter = {}
RateLimiter.__index = RateLimiter

export type RateLimiter = {
	allow: (self: RateLimiter, player: Player) -> boolean,
}

-- One shared cleanup hook feeds every limiter instance so we connect
-- PlayerRemoving exactly once instead of per-limiter.
local activeBuckets: { { [number]: number } } = {}
Players.PlayerRemoving:Connect(function(player)
	for _, buckets in activeBuckets do
		buckets[player.UserId] = nil
	end
end)

-- minInterval: minimum seconds between accepted calls from the same player.
function RateLimiter.new(minInterval: number)
	local self = setmetatable({}, RateLimiter)
	self._interval = minInterval
	self._last = {} :: { [number]: number }
	table.insert(activeBuckets, self._last)
	return self
end

-- Returns true and records the call if enough time has elapsed; false (drop
-- this call) otherwise. Non-players (nil) are always rejected.
function RateLimiter:allow(player: Player): boolean
	if not player then
		return false
	end
	local now = os.clock()
	local last = self._last[player.UserId]
	if last and (now - last) < self._interval then
		return false
	end
	self._last[player.UserId] = now
	return true
end

return RateLimiter
