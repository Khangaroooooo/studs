--[[
	UITheme.lua — Centralized UI styling for Stud Catcher
	Provides shared colors, fonts, and helper functions for all UI scripts.
	Replaces hardcoded color/font values scattered across individual scripts.
]]

local UITheme = {}

-- ─── RETRO / 8-BIT PALETTE ──────────────────────────────────────────────
-- Dark "cartridge" background with a warm, high-contrast arcade accent —
-- evokes an old handheld Stud-catcher cartridge rather than a flat modern app.
UITheme.C_BG        = Color3.fromRGB(16, 14, 24)    -- Dark background (near-black plum)
UITheme.C_PANEL     = Color3.fromRGB(34, 28, 46)    -- Panel background (retro purple-brown)
UITheme.C_ACCENT    = Color3.fromRGB(255, 196, 40)  -- Gold/amber accent (arcade marquee gold)
UITheme.C_WHITE     = Color3.fromRGB(255, 250, 235)  -- Primary text (warm off-white, like phosphor)
UITheme.C_SEC       = Color3.fromRGB(170, 150, 180)  -- Secondary text
UITheme.C_BORDER    = Color3.fromRGB(10, 8, 14)     -- Chunky pixel-border black
UITheme.C_SUCCESS   = Color3.fromRGB(90, 210, 90)    -- Success green
UITheme.C_WARNING   = Color3.fromRGB(255, 196, 40)  -- Warning amber
UITheme.C_INFO      = Color3.fromRGB(80, 160, 255)  -- Info blue
UITheme.C_DANGER    = Color3.fromRGB(235, 70, 60)    -- Danger red
UITheme.C_SHADOW    = Color3.fromRGB(0, 0, 0)       -- Offset drop-shadow used for the "pressed cartridge" look

-- ─── FONTS ──────────────────────────────────────────────────────────────
-- Press Start 2P is a true pixel-arcade font; used sparingly for headers/big
-- numbers. Body copy stays monospace (Code) so it still reads at small sizes.
-- MUST be an Enum.Font (Enum.Font.Arcade == Press Start 2P): every UI factory
-- assigns this to TextLabel.Font, and assigning a Font.fromName() datatype
-- there throws — which killed buildUI() in several scripts (this is why the
-- E-key inventory hotkey was dead: its ScreenGui never finished building).
UITheme.F_PIXEL = Enum.Font.Arcade
UITheme.F_HEAD = UITheme.F_PIXEL
UITheme.F_BODY = Enum.Font.Code
UITheme.F_BTN  = UITheme.F_PIXEL

-- ─── RARITY COLORS ──────────────────────────────────────────────────────
UITheme.RARITY_COLORS = {
	Common    = Color3.fromRGB(180, 180, 180),
	Uncommon  = Color3.fromRGB(50, 200, 50),
	Rare      = Color3.fromRGB(50, 100, 255),
	Legendary = Color3.fromRGB(255, 200, 0),
}

-- ─── HP BAR COLORS ──────────────────────────────────────────────────────
UITheme.HP_HIGH = Color3.fromRGB(50, 200, 50)
UITheme.HP_MID  = Color3.fromRGB(255, 220, 60)
UITheme.HP_LOW  = Color3.fromRGB(230, 60, 40)
UITheme.HP_BG   = Color3.fromRGB(40, 42, 54)

-- ─── HELPER FUNCTIONS ───────────────────────────────────────────────────

-- Create a styled frame
function UITheme.CreateFrame(props)
	local frame = Instance.new("Frame")
	frame.Name = props.name or "Frame"
	frame.Size = props.size or UDim2.new(1, 0, 1, 0)
	frame.Position = props.pos or UDim2.new(0, 0, 0, 0)
	frame.BackgroundColor3 = props.bg or UITheme.C_PANEL
	frame.BackgroundTransparency = props.transparency or 0
	frame.BorderSizePixel = 0
	if props.clips then frame.ClipsDescendants = true end
	if props.visible ~= nil then frame.Visible = props.visible end
	if props.zIndex then frame.ZIndex = props.zIndex end
	if props.parent then frame.Parent = props.parent end
	if props.stroke or props.strokeColor then
		local stroke = Instance.new("UIStroke")
		stroke.Color = props.strokeColor or UITheme.C_BORDER
		stroke.Thickness = props.strokeThickness or 1
		stroke.Transparency = props.strokeTransparency or 0
		stroke.Parent = frame
	end
	return frame
end

-- Create a styled text label
function UITheme.CreateLabel(props)
	local label = Instance.new("TextLabel")
	label.Name = props.name or "Label"
	label.Size = props.size or UDim2.new(1, 0, 1, 0)
	label.Position = props.pos or UDim2.new(0, 0, 0, 0)
	label.BackgroundTransparency = props.bgTransparency or 1
	label.Text = props.text or ""
	label.TextColor3 = props.color or UITheme.C_WHITE
	label.Font = props.font or UITheme.F_BODY
	label.TextSize = props.ts or 14
	label.TextXAlignment = props.xa or Enum.TextXAlignment.Center
	label.TextYAlignment = props.ya or Enum.TextYAlignment.Center
	if props.scaled then label.TextScaled = true end
	if props.zIndex then label.ZIndex = props.zIndex end
	if props.parent then label.Parent = props.parent end
	return label
end

-- Create a styled text button
function UITheme.CreateButton(props)
	local btn = Instance.new("TextButton")
	btn.Name = props.name or "Button"
	btn.Size = props.size or UDim2.new(1, 0, 0, 40)
	btn.Position = props.pos or UDim2.new(0, 0, 0, 0)
	btn.BackgroundColor3 = props.bg or UITheme.C_PANEL
	btn.BackgroundTransparency = props.transparency or 0
	btn.Text = props.text or ""
	btn.TextColor3 = props.tc or UITheme.C_WHITE
	btn.Font = props.font or UITheme.F_BTN
	btn.TextSize = props.ts or 14
	btn.BorderSizePixel = 0
	btn.AutoButtonColor = props.autoButtonColor ~= false
	if props.zIndex then btn.ZIndex = props.zIndex end
	if props.parent then btn.Parent = props.parent end
	if props.stroke or props.strokeColor then
		local stroke = Instance.new("UIStroke")
		stroke.Color = props.strokeColor or UITheme.C_BORDER
		stroke.Thickness = props.strokeThickness or 1
		stroke.Parent = btn
	end
	return btn
end

-- Apply a UIStroke to any instance
function UITheme.ApplyStroke(instance, color, thickness, transparency)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or UITheme.C_BORDER
	stroke.Thickness = thickness or 1
	stroke.Transparency = transparency or 0
	stroke.Parent = instance
	return stroke
end

-- ─── RETRO HELPERS ──────────────────────────────────────────────────────

-- Chunky "cartridge" panel: square corners, thick black outline, and a solid
-- offset drop-shadow behind it (the classic 8-bit "pressed button" look).
-- Returns the panel; the shadow is a sibling placed just behind it in ZIndex.
function UITheme.CreateRetroPanel(props)
	props = props or {}
	local shadowOffset = props.shadowOffset or 6

	if props.parent then
		local shadow = Instance.new("Frame")
		shadow.Name = (props.name or "Panel") .. "Shadow"
		shadow.Size = props.size or UDim2.new(1, 0, 1, 0)
		local basePos = props.pos or UDim2.new(0, 0, 0, 0)
		shadow.Position = basePos + UDim2.new(0, shadowOffset, 0, shadowOffset)
		shadow.BackgroundColor3 = UITheme.C_SHADOW
		shadow.BorderSizePixel = 0
		shadow.ZIndex = (props.zIndex or 1) - 1
		shadow.Parent = props.parent
	end

	local panel = UITheme.CreateFrame(props)
	local stroke = Instance.new("UIStroke")
	stroke.Color = UITheme.C_BORDER
	stroke.Thickness = props.strokeThickness or 3
	stroke.Parent = panel
	return panel
end

-- Small rectangular "badge" icon used in place of emoji (Roblox's built-in
-- fonts don't cover most emoji glyphs, which is why they were rendering as
-- blank boxes). Draws a solid-color square tag with a short pixel-font label
-- instead, e.g. UITheme.CreateIconBadge({parent=row, text="$", color=C_ACCENT}).
function UITheme.CreateIconBadge(props)
	props = props or {}
	local badge = Instance.new("Frame")
	badge.Name = props.name or "IconBadge"
	badge.Size = props.size or UDim2.new(0, 28, 0, 20)
	badge.Position = props.pos or UDim2.new(0, 0, 0, 0)
	badge.BackgroundColor3 = props.color or UITheme.C_ACCENT
	badge.BorderSizePixel = 0
	if props.zIndex then badge.ZIndex = props.zIndex end
	if props.parent then badge.Parent = props.parent end

	local stroke = Instance.new("UIStroke")
	stroke.Color = UITheme.C_BORDER
	stroke.Thickness = props.strokeThickness or 2
	stroke.Parent = badge

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.new(1, -2, 1, -2)
	label.Position = UDim2.new(0, 1, 0, 1)
	label.BackgroundTransparency = 1
	label.Text = props.text or "?"
	label.TextColor3 = props.textColor or UITheme.C_BORDER
	label.Font = UITheme.F_PIXEL
	label.TextScaled = true
	label.Parent = badge

	return badge
end

return UITheme