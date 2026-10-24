class_name UIUtil
## Shared UI helpers and the demo's design tokens (index.html :root, L9–17).

const SILK := Color("#ece4cf")
const SILK_HI := Color("#f6f0e0")
const INK := Color("#26231f")
const INK_SOFT := Color("#4d473e")
const CINNABAR := Color("#b8392a")
const JADE := Color("#3f9b86")
const JADE_HI := Color("#6fe0c0")
const CHROME := Color(17 / 255.0, 31 / 255.0, 29 / 255.0, 0.9)
const CHROME_SOLID := Color("#13221f")
const CHROME_2 := Color("#1c302c")
const CHROME_LINE := Color(120 / 255.0, 160 / 255.0, 150 / 255.0, 0.22)
const CHROME_TEXT := Color("#ebe5d4")
const CHROME_DIM := Color("#a3b3ad")
const SECT := Color("#57799e")
const SECT_LINE := Color("#83a3c4")
const CITY := Color("#e9e2cc")
const SECRET := Color("#f2d58a")
const MOUNT := Color("#efe7d2")
const WATER := Color("#9ccbd0")

static var _fonts := {}


static func brush() -> Font:
	return _font("res://fonts/MaShanZheng-Regular.ttf")


## Noto Serif SC at 400 / 600 / 700 / 900.
static func serif(weight := 400) -> Font:
	return _font("res://fonts/NotoSerifSC-%d.ttf" % weight)


static func _font(path: String) -> Font:
	if not _fonts.has(path):
		_fonts[path] = load(path)
	return _fonts[path]


## Label settings: a font, size, colour, an optional soft glow (CSS text-shadow 0 0 Npx) or a hard dark halo (outline).
static func ls(font: Font, size: int, color: Color, glow := Color(0, 0, 0, 0), glow_size := 0, outline := Color(0, 0, 0, 0), outline_size := 0) -> LabelSettings:
	var s := LabelSettings.new()
	s.font = font
	s.font_size = size
	s.font_color = color
	if glow_size > 0:
		s.shadow_color = glow
		s.shadow_size = glow_size
		s.shadow_offset = Vector2.ZERO
	if outline_size > 0:
		s.outline_color = outline
		s.outline_size = outline_size
	return s


## CSS writing-mode: vertical-rl for a short run of CJK: one character per line.
static func vertical(text: String) -> String:
	var out := PackedStringArray()
	for i in text.length():
		out.append(text[i])
	return "\n".join(out)


## letter-spacing in em → a FontVariation's glyph spacing in px.
static func spaced(font: Font, size: int, em: float) -> FontVariation:
	var v := FontVariation.new()
	v.base_font = font
	v.spacing_glyph = int(round(size * em))
	return v


static func box(bg: Color, radius := 0, border := 0, border_col := Color(0, 0, 0, 0), margin := Vector4(0, 0, 0, 0)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.set_border_width_all(border)
	s.border_color = border_col
	s.content_margin_left = margin.x; s.content_margin_top = margin.y; s.content_margin_right = margin.z; s.content_margin_bottom = margin.w
	s.anti_aliasing = true
	return s


static func director() -> Node:
	return Engine.get_main_loop().get_first_node_in_group("director")
