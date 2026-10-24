extends Node
## The demo's CONFIG (index.html §01): every tunable number in one dictionary, read from the export (data/world/meta.json → config)
## so the port starts from exactly the values the Three.js demo used. Dotted paths ("flight.speed") like the demo's debug panel.

signal changed(path: String, value)

const META := "res://data/world/meta.json"

var data: Dictionary = {}
var defaults: Dictionary = {}


func _init() -> void:
	var f := FileAccess.open(META, FileAccess.READ)
	if f:
		var meta = JSON.parse_string(f.get_as_text())
		if meta is Dictionary and meta.has("config"):
			data = meta.config
	if data.is_empty():
		push_warning("Cfg: %s not found — run tools/export-world first; using built-in defaults" % META)
		data = _fallback()
	defaults = data.duplicate(true)


func g(path: String, fallback = null):
	var node = data
	for k in path.split("."):
		if node is Dictionary and node.has(k):
			node = node[k]
		else:
			return fallback
	return node


func f(path: String, fallback := 0.0) -> float:
	var v = g(path, fallback)
	return float(v) if (v is float or v is int) else fallback


func s(path: String, value) -> void:
	var keys := path.split(".")
	var node = data
	for i in keys.size() - 1:
		if not node.has(keys[i]):
			node[keys[i]] = {}
		node = node[keys[i]]
	node[keys[-1]] = value
	changed.emit(path, value)


func reset() -> void:
	data = defaults.duplicate(true)
	changed.emit("", null)


## The values the flight, camera and UI need, should the export be missing (copied from index.html L320–447).
func _fallback() -> Dictionary:
	return {
		"flight": {"speed": 0.12, "boostMul": 3.0, "accel": 0.5, "glide": 1.25, "fling": 0.85, "lightHeight": 0.24, "bob": 1.0, "dunIn": 0.22, "dunOut": 0.55},
		"camera": {"fov": 40, "lookAhead": 0.6, "follow": 0.3, "pitchLow": 38, "pitchMid": 45, "pitchHigh": 54, "pitchTop": 60, "boostPull": 0.1, "lead": 0.1},
		"zoom": {"low": 950, "mid": 1650, "high": 8000, "mapAt": 11000, "start": 1650, "wheel": 0.0013, "keyRate": 0.95, "ease": 0.28},
		"look": {"tiltShift": 1.0, "focusBand": 0.18, "paper": 0.24, "vignette": 0.38, "edgeFade": 0.05, "haze": 0.5, "edgeInk": 0.7, "pixelRatio": 1.0},
		"cinema": {"grade": 1.0, "valleyMist": 0.8, "warmth": 0.6, "vignette": 0.35},
		"intro": {"duration": 4.6, "ink": [0.05, 1.35], "wash": [1.0, 3.05], "clouds": [2.7, 3.8], "lightIn": [3.35, 4.55], "title": [0.15, 3.3], "startAlt": 2700},
		"hotspot": {"radius": 700, "labelMaxAlt": 4200, "prompt": "按 E 落脚"},
		"map": {"fov": 20, "minView": 2400, "maxView": 42000},
		"terrain": {"relief": 1.0, "soft": 0.85, "creaseInk": 0.75, "footInk": 0.8},
		"sun": {"azimuth": 140, "elevation": 40, "shadow": 0.85, "contrast": 1.0, "ao": 0.5},
		"water": {"depth": 7, "seaDepth": 20, "steps": 4, "waves": 1.0, "ripples": 1.0, "seaMotion": 1.8},
		"cloudSea": {"amount": 1.0, "height": 175, "billow": 1.0, "speed": 1.0, "thick": 150, "density": 1.0, "steps": 9},
		"light": {"size": 1.0, "tail": 1.0, "intensity": 0.85, "breath": 0.08, "shadow": 0.32, "speedLines": 0.6, "core": "#e8fff6", "glow": "#3fd9b0"},
		"trees": {"density": 1.0, "size": 1.0, "sway": 1.0},
	}
