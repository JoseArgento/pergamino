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
        self.loader = self.lua.eval("function(src, name) return assert(loadstring(src, '@' .. name)) end")

    def load(self, addon="TestAddon", src=None):
        chunk = self.loader(src or LIB.read_text(encoding="utf-8"), f"{addon}/Libs/Pergamino/Pergamino.lua")
        chunk(addon, self.lua.table())
        return self.lua.globals().Pergamino

    def run(self, code):
        return self.lua.eval("function(P, MOCK) " + code + " end")(self.lua.globals().Pergamino, self.m)


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
    for name in ("Alegreya-Regular", "Alegreya-SemiBold", "Alegreya-Italic", "Cinzel-SemiBold", "Cinzel-Bold"):
        assert f'"{name}.ttf"' in src
        assert (ROOT / "Libs" / "Pergamino" / "Fonts" / f"{name}.ttf").exists()
    assert (ROOT / "Libs" / "Pergamino" / "Fonts" / "OFL.txt").exists()


def test_textures_named_in_the_code_exist_and_are_powers_of_two():
    src = LIB.read_text(encoding="utf-8")
    import re

    names = set(re.findall(r'P\.MEDIA \.\. "(\w+)"', src))
    assert {"page", "leather", "spine", "ribbon", "title", "seal", "check", "pill"} <= names
    for name in names:
        data = (ROOT / "Libs" / "Pergamino" / "Media" / f"{name}.tga").read_bytes()
        width, height, bpp = int.from_bytes(data[12:14], "little"), int.from_bytes(data[14:16], "little"), data[16]
        assert data[2] == 2 and bpp == 32 and width & (width - 1) == 0 and height & (height - 1) == 0, name
        assert width <= 1024 and height <= 1024


def test_a_newer_copy_wins_and_an_older_one_steps_aside(game):
    src = LIB.read_text(encoding="utf-8")
    older = src.replace("local VERSION = 1", "local VERSION = 0")
    game.load("OtherAddon", older)
    P = game.lua.globals().Pergamino
    assert P.VERSION == 1 and "TestAddon" in P.MEDIA  # the older copy did not replace it
    newer = src.replace("local VERSION = 1", "local VERSION = 2")
    game.load("NewAddon", newer)
    P = game.lua.globals().Pergamino
    assert P.VERSION == 2 and "NewAddon" in P.MEDIA


def test_book_has_two_pages_a_title_a_seal_and_bookmarks(game):
    book = game.run("""
        local b = P.Book("TestBook", { title = "Bitácora", tabs = { { "notes", "Libreta" }, { "journal", "Diario" } } })
        return b
    """)
    assert book.left is not None and book.right is not None and game.run("return TestBook.page == TestBook.left")
    assert book.title._text == "Bitácora"
    assert book.pageL is not None and book.pageR is not None and book.spine is not None
    assert book.tabOrder[1] == "notes" and book.tabOrder[2] == "journal"
    assert "TestBook" in list(game.lua.globals().UISpecialFrames.values())
    # the right page is the mirror of the left one
    assert game.run("local b = TestBook; return b.pageR:GetTexCoord()") == (1, 0.2, 0, 1)
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
    assert game.run("return TestBook.pages.b.left:IsShown(), TestBook.pages.a.left:IsShown()") == (True, False)
    assert game.run("return TestBook.pages.b.right:IsShown()") is True
    assert list(game.m.tabs.values()) == ["b"]
    # the active bookmark is wider and wears the gold half of the cloth
    assert game.run("return TestBook.tabs.b:GetWidth(), TestBook.tabs.a:GetWidth()") == (142, 128)
    assert game.run("return TestBook.tabs.b.cloth:GetTexCoord()") == (0, 1, 0.5, 1)
    assert game.run("return TestBook.tabs.a.cloth:GetTexCoord()") == (0, 1, 0, 0.5)
    # clicking a bookmark selects it and turns the page
    game.m.sounds = game.lua.table()
    game.run("SOUNDKIT.IG_ABILITY_PAGE_TURN = 1234; TestBook.tabs.a:GetScript('OnClick')()")
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
    b = game.run("return P.Button(UIParent, 'Nueva nota', 120, function() MOCK.clicked = true end)")
    assert b._text == "Nueva nota" and b.fill.texture.endswith("leather")
    game.run("UIParent._x = P.Button(UIParent, 'x', 50, function() MOCK.clicked = true end); UIParent._x:GetScript('OnClick')()")
    assert game.m.clicked is True
    chip = game.run("return P.Chip(UIParent, 'Todas')")
    assert chip.pressed is False
    game.run("local c = P.Chip(UIParent, 'Todas'); c:SetPressed(true); MOCK.chip = c")
    assert game.m.chip.pressed is True and game.m.chip.fill._alpha == 1
    check = game.run("return P.Check(UIParent, 'Solo este personaje')")
    assert check.label._text == "Solo este personaje" and check._normalTexture is not None and check._checkedTexture is not None
    edit = game.run("return P.Edit(UIParent, 200, { placeholder = 'Buscar' })")
    assert edit.placeholder._text == "Buscar" and edit.placeholder._shown is True
    game.run("local e = P.Edit(UIParent, 200, { placeholder = 'Buscar' }); e:SetText('hola'); MOCK.edit = e")
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
    assert rows[1].rule is not None and rows[1].highlight is not None and rows[1].selected is not None
    game.run("MOCK.list.box.rows[2]:GetScript('OnClick')(MOCK.list.box.rows[2], 'LeftButton')")
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
