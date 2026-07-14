-- ShiftLockSetup: Enables shiftlock mode availability so players can toggle it with Ctrl
-- The MouseLockController requires ControlMode == MouseLockSwitch to enable the shiftlock feature

local UserSettings = UserSettings()
local GameSettings = UserSettings.GameSettings

-- Enable shiftlock toggle availability
GameSettings.ControlMode = Enum.ControlMode.MouseLockSwitch

print("[ShiftLockSetup] Shiftlock enabled - press Ctrl to toggle")