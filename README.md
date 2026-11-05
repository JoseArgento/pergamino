# Pergamino

La piel compartida de los addons de José Argento para WoW Forever: un libro abierto de pergamino dentro de una tapa de cuero, marcadores de tela como pestañas, tinta y tipografía de manuscrito (Cinzel para títulos, Alegreya para el cuerpo). Nada de plantillas de Blizzard: cada pieza se dibuja acá, con texturas y fuentes propias.

![Vista previa](docs/preview.png)

## Cómo se usa

Cada addon lleva **su propia copia** de `Libs/Pergamino` (no es una dependencia aparte):

```bash
tools/vendor.sh /ruta/a/MiAddon      # copia Libs/Pergamino adentro del addon
```

y en el `.toc`, como primer archivo:

```
Libs\Pergamino\Pergamino.lua
```

La librería define un global `Pergamino`. Si dos addons traen copias, queda la más nueva (`Pergamino.VERSION`); las texturas y fuentes se leen de la carpeta del addon cuya copia se cargó, así que cada copia tiene que estar completa.

## API

Todo devuelve frames normales de WoW; los puntos y tamaños los ponés vos.

| Función | Qué devuelve |
|---|---|
| `Pergamino.Book(name, opts)` | El libro. `opts = { title, width (860), height (540), single = false, tabs = { { "clave", "Rótulo" }, … }, escape = true }`. Tiene `.left` y `.right` (áreas de contenido de cada página; `.right` es nil en modo `single`), `.title`, `.close` (el sello de lacre), `.tabs[clave]`, `:AddTab(clave, rótulo)`, `:AddPage(clave)` → `{ left, right }` (frames que se muestran solo con esa pestaña), `:SelectTab(clave)`, `:SetTitle(texto)`, `:SetTabsShown(bool)`, `.OnTab = function(clave)`, `.OnMoved = function(point, …)`, `.selected`. Se mueve arrastrando, se cierra con Escape y suena al abrir, cerrar y pasar de página. |
| `Pergamino.Label(parent, texto, rol, justify)` | Un texto. Roles: `title`, `heading`, `subheading`, `body`, `strong`, `italic`, `big`, `small`, `muted`, `link`. |
| `Pergamino.Button(parent, texto, ancho, onClick)` | Botón de cuero con letras doradas, 26 de alto. |
| `Pergamino.Chip(parent, texto, onClick)` | Pastilla de tinta para filtros; `:SetPressed(bool)`, `:Fit()`. |
| `Pergamino.Check(parent, texto, onClick)` | Casilla de tinta con tilde; `.label`. |
| `Pergamino.Edit(parent, ancho, { placeholder, font, maxLetters, onEnter })` | Campo de una línea sobre una línea de tinta; `:SetPlaceholder(texto)`. |
| `Pergamino.TextArea(parent)` | Texto largo (el `ScrollingEditBoxTemplate` del juego con nuestra fuente); `.box`, `.bar`. |
| `Pergamino.List(parent, altoFila, init, onClick)` | Lista con scroll (ScrollBox); filas con filete de tinta, hover tinta y selección dorada (`row.selected:Show()`); `:SetData(items, keepScroll)`, `:Refresh()`, `.box`, `.bar`. |
| `Pergamino.Panel(parent)` | Recuadro apenas hundido con borde de tinta. |
| `Pergamino.Rule(parent, alpha)` | Filete horizontal de tinta (alto 1). |
| `Pergamino.Tag(parent, texto, kind)` | Etiqueta chica de color según `Pergamino.KIND_COLORS` (`level`, `boss`, `death`, `note`, `loot`, `zone`, …); `:Set(texto, kind)`. |
| `Pergamino.Card(name, ancho, alto, título)` | Una tarjeta de pergamino suelta (para vistas previas); `.body`, `.close`. |
| `Pergamino.Apply(frame, rol)` | Pone la fuente del rol a todos los textos de un frame que no se armó con la librería. |
| `Pergamino.fonts.*` | Los objetos `Font` (`PergaminoBody`, `PergaminoHeading`, …) para `SetFontObject`. |
| `Pergamino.INK`, `.INK_SOFT`, `.CRIMSON`, `.GOLD`, `.GOLD_DEEP`, `.LINK`, `.PARCHMENT` | Las tintas, como `{ r, g, b }`. |

Los popups siguen siendo los de Blizzard (`StaticPopup`): no se pueden reskinear sin taint.

## Texturas y fuentes

`tools/make_textures.py` dibuja todo con Pillow (ruido y formas, sin arte del juego) en `Libs/Pergamino/Media/*.tga`, potencias de 2. Las fuentes son Alegreya y Cinzel, licencia OFL (`Libs/Pergamino/Fonts/OFL.txt`). `tools/preview.html` es una maqueta HTML con las mismas medidas, para mirar el diseño sin entrar al juego (`docs/preview.png`).

## Desarrollo

```bash
pip install pytest lupa pillow playwright
python tools/make_textures.py
pytest
```

⏳ Todo lo visual está verificado solo en la maqueta HTML y con el mock de Lua: cómo se ve de verdad en el cliente de Forever lo decide el juego.

Sin relación con Blizzard Entertainment. Licencia MIT.
