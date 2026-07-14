--!strict
--[[
	ServerRegistry.lua — Centralized inter-script communication hub for server systems
	Replaces _G-based coupling (_G.ActivePlayers, _G.CheckMilestones, _G.OnStudCaught, etc.)
	with a proper ModuleScript registry. Mirrors UIManager's client-side pattern so the
	same mental model works on both sides of the client/server boundary.

	Why this exists:
	  Six+ server scripts were talking to each other exclusively through globals like
	  _G.ActivePlayers and _G.CheckMilestones. That works, but it's load-order fragile
	  (if the reader runs before the writer, you silently get nil) and impossible to
	  discover without grepping every script for "_G." — a shared registry makes both
	  problems visible and fixable in one place.

	Usage:
	  Share a function:  ServerRegistry.Register("CheckMilestones", fn)
	  Call a function:   ServerRegistry.Call("CheckMilestones", player)
	  Share a value:      ServerRegistry.Register("ActivePlayers", activePlayers)
	  Read a value:       local activePlayers = ServerRegistry.Get("ActivePlayers")

	Load-order safety:
	  Get() returns nil immediately if nothing is registered yet (same as before).
	  WaitFor() blocks (like WaitForChild) until the value shows up or timeout hits —
	  use this for anything you need at script-init time, so it doesn't matter which
	  server script happens to run first.
]]

local ServerRegistry = {}

-- ─── REGISTRY ────────────────────────────────────────────────────────────
-- Values are heterogeneous (functions, tables, primitives shared between
-- systems), so the store is intentionally { [string]: any }.
local registry: { [string]: any } = {}

-- Register a function or value by name so other scripts can read/call it
function ServerRegistry.Register(name: string, value: any)
	registry[name] = value
end

-- Unregister (clears it from the registry)
function ServerRegistry.Unregister(name: string)
	registry[name] = nil
end

-- Get a registered value immediately (returns nil if not registered yet)
function ServerRegistry.Get(name: string): any
	return registry[name]
end

-- Check if something is registered
function ServerRegistry.IsRegistered(name: string): boolean
	return registry[name] ~= nil
end

-- Call a registered function by name (silently no-ops if not registered,
-- same forgiving behavior the old "if _G.X then _G.X(...) end" checks had)
function ServerRegistry.Call(name: string, ...: any): ...any
	local fn = registry[name]
	if fn then
		return (fn :: any)(...)
	end
	return
end

-- Block until a value is registered (or timeout elapses), for scripts that
-- need something at init time regardless of script execution order.
-- Returns the value, or nil if the timeout was hit first.
function ServerRegistry.WaitFor(name: string, timeout: number?): any
	if registry[name] ~= nil then return registry[name] end

	local interval = 0.05
	local elapsed = 0
	while registry[name] == nil do
		task.wait(interval)
		elapsed += interval
		if timeout and elapsed >= timeout then
			warn("[ServerRegistry] WaitFor('" .. name .. "') timed out after " .. timeout .. "s")
			return nil
		end
	end
	return registry[name]
end

return ServerRegistry
