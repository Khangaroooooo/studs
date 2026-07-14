--[[
	UIManager.lua — Centralized UI communication hub for Stud Catcher
	Replaces _G-based inter-script communication with a proper ModuleScript registry.

	Usage:
	  Define:  UIManager.Register("FunctionName", fn)
	  Call:    UIManager.Call("FunctionName", ...)
	  Get:     local fn = UIManager.Get("FunctionName")

	UI Lock (replaces _G._uiLock counter):
	  UIManager.AcquireLock()  — lock player movement (increments counter)
	  UIManager.ReleaseLock()  — unlock (decrements; restores WalkSpeed at 0)
]]

local Players = game:GetService("Players")

local UIManager = {}

-- ─── REGISTRY ────────────────────────────────────────────────────────────
local registry = {}

-- Register a function by name so other scripts can call it
function UIManager.Register(name, fn)
	registry[name] = fn
end

-- Unregister a function (clears it from the registry)
function UIManager.Unregister(name)
	registry[name] = nil
end

-- Get a registered function (returns nil if not registered)
function UIManager.Get(name)
	return registry[name]
end

-- Check if a function is registered
function UIManager.IsRegistered(name)
	return registry[name] ~= nil
end

-- Call a registered function by name (silently does nothing if not registered)
function UIManager.Call(name, ...)
	local fn = registry[name]
	if fn then
		return fn(...)
	end
end

-- ─── EXCLUSIVE PANELS ────────────────────────────────────────────────────
-- Center-screen panels (Shop, Quests, Settings, Leaderboard, ...) register
-- a close function; opening one calls CloseOtherPanels so two panels never
-- stack on top of each other.
local panels = {} -- [name] = closeFn

function UIManager.RegisterPanel(name, closeFn)
	panels[name] = closeFn
end

-- Close every registered panel except `exceptName` (pass nil to close all)
function UIManager.CloseOtherPanels(exceptName)
	for name, closeFn in pairs(panels) do
		if name ~= exceptName then
			pcall(closeFn)
		end
	end
end

-- ─── UI LOCK MECHANISM (replaces _G._uiLock) ─────────────────────────────
local lockCount = 0
local DEFAULT_WALK_SPEED = 16

-- Lock player movement (increments counter, sets WalkSpeed to 0)
function UIManager.AcquireLock()
	lockCount = lockCount + 1
	local player = Players.LocalPlayer
	if player then
		local char = player.Character
		if char then
			local h = char:FindFirstChildOfClass("Humanoid")
			if h then h.WalkSpeed = 0 end
		end
	end
end

-- Unlock player movement (decrements counter; restores WalkSpeed when 0)
function UIManager.ReleaseLock()
	lockCount = math.max(0, lockCount - 1)
	if lockCount == 0 then
		local player = Players.LocalPlayer
		if player then
			local char = player.Character
			if char then
				local h = char:FindFirstChildOfClass("Humanoid")
				if h then h.WalkSpeed = DEFAULT_WALK_SPEED end
			end
		end
	end
end

-- Get current lock count (useful for checking if any UI is open)
function UIManager.GetLockCount()
	return lockCount
end

return UIManager