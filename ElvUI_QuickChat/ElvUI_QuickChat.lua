--[[
================================================================================
ElvUI_QuickChat
================================================================================
A row of flat colored bars that pre-fill the chat edit box for a channel
(Say / Yell / Party / Guild / Officer / Raid / Raid Warning / Reply), so you can
jump between them without typing the slash command. Built as a proper ElvUI
plugin rather than a standalone addon:

  - Shows up as its own tab under ElvUI's Chat options (Options > Chat >
    Quick Chat), following the same pattern LibElvUIPlugin-based addons use.
  - Uses ElvUI's own mover system (E:CreateMover), so it shows up and drags
    freely whenever you hit "Toggle Anchors" - same as every other ElvUI
    element. Position is saved automatically by ElvUI (E.db.movers), no
    custom position-saving code needed.
  - Doesn't hook or modify ElvUI's chat frames at all - it only calls
    ChatFrame_OpenChat, the same function the default UI's own channel
    buttons use, so it can't conflict with the ElvUI chat module.
  - Every bar's color lives in the profile DB, so each one has its own color
    picker in the options and repaints live without a /reload.

Styling notes: bars use ElvUI's own statusbar texture and backdrop border, so
they inherit your media settings and look native next to the rest of the UI.
Labels are off by default (the bars are the affordance); turning them on picks
black or white text automatically based on how light the bar color is.
================================================================================
]]

local E, L, V, P, G = unpack(ElvUI)
local QC = E:NewModule("QuickChat", "AceEvent-3.0")
local EP = LibStub("LibElvUIPlugin-1.0")
local addonName = ...

local ipairs = ipairs
local CreateFrame = CreateFrame
local ChatFrame_OpenChat = ChatFrame_OpenChat
local GameTooltip = GameTooltip

----------------------------------------------------------------------
-- Channel definitions
--
-- `key` is the stable identifier used for the color table in the profile DB,
-- so reordering or relabeling this list never orphans a saved color.
----------------------------------------------------------------------
local CHANNELS = {
	{ key = "SAY",     label = "S",  prefix = "/s ",    name = "Say" },
	{ key = "YELL",    label = "Y",  prefix = "/y ",    name = "Yell" },
	{ key = "PARTY",   label = "P",  prefix = "/p ",    name = "Party" },
	{ key = "GUILD",   label = "G",  prefix = "/g ",    name = "Guild" },
	{ key = "OFFICER", label = "O",  prefix = "/o ",    name = "Officer" },
	{ key = "RAID",    label = "R",  prefix = "/raid ", name = "Raid" },
	{ key = "WARNING", label = "RW", prefix = "/rw ",   name = "Raid Warning" },
	{ key = "REPLY",   label = "W",  prefix = "/r ",    name = "Reply (last whisper)" },
}

----------------------------------------------------------------------
-- Profile defaults
----------------------------------------------------------------------
P.quickchat = {
	enable = true,
	width = 34,
	height = 7,
	spacing = 4,
	alpha = 1,
	flatTexture = false,
	showText = false,
	fontSize = 10,
	colors = {
		SAY     = { r = 1.00, g = 1.00, b = 1.00 },
		YELL    = { r = 1.00, g = 0.25, b = 0.25 },
		PARTY   = { r = 0.67, g = 0.67, b = 1.00 },
		GUILD   = { r = 0.31, g = 0.94, b = 0.28 },
		OFFICER = { r = 1.00, g = 0.92, b = 0.31 },
		RAID    = { r = 1.00, g = 0.62, b = 0.11 },
		WARNING = { r = 1.00, g = 0.42, b = 0.62 },
		REPLY   = { r = 0.82, g = 0.82, b = 0.80 },
	},
}

----------------------------------------------------------------------
-- Buttons
----------------------------------------------------------------------
local function ChannelButton_OnClick(self)
	ChatFrame_OpenChat(self.prefix, DEFAULT_CHAT_FRAME)
end

local function ChannelButton_OnEnter(self)
	GameTooltip:SetOwner(self, "ANCHOR_TOP")
	GameTooltip:SetText(self.tooltipText, 1, 1, 1)
	GameTooltip:Show()
	self.tex:SetAlpha(1)
end

local function ChannelButton_OnLeave(self)
	GameTooltip:Hide()
	self.tex:SetAlpha(E.db.quickchat.alpha)
end

function QC:CreateBar()
	if self.bar then return self.bar end

	local bar = CreateFrame("Frame", "QuickChatBar", E.UIParent)
	-- initial default only; overridden by the saved mover position
	bar:Point("BOTTOMLEFT", E.UIParent, "BOTTOMLEFT", 20, 250)

	self.bar = bar
	self.buttons = {}

	for i, info in ipairs(CHANNELS) do
		local btn = CreateFrame("Button", "QuickChatButton" .. info.key, bar)
		btn:CreateBackdrop("Transparent")

		local tex = btn:CreateTexture(nil, "ARTWORK")
		tex:SetAllPoints(btn)
		btn.tex = tex

		local text = btn:CreateFontString(nil, "OVERLAY")
		text:SetPoint("CENTER")
		btn.text = text

		btn.prefix = info.prefix
		btn.tooltipText = info.name
		btn.channelKey = info.key
		btn.label = info.label

		btn:SetScript("OnClick", ChannelButton_OnClick)
		btn:SetScript("OnEnter", ChannelButton_OnEnter)
		btn:SetScript("OnLeave", ChannelButton_OnLeave)

		self.buttons[i] = btn
	end

	-- The shouldDisable callback matters on profile switches: E:SetMoversPositions
	-- re-enables every disabled mover unless its shouldDisable() says otherwise.
	E:CreateMover(bar, "QuickChatMover", L["Quick Chat"] or "Quick Chat", nil, nil, nil, nil,
		function() return not E.db.quickchat.enable end, "chat,quickchat")

	return bar
end

-- Sizes, spacing, texture and labels. Also resizes the ElvUI mover so its
-- click region keeps matching the bar after the sliders change.
function QC:UpdateLayout()
	if not self.bar then return end

	local db = E.db.quickchat
	local texture = db.flatTexture and E.media.blankTex or E.media.normTex
	local count = #self.buttons

	for i, btn in ipairs(self.buttons) do
		btn:Size(db.width, db.height)
		btn:ClearAllPoints()
		btn:Point("LEFT", self.bar, "LEFT", (i - 1) * (db.width + db.spacing), 0)

		btn.tex:SetTexture(texture)
		btn.tex:SetAlpha(db.alpha)

		if db.showText then
			btn.text:FontTemplate(nil, db.fontSize, "OUTLINE")
			btn.text:SetText(btn.label)
			btn.text:Show()
		else
			btn.text:Hide()
		end
	end

	-- dirtyWidth/dirtyHeight must be set *before* the resize: ElvUI's mover
	-- hooks OnSizeChanged and reads them to size its own click region, so
	-- setting them afterwards would leave the mover a step behind.
	local width = count * db.width + (count - 1) * db.spacing
	self.bar.dirtyWidth, self.bar.dirtyHeight = width, db.height
	self.bar:Size(width, db.height)

	-- ElvUI's OnSizeChanged handler bails in combat, so catch up by hand.
	if self.bar.mover then
		self.bar.mover:Size(width, db.height)
	end

	self:UpdateColors()
end

function QC:UpdateColors()
	if not self.buttons then return end

	for _, btn in ipairs(self.buttons) do
		local c = E.db.quickchat.colors[btn.channelKey] or P.quickchat.colors[btn.channelKey]
		btn.tex:SetVertexColor(c.r, c.g, c.b)

		-- Pick label contrast from the bar's perceived brightness, so a white
		-- Say bar and a red Yell bar both stay readable without a setting.
		local luminance = (0.299 * c.r) + (0.587 * c.g) + (0.114 * c.b)
		if luminance > 0.55 then
			btn.text:SetTextColor(0, 0, 0)
		else
			btn.text:SetTextColor(1, 1, 1)
		end
	end
end

-- Note: never call Show()/Hide() on the mover frame directly. Movers are
-- created hidden and are only meant to be revealed by E:ToggleMovers when the
-- user enters config mode ("Toggle Anchors"). Showing it here is what made the
-- anchor sit on screen after every login/reload. E:Enable/DisableMover is the
-- supported way to gate one on a setting - it respects E.configMode.
function QC:UpdateVisibility()
	if not self.bar then return end

	if E.db.quickchat.enable then
		self.bar:Show()
		E:EnableMover("QuickChatMover")
	else
		self.bar:Hide()
		E:DisableMover("QuickChatMover")
	end
end

function QC:Update()
	self:UpdateLayout()
	self:UpdateVisibility()
end

----------------------------------------------------------------------
-- Options: new tab under Chat
----------------------------------------------------------------------
local function InsertOptions()
	if not E.Options.args.chat or not E.Options.args.chat.args then return end

	local colorArgs = {}
	for i, info in ipairs(CHANNELS) do
		colorArgs[info.key] = {
			order = i,
			type = "color",
			hasAlpha = false,
			name = info.name,
			get = function()
				local t = E.db.quickchat.colors[info.key]
				local d = P.quickchat.colors[info.key]
				return t.r, t.g, t.b, 1, d.r, d.g, d.b
			end,
			set = function(_, r, g, b)
				local t = E.db.quickchat.colors[info.key]
				t.r, t.g, t.b = r, g, b
				QC:UpdateColors()
			end,
		}
	end

	colorArgs.resetColors = {
		order = 20,
		type = "execute",
		name = L["Restore Defaults"] or "Restore Defaults",
		func = function()
			for _, info in ipairs(CHANNELS) do
				local t, d = E.db.quickchat.colors[info.key], P.quickchat.colors[info.key]
				t.r, t.g, t.b = d.r, d.g, d.b
			end
			QC:UpdateColors()
		end,
	}

	E.Options.args.chat.args.quickchat = {
		order = 19, -- after the built-in Chat tabs
		type = "group",
		name = L["Quick Chat"] or "Quick Chat",
		args = {
			intro = {
				order = 1,
				type = "description",
				name = "A row of colored bars near your chat frame for switching channels (Say/Yell/Party/Guild/Officer/Raid/Raid Warning/Reply). Move it with ElvUI's own 'Toggle Anchors' like any other element.",
			},
			enable = {
				order = 2,
				type = "toggle",
				name = L["Enable"],
				get = function() return E.db.quickchat.enable end,
				set = function(_, value)
					E.db.quickchat.enable = value
					QC:UpdateVisibility()
				end,
			},
			layout = {
				order = 10,
				type = "group",
				guiInline = true,
				name = L["Layout"] or "Layout",
				disabled = function() return not E.db.quickchat.enable end,
				args = {
					width = {
						order = 1,
						type = "range",
						name = L["Width"],
						min = 8, max = 120, step = 1,
						get = function() return E.db.quickchat.width end,
						set = function(_, value)
							E.db.quickchat.width = value
							QC:UpdateLayout()
						end,
					},
					height = {
						order = 2,
						type = "range",
						name = L["Height"],
						min = 3, max = 40, step = 1,
						get = function() return E.db.quickchat.height end,
						set = function(_, value)
							E.db.quickchat.height = value
							QC:UpdateLayout()
						end,
					},
					spacing = {
						order = 3,
						type = "range",
						name = L["Spacing"],
						min = 0, max = 20, step = 1,
						get = function() return E.db.quickchat.spacing end,
						set = function(_, value)
							E.db.quickchat.spacing = value
							QC:UpdateLayout()
						end,
					},
					alpha = {
						order = 4,
						type = "range",
						name = L["Alpha"],
						min = 0.1, max = 1, step = 0.01, isPercent = true,
						get = function() return E.db.quickchat.alpha end,
						set = function(_, value)
							E.db.quickchat.alpha = value
							QC:UpdateLayout()
						end,
					},
					flatTexture = {
						order = 5,
						type = "toggle",
						name = "Flat Texture",
						desc = "Use a solid fill instead of ElvUI's statusbar texture.",
						get = function() return E.db.quickchat.flatTexture end,
						set = function(_, value)
							E.db.quickchat.flatTexture = value
							QC:UpdateLayout()
						end,
					},
					showText = {
						order = 6,
						type = "toggle",
						name = "Show Labels",
						desc = "Show the channel letter on each bar. Text color is chosen automatically for contrast.",
						get = function() return E.db.quickchat.showText end,
						set = function(_, value)
							E.db.quickchat.showText = value
							QC:UpdateLayout()
						end,
					},
					fontSize = {
						order = 7,
						type = "range",
						name = L["Font Size"],
						min = 6, max = 22, step = 1,
						disabled = function() return not E.db.quickchat.showText end,
						get = function() return E.db.quickchat.fontSize end,
						set = function(_, value)
							E.db.quickchat.fontSize = value
							QC:UpdateLayout()
						end,
					},
				},
			},
			colors = {
				order = 20,
				type = "group",
				guiInline = true,
				name = L["Colors"] or "Colors",
				disabled = function() return not E.db.quickchat.enable end,
				args = colorArgs,
			},
		},
	}
end

EP:RegisterPlugin(addonName, InsertOptions)

----------------------------------------------------------------------
-- Initialize (deferred until ElvUI itself is ready)
----------------------------------------------------------------------
function QC:Initialize()
	self:CreateBar()
	self:Update()

	-- E:UpdateAll only reassigns .db for ElvUI's own built-in modules, so a
	-- profile switch would otherwise leave this bar drawn with the previous
	-- profile's colors and sizes until something else touched it.
	hooksecurefunc(E, "UpdateAll", function() QC:Update() end)
end

E:RegisterModule(QC:GetName(), function() QC:Initialize() end)
