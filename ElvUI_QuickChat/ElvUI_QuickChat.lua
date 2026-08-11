--[[
================================================================================
ElvUI_QuickChat
================================================================================
A row of buttons that pre-fill the chat edit box for a channel (Say / Yell /
Party / Guild / Officer / Raid / Raid Warning / Reply), so you can jump
between them without typing the slash command. Built as a proper ElvUI
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
================================================================================
]]

local E, L, V, P, G = unpack(ElvUI)
local QC = E:NewModule("QuickChat", "AceEvent-3.0")
local EP = LibStub("LibElvUIPlugin-1.0")
local addonName = ...

-- label, slash prefix, r, g, b, tooltip text
local CHANNELS = {
	{ "S",  "/s ",     1.00, 1.00, 1.00, "Say" },
	{ "Y",  "/y ",     0.90, 0.10, 0.10, "Yell" },
	{ "P",  "/p ",     0.35, 0.55, 1.00, "Party" },
	{ "G",  "/g ",     0.20, 0.85, 0.20, "Guild" },
	{ "O",  "/o ",     0.85, 0.65, 0.10, "Officer" },
	{ "R",  "/raid ",  1.00, 0.50, 0.00, "Raid" },
	{ "RW", "/rw ",    1.00, 0.30, 0.65, "Raid Warning" },
	{ "W",  "/r ",     0.70, 0.70, 0.70, "Reply (last whisper)" },
}

local BTN_W, BTN_H, SPACING = 26, 20, 2

----------------------------------------------------------------------
-- Profile defaults
----------------------------------------------------------------------
P["quickchat"] = {
	["enable"] = true,
}

----------------------------------------------------------------------
-- Bar
----------------------------------------------------------------------
local function ChannelButton_OnClick(self)
	ChatFrame_OpenChat(self.prefix, DEFAULT_CHAT_FRAME)
end

local function ChannelButton_OnEnter(self)
	GameTooltip:SetOwner(self, "ANCHOR_TOP")
	GameTooltip:SetText(self.tooltipText, 1, 1, 1)
	GameTooltip:Show()
	self.bg:SetAlpha(1)
end

local function ChannelButton_OnLeave(self)
	GameTooltip:Hide()
	self.bg:SetAlpha(0.75)
end

local function CreateChannelButton(parent, index, data)
	local label, prefix, r, g, b, tooltipText = data[1], data[2], data[3], data[4], data[5], data[6]

	local btn = CreateFrame("Button", "QuickChatButton" .. index, parent)
	btn:SetSize(BTN_W, BTN_H)
	btn:SetPoint("LEFT", (index - 1) * (BTN_W + SPACING), 0)

	local bg = btn:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetTexture("Interface\\Buttons\\WHITE8x8")
	bg:SetVertexColor(r, g, b)
	bg:SetAlpha(0.75)
	btn.bg = bg

	local border = CreateFrame("Frame", nil, btn)
	border:SetAllPoints()
	if border.SetBackdrop then
		border:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
		border:SetBackdropBorderColor(0, 0, 0, 0.9)
	end

	local text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	text:SetPoint("CENTER")
	text:SetTextColor(0, 0, 0)
	text:SetShadowColor(0, 0, 0, 0)
	text:SetText(label)

	btn.prefix = prefix
	btn.tooltipText = tooltipText
	btn:SetScript("OnClick", ChannelButton_OnClick)
	btn:SetScript("OnEnter", ChannelButton_OnEnter)
	btn:SetScript("OnLeave", ChannelButton_OnLeave)

	return btn
end

function QC:CreateBar()
	if self.bar then return self.bar end

	local numButtons = #CHANNELS
	local width = numButtons * BTN_W + (numButtons - 1) * SPACING

	local bar = CreateFrame("Frame", "QuickChatBar", E.UIParent)
	bar:SetSize(width, BTN_H)
	bar:Point("BOTTOMLEFT", E.UIParent, "BOTTOMLEFT", 20, 250) -- initial default; overridden by saved mover position

	for i, data in ipairs(CHANNELS) do
		CreateChannelButton(bar, i, data)
	end

	E:CreateMover(bar, "QuickChatMover", L["Quick Chat"] or "Quick Chat", nil, nil, nil, nil, nil, "chat,quickchat")

	self.bar = bar
	return bar
end

function QC:UpdateVisibility()
	if not self.bar then return end
	if E.db.quickchat.enable then
		self.bar:Show()
		_G.QuickChatMover:Show()
	else
		self.bar:Hide()
		_G.QuickChatMover:Hide()
	end
end

----------------------------------------------------------------------
-- Options: new tab under Chat
----------------------------------------------------------------------
local function InsertOptions()
	if not E.Options.args.chat or not E.Options.args.chat.args then return end

	E.Options.args.chat.args.quickchat = {
		order = 19, -- after the built-in Chat tabs
		type = "group",
		name = L["Quick Chat"] or "Quick Chat",
		args = {
			intro = {
				order = 1,
				type = "description",
				name = "Adds a row of buttons near your chat frame to quickly switch channels (Say/Yell/Party/Guild/Officer/Raid/Raid Warning/Reply). Right-click drag isn't used here - move it with ElvUI's own 'Toggle Anchors' like any other element.",
			},
			enable = {
				order = 2,
				type = "toggle",
				name = L["Enable"],
				get = function(info) return E.db.quickchat.enable end,
				set = function(info, value)
					E.db.quickchat.enable = value
					QC:UpdateVisibility()
				end,
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
	self:UpdateVisibility()
end

E:RegisterModule(QC:GetName(), function() QC:Initialize() end)
