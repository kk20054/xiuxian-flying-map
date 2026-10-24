extends CanvasLayer
## The flight HUD (demo #brand, #banner, #hint, #readout — L28–41, updateBanner L14253, readout L14231).
## Ink on silk; visible only in flight (fades over 0.6 s like the CSS transition).

@onready var brand: Control = %Brand
@onready var banner: Control = %Banner
@onready var banner_name: Label = %BannerName
@onready var banner_sub: Label = %BannerSub
@onready var hint: Control = %Hint
@onready var readout: Control = %Readout
@onready var alt_l: Label = %Alt
@onready var alt_band: Label = %AltBand
@onready var spd_l: Label = %Spd

var banner_t := 0.0
var last_banner := ""
var shown := -1.0


func _ready() -> void:
	for c in [brand, hint, readout, banner]:
		c.modulate.a = 0.0
	if DisplayServer.is_touchscreen_available():
		hint.visible = false


func _process(dt: float) -> void:
	var d := UIUtil.director()
	if d == null:
		return
	var on := 1.0 if Game.mode == Game.Mode.FLIGHT else 0.0
	if on != shown:
		shown = on
		var tw := create_tween().set_parallel()
		for c in [brand, readout]:
			tw.tween_property(c, "modulate:a", on, 0.6)
		if on == 0.0:
			tw.tween_property(hint, "modulate:a", 0.0, 0.6)
			banner_t = 0.0
	if on > 0.0:
		hint.modulate.a = move_toward(hint.modulate.a, 1.0 if Game.hint_t > 0.0 else 0.0, dt / 0.6)
		var A: float = d.A
		alt_l.text = str(int(round(A)))
		alt_band.text = " 丈 · " + d.band_name(A)
		var v := Vector2(d.vel.x, d.vel.z).length()
		var cruise := Cfg.f("flight.speed", 0.12) * A
		spd_l.text = "遁速 %d 丈/息 · %s" % [int(round(v)), "遁光" if d.boosting else ("御空" if v > 0.12 * cruise else "悬停")]
		_update_banner(dt, d)
	banner.modulate.a = clampf(minf(banner_t, 4.2 - banner_t) * 1.5, 0.0, 1.0)


## A place's name rises over the view as you enter its banner radius (900–1800 丈), fades after ~4 s; hysteresis ×1.25.
func _update_banner(dt: float, d: Node) -> void:
	var best = null
	var bd := INF
	for p in World.places:
		if not p.has("banner") or p.banner == null:
			continue
		var dist := Vector2(d.pos.x - p.x, d.pos.z - p.z).length()
		if dist < float(p.banner) and dist < bd:
			bd = dist; best = p
	if best != null and best.id != last_banner:
		last_banner = best.id
		banner_t = 4.2
		banner_name.text = best.name
		banner_sub.text = best.get("sub", "")
		Game.banner.emit(best)
	elif best == null and last_banner != "":
		var p = World.by_id.get(last_banner)
		if p == null or Vector2(d.pos.x - p.x, d.pos.z - p.z).length() > float(p.banner) * 1.25:
			last_banner = ""
	banner_t = maxf(0.0, banner_t - dt)
