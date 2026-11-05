-- A small stand-in for the WoW client, enough to load Bitácora and drive its events in Lua 5.1.
-- It does not draw anything: widget methods that only affect the screen are accepted and recorded.
-- That every global and method Bitácora calls exists in Forever is checked separately (tools/check_api.py).

MOCK = {
	events = {},       -- event -> list of frames
	timers = {},       -- pending C_Timer.After callbacks
	tickers = {},
	chat = {},         -- DEFAULT_CHAT_FRAME lines
	warnings = {},     -- RaidWarningUtil messages
	sounds = {},
	popups = {},
	tooltipCalls = {}, -- [type] = list of callbacks
	now = 1762240000,  -- 2025-11-04 07:06:40 UTC; tests move it
	gametime = 1000,
	player = { name = "Josecito", realm = "Forever", level = 10, class = "MAGE", race = "Human", money = 0 },
	where = { mapID = 1429, zone = "Elwynn Forest", sub = "Goldshire", x = 0.4231, y = 0.6512 },
	maps = { [1429] = "Elwynn Forest", [1453] = "Stormwind City", [1455] = "Ironforge" },
	group = {},        -- unit -> name, e.g. party1 = "Ana"
	secret = {},       -- values that issecretvalue() reports as secret
	quests = { [176] = "Wanted: Hogger" },
	items = {},        -- itemID -> quality
	locale = "enUS",
}

local real_time, real_date = os.time, os.date
function time(t)
	if t then
		return real_time(t)
	end
	return MOCK.now
end
function date(fmt, t)
	return real_date(fmt, t or MOCK.now)
end

-- string helpers WoW adds -------------------------------------------------------------------------
function strsplit(sep, s, limit)
	local out, start, count = {}, 1, 0
	while true do
		count = count + 1
		if limit and count >= limit then
			table.insert(out, s:sub(start))
			break
		end
		local i, j = s:find(sep, start, true)
		if not i then
			table.insert(out, s:sub(start))
			break
		end
		table.insert(out, s:sub(start, i - 1))
		start = j + 1
	end
	return unpack(out)
end
function strtrim(s)
	return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end
tinsert, tremove = table.insert, table.remove
function wipe(t)
	for k in pairs(t) do
		t[k] = nil
	end
	return t
end
function issecretvalue(v)
	return v ~= nil and MOCK.secret[v] == true
end
function GetLocale()
	return MOCK.locale
end
function GetTime()
	return MOCK.gametime
end

-- frames ------------------------------------------------------------------------------------------
local Frame = {}
local frameMeta = {
	__index = function(self, key)
		local m = Frame[key]
		if m then
			return m
		end
		-- any other widget method (WoW methods are PascalCase): accept the call, remember it, return nothing.
		-- Lower-case keys are the addon's own fields and stay nil until it sets them.
		if type(key) == "string" and key:match("^%u") then
			return function(obj, ...)
				table.insert(rawget(obj, "_calls"), { key, ... })
			end
		end
		return nil
	end,
}

local function newObject(kind, name, parent, template)
	-- the mock's own fields start with "_" so they never clash with fields the addon sets on its frames
	local o = setmetatable({ _kind = kind, _name = name, _parent = parent, _template = template, _scripts = {}, _calls = {}, _shown = true, _text = "" }, frameMeta)
	if name then
		_G[name] = o
	end
	if template and template:find("BasicFrameTemplate", 1, true) then
		o.TitleText = newObject("FontString", nil, o)
		o.CloseButton = newObject("Button", nil, o)
	end
	if template == "ScrollingEditBoxTemplate" then
		o.callbacks = {}
		o.editBox = newObject("EditBox", nil, o)
		o.scrollBox = newObject("Frame", nil, o)
	end
	if template == "PanelTabButtonTemplate" and parent then
		rawset(parent, "Tabs", rawget(parent, "Tabs") or {})
		table.insert(rawget(parent, "Tabs"), o)
	end
	if template == "UIPanelButtonTemplate" or kind == "Button" or kind == "CheckButton" then
		o.fontString = newObject("FontString", nil, o)
	end
	return o
end

function CreateFont(name)
	local f = newObject("Font", name)
	f._font = {}
	return f
end
function Frame:SetFont(path, size, flags)
	self._font = { path, size, flags }
end
function Frame:GetFont()
	return unpack(self._font or {})
end
function Frame:SetFontObject(font)
	self._fontObject = font
end
function Frame:GetFontObject()
	return self._fontObject
end
function Frame:SetNormalFontObject(font)
	self._normalFont = font
end
function Frame:GetNormalFontObject()
	return self._normalFont
end
function Frame:GetObjectType()
	return self._kind
end
function Frame:ClearAllPoints()
	self._points = {}
end
function Frame:SetPoint(...)
	self._points = self._points or {}
	table.insert(self._points, { ... })
end
function Frame:GetNumPoints()
	return #(self._points or {})
end
function Frame:SetTexCoord(...)
	self._texCoord = { ... }
end
function Frame:GetTexCoord()
	return unpack(self._texCoord or { 0, 1, 0, 1 })
end
function Frame:SetVertexColor(r, g, b, a)
	self._vertex = { r, g, b, a or 1 }
end
function Frame:SetAlpha(a)
	self._alpha = a
end
function Frame:GetAlpha()
	return self._alpha or 1
end
function Frame:SetNormalTexture(t)
	self._normalTexture = t
end
function Frame:SetCheckedTexture(t)
	self._checkedTexture = t
end
function Frame:SetEnabled(v)
	self._enabled = v and true or false
end
function Frame:IsEnabled()
	return self._enabled ~= false
end
function Frame:GetRegions() end
function Frame:GetChildren() end
MOCK.newObject = newObject

function Frame:SetScript(event, fn)
	self._scripts[event] = fn
end
function Frame:HookScript(event, fn)
	local old = self._scripts[event]
	self._scripts[event] = function(...)
		if old then
			old(...)
		end
		fn(...)
	end
end
function Frame:GetScript(event)
	return self._scripts[event]
end
function Frame:RegisterEvent(event)
	MOCK.events[event] = MOCK.events[event] or {}
	table.insert(MOCK.events[event], self)
end
function Frame:UnregisterEvent(event)
	local list = MOCK.events[event] or {}
	for i = #list, 1, -1 do
		if list[i] == self then
			table.remove(list, i)
		end
	end
end
function Frame:Show()
	local was = self._shown
	self._shown = true
	if not was and self._scripts.OnShow then
		self._scripts.OnShow(self)
	end
end
function Frame:Hide()
	local was = self._shown
	self._shown = false
	if was and self._scripts.OnHide then
		self._scripts.OnHide(self)
	end
end
function Frame:SetShown(v)
	if v then
		self:Show()
	else
		self:Hide()
	end
end
function Frame:IsShown()
	return self._shown
end
function Frame:IsVisible()
	local o = self
	while o do
		if not o._shown then
			return false
		end
		o = o._parent
	end
	return true
end
function Frame:SetText(t)
	self._text = t or ""
	if self.fontString then
		self.fontString._text = self._text
	end
	if self.editBox then
		self.editBox._text = self._text
	end
	if self._scripts.OnTextChanged then
		self._scripts.OnTextChanged(self, false)
	end
end
function Frame:GetText()
	return self._text
end
function Frame:Insert(t)
	self._text = self._text .. t
	if self.editBox then
		self.editBox._text = self._text
	end
	if self.callbacks and self.callbacks.OnTextChanged then
		self.callbacks.OnTextChanged[1](self.callbacks.OnTextChanged[2], self.editBox, true)
	end
end
function Frame:SetFocus()
	if MOCK.focus and MOCK.focus ~= self then
		MOCK.focus:ClearFocus()
	end
	MOCK.focus = self
	if self._scripts.OnEditFocusGained then
		self._scripts.OnEditFocusGained(self)
	end
end
function Frame:ClearFocus()
	if MOCK.focus == self then
		MOCK.focus = nil
		if self._scripts.OnEditFocusLost then
			self._scripts.OnEditFocusLost(self)
		end
	end
end
function Frame:HasFocus()
	return MOCK.focus == self
end
function Frame:GetChecked()
	return self.checked
end
function Frame:SetChecked(v)
	self.checked = v
end
function Frame:SetID(id)
	self.id = id
end
function Frame:GetID()
	return self.id or 0
end
function Frame:GetWidth()
	return self.width or 100
end
function Frame:SetWidth(w)
	self.width = w
end
function Frame:SetHeight(h)
	self.height = h
end
function Frame:GetCenter()
	return self._cx or 0, self._cy or 0
end
function Frame:GetEffectiveScale()
	return self._scale or 1
end
function Frame:SetMask(path)
	self.mask = path
end
function Frame:SetCursorPosition(n)
	self._cursor = n
end
function Frame:GetHeight()
	return self.height or 100
end
function Frame:SetSize(w, h)
	self.width, self.height = w, h
end
function Frame:GetSize()
	return self.width or 100, self.height or 100
end
function Frame:GetStringWidth()
	return #(self._text or "") * 6
end
function Frame:GetFontString()
	return self.fontString
end
function Frame:GetPoint()
	return "CENTER", nil, "CENTER", 10, 20
end
function Frame:CreateFontString()
	return newObject("FontString", nil, self)
end
function Frame:CreateTexture()
	return newObject("Texture", nil, self)
end
function Frame:SetTexture(path)
	self.texture = path
end
function Frame:GetEditBox()
	return self.editBox
end
function Frame:GetScrollBox()
	return self.scrollBox
end
function Frame:RegisterCallback(event, fn, owner)
	self.callbacks[event] = { fn, owner }
end
function Frame:SetDataProvider(provider)
	self.data = provider.items
	-- build rows like a ScrollBox would, so row initializers run
	if self.view and self.view.init then
		self.rows = {}
		for i, item in ipairs(self.data) do
			local row = self.rows[i] or newObject("Button", nil, self)
			self.rows[i] = row
			self.view.init(row, item)
		end
	end
	if self.managedBar and self.view then
		self.managedBar:SetShown(#self.data * (self.view.extent or 0) > self:GetHeight())
	end
end
function Frame:ForEachFrame(fn)
	for _, row in ipairs(self.rows or {}) do
		fn(row)
	end
end
function Frame:GetUnit()
	return self.unitName, self.unit
end
function Frame:GetItem()
	return self.itemName, self.itemLink
end
function Frame:AddLine(text)
	self.lines = self.lines or {}
	table.insert(self.lines, text)
end
function Frame:SetHyperlinksEnabled() end
function Frame:GetTextColor()
	return unpack(self._color or { 1, 1, 1, 1 })
end
function Frame:SetTextColor(r, g, b, a)
	if type(r) == "table" then
		self._color = { r.r, r.g, r.b, 1 }
	else
		self._color = { r, g, b, a or 1 }
	end
end
function Frame:GetFrameLevel()
	return self._level or 1
end
function Frame:CreateAnimationGroup()
	local ag = newObject("AnimationGroup", nil, self)
	ag._anims = {}
	function ag:CreateAnimation(kind)
		local a = newObject(kind, nil, self)
		table.insert(self._anims, a)
		return a
	end
	function ag:Play()
		MOCK.played = (MOCK.played or 0) + 1
		if self._scripts.OnFinished then
			self._scripts.OnFinished(self)
		end
	end
	return ag
end
function CreateColor(r, g, b)
	return { r = r, g = g, b = b }
end
function Frame:GetXY()
	return self.x, self.y
end

function CreateFrame(kind, name, parent, template)
	return newObject(kind, name, parent, template)
end

UIParent = newObject("Frame", "UIParent")
Minimap = newObject("Frame", "Minimap")
Minimap.width, Minimap.height, Minimap._cx, Minimap._cy = 140, 140, 1000, 500
function GetCursorPosition()
	return MOCK.cursorX or 0, MOCK.cursorY or 0
end
GameTooltip = newObject("GameTooltip", "GameTooltip")
ItemRefTooltip = newObject("GameTooltip", "ItemRefTooltip")
DEFAULT_CHAT_FRAME = newObject("ScrollingMessageFrame", "ChatFrame1")
function DEFAULT_CHAT_FRAME:AddMessage(text)
	table.insert(MOCK.chat, text)
end
UISpecialFrames = {}
StaticPopupDialogs = {}
SlashCmdList = {}
ACCEPT, CANCEL, YES, NO, OKAY = "Accept", "Cancel", "Yes", "No", "Okay"
RAID_CLASS_COLORS = { MAGE = { colorStr = "ff3fc7eb" }, PRIEST = { colorStr = "ffffffff" }, WARRIOR = { colorStr = "ffc69b6d" } }
SOUNDKIT = { RAID_WARNING = 8959, IG_CHARACTER_INFO_TAB = 841, IG_CHARACTER_INFO_OPEN = 839, IG_CHARACTER_INFO_CLOSE = 840 }
ChatTypeInfo = { RAID_WARNING = { r = 1, g = 0.28, b = 0 } }
function PlaySound(id)
	table.insert(MOCK.sounds, id)
end
RaidWarningUtil = {
	AddMessage = function(text, color)
		assert(type(color) == "table" and color.r, "RaidWarningUtil.AddMessage needs a color table")
		table.insert(MOCK.warnings, text)
	end,
}
function StaticPopup_Show(which, text, _, data)
	assert(StaticPopupDialogs[which], "unknown popup " .. tostring(which))
	table.insert(MOCK.popups, { which = which, text = text, data = data })
end
function hooksecurefunc(tbl, name, fn)
	if type(tbl) == "string" then
		tbl, name, fn = _G, tbl, name
	end
	local old = tbl[name]
	tbl[name] = function(...)
		local r = { old(...) }
		fn(...)
		return unpack(r)
	end
end
ChatFrameUtil = {
	InsertLink = function()
		return false
	end,
}

-- menus and lists ---------------------------------------------------------------------------------
local function newDescription()
	local d = { items = {} }
	function d:CreateButton(text, fn)
		table.insert(self.items, { kind = "button", text = text, fn = fn })
	end
	function d:CreateRadio(text, isSel, setSel)
		table.insert(self.items, { kind = "radio", text = text, isSel = isSel, fn = setSel })
	end
	function d:CreateCheckbox(text, isSel, setSel)
		table.insert(self.items, { kind = "check", text = text, isSel = isSel, fn = setSel })
	end
	function d:CreateTitle(text)
		table.insert(self.items, { kind = "title", text = text })
	end
	function d:CreateDivider() end
	return d
end
MenuUtil = {
	CreateContextMenu = function(owner, generator)
		local root = newDescription()
		generator(owner, root)
		MOCK.lastMenu = root
		return root
	end,
}
function MOCK.clickMenu(text)
	for _, item in ipairs(MOCK.lastMenu.items) do
		if item.text == text then
			item.fn()
			return true
		end
	end
	error("no menu item " .. text)
end

function CreateScrollBoxListLinearView()
	local v = {}
	function v:SetElementExtent(h)
		self.extent = h
	end
	function v:SetElementInitializer(kind, init)
		self.init = init
	end
	return v
end
function CreateDataProvider(items)
	return { items = items }
end
ScrollBoxConstants = { RetainScrollPosition = true }
ScrollUtil = {
	InitScrollBoxListWithScrollBar = function(box, bar, view)
		assert(view.extent, "set the element extent")
		box.view = view
	end,
	RegisterScrollBoxWithScrollBar = function() end,
	-- like the client's: the bar shows only while the rows overflow the box (checked when data is set)
	AddManagedScrollBarVisibilityBehavior = function(box, bar)
		box.managedBar = bar
	end,
}
function PanelTemplates_SetNumTabs(f, n)
	f.numTabs = n
end
function PanelTemplates_SetTab(f, i)
	f.selectedTab = i
end
function PanelTemplates_GetSelectedTab(f)
	return f.selectedTab
end

-- game state --------------------------------------------------------------------------------------
function UnitFullName(unit)
	if unit == "player" then
		return MOCK.player.name, MOCK.player.realm
	end
end
function GetRealmName()
	return MOCK.player.realm
end
MOCK.groupRealm = {} -- unit -> realm of a group member from another realm
function UnitName(unit)
	if unit == "player" then
		-- like the game: a second value (the realm, nil for your own) that spills into table.insert and the like
		return MOCK.player.name, nil
	end
	if unit == "target" then
		return MOCK.target and MOCK.target.name
	end
	return MOCK.group[unit], MOCK.groupRealm[unit]
end
function UnitIsUnit(a, b)
	return a == b or (b == "player" and MOCK.group[a] == MOCK.player.name)
end
function UnitExists(unit)
	return unit == "player" or (unit == "target" and MOCK.target ~= nil) or MOCK.group[unit] ~= nil
end
function UnitGUID(unit)
	if unit == "target" or unit == "mouseover" then
		return MOCK.target and MOCK.target.guid
	end
end
function UnitIsPlayer(unit)
	return unit == "player" or (MOCK.target and MOCK.target.player) or false
end
function UnitLevel()
	return MOCK.player.level
end
MOCK.groupClass = {} -- unit -> class token of a group member
function UnitClass(unit)
	if unit and unit ~= "player" and MOCK.groupClass[unit] then
		return MOCK.groupClass[unit], MOCK.groupClass[unit]
	end
	return "Mage", MOCK.player.class
end
function UnitRace()
	return "Human", MOCK.player.race
end
function GetMoney()
	return MOCK.player.money
end
function GetNumGroupMembers()
	local n = 0
	for _ in pairs(MOCK.group) do
		n = n + 1
	end
	return n > 0 and n + 1 or 0
end
function IsInRaid()
	return MOCK.raid == true
end
function GetRealZoneText()
	return MOCK.where.zone
end
function GetZoneText()
	return MOCK.where.zone
end
function GetSubZoneText()
	return MOCK.where.sub
end
C_Map = {
	GetBestMapForUnit = function()
		return MOCK.where.mapID
	end,
	GetMapInfo = function(id)
		return MOCK.maps[id] and { name = MOCK.maps[id] }
	end,
	GetPlayerMapPosition = function()
		if MOCK.where.x then
			local v = newObject("Vector2D")
			v.x, v.y = MOCK.where.x, MOCK.where.y
			return v
		end
	end,
}
C_Timer = {
	After = function(_, fn)
		table.insert(MOCK.timers, fn)
	end,
	NewTicker = function(_, fn)
		table.insert(MOCK.tickers, fn)
		return {}
	end,
}
C_QuestLog = {
	GetTitleForQuestID = function(id)
		return MOCK.quests[id]
	end,
}
C_Item = {
	GetItemQualityByID = function(link)
		local id = tonumber(link:match("item:(%d+)"))
		return MOCK.items[id]
	end,
	GetItemInfoInstant = function(link)
		return tonumber(tostring(link):match("item:(%d+)"))
	end,
}
function GetAchievementInfo(id)
	return id, "Level 10"
end
function GetAchievementLink(id)
	return "|cffffff00|Hachievement:" .. id .. "|h[Level 10]|h|r"
end
function GetMoneyString(c)
	return math.floor(c / 10000) .. "g"
end
function SecondsToTime(s)
	return s .. "s"
end
function SetItemRef() end
Enum = { TooltipDataType = { Item = 0, Unit = 2 } }
TooltipDataProcessor = {
	AddTooltipPostCall = function(kind, fn)
		MOCK.tooltipCalls[kind] = MOCK.tooltipCalls[kind] or {}
		table.insert(MOCK.tooltipCalls[kind], fn)
	end,
}

LOOT_ITEM_SELF = "You receive loot: %s"
LOOT_ITEM_SELF_MULTIPLE = "You receive loot: %sx%d"
LOOT_ITEM_PUSHED_SELF = "You receive item: %s"
LOOT_ITEM_PUSHED_SELF_MULTIPLE = "You receive item: %sx%d"
LOOT_ITEM_CREATED_SELF = "You create: %s."

C_AddOns = {
	IsAddOnLoaded = function(name)
		return MOCK.loaded and MOCK.loaded[name] == true
	end,
}

-- driving -----------------------------------------------------------------------------------------
function MOCK.fire(event, ...)
	for _, f in ipairs(MOCK.events[event] or {}) do
		local fn = f._scripts.OnEvent
		if fn then
			fn(f, event, ...)
		end
	end
end
function MOCK.runTimers()
	local timers = MOCK.timers
	MOCK.timers = {}
	for _, fn in ipairs(timers) do
		fn()
	end
end
function MOCK.tick()
	for _, fn in ipairs(MOCK.tickers) do
		fn()
	end
end
function MOCK.lastChat()
	return MOCK.chat[#MOCK.chat]
end

-- SavedVariables the way the client writes them on logout (WTF/Account/<ACCOUNT>/SavedVariables/Bitacora_Datos.lua):
-- one entry per line, ["key"] = value, array entries with a "-- [n]" comment.
local function quote(s)
	return '"' .. s:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n"):gsub("\r", "\\r") .. '"'
end
local function serializeValue(v, out, indent)
	local t = type(v)
	if t == "string" then
		table.insert(out, quote(v))
	elseif t == "number" then
		table.insert(out, (v == math.floor(v) and math.abs(v) < 2 ^ 53) and string.format("%d", v) or string.format("%.14g", v))
	elseif t == "boolean" then
		table.insert(out, tostring(v))
	elseif t == "table" then
		table.insert(out, "{\n")
		local n = #v
		for i = 1, n do
			table.insert(out, indent .. "\t")
			serializeValue(v[i], out, indent .. "\t")
			table.insert(out, ", -- [" .. i .. "]\n")
		end
		local keys = {}
		for k in pairs(v) do
			if not (type(k) == "number" and k >= 1 and k <= n and k == math.floor(k)) then
				table.insert(keys, k)
			end
		end
		table.sort(keys, function(a, b)
			return tostring(a) < tostring(b)
		end)
		for _, k in ipairs(keys) do
			table.insert(out, indent .. "\t[")
			serializeValue(k, out, indent)
			table.insert(out, "] = ")
			serializeValue(v[k], out, indent .. "\t")
			table.insert(out, ",\n")
		end
		table.insert(out, indent .. "}")
	else
		table.insert(out, "nil")
	end
end
function MOCK.savedVariables(name)
	local out = { "\n", name, " = " }
	serializeValue(_G[name], out, "")
	table.insert(out, "\n")
	return table.concat(out)
end
