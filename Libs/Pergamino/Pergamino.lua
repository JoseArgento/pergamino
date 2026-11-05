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
local VERSION = 1

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
	tab = font("PergaminoTab", "Cinzel-SemiBold.ttf", 11, P.PARCHMENT),
	tabOn = font("PergaminoTabOn", "Cinzel-SemiBold.ttf", 11, P.INK),
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

-- A single-line field: just text over an ink line, with a placeholder. opts: { placeholder, font }
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
	e:SetScript("OnTextChanged", function()
		updatePlaceholder()
	end)
	function e:SetPlaceholder(text)
		ph:SetText(text or "")
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
	local list = { box = box, bar = bar }
	function list:SetData(items, keepScroll)
		box:SetDataProvider(CreateDataProvider(items), keepScroll and ScrollBoxConstants.RetainScrollPosition or nil)
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
local TAB_W, TAB_W_ON, TAB_H, TAB_GAP, TAB_TOP, TAB_IN = 128, 142, 30, 6, 70, 40

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
		for i, key in ipairs(f.tabOrder) do
			local t = f.tabs[key]
			local on = f.selected == key
			t:ClearAllPoints()
			t:SetPoint("TOPLEFT", f, "TOPRIGHT", -TAB_IN, -(TAB_TOP + (i - 1) * (TAB_H + TAB_GAP)))
			t:SetWidth(on and TAB_W_ON or TAB_W)
			t.cloth:SetTexCoord(0, 1, on and 0.5 or 0, on and 1 or 0.5)
			t:SetNormalFontObject(on and P.fonts.tabOn or P.fonts.tab)
			t:SetHighlightFontObject(on and P.fonts.tabOn or P.fonts.tab)
		end
	end
	function f:AddTab(key, label)
		local t = CreateFrame("Button", nil, f)
		t:SetSize(TAB_W, TAB_H)
		t:SetFrameLevel(f:GetFrameLevel() + 4)
		local tabCloth = t:CreateTexture(nil, "ARTWORK")
		tabCloth:SetAllPoints()
		tabCloth:SetTexture(P.MEDIA .. "ribbon")
		t.cloth = tabCloth
		local hl = t:CreateTexture(nil, "HIGHLIGHT")
		hl:SetAllPoints()
		hl:SetColorTexture(1, 0.9, 0.6, 0.1)
		t:SetNormalFontObject(P.fonts.tab)
		t:SetText(label or key)
		local fs = t:GetFontString()
		if fs then
			fs:SetPoint("LEFT", t, "LEFT", TAB_IN + 10, 0)
			fs:SetPoint("RIGHT", t, "RIGHT", -18, 0)
			fs:SetJustifyH("LEFT")
		end
		t.key = key
		t:SetScript("OnClick", function()
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
		if not f.tabs[key] then
			key = f.tabOrder[1]
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
