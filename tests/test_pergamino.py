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
    older = src.replace("local VERSION = 3", "local VERSION = 1")
    game.load("OtherAddon", older)
    P = game.lua.globals().Pergamino
    assert (
        P.VERSION == 3 and "TestAddon" in P.MEDIA
    )  # the older copy did not replace it
    newer = src.replace("local VERSION = 3", "local VERSION = 4")
    game.load("NewAddon", newer)
    P = game.lua.globals().Pergamino
    assert P.VERSION == 4 and "NewAddon" in P.MEDIA


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
    )
    assert b.angle == 90 and b._shown is True
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
