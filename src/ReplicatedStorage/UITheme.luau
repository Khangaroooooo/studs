--[[
	UITheme.lua — Centralized UI styling for Stud Catcher
	Provides shared colors, fonts, and helper functions for all UI scripts.
	Replaces hardcoded color/font values scattered across individual scripts.
]]

local TweenService = game:GetService("TweenService")

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
UITheme.C_ACCENT2   = Color3.fromRGB(255, 120, 40)  -- Secondary accent (warm ember) — pairs with gold for gradients
UITheme.C_PANEL_HI  = Color3.fromRGB(48, 40, 64)    -- Lighter panel tint (top of a panel gradient)
UITheme.C_OVERLAY   = Color3.fromRGB(8, 6, 12)      -- Full-screen modal scrim

-- ─── FONTS ──────────────────────────────────────────────────────────────
-- Unified on Arcade (Press Start 2P), the pixel font, for ALL text.
-- MUST be an Enum.Font: every UI factory
-- assigns this to TextLabel.Font, and assigning a Font.fromName() datatype
-- there throws — which killed buildUI() in several scripts (this is why the
-- E-key inventory hotkey was dead: its ScreenGui never finished building).
UITheme.F_PIXEL = Enum.Font.Arcade
UITheme.F_HEAD = UITheme.F_PIXEL
UITheme.F_BODY = Enum.Font.Arcade
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

-- ─── JUICE: GRADIENTS, GLOSS, ANIMATION ─────────────────────────────────
-- These lift the whole UI at once — any screen already using the factory
-- functions can opt into depth/motion without a rewrite. All are additive.

-- Vertical two-stop gradient. Subtle by default so it reads as lit plastic,
-- not a flashy web button. rotation 90 = top→bottom.
function UITheme.ApplyGradient(instance, top, bottom, rotation)
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new(top or UITheme.C_PANEL_HI, bottom or UITheme.C_PANEL)
	grad.Rotation = rotation or 90
	grad.Parent = instance
	return grad
end

-- A thin highlight strip across the top third — the classic 8-bit "gloss" that
-- makes a flat button read as a raised cartridge key.
function UITheme.AddGloss(instance)
	local gloss = Instance.new("Frame")
	gloss.Name = "Gloss"
	gloss.Size = UDim2.new(1, 0, 0.4, 0)
	gloss.BackgroundColor3 = UITheme.C_WHITE
	gloss.BackgroundTransparency = 0.88
	gloss.BorderSizePixel = 0
	gloss.ZIndex = (instance.ZIndex or 1) + 1
	gloss.Parent = instance
	return gloss
end

-- Give a button (or any GuiObject) tactile hover/press feedback: it pops up
-- and brightens on hover, and sinks on click. Restores exactly on leave, so
-- it's safe to attach to buttons that also tween elsewhere.
function UITheme.AddHoverPop(btn, opts)
	opts = opts or {}
	local baseSize = btn.Size
	local grow = opts.grow or 0.04 -- fraction of own size
	local popSize = UDim2.new(
		baseSize.X.Scale * (1 + grow), baseSize.X.Offset,
		baseSize.Y.Scale * (1 + grow), baseSize.Y.Offset
	)
	local sinkSize = UDim2.new(
		baseSize.X.Scale * (1 - grow * 0.6), baseSize.X.Offset,
		baseSize.Y.Scale * (1 - grow * 0.6), baseSize.Y.Offset
	)
	local FAST = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	btn.MouseEnter:Connect(function()
		TweenService:Create(btn, FAST, { Size = popSize }):Play()
	end)
	btn.MouseLeave:Connect(function()
		TweenService:Create(btn, FAST, { Size = baseSize }):Play()
	end)
	btn.MouseButton1Down:Connect(function()
		TweenService:Create(btn, FAST, { Size = sinkSize }):Play()
	end)
	btn.MouseButton1Up:Connect(function()
		TweenService:Create(btn, FAST, { Size = popSize }):Play()
	end)
	return btn
end

-- Full-juice primary button: cartridge panel + gradient + gloss + hover pop.
-- Drop-in richer alternative to CreateButton for the one or two buttons on a
-- screen that should feel like "the" action.
function UITheme.CreateJuicyButton(props)
	props = props or {}
	local btn = UITheme.CreateButton({
		name = props.name, size = props.size, pos = props.pos,
		bg = props.bg or UITheme.C_ACCENT,
		text = props.text, tc = props.tc or UITheme.C_BORDER,
		ts = props.ts or 14, zIndex = props.zIndex, parent = props.parent,
		autoButtonColor = false,
		strokeColor = UITheme.C_BORDER, strokeThickness = props.strokeThickness or 3,
	})
	UITheme.ApplyGradient(btn,
		props.gradTop or Color3.fromRGB(255, 216, 90),
		props.gradBottom or (props.bg or UITheme.C_ACCENT))
	UITheme.AddGloss(btn)
	UITheme.AddHoverPop(btn)
	return btn
end

-- ─── REUSABLE MODAL SHELL ───────────────────────────────────────────────
-- A dark-scrim overlay + centered cartridge panel with a title bar and close
-- button, animated open/close. Returns { gui, panel, content, open, close }.
-- `content` is where the caller parents its body; the title bar and padding
-- are handled here so every modal in the game lines up pixel-for-pixel.
function UITheme.CreateModal(props)
	props = props or {}
	local size = props.size or UDim2.new(0, 340, 0, 400)

	local gui = Instance.new("ScreenGui")
	gui.Name = props.name or "Modal"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = props.displayOrder or 20
	gui.Enabled = false
	gui.Parent = props.parent

	local overlay = Instance.new("TextButton")
	overlay.Name = "Overlay"
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.BackgroundColor3 = UITheme.C_OVERLAY
	overlay.BackgroundTransparency = 0.35
	overlay.BorderSizePixel = 0
	overlay.Text = ""
	overlay.AutoButtonColor = false
	overlay.ZIndex = 1
	overlay.Parent = gui

	local panel = UITheme.CreateFrame({
		name = "Panel", size = size, pos = UDim2.new(0.5, 0, 0.5, 0),
		bg = UITheme.C_PANEL, zIndex = 2, parent = gui,
	})
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	UITheme.ApplyGradient(panel, UITheme.C_PANEL_HI, UITheme.C_PANEL)
	UITheme.ApplyStroke(panel, UITheme.C_BORDER, 3)

	-- Title bar
	local titleBar = UITheme.CreateFrame({
		name = "TitleBar", size = UDim2.new(1, 0, 0, 44),
		bg = UITheme.C_BORDER, zIndex = 3, parent = panel,
	})
	UITheme.CreateLabel({
		name = "Title", text = props.title or "",
		size = UDim2.new(1, -56, 1, 0), pos = UDim2.new(0, 14, 0, 0),
		color = UITheme.C_ACCENT, ts = props.titleSize or 16,
		xa = Enum.TextXAlignment.Left, zIndex = 4, parent = titleBar,
	})
	local closeBtn = UITheme.CreateButton({
		name = "Close", text = "X", size = UDim2.new(0, 32, 0, 32),
		pos = UDim2.new(1, -38, 0, 6), bg = UITheme.C_DANGER,
		tc = UITheme.C_WHITE, ts = 16, zIndex = 4, parent = titleBar,
		strokeColor = UITheme.C_BORDER, strokeThickness = 2,
	})
	UITheme.AddHoverPop(closeBtn)

	-- Body region below the title bar
	local content = UITheme.CreateFrame({
		name = "Content", size = UDim2.new(1, -24, 1, -60),
		pos = UDim2.new(0, 12, 0, 52), bg = UITheme.C_PANEL,
		transparency = 1, zIndex = 3, parent = panel,
	})

	local OPEN = TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	local SHUT = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

	local api = {}
	api.gui, api.overlay, api.panel, api.content = gui, overlay, panel, content

	function api.open()
		gui.Enabled = true
		panel.Size = UDim2.new(size.X.Scale * 0.8, size.X.Offset * 0.8,
			size.Y.Scale * 0.8, size.Y.Offset * 0.8)
		overlay.BackgroundTransparency = 1
		TweenService:Create(panel, OPEN, { Size = size }):Play()
		TweenService:Create(overlay, OPEN, { BackgroundTransparency = 0.35 }):Play()
	end

	function api.close()
		TweenService:Create(overlay, SHUT, { BackgroundTransparency = 1 }):Play()
		local t = TweenService:Create(panel, SHUT, {
			Size = UDim2.new(size.X.Scale * 0.8, size.X.Offset * 0.8,
				size.Y.Scale * 0.8, size.Y.Offset * 0.8),
		})
		t.Completed:Connect(function()
			gui.Enabled = false
		end)
		t:Play()
	end

	closeBtn.MouseButton1Click:Connect(api.close)
	if props.closeOnScrim ~= false then
		overlay.MouseButton1Click:Connect(api.close)
	end

	return api
end

return UITheme