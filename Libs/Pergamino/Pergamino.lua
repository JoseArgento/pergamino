-- Pergamino: the shared look of José Argento's addons for WoW Forever. An open book of parchment pages
-- inside a leather cover, cloth bookmarks as tabs, ink typography (Cinzel for headings, Alegreya for body).
-- Textures and fonts are the library's own (Media/, Fonts/; see tools/make_textures.py and Fonts/OFL.txt).
--
-- Vendored: each addon ships its own copy under Libs/Pergamino and loads this file first. The newest copy
-- wins; an older one loaded later leaves the newer alone. Media and fonts are read from the folder of the
-- addon whose copy got loaded, so every copy must be complete.
--
-- No Blizzard frame templates: every piece is drawn here.

local ADDON = ...
local VERSION = 7

if Pergamino and (Pergamino.VERSION or 0) >= VERSION then
	return
end

local P = Pergamino or {}
Pergamino = P
P.VERSION = VERSION
P.MEDIA = "Interface\\AddOns\\" .. ADDON .. "\\Libs\\Pergamino\\Media\\"
P.FONTS = "Interface\\AddOns\\" .. ADDON .. "\\Libs\\Pergamino\\Fonts\\"

-- inks ---------------------------------------------------------------------------------------------------
P.INK = { 0.23, 0.14, 0.07 } -- #3a2313
P.INK_SOFT = { 0.42, 0.31, 0.19 } -- #6c4e31
P.CRIMSON = { 0.56, 0.16, 0.11 } -- #8f2a1d
P.GOLD = { 0.85, 0.66, 0.27 } -- #d8a845
P.GOLD_DEEP = { 0.58, 0.44, 0.12 } -- #94701f
P.LINK = { 0.17, 0.36, 0.66 } -- #2b5da8
P.PARCHMENT = { 0.95, 0.89, 0.75 } -- #f2e3c0
P.GREEN = { 0.11, 0.43, 0.06 }
P.PURPLE = { 0.44, 0.15, 0.68 }

-- the colour of a tag by what it marks (the web pages use the same ones)
P.KIND_COLORS = {
	level = P.GOLD_DEEP,
	boss = P.CRIMSON,
	death = P.CRIMSON,
	note = P.LINK,
	loot = P.PURPLE,
	zone = P.GREEN,
	quest = P.INK_SOFT,
	achievement = P.GOLD_DEEP,
	legacy = P.GOLD_DEEP,
	money = P.GOLD_DEEP,
	start = P.INK_SOFT,
	played = P.INK_SOFT,
	camp = P.GREEN,
	blueprint = P.INK_SOFT,
	pinned = P.GOLD_DEEP,
	guild = P.LINK,
	done = P.INK_SOFT,
}

local function rgb(c)
	return c[1], c[2], c[3]
end
P.RGB = rgb

-- fonts --------------------------------------------------------------------------------------------------
-- One Font object per role; frames take them with SetFontObject so a later copy of the library can
-- restyle everything at once.
local function font(name, file, size, color, flags)
	local f = _G[name] or CreateFont(name)
	f:SetFont(P.FONTS .. file, size, flags or "")
	f:SetTextColor(rgb(color))
	f:SetShadowColor(0, 0, 0, 0)
	f:SetShadowOffset(0, 0)
	return f
end

P.fonts = {
	title = font("PergaminoTitle", "Cinzel-Bold.ttf", 16, P.GOLD),
	heading = font("PergaminoHeading", "Cinzel-SemiBold.ttf", 13, P.CRIMSON),
	subheading = font("PergaminoSubheading", "Cinzel-SemiBold.ttf", 11, P.INK),
	body = font("PergaminoBody", "Alegreya-Regular.ttf", 14, P.INK),
	strong = font("PergaminoStrong", "Alegreya-SemiBold.ttf", 14, P.INK),
	italic = font("PergaminoItalic", "Alegreya-Italic.ttf", 14, P.INK),
	big = font("PergaminoBig", "Alegreya-SemiBold.ttf", 18, P.INK),
	small = font("PergaminoSmall", "Alegreya-Regular.ttf", 12, P.INK_SOFT),
	muted = font("PergaminoMuted", "Alegreya-Italic.ttf", 13, P.INK_SOFT),
	link = font("PergaminoLink", "Alegreya-SemiBold.ttf", 14, P.LINK),
	button = font("PergaminoButton", "Cinzel-SemiBold.ttf", 11, P.GOLD),
	buttonDisabled = font("PergaminoButtonDisabled", "Cinzel-SemiBold.ttf", 11, P.INK_SOFT),
	chip = font("PergaminoChip", "Cinzel-SemiBold.ttf", 11, P.INK),
	chipOn = font("PergaminoChipOn", "Cinzel-SemiBold.ttf", 11, P.PARCHMENT),
	tab = font("PergaminoTab", "Cinzel-SemiBold.ttf", 10, P.PARCHMENT),
	tabOn = font("PergaminoTabOn", "Cinzel-SemiBold.ttf", 10, P.INK),
	tag = font("PergaminoTag", "Cinzel-SemiBold.ttf", 9, P.PARCHMENT),
}

-- small helpers ------------------------------------------------------------------------------------------
local function line(parent, layer, color, alpha)
	local t = parent:CreateTexture(nil, layer or "ARTWORK")
	t:SetColorTexture(color[1], color[2], color[3], alpha or 1)
	return t
end

-- A text in one of the roles above. justify defaults to LEFT.
function P.Label(parent, text, role, justify)
	local fs = parent:CreateFontString(nil, "OVERLAY")
	fs:SetFontObject(P.fonts[role or "body"] or P.fonts.body)
	fs:SetText(text or "")
	fs:SetJustifyH(justify or "LEFT")
	fs.role = role or "body"
	return fs
end

-- A thin ink rule, horizontal; anchor it yourself (height is 1).
function P.Rule(parent, alpha)
	local t = line(parent, "ARTWORK", P.INK, alpha or 0.35)
	t:SetHeight(1)
	return t
end

-- A faint recessed area with an ink border: for lists and long texts on a page.
function P.Panel(parent)
	local f = CreateFrame("Frame", nil, parent)
	local fill = f:CreateTexture(nil, "BACKGROUND")
	fill:SetAllPoints()
	fill:SetColorTexture(0.23, 0.14, 0.07, 0.05)
	f.fill = fill
	f.edges = {}
	for i, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
		local e = line(f, "BORDER", P.INK, 0.35)
		if side == "TOP" or side == "BOTTOM" then
			e:SetPoint(side .. "LEFT")
			e:SetPoint(side .. "RIGHT")
			e:SetHeight(1)
		else
			e:SetPoint("TOP" .. side)
			e:SetPoint("BOTTOM" .. side)
			e:SetWidth(1)
		end
		f.edges[i] = e
	end
	return f
end

-- A leather button with gold lettering. Any width; 26 high.
function P.Button(parent, text, width, onClick)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(width or 100, 26)
	local fill = b:CreateTexture(nil, "BACKGROUND")
	fill:SetAllPoints()
	fill:SetTexture(P.MEDIA .. "leather")
	fill:SetTexCoord(0.2, 0.6, 0.2, 0.4)
	b.fill = fill
	local outer, inner = {}, {}
	for i, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
		local o = line(b, "BORDER", P.GOLD_DEEP)
		local n = line(b, "ARTWORK", P.GOLD, 0.8)
		if side == "TOP" or side == "BOTTOM" then
			o:SetPoint(side .. "LEFT")
			o:SetPoint(side .. "RIGHT")
			o:SetHeight(1)
			n:SetPoint(side .. "LEFT", 1, side == "TOP" and -1 or 1)
			n:SetPoint(side .. "RIGHT", -1, side == "TOP" and -1 or 1)
			n:SetHeight(1)
		else
			o:SetPoint("TOP" .. side)
			o:SetPoint("BOTTOM" .. side)
			o:SetWidth(1)
			n:SetPoint("TOP" .. side, side == "LEFT" and 1 or -1, -1)
			n:SetPoint("BOTTOM" .. side, side == "LEFT" and 1 or -1, 1)
			n:SetWidth(1)
		end
		outer[i], inner[i] = o, n
	end
	local hl = b:CreateTexture(nil, "HIGHLIGHT")
	hl:SetAllPoints()
	hl:SetColorTexture(1, 0.9, 0.6, 0.12)
	b:SetNormalFontObject(P.fonts.button)
	b:SetHighlightFontObject(P.fonts.button)
	b:SetDisabledFontObject(P.fonts.buttonDisabled)
	b:SetPushedTextOffset(1, -1)
	b:SetText(text or "")
	if onClick then
		b:SetScript("OnClick", onClick)
	end
	return b
end

-- An ink pill for filters: SetPressed(true) fills it with ink and writes in parchment.
function P.Chip(parent, text, onClick)
	local b = CreateFrame("Button", nil, parent)
	b:SetHeight(20)
	local fill = b:CreateTexture(nil, "BACKGROUND")
	fill:SetAllPoints()
	fill:SetTexture(P.MEDIA .. "pill")
	fill:SetVertexColor(rgb(P.INK))
	b.fill = fill
	local hl = b:CreateTexture(nil, "HIGHLIGHT")
	hl:SetAllPoints()
	hl:SetTexture(P.MEDIA .. "pill")
	hl:SetVertexColor(0.23, 0.14, 0.07, 0.12)
	b:SetNormalFontObject(P.fonts.chip)
	b:SetHighlightFontObject(P.fonts.chip)
	b:SetText(text or "")
	function b:SetPressed(on)
		self.pressed = on and true or false
		self.fill:SetAlpha(on and 1 or 0.14)
		self:SetNormalFontObject(on and P.fonts.chipOn or P.fonts.chip)
		self:SetHighlightFontObject(on and P.fonts.chipOn or P.fonts.chip)
	end
	function b:Fit()
		local fs = self:GetFontString()
		self:SetWidth(math.max(44, (fs and fs:GetStringWidth() or 30) + 22))
	end
	b:SetPressed(false)
	b:Fit()
	if onClick then
		b:SetScript("OnClick", onClick)
	end
	return b
end

-- An ink box with a tick; .label is the text beside it. GetChecked/SetChecked as any CheckButton.
function P.Check(parent, text, onClick)
	local c = CreateFrame("CheckButton", nil, parent)
	c:SetSize(18, 18)
	local box = c:CreateTexture(nil, "ARTWORK")
	box:SetAllPoints()
	box:SetTexture(P.MEDIA .. "check")
	box:SetTexCoord(0, 0.5, 0, 1)
	c:SetNormalTexture(box)
	local tick = c:CreateTexture(nil, "OVERLAY")
	tick:SetAllPoints()
	tick:SetTexture(P.MEDIA .. "check")
	tick:SetTexCoord(0.5, 1, 0, 1)
	c:SetCheckedTexture(tick)
	local hl = c:CreateTexture(nil, "HIGHLIGHT")
	hl:SetAllPoints()
	hl:SetColorTexture(0.23, 0.14, 0.07, 0.1)
	c.label = P.Label(c, text, "body")
	c.label:SetPoint("LEFT", c, "RIGHT", 6, 0)
	c:SetHitRectInsets(0, -(c.label:GetStringWidth() + 8), 0, 0)
	if onClick then
		c:SetScript("OnClick", onClick)
	end
	return c
end

-- A single-line field: just text over an ink line, with a placeholder.
-- opts: { placeholder, font, maxLetters, onEnter(edit), onChange(edit, text) }. onChange fires only for what the
-- player types; edit:SetValue(text) writes without firing it and keeps the caret at the end, so a value the
-- addon recomputes (a count after "+") never shows the old typed text beside the new one.
function P.Edit(parent, width, opts)
	opts = opts or {}
	local e = CreateFrame("EditBox", nil, parent)
	e:SetSize(width or 150, 24)
	e:SetAutoFocus(false)
	e:SetFontObject(opts.font or P.fonts.body)
	e:SetTextInsets(2, 2, 0, 2)
	e:SetMaxLetters(opts.maxLetters or 0)
	local under = line(e, "BACKGROUND", P.INK, 0.6)
	under:SetPoint("BOTTOMLEFT")
	under:SetPoint("BOTTOMRIGHT")
	under:SetHeight(1)
	e.under = under
	local ph = P.Label(e, opts.placeholder or "", "muted")
	ph:SetPoint("LEFT", 2, 0)
	ph:SetPoint("RIGHT", -2, 0)
	e.placeholder = ph
	local function updatePlaceholder()
		ph:SetShown((e:GetText() or "") == "" and not e:HasFocus())
	end
	e:SetScript("OnEscapePressed", function(self)
		self:ClearFocus()
	end)
	e:SetScript("OnEnterPressed", function(self)
		if opts.onEnter then
			opts.onEnter(self)
		end
		self:ClearFocus()
	end)
	e:SetScript("OnEditFocusGained", function(self)
		self.under:SetAlpha(1)
		updatePlaceholder()
	end)
	e:SetScript("OnEditFocusLost", function(self)
		self.under:SetAlpha(0.6)
		updatePlaceholder()
	end)
	e:SetScript("OnTextChanged", function(self, userInput)
		updatePlaceholder()
		if userInput and not self.silent and opts.onChange then
			opts.onChange(self, self:GetText() or "")
		end
	end)
	function e:SetPlaceholder(text)
		ph:SetText(text or "")
	end
	function e:SetValue(text)
		text = text == nil and "" or tostring(text)
		self.silent = true
		self:SetText(text)
		self.silent = false
		if self.SetCursorPosition then
			self:SetCursorPosition(#text)
		end
		updatePlaceholder()
	end
	updatePlaceholder()
	return e
end

-- A multi-line text area: Blizzard's scrolling edit box with our font and a bar beside it.
-- Same interface as ScrollingEditBoxTemplate (GetEditBox, SetText, RegisterCallback("OnTextChanged", ...)).
function P.TextArea(parent)
	local holder = CreateFrame("Frame", nil, parent)
	local box = CreateFrame("Frame", nil, holder, "ScrollingEditBoxTemplate")
	box:SetPoint("TOPLEFT", 4, -4)
	box:SetPoint("BOTTOMRIGHT", -22, 4)
	local bar = CreateFrame("EventFrame", nil, holder, "MinimalScrollBar")
	bar:SetPoint("TOPLEFT", box, "TOPRIGHT", 4, 0)
	bar:SetPoint("BOTTOMLEFT", box, "BOTTOMRIGHT", 4, 0)
	bar:SetAlpha(0.7)
	if ScrollUtil and ScrollUtil.RegisterScrollBoxWithScrollBar and box.GetScrollBox then
		ScrollUtil.RegisterScrollBoxWithScrollBar(box:GetScrollBox(), bar)
	end
	if box.SetFontObject then
		box:SetFontObject(P.fonts.body)
	end
	local edit = box.GetEditBox and box:GetEditBox()
	if edit then
		-- Blizzard's EventEditBox puts back its own font (fontName) and colour (textColor) on every
		-- SetText, which left the text white on the parchment: give it ours so it puts back ink.
		edit.fontName = P.fonts.body
		edit.defaultFontName = P.fonts.muted
		if CreateColor then
			edit.textColor = CreateColor(P.INK[1], P.INK[2], P.INK[3], 1)
			edit.defaultFontColor = CreateColor(P.INK_SOFT[1], P.INK_SOFT[2], P.INK_SOFT[3], 1)
		end
		if edit.SetFontObject then
			edit:SetFontObject(P.fonts.body)
		end
		if edit.SetTextColor then
			edit:SetTextColor(rgb(P.INK))
		end
	end
	holder.box, holder.bar = box, bar
	return holder
end

-- A small coloured pill with white lettering ("level", "boss"…). kind picks the colour (P.KIND_COLORS).
function P.Tag(parent, text, kind)
	local f = CreateFrame("Frame", nil, parent)
	f:SetHeight(14)
	local bg = f:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetTexture(P.MEDIA .. "pill")
	f.bg = bg
	f.text = P.Label(f, "", "tag", "CENTER")
	f.text:SetPoint("CENTER", 0, 0)
	function f:Set(label, k)
		self.text:SetText(string.upper(label or ""))
		local c = P.KIND_COLORS[k or ""] or P.INK_SOFT
		self.bg:SetVertexColor(rgb(c))
		self:SetWidth(self.text:GetStringWidth() + 12)
	end
	f:Set(text, kind)
	return f
end

-- Hover and selection of a list row, in ink and gold.
function P.TintRow(row)
	if not row.highlight then
		row.highlight = row:CreateTexture(nil, "HIGHLIGHT")
		row.highlight:SetAllPoints()
		row.selected = row:CreateTexture(nil, "BACKGROUND")
		row.selected:SetAllPoints()
		row.selected:Hide()
		row.rule = line(row, "BORDER", P.INK, 0.22)
		row.rule:SetPoint("BOTTOMLEFT", 2, 0)
		row.rule:SetPoint("BOTTOMRIGHT", -2, 0)
		row.rule:SetHeight(1)
	end
	row.highlight:SetColorTexture(0.23, 0.14, 0.07, 0.07)
	row.selected:SetColorTexture(0.85, 0.66, 0.27, 0.28)
end

-- A scrolling list (the modern ScrollBox) whose rows are plain Buttons with an ink rule under each.
-- init(row, item) fills a row; onClick(item, mouseButton, row) on click.
function P.List(parent, rowHeight, init, onClick)
	local box = CreateFrame("Frame", nil, parent, "WowScrollBoxList")
	local bar = CreateFrame("EventFrame", nil, parent, "MinimalScrollBar")
	bar:SetPoint("TOPLEFT", box, "TOPRIGHT", 6, 0)
	bar:SetPoint("BOTTOMLEFT", box, "BOTTOMRIGHT", 6, 0)
	bar:SetAlpha(0.7)
	local view = CreateScrollBoxListLinearView()
	view:SetElementExtent(rowHeight)
	view:SetElementInitializer("Button", function(row, item)
		if not row.made then
			row.made = true
			P.TintRow(row)
			row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		end
		row.item = item
		row:SetScript("OnClick", function(self, button)
			if onClick then
				onClick(self.item, button, self)
			end
		end)
		init(row, item)
	end)
	ScrollUtil.InitScrollBoxListWithScrollBar(box, bar, view)
	-- the bar only shows while there is more than fits: Blizzard's behaviour when the client has it, else ours
	local managed = ScrollUtil.AddManagedScrollBarVisibilityBehavior ~= nil
	if managed then
		ScrollUtil.AddManagedScrollBarVisibilityBehavior(box, bar)
	end
	local list = { box = box, bar = bar, rowHeight = rowHeight }
	function list:SetData(items, keepScroll)
		box:SetDataProvider(CreateDataProvider(items), keepScroll and ScrollBoxConstants.RetainScrollPosition or nil)
		if not managed then
			bar:SetShown(#items * rowHeight > (box:GetHeight() or 0))
		end
	end
	function list:Refresh()
		box:ForEachFrame(function(row)
			if row.item then
				init(row, row.item)
			end
		end)
	end
	return list
end

-- Give every font string under a frame the body ink (for widgets not built here).
function P.Apply(frame, role)
	local f = P.fonts[role or "body"]
	if frame.GetRegions then
		for _, r in ipairs({ frame:GetRegions() }) do
			if r.GetObjectType and r:GetObjectType() == "FontString" and r.SetFontObject then
				r:SetFontObject(f)
			end
		end
	end
	if frame.GetChildren then
		for _, c in ipairs({ frame:GetChildren() }) do
			P.Apply(c, role)
		end
	end
end

-- the book -----------------------------------------------------------------------------------------------
local LEATHER = 18 -- the cover around the pages
local MARGIN = 22 -- inside each page
-- a bookmark: the first TAB_IN px are tucked under the book; the label gets the rest, on one line.
-- Each bookmark is its own colour (P.BOOKMARK_COLORS, in order), with air between them; the open one is
-- brighter, a little longer and has a gold edge where it leaves the book.
local TAB_W, TAB_W_ON, TAB_H, TAB_GAP, TAB_TOP, TAB_IN = 150, 164, 28, 12, 64, 22
local TAB_SMALL_W, TAB_SMALL_H = 128, 22
P.BOOKMARK_COLORS = {
	{ 0.56, 0.16, 0.11 }, -- crimson
	{ 0.18, 0.29, 0.48 }, -- indigo
	{ 0.24, 0.42, 0.23 }, -- moss
	{ 0.60, 0.42, 0.11 }, -- ochre
	{ 0.37, 0.21, 0.40 }, -- plum
	{ 0.29, 0.31, 0.34 }, -- slate
	{ 0.45, 0.24, 0.13 }, -- rust
	{ 0.15, 0.38, 0.40 }, -- teal
}
P.BOOKMARK_ACTION_COLOR = { 0.36, 0.27, 0.19 } -- a plain brown for bookmarks that do something (Options)

-- A book. opts: { title, width, height, single = false, tabs = { { key, label }, ... }, escape = true }
-- Returns a frame with .left and .right (content areas; .right is nil in single mode), .pages[key] =
-- { left, right } made by AddPage, .tabs[key], :AddTab(key, label), :AddPage(key), :SelectTab(key),
-- :SetTitle(text), .close (the wax seal), .OnTab(key) callback, .selected.
function P.Book(name, opts)
	opts = opts or {}
	local single = opts.single and true or false
	local w = opts.width or (single and 480 or 860)
	local h = opts.height or 540
	local f = CreateFrame("Frame", name, UIParent)
	f:SetSize(w, h)
	f:SetPoint("CENTER")
	f:SetFrameStrata("HIGH")
	f:SetToplevel(true)
	f:SetClampedToScreen(true)
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		if self.OnMoved then
			self.OnMoved(self:GetPoint())
		end
	end)
	f:Hide()
	if name and opts.escape ~= false then
		tinsert(UISpecialFrames, name)
	end
	f.single = single

	-- the cover: the square leather texture cropped to the frame's shape
	local leather = f:CreateTexture(nil, "BACKGROUND", nil, -8)
	leather:SetAllPoints()
	leather:SetTexture(P.MEDIA .. "leather")
	local pad = (1 - h / w) / 2
	if pad >= 0 then
		leather:SetTexCoord(0, 1, pad, 1 - pad)
	else
		pad = (1 - w / h) / 2
		leather:SetTexCoord(pad, 1 - pad, 0, 1)
	end
	f.leather = leather

	-- the pages: the texture's burnt edge is its right side; the right page is the mirror
	local pageW = single and (w - 2 * LEATHER) or math.floor((w - 2 * LEATHER) / 2)
	local pageL = f:CreateTexture(nil, "BACKGROUND", nil, -7)
	pageL:SetPoint("TOPLEFT", LEATHER, -LEATHER)
	pageL:SetSize(pageW, h - 2 * LEATHER)
	pageL:SetTexture(P.MEDIA .. "page")
	pageL:SetTexCoord(0.2, 1, 0, 1)
	f.pageL = pageL
	if not single then
		local pageR = f:CreateTexture(nil, "BACKGROUND", nil, -7)
		pageR:SetPoint("TOPRIGHT", -LEATHER, -LEATHER)
		pageR:SetSize(pageW, h - 2 * LEATHER)
		pageR:SetTexture(P.MEDIA .. "page")
		pageR:SetTexCoord(1, 0.2, 0, 1)
		f.pageR = pageR
		local spine = f:CreateTexture(nil, "BACKGROUND", nil, -6)
		spine:SetPoint("TOP", 0, -LEATHER)
		spine:SetPoint("BOTTOM", 0, LEATHER)
		spine:SetWidth(96)
		spine:SetTexture(P.MEDIA .. "spine")
		f.spine = spine
	end

	-- content areas
	f.left = CreateFrame("Frame", nil, f)
	f.left:SetPoint("TOPLEFT", LEATHER + MARGIN, -(LEATHER + MARGIN))
	f.left:SetSize(pageW - 2 * MARGIN, h - 2 * (LEATHER + MARGIN))
	if not single then
		f.right = CreateFrame("Frame", nil, f)
		f.right:SetPoint("TOPRIGHT", -(LEATHER + MARGIN), -(LEATHER + MARGIN))
		f.right:SetSize(pageW - 2 * MARGIN, h - 2 * (LEATHER + MARGIN))
	end
	f.page = f.left

	-- the title banner, hanging over the top edge
	local banner = CreateFrame("Frame", nil, f)
	banner:SetSize(math.min(360, w - 120), 44)
	banner:SetPoint("TOP", f, "TOP", 0, 12)
	banner:SetFrameLevel(f:GetFrameLevel() + 5)
	local cloth = banner:CreateTexture(nil, "ARTWORK")
	cloth:SetAllPoints()
	cloth:SetTexture(P.MEDIA .. "title")
	f.title = P.Label(banner, opts.title or "", "title", "CENTER")
	f.title:SetPoint("CENTER", 0, 1)
	f.banner = banner
	function f:SetTitle(text)
		self.title:SetText(text or "")
	end

	-- the wax seal closes the book
	local close = CreateFrame("Button", nil, f)
	close:SetSize(40, 40)
	close:SetPoint("TOPRIGHT", f, "TOPRIGHT", 10, 10)
	close:SetFrameLevel(f:GetFrameLevel() + 6)
	local wax = close:CreateTexture(nil, "ARTWORK")
	wax:SetAllPoints()
	wax:SetTexture(P.MEDIA .. "seal")
	close:SetNormalTexture(wax)
	local waxHl = close:CreateTexture(nil, "HIGHLIGHT")
	waxHl:SetAllPoints()
	waxHl:SetTexture(P.MEDIA .. "seal")
	waxHl:SetVertexColor(1, 0.8, 0.6, 0.35)
	close:SetScript("OnClick", function()
		f:Hide()
	end)
	f.close = close

	-- bookmarks
	f.tabs, f.tabOrder, f.pages = {}, {}, {}
	local function layoutTabs()
		local y = TAB_TOP
		for i, key in ipairs(f.tabOrder) do
			local t = f.tabs[key]
			local on = f.selected == key
			local small = t.action ~= nil
			if small and i > 1 then
				y = y + 4 -- a little more air before the bookmarks that do something
			end
			t:ClearAllPoints()
			t:SetPoint("TOPLEFT", f, "TOPRIGHT", -TAB_IN, -y)
			t:SetSize(small and TAB_SMALL_W or (on and TAB_W_ON or TAB_W), small and TAB_SMALL_H or TAB_H)
			local c = t.color
			local k = on and 1.25 or 1
			t.cloth:SetVertexColor(math.min(1, c[1] * k), math.min(1, c[2] * k), math.min(1, c[3] * k), 1)
			t.edge:SetShown(on)
			t:SetNormalFontObject(P.fonts.tab)
			t:SetHighlightFontObject(P.fonts.tab)
			y = y + (small and TAB_SMALL_H or TAB_H) + TAB_GAP
		end
	end
	-- A bookmark. opts.action = function() makes one that does something (opens Options) instead of
	-- turning to a page: smaller, brown, never selected. opts.color = { r, g, b } overrides the colour.
	function f:AddTab(key, label, opts)
		opts = opts or {}
		local t = CreateFrame("Button", nil, f)
		t:SetSize(TAB_W, TAB_H)
		t:SetFrameLevel(f:GetFrameLevel() + 4)
		t.action = opts.action
		local n = 0
		for _, k in ipairs(f.tabOrder) do
			if not f.tabs[k].action then
				n = n + 1
			end
		end
		t.color = opts.color
			or (opts.action and P.BOOKMARK_ACTION_COLOR)
			or P.BOOKMARK_COLORS[(n % #P.BOOKMARK_COLORS) + 1]
		local tabCloth = t:CreateTexture(nil, "ARTWORK")
		tabCloth:SetAllPoints()
		tabCloth:SetTexture(P.MEDIA .. "bookmark")
		t.cloth = tabCloth
		-- the gold edge of the open bookmark, where it comes out of the book
		local edge = t:CreateTexture(nil, "OVERLAY")
		edge:SetPoint("TOPLEFT", TAB_IN - 2, -2)
		edge:SetPoint("BOTTOMLEFT", TAB_IN - 2, 2)
		edge:SetWidth(3)
		edge:SetColorTexture(P.GOLD[1], P.GOLD[2], P.GOLD[3], 1)
		edge:Hide()
		t.edge = edge
		local hl = t:CreateTexture(nil, "HIGHLIGHT")
		hl:SetAllPoints()
		hl:SetTexture(P.MEDIA .. "bookmark")
		hl:SetVertexColor(1, 0.95, 0.8, 0.18)
		t:SetNormalFontObject(P.fonts.tab)
		t:SetText(label or key)
		local fs = t:GetFontString()
		if fs then
			fs:ClearAllPoints()
			fs:SetPoint("LEFT", t, "LEFT", TAB_IN + 10, 0)
			fs:SetPoint("RIGHT", t, "RIGHT", -16, 0)
			fs:SetJustifyH("LEFT")
			fs:SetWordWrap(false)
			fs:SetShadowColor(0, 0, 0, 0.6)
			fs:SetShadowOffset(0, -1)
		end
		t.key = key
		t:SetScript("OnClick", function()
			if t.action then
				t.action()
				return
			end
			f:SelectTab(key)
			if PlaySound and SOUNDKIT and SOUNDKIT.IG_ABILITY_PAGE_TURN then
				PlaySound(SOUNDKIT.IG_ABILITY_PAGE_TURN)
			end
		end)
		f.tabs[key] = t
		table.insert(f.tabOrder, key)
		layoutTabs()
		return t
	end
	-- A page: a pair of content frames (left, right) shown only while its tab is selected.
	function f:AddPage(key)
		local page = { left = CreateFrame("Frame", nil, f.left) }
		page.left:SetAllPoints()
		if f.right then
			page.right = CreateFrame("Frame", nil, f.right)
			page.right:SetAllPoints()
		end
		page.left:Hide()
		if page.right then
			page.right:Hide()
		end
		f.pages[key] = page
		return page
	end
	function f:SelectTab(key)
		if not f.tabs[key] or f.tabs[key].action then
			key = nil
			for _, k in ipairs(f.tabOrder) do
				if not f.tabs[k].action then
					key = k
					break
				end
			end
		end
		f.selected = key
		for k, page in pairs(f.pages) do
			page.left:SetShown(k == key)
			if page.right then
				page.right:SetShown(k == key)
			end
		end
		layoutTabs()
		if f.OnTab then
			f.OnTab(key)
		end
	end
	function f:SetTabsShown(shown)
		for _, t in pairs(f.tabs) do
			t:SetShown(shown)
		end
	end
	for _, pair in ipairs(opts.tabs or {}) do
		f:AddTab(pair[1] or pair.key, pair[2] or pair.label)
	end

	f:SetScript("OnShow", function()
		if PlaySound and SOUNDKIT and SOUNDKIT.IG_SPELLBOOK_OPEN then
			PlaySound(SOUNDKIT.IG_SPELLBOOK_OPEN)
		end
	end)
	f:SetScript("OnHide", function()
		if PlaySound and SOUNDKIT and SOUNDKIT.IG_SPELLBOOK_CLOSE then
			PlaySound(SOUNDKIT.IG_SPELLBOOK_CLOSE)
		end
	end)
	return f
end

-- A small parchment card (a popup of our own, for previews and the like), with a title and a seal to close.
function P.Card(name, width, height, title)
	local f = CreateFrame("Frame", name, UIParent)
	f:SetSize(width, height)
	f:SetPoint("CENTER")
	f:SetFrameStrata("DIALOG")
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)
	f:Hide()
	if name then
		tinsert(UISpecialFrames, name)
	end
	local leather = f:CreateTexture(nil, "BACKGROUND", nil, -8)
	leather:SetAllPoints()
	leather:SetTexture(P.MEDIA .. "leather")
	local page = f:CreateTexture(nil, "BACKGROUND", nil, -7)
	page:SetPoint("TOPLEFT", 8, -8)
	page:SetPoint("BOTTOMRIGHT", -8, 8)
	page:SetTexture(P.MEDIA .. "page")
	f.title = P.Label(f, title or "", "heading", "CENTER")
	f.title:SetPoint("TOP", 0, -18)
	f.body = CreateFrame("Frame", nil, f)
	f.body:SetPoint("TOPLEFT", 20, -40)
	f.body:SetPoint("BOTTOMRIGHT", -20, 20)
	local close = CreateFrame("Button", nil, f)
	close:SetSize(32, 32)
	close:SetPoint("TOPRIGHT", 6, 6)
	local wax = close:CreateTexture(nil, "ARTWORK")
	wax:SetAllPoints()
	wax:SetTexture(P.MEDIA .. "seal")
	close:SetNormalTexture(wax)
	close:SetScript("OnClick", function()
		f:Hide()
	end)
	f.close = close
	return f
end

-- the minimap button ------------------------------------------------------------------------------------
-- A round 34 px button on the rim of the minimap, like the game's own: a bevelled gold ring, a dark
-- leather disc under the picture, a soft shadow, a brighter ring on hover and a 1 px dip when pressed.
-- It can be dragged around the rim (no LibDBIcon: nothing to depend on). opts:
--   icon         = "Interface\AddOns\X\Media\icon"  the picture inside (rounded by Media/mask), ~70 %
--   onClick      = function(button) end                "LeftButton" or "RightButton"
--   onRightClick = function() end                      shortcut: called instead of onClick("RightButton")
--   tooltip      = function(tip) end                   fills GameTooltip (AddLine…) on hover
--   angle        = degrees                             where it sits (0 = right, 90 = top); default 200
--   onMove       = function(angle) end                 after a drag, to save the angle
--   shown        = bool                                false hides it (default true)
--   guard        = a P.Guard instance                  wraps onClick/onRightClick/tooltip (errors kept, no popup)
--   hub          = { addon = "X", label = "Bitácora", order = 10 }  also registers it in the family hub
-- Returns the Button with :SetAngle(deg), .angle, .icon, .ring, .disc; SetShown as any frame.
local MINIMAP_RADIUS_EXTRA = 5
local MINIMAP_SIZE = 34

function P.MinimapButton(name, opts)
	opts = opts or {}
	local g = opts.guard
	local onClick = g and g.Wrap(opts.onClick, "minimap") or opts.onClick
	local onRight = g and g.Wrap(opts.onRightClick, "minimap") or opts.onRightClick
	local tooltip = g and g.Wrap(opts.tooltip, "minimap tooltip") or opts.tooltip
	local b = CreateFrame("Button", name, Minimap)
	b:SetSize(MINIMAP_SIZE, MINIMAP_SIZE)
	b:SetFrameStrata("MEDIUM")
	b:SetFrameLevel(8)
	b:SetMovable(true)
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b:RegisterForDrag("LeftButton")
	local shadow = b:CreateTexture(nil, "BACKGROUND", nil, -2)
	shadow:SetPoint("TOPLEFT", -2, -1)
	shadow:SetPoint("BOTTOMRIGHT", 2, -3)
	shadow:SetTexture(P.MEDIA .. "shadow")
	b.shadow = shadow
	local disc = b:CreateTexture(nil, "BACKGROUND", nil, -1)
	disc:SetAllPoints()
	disc:SetTexture(P.MEDIA .. "disc")
	b.disc = disc
	local iconSize = math.floor(MINIMAP_SIZE * 0.7)
	local icon = b:CreateTexture(nil, "ARTWORK")
	icon:SetSize(iconSize, iconSize)
	icon:SetPoint("CENTER", 0, 0)
	icon:SetTexture(opts.icon)
	if icon.SetMask then
		icon:SetMask(P.MEDIA .. "mask")
	end
	b.icon = icon
	local ring = b:CreateTexture(nil, "OVERLAY")
	ring:SetAllPoints()
	ring:SetTexture(P.MEDIA .. "ring")
	b.ring = ring
	local hl = b:CreateTexture(nil, "HIGHLIGHT")
	hl:SetAllPoints()
	hl:SetTexture(P.MEDIA .. "ring_hl")
	hl:SetAlpha(0.85)
	b.highlight = hl

	function b:SetAngle(deg)
		self.angle = deg or 200
		local r = (Minimap:GetWidth() or 140) / 2 + MINIMAP_RADIUS_EXTRA
		local a = math.rad(self.angle)
		self:ClearAllPoints()
		self:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * r, math.sin(a) * r)
	end
	local function follow(self)
		local mx, my = Minimap:GetCenter()
		local cx, cy = GetCursorPosition()
		local scale = Minimap:GetEffectiveScale() or 1
		if not (mx and my and cx and cy) then
			return
		end
		self:SetAngle(math.deg(math.atan2(cy / scale - my, cx / scale - mx)))
	end
	b:SetScript("OnDragStart", function(self)
		self.dragging = true
		self:SetScript("OnUpdate", follow)
	end)
	b:SetScript("OnDragStop", function(self)
		self.dragging = false
		self:SetScript("OnUpdate", nil)
		if opts.onMove then
			opts.onMove(self.angle)
		end
	end)
	-- pressed: the picture dips a pixel
	b:SetScript("OnMouseDown", function(self)
		self.icon:SetPoint("CENTER", 1, -1)
	end)
	b:SetScript("OnMouseUp", function(self)
		self.icon:SetPoint("CENTER", 0, 0)
	end)
	b:SetScript("OnClick", function(self, button)
		if self.dragging then
			return
		end
		if button == "RightButton" and onRight then
			onRight()
		elseif onClick then
			onClick(button)
		end
	end)
	b:SetScript("OnEnter", function(self)
		if not tooltip or not GameTooltip then
			return
		end
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		tooltip(GameTooltip)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function()
		if GameTooltip then
			GameTooltip:Hide()
		end
	end)
	b:SetAngle(opts.angle)
	b.wanted = opts.shown ~= false
	b:SetShown(b.wanted)
	if opts.hub then
		P.MinimapHub.Register(opts.hub.addon or name, {
			icon = opts.icon,
			label = opts.hub.label or opts.hub.addon or name,
			order = opts.hub.order,
			onClick = onClick,
			onRightClick = onRight,
			tooltip = tooltip,
			button = b,
		})
	end
	return b
end

-- the family hub ---------------------------------------------------------------------------------------
-- Six addons, six buttons around the minimap is a lot. Each addon registers its button here; when the
-- family is "merged" (one setting, owned by whichever addon the player changes it in, propagated here),
-- the individual buttons hide and ONE button with the lib's own picture opens a small parchment menu
-- with a row per addon: click opens it, right click does its right-click action.
--   P.MinimapHub.Register(addonName, { icon, label, onClick(button), onRightClick, order, tooltip, button })
--   P.MinimapHub.SetMerged(bool)   the addon that owns the setting calls it (and saves the value itself);
--                                 every registered button follows
--   P.MinimapHub.IsMerged()
--   P.MinimapHub.SetAngle(deg) / OnMove(function(angle))  the merged button's place (the owner saves it)
--   P.MinimapHub.Entries()         the registered addons, in order
-- Pattern for the owner (any addon can be the owner; the last one to call SetMerged wins):
--   in ADDON_LOADED: if settings.minimapMerged ~= nil then P.MinimapHub.SetMerged(settings.minimapMerged) end
--   in its options:  settings.minimapMerged = v; P.MinimapHub.SetMerged(v)
P.MinimapHub = P.MinimapHub or {}
local Hub = P.MinimapHub
Hub.entries = Hub.entries or {}
Hub.merged = Hub.merged or false

local function hubSort()
	table.sort(Hub.entries, function(a, b)
		local oa, ob = a.order or 100, b.order or 100
		if oa ~= ob then
			return oa < ob
		end
		return tostring(a.label) < tostring(b.label)
	end)
end

local function hubApply()
	for _, e in ipairs(Hub.entries) do
		if e.button then
			e.button:SetShown((not Hub.merged) and e.button.wanted ~= false)
		end
	end
	if Hub.button then
		Hub.button:SetShown(Hub.merged and #Hub.entries > 0)
	end
	if Hub.menu then
		Hub.menu:Hide()
	end
end

function Hub.Register(addonName, entry)
	entry = entry or {}
	entry.addon = addonName
	for i, e in ipairs(Hub.entries) do
		if e.addon == addonName then
			Hub.entries[i] = entry
			hubSort()
			hubApply()
			return entry
		end
	end
	table.insert(Hub.entries, entry)
	hubSort()
	hubApply()
	return entry
end

function Hub.Entries()
	return Hub.entries
end

function Hub.IsMerged()
	return Hub.merged
end

local HUB_ROW = 26
local function hubMenu()
	if Hub.menu then
		return Hub.menu
	end
	local m = P.Card("PergaminoMinimapHubMenu", 190, 60, "")
	m.title:Hide()
	m.close:Hide()
	m:SetFrameStrata("TOOLTIP")
	m:SetMovable(false)
	m:SetScript("OnDragStart", nil)
	m:SetScript("OnDragStop", nil)
	m.body:ClearAllPoints()
	m.body:SetPoint("TOPLEFT", 12, -12)
	m.body:SetPoint("BOTTOMRIGHT", -12, 12)
	m.rows = {}
	m:SetScript("OnLeave", function(self)
		if not self:IsMouseOver() then
			self:Hide()
		end
	end)
	Hub.menu = m
	return m
end

function Hub.Refresh()
	local m = hubMenu()
	for _, r in ipairs(m.rows) do
		r:Hide()
	end
	for i, e in ipairs(Hub.entries) do
		local r = m.rows[i]
		if not r then
			r = CreateFrame("Button", nil, m.body)
			r:SetHeight(HUB_ROW)
			r:SetPoint("LEFT")
			r:SetPoint("RIGHT")
			r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
			local hl = r:CreateTexture(nil, "HIGHLIGHT")
			hl:SetAllPoints()
			hl:SetColorTexture(P.INK[1], P.INK[2], P.INK[3], 0.08)
			r.icon = r:CreateTexture(nil, "ARTWORK")
			r.icon:SetSize(18, 18)
			r.icon:SetPoint("LEFT", 2, 0)
			if r.icon.SetMask then
				r.icon:SetMask(P.MEDIA .. "mask")
			end
			r.label = P.Label(r, "", "body")
			r.label:SetPoint("LEFT", r.icon, "RIGHT", 8, 0)
			r.label:SetPoint("RIGHT")
			r:SetScript("OnClick", function(self, button)
				m:Hide()
				local entry = self.entry
				if button == "RightButton" and entry.onRightClick then
					entry.onRightClick()
				elseif entry.onClick then
					entry.onClick(button)
				end
			end)
			r:SetScript("OnEnter", function(self)
				if self.entry.tooltip and GameTooltip then
					GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
					self.entry.tooltip(GameTooltip)
					GameTooltip:Show()
				end
			end)
			r:SetScript("OnLeave", function()
				if GameTooltip then
					GameTooltip:Hide()
				end
				if not m:IsMouseOver() then
					m:Hide()
				end
			end)
			m.rows[i] = r
		end
		r.entry = e
		r.icon:SetTexture(e.icon)
		r.label:SetText(e.label or e.addon)
		r:ClearAllPoints()
		r:SetPoint("TOPLEFT", 0, -(i - 1) * HUB_ROW)
		r:SetPoint("RIGHT")
		r:Show()
	end
	m:SetHeight(#Hub.entries * HUB_ROW + 24)
	return m
end

function Hub.Toggle()
	local m = Hub.Refresh()
	if m:IsShown() then
		m:Hide()
		return
	end
	m:ClearAllPoints()
	m:SetPoint("TOPRIGHT", Hub.button or Minimap, "BOTTOMLEFT", 0, 0)
	m:Show()
end

local function hubButton()
	if Hub.button then
		return Hub.button
	end
	local b = P.MinimapButton("PergaminoMinimapHub", {
		icon = P.MEDIA .. "icon_hub",
		angle = Hub.angle or 200,
		onClick = function()
			Hub.Toggle()
		end,
		onRightClick = function()
			Hub.Toggle()
		end,
		onMove = function(angle)
			Hub.angle = angle
			if Hub.onMove then
				Hub.onMove(angle)
			end
		end,
		tooltip = function(tip)
			tip:SetText("Pergamino")
			for _, e in ipairs(Hub.entries) do
				tip:AddLine(e.label or e.addon, 1, 1, 1)
			end
		end,
		shown = false,
	})
	Hub.button = b
	return b
end

function Hub.SetMerged(v)
	Hub.merged = v and true or false
	if Hub.merged then
		hubButton()
	end
	hubApply()
end

function Hub.SetAngle(deg)
	Hub.angle = deg
	if Hub.button then
		Hub.button:SetAngle(deg)
	end
end

function Hub.OnMove(fn)
	Hub.onMove = fn
end

-- the addon's own errors -----------------------------------------------------------------------------------
-- A guard wraps an addon's handlers so a Lua error never reaches the player as a popup: it is kept in the
-- addon's saved variables (up to GUARD_MAX, repeats counted), said once in the chat, and shown on a page of
-- pergamino to copy into an issue. opts = { slash = "/bita", notice = "%s: tuvo un error. %s errores lo muestra.",
-- chat = function(text) end, L = { title, empty, clear, copy } }. Returns the guard:
--   guard.Wrap(fn, label)            → fn, guarded; errors are kept under label
--   guard.Install(eventFrame, slashFn, buttons) → wraps the frame's OnEvent (label = the event) and the OnClick of
--                                      each button in the list (minimap, compartment…); returns slashFn guarded
--   guard.Errors()                   → db.errors, newest first
--   guard.Clear()
--   guard.Page(left, right)          → the error page: list on the left, the chosen one to copy on the right
--                                      (with one parent, list above and text below); returns { list, area, Refresh }
local GUARD_MAX, GUARD_LINES = 10, 6
-- Links on parchment -------------------------------------------------------------------------------
-- Item quality colours are made for a dark background: white, grey and bright green vanish on parchment.
-- These are the same hues, darkened until they read as ink.
P.QUALITY_INK = {
	[0] = "ff6c4e31", -- poor: soft ink
	[1] = "ff3a2313", -- common: ink
	[2] = "ff1f6b2a", -- uncommon: moss
	[3] = "ff1f4f9c", -- rare: deep blue
	[4] = "ff6a2a8f", -- epic: plum
	[5] = "ffb35a00", -- legendary: burnt orange
	[6] = "ffa0741c", -- artifact: old gold
	[7] = "ff2a7a7a", -- heirloom: teal
}
function P.QualityInk(quality)
	return P.QUALITY_INK[quality] or P.QUALITY_INK[1]
end

-- A chat link coloured for the page: ref is "item:123" (or any |H ref), name the bracketed text.
function P.RefLink(ref, name, quality)
	if quality == nil and C_Item and C_Item.GetItemQualityByID and tostring(ref):match("^item:%d+$") then
		quality = C_Item.GetItemQualityByID(ref)
	end
	return "|c" .. P.QualityInk(quality) .. "|H" .. ref .. "|h[" .. (name or ref) .. "]|h|r"
end

-- Text that may hold chat links, with the game's tooltip when the mouse is over one of them. A
-- SimpleHTML frame (FontStrings never report hyperlinks). Width comes from the anchors; height follows
-- the text. opts: role (font role), justify.
function P.LinkText(parent, text, opts)
	opts = opts or {}
	local font = P.fonts[opts.role or "body"] or P.fonts.body
	local ok, h = pcall(CreateFrame, "SimpleHTML", nil, parent)
	if not ok or not h then
		-- no SimpleHTML here: a plain label with the same small API (no tooltips over links)
		local fs = P.Label(parent, text, opts.role, opts.justify)
		fs:SetWordWrap(true)
		fs.Fit = function(self)
			if self.GetStringHeight then
				self:SetHeight(math.max(1, self:GetStringHeight()))
			end
		end
		return fs
	end
	-- SimpleHTML is a FontInstance, but some clients want the element ("p") first: try both ways
	local function fontCall(method, ...)
		local fn = h[method]
		if not fn then
			return
		end
		if not pcall(fn, h, ...) then
			pcall(fn, h, "p", ...)
		end
	end
	fontCall("SetFontObject", font)
	fontCall("SetTextColor", P.INK[1], P.INK[2], P.INK[3])
	fontCall("SetJustifyH", opts.justify or "LEFT")
	pcall(h.SetHyperlinksEnabled, h, true)
	h:SetScript("OnHyperlinkEnter", function(self, link)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		if pcall(GameTooltip.SetHyperlink, GameTooltip, link) then
			GameTooltip:Show()
		end
	end)
	h:SetScript("OnHyperlinkLeave", function()
		GameTooltip:Hide()
	end)
	h:SetScript("OnHyperlinkClick", function(_, link, linkText)
		if IsShiftKeyDown and IsShiftKeyDown() and ChatFrameUtil and ChatFrameUtil.InsertLink then
			ChatFrameUtil.InsertLink(linkText or link)
		end
	end)
	local setText = h.SetText
	function h:SetText(t)
		self.text = t or ""
		-- SimpleHTML wants markup; "<" in plain text would be read as a tag
		local safe = self.text:gsub("<", "&lt;")
		pcall(setText, self, "<html><body><p>" .. safe .. "</p></body></html>")
	end
	function h:GetText()
		return self.text or ""
	end
	function h:Fit()
		local okH, ch = pcall(self.GetContentHeight, self)
		if okH and ch and ch > 0 then
			self:SetHeight(ch)
		end
	end
	h:SetText(text or "")
	return h
end

-- Shift-click on an item while one of these edit boxes has focus: the link goes to the box and the game
-- does NOT open the stack-split dialog (that only happens when ChatFrameUtil.InsertLink returns false,
-- which a post-hook cannot change). One wrapper for every addon that shares the lib: the newest copy
-- installs it, older copies find it installed.
P.linkSinks = P.linkSinks or {}
function P.AcceptLinks(edit, onLink)
	table.insert(P.linkSinks, { edit = edit, onLink = onLink })
	if P.insertLinkWrapped or not (ChatFrameUtil and ChatFrameUtil.InsertLink) then
		return
	end
	local orig = ChatFrameUtil.InsertLink
	ChatFrameUtil.InsertLink = function(text)
		if text then
			for _, sink in ipairs(P.linkSinks) do
				local e = sink.edit
				if e and e.HasFocus and e:HasFocus() and (not e.IsVisible or e:IsVisible()) then
					if sink.onLink then
						sink.onLink(text)
					elseif e.SetValue then
						e:SetValue(text)
					else
						e:Insert(text)
					end
					return true
				end
			end
		end
		return orig(text)
	end
	P.insertLinkWrapped = true
end

function P.Guard(addonName, db, opts)
	opts = opts or {}
	db.errors = db.errors or {}
	local g = { addon = addonName, db = db, told = false, opts = opts }
	local L = opts.L or {}

	local function say(text)
		if opts.chat then
			opts.chat(text)
		elseif DEFAULT_CHAT_FRAME then
			DEFAULT_CHAT_FRAME:AddMessage(text)
		elseif print then
			print(text)
		end
	end

	local function trim(trace)
		local out, n = {}, 0
		for ln in tostring(trace or ""):gmatch("[^\n]+") do
			ln = ln:gsub("^%s+", "")
			if ln ~= "" and ln ~= "stack traceback:" then
				n = n + 1
				if n > GUARD_LINES then
					break
				end
				out[#out + 1] = ln
			end
		end
		return table.concat(out, "\n")
	end

	function g.Record(label, message, stack)
		message = tostring(message)
		for _, e in ipairs(db.errors) do
			if e.message == message and e.label == label then
				e.count = (e.count or 1) + 1
				e.when = time()
				return e
			end
		end
		local e = { when = time(), label = label or "?", message = message, stack = stack or "", count = 1 }
		table.insert(db.errors, 1, e)
		while #db.errors > GUARD_MAX do
			table.remove(db.errors)
		end
		if not g.told then
			g.told = true
			say(string.format(opts.notice or "%s: tuvo un error. %s errores lo muestra para copiarlo.", addonName, opts.slash or "/" .. addonName:lower()))
		end
		if g.OnError then
			g.OnError(e)
		end
		return e
	end

	-- the game's traceback is debugstack (levels to skip, lines from the top, lines from the bottom);
	-- plain Lua (the tests) has debug.traceback
	local traceback = debugstack and function()
		return debugstack(3, GUARD_LINES, 0)
	end or function()
		local d = rawget(_G, "debug")
		return d and d.traceback and d.traceback("", 3) or ""
	end
	local function handler(err)
		return { message = err, stack = trim(traceback()) }
	end

	function g.Wrap(fn, label)
		if type(fn) ~= "function" then
			return fn
		end
		return function(...)
			local args, n = { ... }, select("#", ...)
			local results = { xpcall(function()
				return fn(unpack(args, 1, n))
			end, handler) }
			if results[1] then
				return unpack(results, 2)
			end
			local info = results[2]
			if type(info) == "table" then
				g.Record(label, info.message, info.stack)
			else
				g.Record(label, info, "")
			end
			return nil
		end
	end

	function g.Install(eventFrame, slashFn, buttons)
		for _, btn in ipairs(buttons or {}) do
			if btn and btn.GetScript then
				local onClick = btn:GetScript("OnClick")
				if onClick then
					btn:SetScript("OnClick", g.Wrap(onClick, btn.GetName and btn:GetName() or "click"))
				end
			end
		end
		if eventFrame and eventFrame.GetScript then
			local onEvent = eventFrame:GetScript("OnEvent")
			if onEvent then
				local wrapped = {}
				eventFrame:SetScript("OnEvent", function(self, event, ...)
					local w = wrapped[event]
					if not w then
						w = g.Wrap(onEvent, event)
						wrapped[event] = w
					end
					return w(self, event, ...)
				end)
			end
		end
		return slashFn and g.Wrap(slashFn, "slash") or nil
	end

	function g.Errors()
		return db.errors
	end

	function g.Clear()
		for i = #db.errors, 1, -1 do
			db.errors[i] = nil
		end
	end

	local function text(e)
		local d = date and date("%Y-%m-%d %H:%M", e.when) or tostring(e.when)
		local head = addonName .. " · " .. d .. " · " .. tostring(e.label)
		if (e.count or 1) > 1 then
			head = head .. " · x" .. e.count
		end
		return head .. "\n" .. e.message .. (e.stack ~= "" and ("\n" .. e.stack) or "")
	end
	g.Text = text

	function g.Page(left, right)
		local page = {}
		local listParent, areaParent = left, right or left
		local title = P.Label(listParent, L.title or "Errores", "heading")
		title:SetPoint("TOPLEFT")
		local rule = P.Rule(listParent)
		rule:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
		rule:SetPoint("RIGHT")
		local empty = P.Label(listParent, L.empty or "Sin errores guardados.", "muted")
		empty:SetPoint("TOPLEFT", rule, "BOTTOMLEFT", 0, -10)
		local list = P.List(listParent, 26, function(row, item)
			if not row.text then
				row.text = P.Label(row, "", "body")
				row.text:SetPoint("LEFT", 4, 0)
				row.text:SetPoint("RIGHT", -4, 0)
				row.text:SetWordWrap(false)
			end
			local d = date and date("%d/%m %H:%M", item.when) or ""
			local first = tostring(item.message):match("^[^\n]*") or ""
			row.text:SetText(d .. " · " .. tostring(item.label) .. " · " .. first .. ((item.count or 1) > 1 and (" (x" .. item.count .. ")") or ""))
		end, function(item)
			page.chosen = item
			page.Refresh()
		end)
		list.box:SetPoint("TOPLEFT", rule, "BOTTOMLEFT", 0, -8)
		if right then
			list.box:SetPoint("BOTTOMRIGHT", listParent, "BOTTOMRIGHT", -16, 0)
		else
			list.box:SetPoint("RIGHT", listParent, "RIGHT", -16, 0)
			list.box:SetHeight(26 * 4)
		end
		local area = P.TextArea(areaParent)
		if right then
			local hint = P.Label(areaParent, L.copy or "Seleccioná el texto y copialo con Ctrl+C.", "muted")
			hint:SetPoint("TOPLEFT")
			hint:SetPoint("TOPRIGHT")
			area:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -8)
		else
			area:SetPoint("TOPLEFT", list.box, "BOTTOMLEFT", 0, -10)
		end
		area:SetPoint("BOTTOMRIGHT", areaParent, "BOTTOMRIGHT", 0, 32)
		local clear = P.Button(areaParent, L.clear or "Borrar", 110, function()
			g.Clear()
			page.chosen = nil
			page.Refresh()
		end)
		clear:SetPoint("BOTTOMRIGHT", areaParent, "BOTTOMRIGHT", 0, 0)
		function page.Refresh()
			local errors = db.errors
			empty:SetShown(#errors == 0)
			list:SetData(errors)
			if not page.chosen and errors[1] then
				page.chosen = errors[1]
			end
			local chosen = page.chosen
			if area.box.SetText then
				area.box:SetText(chosen and text(chosen) or "")
			end
			clear:SetShown(#errors > 0)
		end
		page.list, page.area, page.clear, page.empty = list, area, clear, empty
		page.Refresh()
		return page
	end

	return g
end
