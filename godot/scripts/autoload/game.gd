extends Node
## App state shared by the 3D side and the UI (the demo's ST / MAP / CARD, §12): the mode, the 舆图 blend map_k (uMap),
## the selected place, plus a few signals. The work is done by Director (camera + modes) and the UI nodes; this only holds state.

enum Mode { LOADING, INTRO, FLIGHT, TO_MAP, MAP, TO_FLIGHT }

signal mode_changed(mode: Mode)
signal card_open(place: Dictionary, from_flight: bool)
signal card_close
signal near_changed(place)               # the hotspot the light is near (or null)
signal banner(place: Dictionary)
signal toast(text: String)
signal trail_changed(on: bool)
signal legend_changed

var mode: Mode = Mode.LOADING:
	set(v):
		mode = v
		mode_changed.emit(v)

## 0 = the living sandbox, 1 = the flat painted 舆图. Every world shader reads it as `global uniform float map_k`.
var map_k := 0.0:
	set(v):
		map_k = v
		RenderingServer.global_shader_parameter_set("map_k", v)

## the intro's reveal (also pushed to the shader globals ink_reveal / wash_reveal / cloud_in)
var ink := 1.0
var wash := 1.0
var cloud_in := 1.0

var near = null                          # Dictionary or null
var selected = null                      # the place shown in the card / highlighted on the map
var card_from_flight := false
var trail := false
var hidden_cats := {}                    # legend group → true when switched off
var hint_t := 18.0                       # the key hint hides after this many seconds of flight
var debug_open := false

# legend groups (demo LEGEND_OF L638): feat → mount; region/state/alliance/sea/edge → force
const LEGEND_OF := {"sect": "sect", "city": "city", "secret": "secret", "mount": "mount", "feat": "mount",
	"region": "force", "state": "force", "alliance": "force", "sea": "force", "edge": "force"}
# minor places, hidden when the map is zoomed far out (demo MINOR)
const MINOR := ["tingyun", "feilian", "guxiu", "sunshi", "yingxian", "dimai"]
# 韩立行迹 (demo TRAIL L641)
const TRAIL := [["luoyun", "① 入落云宗"], ["lingyan", "② 试剑大会"], ["zimu", "③ 子母峰洞府"]]


func set_reveal(i: float, w: float, c: float) -> void:
	ink = i; wash = w; cloud_in = c
	RenderingServer.global_shader_parameter_set("ink_reveal", i)
	RenderingServer.global_shader_parameter_set("wash_reveal", w)
	RenderingServer.global_shader_parameter_set("cloud_in", c)


func in_flight() -> bool:
	return mode == Mode.FLIGHT


func can_fly_to(p: Dictionary) -> bool:
	return not p.get("mapOnly", false) and not (p.cat in ["region", "state", "alliance", "sea", "edge"])


func label_hidden(p: Dictionary) -> bool:
	return hidden_cats.get(LEGEND_OF.get(p.cat, p.cat), false)


func open_card(p: Dictionary, from_flight: bool) -> void:
	selected = p
	card_from_flight = from_flight
	card_open.emit(p, from_flight)


func close_card() -> void:
	selected = null
	card_from_flight = false
	card_close.emit()
