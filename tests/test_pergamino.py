"""Pergamino in Lua 5.1 (the WoW Lua) with a stand-in for the client (tests/wow_mock.lua)."""

from pathlib import Path

import pytest

lupa = pytest.importorskip("lupa.lua51")

ROOT = Path(__file__).resolve().parents[1]
LIB = ROOT / "Libs" / "Pergamino" / "Pergamino.lua"
MOCK = ROOT / "tests" / "wow_mock.lua"


class Game:
    def __init__(self):
        self.lua = lupa.LuaRuntime(unpack_returned_tuples=True)
        self.lua.execute(MOCK.read_text(encoding="utf-8"))
        self.m = self.lua.globals().MOCK
        self.loader = self.lua.eval(
            "function(src, name) return assert(loadstring(src, '@' .. name)) end"
        )

    def load(self, addon="TestAddon", src=None):
        chunk = self.loader(
            src or LIB.read_text(encoding="utf-8"),
            f"{addon}/Libs/Pergamino/Pergamino.lua",
        )
        chunk(addon, self.lua.table())
        return self.lua.globals().Pergamino

    def run(self, code):
        return self.lua.eval("function(P, MOCK) " + code + " end")(
            self.lua.globals().Pergamino, self.m
        )


@pytest.fixture
def game():
    g = Game()
    g.load()
    return g


def test_media_and_fonts_come_from_the_loading_addon(game):
    P = game.lua.globals().Pergamino
    assert P.MEDIA == "Interface\\AddOns\\TestAddon\\Libs\\Pergamino\\Media\\"
    assert P.FONTS == "Interface\\AddOns\\TestAddon\\Libs\\Pergamino\\Fonts\\"
    path, size, flags = game.run("return P.fonts.body:GetFont()")
    assert path.endswith("Alegreya-Regular.ttf") and size == 14 and flags == ""
    path, size, _ = game.run("return P.fonts.title:GetFont()")
    assert path.endswith("Cinzel-Bold.ttf") and size == 16
    # every font file the library names exists in the vendored folder
    src = LIB.read_text(encoding="utf-8")
    for name in (
        "Alegreya-Regular",
        "Alegreya-SemiBold",
        "Alegreya-Italic",
        "Cinzel-SemiBold",
        "Cinzel-Bold",
    ):
        assert f'"{name}.ttf"' in src
        assert (ROOT / "Libs" / "Pergamino" / "Fonts" / f"{name}.ttf").exists()
    assert (ROOT / "Libs" / "Pergamino" / "Fonts" / "OFL.txt").exists()


def test_textures_named_in_the_code_exist_and_are_powers_of_two():
    src = LIB.read_text(encoding="utf-8")
    import re

    names = set(re.findall(r'P\.MEDIA \.\. "(\w+)"', src))
    assert {
        "page",
        "leather",
        "spine",
        "bookmark",
        "title",
        "seal",
        "check",
        "pill",
        "ring",
        "mask",
    } <= names
    for name in names:
        data = (ROOT / "Libs" / "Pergamino" / "Media" / f"{name}.tga").read_bytes()
        width, height, bpp = (
            int.from_bytes(data[12:14], "little"),
            int.from_bytes(data[14:16], "little"),
            data[16],
        )
        assert (
            data[2] == 2
            and bpp == 32
            and width & (width - 1) == 0
            and height & (height - 1) == 0
        ), name
        assert width <= 1024 and height <= 1024


def test_a_newer_copy_wins_and_an_older_one_steps_aside(game):
    src = LIB.read_text(encoding="utf-8")
    older = src.replace("local VERSION = 7", "local VERSION = 1")
    game.load("OtherAddon", older)
    P = game.lua.globals().Pergamino
    assert (
        P.VERSION == 7 and "TestAddon" in P.MEDIA
    )  # the older copy did not replace it
    newer = src.replace("local VERSION = 7", "local VERSION = 8")
    game.load("NewAddon", newer)
    P = game.lua.globals().Pergamino
    assert P.VERSION == 8 and "NewAddon" in P.MEDIA


def test_book_has_two_pages_a_title_a_seal_and_bookmarks(game):
    book = game.run("""
        local b = P.Book("TestBook", { title = "Bitácora", tabs = { { "notes", "Libreta" }, { "journal", "Diario" } } })
        return b
    """)
    assert (
        book.left is not None
        and book.right is not None
        and game.run("return TestBook.page == TestBook.left")
    )
    assert book.title._text == "Bitácora"
    assert book.pageL is not None and book.pageR is not None and book.spine is not None
    assert book.tabOrder[1] == "notes" and book.tabOrder[2] == "journal"
    assert "TestBook" in list(game.lua.globals().UISpecialFrames.values())
    # the right page is the mirror of the left one
    assert game.run("local b = TestBook; return b.pageR:GetTexCoord()") == (
        1,
        0.2,
        0,
        1,
    )
    # closing seal hides the book
    game.run("TestBook:Show(); TestBook.close:GetScript('OnClick')()")
    assert not book._shown


def test_selecting_a_tab_shows_its_page_and_marks_the_bookmark(game):
    game.run("""
        local b = P.Book("TestBook", { tabs = { { "a", "A" }, { "b", "B" } } })
        b:AddPage("a"); b:AddPage("b")
        MOCK.tabs = {}
        b.OnTab = function(key) table.insert(MOCK.tabs, key) end
        b:SelectTab("b")
    """)
    assert game.run("return TestBook.selected") == "b"
    assert game.run(
        "return TestBook.pages.b.left:IsShown(), TestBook.pages.a.left:IsShown()"
    ) == (True, False)
    assert game.run("return TestBook.pages.b.right:IsShown()") is True
    assert list(game.m.tabs.values()) == ["b"]
    # the active bookmark is a little longer, brighter, and shows its gold edge
    assert game.run(
        "return TestBook.tabs.b:GetWidth(), TestBook.tabs.a:GetWidth()"
    ) == (164, 150)
    assert game.run("return TestBook.tabs.b.edge:IsShown(), TestBook.tabs.a.edge:IsShown()") == (True, False)
    # each bookmark has its own colour, from the list, in order
    assert game.run("return TestBook.tabs.a.color == P.BOOKMARK_COLORS[1], TestBook.tabs.b.color == P.BOOKMARK_COLORS[2]") == (True, True)
    ra = game.run("return TestBook.tabs.a.cloth._vertex[1]")
    rb = game.run("return TestBook.tabs.b.cloth._vertex[3]")
    assert abs(ra - 0.56) < 1e-6  # crimson, as is
    assert abs(rb - min(1, 0.48 * 1.25)) < 1e-6  # indigo, brighter because open
    # the label sits on one line in the part of the bookmark that shows past the cover
    calls = [c[1] for c in game.run("return TestBook.tabs.a:GetFontString()._calls").values()]
    assert "SetWordWrap" in calls
    # air between bookmarks: the second starts TAB_H + TAB_GAP below the first
    ya = game.run("local p = TestBook.tabs.a._points; return p[#p][5]")
    yb = game.run("local p = TestBook.tabs.b._points; return p[#p][5]")
    assert ya - yb == 28 + 12
    # clicking a bookmark selects it and turns the page
    game.m.sounds = game.lua.table()
    game.run(
        "SOUNDKIT.IG_ABILITY_PAGE_TURN = 1234; TestBook.tabs.a:GetScript('OnClick')()"
    )
    assert game.run("return TestBook.selected") == "a"
    assert 1234 in list(game.m.sounds.values())
    # an unknown key falls back to the first tab
    game.run("TestBook:SelectTab('zzz')")
    assert game.run("return TestBook.selected") == "a"


def test_single_page_book(game):
    book = game.run("return P.Book('Single', { single = true, title = 'Recordame' })")
    assert book.right is None and book.left is not None and book.single is True
    assert book.spine is None and book.pageR is None
    assert game.run("return Single:GetWidth()") == 480
    page = game.run("return Single:AddPage('x')")
    assert page.right is None and page.left is not None


def test_widgets(game):
    b = game.run(
        "return P.Button(UIParent, 'Nueva nota', 120, function() MOCK.clicked = true end)"
    )
    assert b._text == "Nueva nota" and b.fill.texture.endswith("leather")
    game.run(
        "UIParent._x = P.Button(UIParent, 'x', 50, function() MOCK.clicked = true end); UIParent._x:GetScript('OnClick')()"
    )
    assert game.m.clicked is True
    chip = game.run("return P.Chip(UIParent, 'Todas')")
    assert chip.pressed is False
    game.run("local c = P.Chip(UIParent, 'Todas'); c:SetPressed(true); MOCK.chip = c")
    assert game.m.chip.pressed is True and game.m.chip.fill._alpha == 1
    check = game.run("return P.Check(UIParent, 'Solo este personaje')")
    assert (
        check.label._text == "Solo este personaje"
        and check._normalTexture is not None
        and check._checkedTexture is not None
    )
    edit = game.run("return P.Edit(UIParent, 200, { placeholder = 'Buscar' })")
    assert edit.placeholder._text == "Buscar" and edit.placeholder._shown is True
    game.run(
        "local e = P.Edit(UIParent, 200, { placeholder = 'Buscar' }); e:SetText('hola'); MOCK.edit = e"
    )
    assert game.m.edit.placeholder._shown is False
    label = game.run("return P.Label(UIParent, 'Hola', 'heading')")
    assert label.role == "heading" and label._fontObject is not None
    tag = game.run("return P.Tag(UIParent, 'nivel', 'level')")
    assert tag.text._text == "NIVEL" and tag.bg._vertex[1] == 0.58
    rule = game.run("return P.Rule(UIParent)")
    assert rule.height == 1
    panel = game.run("return P.Panel(UIParent)")
    assert len(panel.edges) == 4
    area = game.run("return P.TextArea(UIParent)")
    assert area.box is not None and area.bar is not None
    card = game.run("return P.Card('TestCard', 300, 200, 'Imagen')")
    assert card.title._text == "Imagen" and card.body is not None


def test_list_rows_get_an_ink_rule_and_the_init_runs(game):
    game.run("""
        local list = P.List(UIParent, 24, function(row, item) row.text = item.name end, function(item) MOCK.picked = item.name end)
        list:SetData({ { name = "a" }, { name = "b" } })
        MOCK.list = list
    """)
    rows = game.run("return MOCK.list.box.rows")
    assert rows[1].text == "a" and rows[2].text == "b"
    assert (
        rows[1].rule is not None
        and rows[1].highlight is not None
        and rows[1].selected is not None
    )
    game.run(
        "MOCK.list.box.rows[2]:GetScript('OnClick')(MOCK.list.box.rows[2], 'LeftButton')"
    )
    assert game.m.picked == "b"
    game.run("MOCK.list:Refresh()")


def test_apply_puts_the_body_font_on_plain_font_strings(game):
    game.run("""
        local f = CreateFrame("Frame")
        local fs = f:CreateFontString()
        f.GetRegions = function() return fs end
        P.Apply(f)
        MOCK.fs = fs
    """)
    assert game.m.fs._fontObject is not None


def test_edit_set_value_is_silent_and_typing_fires_on_change(game):
    game.run("""
        MOCK.changes = {}
        local e = P.Edit(UIParent, 80, { placeholder = "0", onChange = function(_, text) table.insert(MOCK.changes, text) end })
        e:SetNumeric(true)
        e:SetFocus()
        e:SetValue(4)
        MOCK.edit = e
    """)
    assert (
        game.m.edit._text == "4"
        and game.m.edit._cursor == 1
        and game.m.edit.placeholder._shown is False
    )
    assert len(game.m.changes) == 0  # SetValue never counts as typing
    # a SetText from the addon (userInput false) does not fire onChange either; what the player types does
    game.run("MOCK.edit:SetText('41')")
    assert len(game.m.changes) == 0
    game.run("MOCK.edit:GetScript('OnTextChanged')(MOCK.edit, true)")
    assert list(game.m.changes.values()) == ["41"]
    game.run("MOCK.edit:SetValue('')")
    assert (
        game.m.edit.placeholder._shown is False
    )  # still focused: no placeholder over the caret
    game.run(
        "MOCK.edit:ClearFocus(); MOCK.edit:GetScript('OnEditFocusLost')(MOCK.edit)"
    )
    assert game.m.edit.placeholder._shown is True


def test_list_bar_shows_only_when_the_rows_overflow(game):
    game.run("""
        local list = P.List(UIParent, 24, function(row, item) row.text = item.name end)
        list.box.height = 100
        list:SetData({ { name = "a" }, { name = "b" } })
        MOCK.list = list
    """)
    assert game.run("return MOCK.list.bar:IsShown()") is False
    game.run(
        "MOCK.list:SetData({ {name='a'}, {name='b'}, {name='c'}, {name='d'}, {name='e'} })"
    )
    assert game.run("return MOCK.list.bar:IsShown()") is True
    # without Blizzard's behaviour the list works it out itself
    game.run("""
        ScrollUtil.AddManagedScrollBarVisibilityBehavior = nil
        local list = P.List(UIParent, 24, function() end)
        list.box.height = 100
        list:SetData({ { name = "a" } })
        MOCK.list2 = list
        list:SetData({ {name='a'}, {name='b'}, {name='c'}, {name='d'}, {name='e'} })
        MOCK.list3shown = list.bar:IsShown()
    """)
    assert game.m.list3shown is True


def test_minimap_button_sits_on_the_rim_drags_around_it_and_clicks(game):
    game.run("""
        MOCK.clicks, MOCK.moved = {}, nil
        local b = P.MinimapButton("TestMini", {
            icon = "Interface/AddOns/TestAddon/Media/icon",
            angle = 90,
            onClick = function(button) table.insert(MOCK.clicks, button) end,
            onMove = function(angle) MOCK.moved = angle end,
            tooltip = function(tip) tip:AddLine("Bitácora") end,
        })
        MOCK.mini = b
    """)
    b = game.m.mini
    assert (
        b.icon.texture.endswith("Media/icon")
        and b.icon.mask.endswith("Media\\mask")
        and b.ring.texture.endswith("ring")
        and b.disc.texture.endswith("disc")
        and b.shadow.texture.endswith("shadow")
        and b.highlight.texture.endswith("ring_hl")
    )
    assert b.angle == 90 and b._shown is True
    # 34 px, the picture at ~70 %
    assert game.run("return MOCK.mini:GetWidth(), MOCK.mini.icon:GetWidth()") == (34, 23)
    # pressed: the picture dips a pixel and comes back
    game.run("MOCK.mini:GetScript('OnMouseDown')(MOCK.mini)")
    assert game.run("local p = MOCK.mini.icon._points[#MOCK.mini.icon._points]; return p[2], p[3]") == (1, -1)
    game.run("MOCK.mini:GetScript('OnMouseUp')(MOCK.mini)")
    assert game.run("local p = MOCK.mini.icon._points[#MOCK.mini.icon._points]; return p[2], p[3]") == (0, 0)
    # 90 degrees = straight above the minimap's centre, 5 px past its edge (70 + 5)
    pts = game.run("return MOCK.mini._points")
    assert pts is not None
    assert game.run(
        "local p = MOCK.mini._points[#MOCK.mini._points]; return p[1], p[3], math.floor(p[4] + 0.5), math.floor(p[5] + 0.5)"
    ) == ("CENTER", "CENTER", 0, 75)
    # drag: the cursor to the right of the minimap centre puts it at 0 degrees, and the angle is reported
    game.run(
        "MOCK.cursorX, MOCK.cursorY = 1200, 500; MOCK.mini:GetScript('OnDragStart')(MOCK.mini); MOCK.mini:GetScript('OnUpdate')(MOCK.mini); MOCK.mini:GetScript('OnDragStop')(MOCK.mini)"
    )
    assert game.m.moved == 0 and game.m.mini.angle == 0
    game.run("MOCK.mini:GetScript('OnClick')(MOCK.mini, 'RightButton')")
    assert list(game.m.clicks.values()) == ["RightButton"]
    game.run("MOCK.mini:GetScript('OnEnter')(MOCK.mini)")
    assert game.run("return GameTooltip.lines[#GameTooltip.lines]") == "Bitácora"
    hidden = game.run(
        "return P.MinimapButton('TestMini2', { icon = 'x', shown = false })"
    )
    assert hidden._shown is False


def test_an_action_bookmark_does_something_and_is_never_selected(game):
    game.run("""
        local b = P.Book("ActionBook", { tabs = { { "a", "A" } } })
        b:AddPage("a")
        b.OnTab = function() end
        MOCK.opened = 0
        b:AddTab("options", "Opciones", { action = function() MOCK.opened = MOCK.opened + 1 end })
        b:SelectTab("a")
    """)
    assert game.run("return ActionBook.tabs.options:GetWidth(), ActionBook.tabs.options:GetHeight()") == (128, 22)
    assert game.run("return ActionBook.tabs.options.color == P.BOOKMARK_ACTION_COLOR") is True
    game.run("ActionBook.tabs.options:GetScript('OnClick')()")
    assert game.m.opened == 1
    assert game.run("return ActionBook.selected") == "a"
    game.run("ActionBook:SelectTab('options')")
    assert game.run("return ActionBook.selected") == "a"
    # and a page bookmark added after it still takes the next colour, not the brown
    game.run("ActionBook:AddTab('b', 'B')")
    assert game.run("return ActionBook.tabs.b.color == P.BOOKMARK_COLORS[2]") is True


def test_text_area_keeps_ink_after_set_text(game):
    # Blizzard's edit box re-applies edit.fontName / edit.textColor on every SetText: they must be ours
    game.run("""
        CreateColor = CreateColor or function(r, g, b, a) return { r = r, g = g, b = b, a = a, GetRGB = function(c) return c.r, c.g, c.b end } end
        MOCK.area = P.TextArea(UIParent)
    """)
    assert game.run("return MOCK.area.box:GetEditBox() ~= nil") is True
    assert game.run("local e = MOCK.area.box:GetEditBox(); return e.fontName == P.fonts.body") is True
    assert game.run("local e = MOCK.area.box:GetEditBox(); return e.textColor ~= nil and math.abs(e.textColor.r - P.INK[1]) < 1e-6") is True


def test_guard_keeps_errors_says_so_once_and_shows_a_page(game):
    game.run("""
        MOCK.db = { }
        MOCK.g = P.Guard("Prueba", MOCK.db, { slash = "/prueba" })
        MOCK.boom = MOCK.g.Wrap(function(a, b) error("se rompio " .. a) end, "boton")
        MOCK.fine = MOCK.g.Wrap(function(a, b) return a + b, "ok" end, "suma")
    """)
    assert game.run("return MOCK.fine(2, 3)") == (5, "ok")
    assert game.run("return MOCK.boom('x')") is None  # never re-raised
    game.run("MOCK.boom('x'); MOCK.boom('y')")
    errs = game.run("return MOCK.g.Errors()")
    assert len(errs) == 2  # 'x' twice folded into one, 'y' separate; newest first
    assert errs[1].message.endswith("se rompio y") and errs[1].count == 1 and errs[1].label == "boton"
    assert errs[2].count == 2 and "se rompio x" in errs[2].message
    assert errs[1].stack != ""  # a trimmed traceback travels with it
    assert len(errs[1].stack.split("\n")) <= 6
    chat = [c for c in game.m.chat.values() if "Prueba" in c]
    assert chat == ["Prueba: tuvo un error. /prueba errores lo muestra para copiarlo."]
    # the tenth error pushes the oldest out
    game.run("for i = 1, 12 do MOCK.g.Wrap(function() error('e' .. i) end, 'loop')() end")
    assert game.run("return #MOCK.g.Errors()") == 10
    assert game.run("return MOCK.g.Errors()[1].message").endswith("e12")
    # Install guards the frame's OnEvent under the event's name, and the slash handler
    game.run("""
        MOCK.f = CreateFrame("Frame")
        MOCK.f:SetScript("OnEvent", function(self, event, arg) if arg == "bad" then error("evento malo") end MOCK.lastEvent = event .. arg end)
        MOCK.slash = MOCK.g.Install(MOCK.f, function(msg) if msg == "bad" then error("slash malo") end return "ok:" .. msg end)
        MOCK.f:GetScript("OnEvent")(MOCK.f, "PLAYER_LOGIN", "good")
        MOCK.f:GetScript("OnEvent")(MOCK.f, "PLAYER_LOGIN", "bad")
    """)
    assert game.m.lastEvent == "PLAYER_LOGINgood"
    assert game.run("return MOCK.g.Errors()[1].label") == "PLAYER_LOGIN"
    assert game.run("return MOCK.slash('hola')") == "ok:hola"
    game.run("MOCK.slash('bad')")
    assert game.run("return MOCK.g.Errors()[1].label") == "slash"
    # the page lists them and puts the chosen one in the text area; Borrar empties everything
    game.run("MOCK.page = MOCK.g.Page(UIParent)")
    assert game.run("return MOCK.page.empty:IsShown()") is False
    assert game.run("return MOCK.page.area.box._text") is not None
    game.run("MOCK.page.clear:GetScript('OnClick')()")
    assert game.run("return #MOCK.g.Errors(), MOCK.page.empty:IsShown()") == (0, True)


def test_ref_links_use_ink_quality_colours(game):
    # common (white) and poor (grey) are unreadable on parchment: they become ink and soft ink
    assert game.run('return P.RefLink("item:2996", "Linen", 1)') == "|cff3a2313|Hitem:2996|h[Linen]|h|r"
    assert game.run('return P.RefLink("item:1", "Junk", 0)') == "|cff6c4e31|Hitem:1|h[Junk]|h|r"
    assert game.run('return P.RefLink("item:2", "Green", 2)') == "|cff1f6b2a|Hitem:2|h[Green]|h|r"
    assert game.run('return P.RefLink("item:3", "Odd", 99)') == "|cff3a2313|Hitem:3|h[Odd]|h|r"


def test_link_text_shows_the_tooltip_over_a_link(game):
    game.run("""
        MOCK.tips = {}
        GameTooltip.SetHyperlink = function(_, link) table.insert(MOCK.tips, link) end
        MOCK.lt = P.LinkText(UIParent, "trade for |cff3a2313|Hitem:2589|h[Wool]|h|r")
    """)
    assert game.run("return MOCK.lt:GetText()").startswith("trade for ")
    assert game.run("return MOCK.lt._text").startswith("<html><body><p>trade for ")
    game.run("MOCK.lt:GetScript('OnHyperlinkEnter')(MOCK.lt, 'item:2589')")
    assert list(game.run("return MOCK.tips").values()) == ["item:2589"]
    game.run("MOCK.lt:SetText('a < b')")
    assert "&lt;" in game.run("return MOCK.lt._text")


def test_accept_links_feeds_the_box_and_stops_the_stack_split(game):
    # the game splits a stack only when ChatFrameUtil.InsertLink returns false; with a box of ours focused
    # the wrapper takes the link and returns true
    game.run("""
        ChatFrameUtil = { InsertLink = function(text) MOCK.orig = text; return false end }
        MOCK.box = P.Edit(UIParent, 200, {})
        MOCK.got = nil
        P.AcceptLinks(MOCK.box, function(text) MOCK.got = text end)
    """)
    assert game.run("return ChatFrameUtil.InsertLink('|Hitem:1|h[x]|h')") is False
    assert game.m.orig == "|Hitem:1|h[x]|h" and game.run("return MOCK.got") is None
    game.run("MOCK.box:SetFocus()")
    assert game.run("return ChatFrameUtil.InsertLink('|Hitem:2|h[y]|h')") is True
    assert game.run("return MOCK.got") == "|Hitem:2|h[y]|h"
    # a second box registers without wrapping twice
    game.run("MOCK.box2 = P.Edit(UIParent, 200, {}); P.AcceptLinks(MOCK.box2); MOCK.box:ClearFocus(); MOCK.box2:SetFocus()")
    assert game.run("return ChatFrameUtil.InsertLink('|Hitem:3|h[z]|h')") is True
    assert game.run("return MOCK.box2:GetText()") == "|Hitem:3|h[z]|h"


def test_minimap_right_click_shortcut_and_guard(game):
    game.run("""
        MOCK.db = { errors = {} }
        MOCK.g = P.Guard("TestAddon", MOCK.db, { slash = "/t", chat = function() end })
        MOCK.left, MOCK.right = 0, 0
        MOCK.b = P.MinimapButton("TestMini3", {
            icon = "x",
            onClick = function(button) MOCK.left = MOCK.left + 1; error("boom") end,
            onRightClick = function() MOCK.right = MOCK.right + 1 end,
            guard = MOCK.g,
        })
    """)
    game.run("MOCK.b:GetScript('OnClick')(MOCK.b, 'RightButton')")
    assert game.run("return MOCK.left, MOCK.right") == (0, 1)
    # a left click that errors is kept by the guard instead of reaching the player
    game.run("MOCK.b:GetScript('OnClick')(MOCK.b, 'LeftButton')")
    assert game.run("return MOCK.left, #MOCK.db.errors, MOCK.db.errors[1].label") == (1, 1, "minimap")


def test_guard_install_wraps_the_clicks_of_the_given_buttons(game):
    game.run("""
        MOCK.db2 = { errors = {} }
        local g = P.Guard("TestAddon", MOCK.db2, { slash = "/t", chat = function() end })
        MOCK.btn = CreateFrame("Button", "TestGuardedButton")
        MOCK.btn:SetScript("OnClick", function() error("click boom") end)
        g.Install(nil, nil, { MOCK.btn })
    """)
    game.run("MOCK.btn:GetScript('OnClick')(MOCK.btn, 'LeftButton')")
    assert game.run("return #MOCK.db2.errors, MOCK.db2.errors[1].label") == (1, "TestGuardedButton")


def test_the_hub_merges_the_family_into_one_button_with_a_menu(game):
    game.run("""
        MOCK.opened = {}
        MOCK.b1 = P.MinimapButton("HubA", { icon = "a", onClick = function(btn) table.insert(MOCK.opened, "A:" .. btn) end,
            hub = { addon = "AddonA", label = "Alfa", order = 20 } })
        MOCK.b2 = P.MinimapButton("HubB", { icon = "b", onClick = function() table.insert(MOCK.opened, "B") end,
            onRightClick = function() table.insert(MOCK.opened, "B-right") end,
            hub = { addon = "AddonB", label = "Beta", order = 10 } })
    """)
    # registered in order, both buttons shown, no hub button yet
    assert [e["label"] for e in game.run("return P.MinimapHub.Entries()").values()] == ["Beta", "Alfa"]
    assert game.run("return MOCK.b1:IsShown(), MOCK.b2:IsShown(), P.MinimapHub.button") == (True, True, None)
    # merged: the two hide, the one hub button shows with the lib's picture
    game.run("P.MinimapHub.SetMerged(true)")
    assert game.run("return MOCK.b1:IsShown(), MOCK.b2:IsShown(), P.MinimapHub.button:IsShown()") == (False, False, True)
    assert game.run("return P.MinimapHub.button.icon.texture").endswith("icon_hub")
    # the menu: one row per addon, click opens, right click does the right action
    game.run("P.MinimapHub.button:GetScript('OnClick')(P.MinimapHub.button, 'LeftButton')")
    assert game.run("return P.MinimapHub.menu:IsShown(), #P.MinimapHub.menu.rows") == (True, 2)
    assert game.run("return P.MinimapHub.menu.rows[1].label:GetText(), P.MinimapHub.menu.rows[2].label:GetText()") == ("Beta", "Alfa")
    game.run("local r = P.MinimapHub.menu.rows[1]; r:GetScript('OnClick')(r, 'RightButton')")
    game.run("local r = P.MinimapHub.menu.rows[2]; r:GetScript('OnClick')(r, 'LeftButton')")
    assert list(game.run("return MOCK.opened").values()) == ["B-right", "A:LeftButton"]
    assert game.run("return P.MinimapHub.menu:IsShown()") is False
    # back to separate buttons
    game.run("P.MinimapHub.SetMerged(false)")
    assert game.run("return MOCK.b1:IsShown(), MOCK.b2:IsShown(), P.MinimapHub.button:IsShown()") == (True, True, False)
    # a hidden-by-setting button stays hidden when un-merging
    game.run("MOCK.b2.wanted = false; P.MinimapHub.SetMerged(true); P.MinimapHub.SetMerged(false)")
    assert game.run("return MOCK.b2:IsShown()") is False
    # re-registering the same addon replaces its entry instead of duplicating it
    game.run("P.MinimapHub.Register('AddonA', { label = 'Alfa 2', order = 5 })")
    assert [e["label"] for e in game.run("return P.MinimapHub.Entries()").values()] == ["Alfa 2", "Beta"]
