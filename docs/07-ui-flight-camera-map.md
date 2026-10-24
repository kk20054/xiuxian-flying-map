# A · UI, flight, camera, fly↔map transition, 舆图 rendering, main loop: rebuild notes for Godot 4

Source: `demo/index.html`. "L123" means line 123 of that file. Covered: L1–276 (HTML+CSS),
L13143–13306 (sec 10 · 舆图 shader), L14078–15009 (sec 12–14), plus CONFIG (L311–447), POIS (L565–641), shared uniforms (L480–490),
the intro shader chunk (L4252–4276) and updatePost (L13106–13140), where these sections depend on them.

Units: 1 world unit = 1 丈. +x = east, +z = south, +y = up (L310 comment). North is −z. Godot uses the same right-handed, Y-up axes
with −Z as "forward", so **world coordinates carry over 1:1** (no axis flip needed). The camera always looks north (−z).

---------------------------------------------------------------------------------------------------------------------------------

## 0. Key derived numbers (computed from CONFIG + GEO, see computeLayout L360–398)

| quantity | formula | value |
|---|---|---|
| cruise speed at mid altitude | `flight.speed × zoom.mid` = 0.12 × 1650 | **198 丈/s** ("丈/息") |
| k (丈 per screenshot px) | `gujianLuoyunSec × cruise × spacing / |G−L|px` = 62×198/211.44 | **58.06** |
| LAYOUT.S | k / 23.5 | **2.4706** |
| origin (px) | centroid of 古剑门/落云宗/百巧院 pins | (570.33, 394.33) |
| LAYOUT.rect (world) | GEO.frame x 60–2330, y −700–680 mapped | x0 −29 630, x1 102 167, z0 −63 537, z1 16 586 |
| 落云宗 world pos | | (11 477, −658) |
| startPos | luoyun + (−450, +1450) (L393) | (11 027, 792) |
| MAP_HOME (L4089–4092) | cx=(x0+x1)/2 with x0 = 天柱山.x−2500, x1 = 倪航斋.x+4500; cz = −14000; view = max(7000,(x1−x0)/2/1.7) | cx ≈ 39 652, cz −14 000, view ≈ 36 077 |
| travel times (debug table, mid altitude) | | 古剑↔落云 12 276 丈 62.0 s (boost 20.7 s); 古剑↔百巧 11 645 丈 58.8 s; 百巧↔落云 22 622 丈 114.3 s |
| minor-label cutoff | 3400 × S | ≈ 8 400 (map view half-extent) |
| selectPoi zoom-to | 2600 × S / 5200 × S | ≈ 6 424 / ≈ 12 847 |

CONFIG blocks used by these sections (verbatim values):

```
flight: { speed: 0.12, boostMul: 3.0, accel: 0.5, glide: 1.25, fling: 0.85, lightHeight: 0.24, bob: 1.0, dunIn: 0.22, dunOut: 0.55 }   // L404
figure: { on: false, size: 1.5, lean: 30, boostLean: 66, bank: 22, fade: 0.22 }                                                    // L407  (on:false → FIG = null)
camera: { fov: 40, lookAhead: 0.6, follow: 0.3, pitchLow: 38, pitchMid: 45, pitchHigh: 54, pitchTop: 60, boostPull: 0.1, lead: 0.1 } // L409
zoom:   { low: 950, mid: 1650, high: 8000, mapAt: 11000, start: 1650, wheel: 0.0013, keyRate: 0.95, ease: 0.28 }                 // L411
look:   { tiltShift: 1.0, focusBand: 0.18, paper: 0.24, vignette: 0.38, edgeFade: 0.05, detail: 1.0, pixelRatio: 1.0, haze: 0.5, edgeInk: 0.7, ground: 1.0 }  // L~436
cinema: { grade: 1.0, valleyMist: 0.8, shafts: 1.0, cirrus: 1.0, warmth: 0.6, vignette: 0.35, region: 1.0 }
intro:  { duration: 4.6, ink: [0.05, 1.35], wash: [1.0, 3.05], clouds: [2.7, 3.8], lightIn: [3.35, 4.55], title: [0.15, 3.3], startAlt: 2700 }
hotspot:{ radius: 700, labelMaxAlt: 4200, prompt: '按 E 落脚' }
map:    { fov: 20, minView: 2400, maxView: 42000 }
terrain.relief: 1.0  (groundClear multiplies by it)
```
`CONFIG_DEFAULT` is a deep JSON clone taken right after (used by debug "恢复默认" and the test API `layers`).

Easing helpers (L463–466):
```
smoothstep(a,b,x) = t*t*(3-2t), t = clamp((x-a)/(b-a),0,1)
easeInOut(t) = t<.5 ? 4t³ : 1 - (-2t+2)³/2          // cubic in-out
easeOut(t)   = 1 - (1 - clamp(t,0,1))³                // cubic out
```
Frame-rate-independent smoothing everywhere is `x = lerp(x, target, 1 - exp(-dt/τ))` (τ in seconds) or `1 - exp(-dt*rate)`.

---------------------------------------------------------------------------------------------------------------------------------

## 1. UI: tokens, fonts, layers

### 1.1 Design tokens (`:root`, L9–17)

| token | value | use |
|---|---|---|
| --silk | `#ece4cf` | html/body background (behind canvas) |
| --silk-hi | `#f6f0e0` | glow text-shadow colour for ink HUD text |
| --ink | `#26231f` | HUD text |
| --ink-soft | `#4d473e` | HUD secondary text |
| --cinnabar | `#b8392a` | seal background, banner rule |
| --cinnabar-d | `#93281c` | (declared, unused in CSS shown) |
| --jade | `#3f9b86` | primary button, quote bar, sliders accent |
| --jade-hi | `#6fe0c0` | focus ring, pins hover/selected, player marker, debug outputs |
| --chrome | `rgba(17,31,29,.9)` | dark map-chrome panel fill |
| --chrome-solid | `#13221f` | debug header |
| --chrome-2 | `#1c302c` | hover / active fill |
| --chrome-line | `rgba(120,160,150,.22)` | 1px borders, dividers |
| --chrome-text | `#ebe5d4` | text on chrome |
| --chrome-dim | `#a3b3ad` | secondary text on chrome |
| --sect | `#57799e` | sect tag fill |
| --sect-line | `#83a3c4` | sect tag 1px ring |
| --city | `#e9e2cc` | city label |
| --secret | `#f2d58a` | 秘境 label |
| --mount | `#efe7d2` | 山川 label |
| --water | `#9ccbd0` | feat (途中地名) label |
| --brush | `"Ma Shan Zheng","STKaiti","KaiTi","Kaiti SC",serif` | calligraphic display |
| --serif | `"Noto Serif SC","Songti SC","STSong","SimSun",serif` | body |
| --r | `12px` | chrome radius |

Fonts loaded from Google Fonts (L5): **Ma Shan Zheng** (400 only) and **Noto Serif SC** weights **400, 600, 700, 900**.
Body base font = --serif (L18). `-webkit-font-smoothing: antialiased`. Text in brush font always uses `font-weight:400`.
The comment at L7–8 states the design is intentionally light-only ("no dark variant").

Global: `button{font:inherit;color:inherit}`; `:focus-visible{outline:2px solid #6fe0c0; outline-offset:2px}` (L24–25).

### 1.2 Z-order of every layer (bottom → top)

| z | element | notes |
|---|---|---|
| — | `#gl` canvas (L19, L206) | fixed, inset 0, `touch-action:none`, `cursor:grab` (`.dragging` → grabbing, `.picking` → crosshair L200). tabindex 0, aria-label "云梦山御空：一张会动的青绿山水舆图。WASD 飞行，滚轮升降，拖动平移，M 收图" |
| — | `#silk` (L21) | fixed overlay, `mix-blend-mode:multiply`, CSS opacity .26 (runtime overwritten every frame: `look.paper × (1 − 0.4·uMap)` L14960), bg = 256×256 procedural canvas tile (setupSilk L14579–14588) |
| — | `#vignette` (L22) | `radial-gradient(125% 100% at 50% 46%, transparent 56%, rgba(70,62,44,.42) 100%)`, opacity .42 (runtime: `look.vignette × (1 − uMap)` L14961) |
| — | `#fog` (L23) | `#f3f2ec`, opacity 0, transition .25s. **Never referenced by JS** – dead element |
| 4 | `#hot` flight hotspots (L180) | fixed, inset 0, overflow hidden, transition opacity .5s |
| 5 | `.hud` (#brand, #banner, #hint, #readout) (L28) | pointer-events none, transition opacity .6s |
| 6 | `#pad`, `#boostBtn` touch controls (L139, L141) | display none unless `(pointer:coarse)` (L202) |
| 10 | `#map` 舆图 chrome container (L58) | opacity 0 → `.on` 1 with .7s transition; children `.live`/`.lb` get pointer events only while `.on` (L60) |
| 12 | `#unroll` "舆图展开中" (L115) | centred |
| 15 | `#intro` (L50) | |
| 16 | `#skip` (L55) | |
| 20 | `#modeSwitch` (L44) | |
| 22 | `#panel` info card (L178, moved out of #map in v3) | |
| 24 | `#pickDot` (L201) | |
| 25 | `#dbg` debug panel (L151) | created by JS |
| 30 | `#toast` (L148) | created on demand by JS |
| 31 | `#loading` (L190) | |

All edge offsets add `env(safe-area-inset-*)`; Godot: add `DisplayServer.get_display_safe_area()` margins.

### 1.3 Flight HUD

**#brand** (L29–32, DOM L209) top-left, `top:16px; left:16px`, flex row gap 10, align center.
- `.seal` (L30): 40×40, radius 6, bg `#b8392a`, text `#fbeee2`, brush 17px, line-height 16px, `writing-mode:vertical-rl` (two chars "云梦" stacked vertically), padding-top 2,
  box-shadow `inset 0 0 0 2px rgba(255,236,220,.35), 0 1px 2px rgba(0,0,0,.25)`.
- `.brand-t b` "云梦山": brush 26px, line-height 1, color --ink, text-shadow `0 0 8px #f6f0e0`.
- `.brand-t span` "天南 › 溪国 · 西部灵脉": 12px, letter-spacing .12em, --ink-soft, margin-top 4, shadow `0 0 6px #f6f0e0`. Hidden ≤640px.

**#banner** (L38–41, DOM L210) top 70px, horizontally centred (`left:50%; translateX(-50%)`), text-align center, opacity driven by JS.
- `b` place name: brush 44px (34px ≤640px), line-height 1.1, --ink, shadow `0 0 14px #f6f0e0, 0 0 3px #f6f0e0`.
- `span` subtitle (POI `sub`): 13px, letter-spacing .3em, --ink-soft.
- `i` rule: 44×2px, `#b8392a`, margin 8px auto 0, opacity .8.
- aria-live polite.

**#hint** (L33–35, DOM L211–219) bottom-left 16/16. bg `rgba(246,240,224,.72)` + blur 6px, border 1px `rgba(80,66,44,.18)`, radius 10, padding 10×14, 13px --ink,
CSS grid 2 columns (`auto auto`), gap 4px 12px, max-width `min(360px, 100vw−32px)`. Hidden on coarse pointers.
`kbd`: serif 700 12px, bg `rgba(38,35,31,.08)`, border 1px `rgba(38,35,31,.2)` with bottom 2px, radius 5, padding 0 5, margin-right 2.
Rows (key → action), exact text:
```
W A S D        御光飞行
Shift          疾遁加速
Space / Q      升 / 降
滚轮 · 拖动     升降 · 平移
E              落脚（近宗门时）
M              收图 / 御空
`              调试面板
```
Auto-hides after `ST.hintT` = 18 s of flight (L14086, L14235); `H` toggles (L14537).

**#readout** (L36–37, DOM L220) bottom-right 16/16, right-aligned, 12px, letter-spacing .08em, --ink-soft, tabular nums.
`<b id=roAlt>` brush 18px --ink (altitude integer); `#roAltL` "丈 · 低空|中空|高空"; line break; `#roSpd` "遁速 N 丈/息 · 遁光|御空|悬停". Initial "—", "丈", "遁速 0".

Night variant (L169–175): rules for `body.night` (pale ink HUD `#eef1f6`/`#c6cfdc`, hint bg `rgba(18,26,40,.72)`, silk .18, bluer vignette). **No JS
in the file adds the `night` class** (grep: only CSS hits) – optional/dead; port only if you add a night mode.

### 1.4 Mode switch `#modeSwitch` (L44–47, DOM L223)

Button, fixed top-right 16/16, z 20, flex, padding 4, gap 2, radius 12, bg --chrome, border 1px --chrome-line, shadow `0 6px 20px rgba(0,0,0,.25)`.
Two segments `<span data-k=fly>御空</span><span data-k=map>收图</span>`: brush 19px, line-height 1, padding 9/14/8, radius 9, letter-spacing .1em,
color --chrome-dim; `.on` → bg `#1c302c`, color `#ebe5d4`, `inset 0 0 0 1px rgba(160,200,190,.18)`; transition bg/color .3s. Hover lights non-on segment text.
Click → `toggleMap()` (L14543). `.on` follows the *destination* mode at transition start (L14323). aria-label "切换舆图与飞行".

### 1.5 Intro & skip & loading

**#intro** (L50–54, DOM L224): fixed full-screen, flex top-left, padding `max(9vh,64px) 0 0 max(12vw,24px)`; ≤640px: centred horizontally, padding-top 96px.
`.t` row gap 18, opacity 0 → 1 (CSS transition 1.2s), content:
- `.seal` "人界" 34×34, 14px, line-height 13px, margin-top 6.
- `b` "云梦山": brush `clamp(56px, 9vw, 96px)`, vertical-rl, letter-spacing .18em, shadow `0 0 18px #f6f0e0`.
- `span` "凡人修仙传 · 溪国西部灵脉": vertical-rl, 15px, letter-spacing .42em, --ink-soft, margin-top 18.

**#skip** (L55, DOM L225) "点击或按任意键跳过": bottom 20px centred, 12px, letter-spacing .3em, --ink-soft, opacity .85, pointer-events none. Set to 0 by finishIntro.

**#loading** (L190–193, DOM L222): fixed right 16, top 70, z 31, row gap 8, 12px, letter-spacing .2em, --ink-soft; opacity 0 → `.on` .9 (transition .6s).
Spinner `i`: 14×14 circle, border 2px `rgba(63,155,134,.25)`, top colour --jade, `spin 1s linear infinite`. Label text sequence in boot: "展卷中 N%" (world gen progress) → "运模型" (waiting on asset pack) → removed.

### 1.6 Flight hotspots `#hot` (L180–186, built L14267–14279)

Each hotspot POI → `<div class="lb lb-sect hs [hs-minor]"><span class=tag>NAME</span><span class=pin></span><em>按 E 落脚</em></div>`.
- `.lb` absolute at 0,0, positioned via `transform: translate3d(x,y,0) translate(-50%,-100%)` (anchor = bottom-centre at the projected point).
- `.lb-sect` column flex centred. `.tag`: vertical-rl, bg `#57799e`, text `#f4f6f8`, 700 14px, letter-spacing .2em, padding 8/3/6, radius 3,
  shadow `0 0 0 1px #83a3c4, 0 3px 10px rgba(0,0,0,.35)`; hover/sel bg `#6a90b8` (L71). `.pin`: 7×7 white dot with 2px `#2d4560` border, margin-top 3; hover/sel bg #6fe0c0.
- `.hs-minor` (non-sect hotspots) tag bg `#5d7a72`, ring `#87a59c`.
- `.near` → tag bg `#3f9b86`, shadow `0 0 0 1px #6fe0c0, 0 0 14px rgba(111,224,192,.55), 0 3px 10px rgba(0,0,0,.35)`; transitions .3s.
- `em` prompt "按 E 落脚": below the pin (top 100%, margin-top 14, centred), 12px, letter-spacing .15em, `#f4fffb` on `rgba(17,31,29,.82)`, border 1px `rgba(111,224,192,.45)`, pill radius, padding 3×10, opacity 0 → 1 when `.near`.
- Click → `openCard(p)`.
Hotspot POIs (`hotspot:true`, L565–635): 古剑门, 落云宗, 百巧院, 鸾鸣宗, 倪航斋, 水影宗 (sect, blue); 云梦山, 天柱山, 灵眼之树, 韵州城, 封日城, 七灵岛, 大漩涡 (`hs-minor`).

### 1.7 舆图 chrome `#map` (DOM L229–256)

Container fixed inset 0, z 10, opacity transition .7s. Children in DOM order: `#plate`, `svg#riverSvg`, `#labels`, `svg#trailSvg`, `#mtitle`, `#mtop`, `#mlegend`, `#mzoom`.

**#plate** (L62–65): absolute box positioned each frame over the projected world rect (updatePlate L14373–14380). Its huge
`box-shadow: 0 0 0 200vmax rgba(11,22,24,.94)` darkens **everything outside the world rect** to near-black teal, plus `inset 0 0 60px rgba(8,16,18,.55)`
inner vignette, border 1px `rgba(214,180,110,.35)`, outline 1px `rgba(214,180,110,.55)` offset 6px (gold double frame). Four corner brackets `.c` 18×18
with 2px `rgba(214,180,110,.7)` border on two sides, placed at −12px outside each corner.

**#riverSvg** (L84): path style stroke `#4f8797`, round caps, opacity .9 – **no JS writes it** in scope (rivers are painted into the map shader instead).

**#labels** (L61, built L14357–14372): one `.lb` per POI, class `lb-{cat}` (+ `lb-minor` for MINOR ids). Styles L66–82, L143–146, L187–189:
| cat | markup | style |
|---|---|---|
| sect | tag + pin (as hotspot) | anchor bottom-centre (−50%,−100%) |
| mount | `<i>△</i>name` | 600 13px `#efe7d2`, text-shadow `0 0 3px #1b2523 ×2, 0 0 6px rgba(20,30,28,.9)`, row gap 4, icon 11px |
| secret | `<i>✦</i>name` | same, colour `#f2d58a` |
| city | `<i>◆</i>name` | same, colour `#e9e2cc` |
| feat | `<i>·</i>name` | 400 12px `#9ccbd0` (note: `.lb-feat i` gets no size rule) |
| region | text | 900 22px `#f7f2e4`, letter-spacing .12em, shadow `0 0 2px #1d2725, 0 0 4px #1d2725, 0 0 10px rgba(20,30,28,.8)` |
| state | text | 14px `#d8d1bf`, letter-spacing .1em |
| alliance | text | serif 700 34px, letter-spacing .9em, `rgba(28,40,38,.55)`, cursor default |
| sea | text | serif 600 34px, letter-spacing 1em, `rgba(186,214,214,.55)` |
| edge | text | 12px --chrome-dim, letter-spacing .1em (no base POI has cat edge) |
| `.lb-minor` | | opacity .9 |
All non-sect anchor centre (−50%,−50%). `.hide` = display none. Click → `selectPoi(p, true)`.

Player marker `ME` (`.lb-me`, L143–145 overridden by L187–189): column, gap 4; `i` = 12×12 jade-hi dot with
`box-shadow:0 0 0 3px rgba(63,155,134,.35), 0 0 14px 4px rgba(111,224,192,.7)` and `mepulse` 2.2s ease-in-out infinite
(0/100%: ring 3px .35 + glow 10px 3px .55; 50%: ring 6px .18 + glow 20px 7px .8); `span` "遁光所在" 11px, letter-spacing .2em, jade-hi, dark shadow. pointer-events none.

**#trailSvg** (L85–87): path stroke `#f2d58a` 2.2px, dash 7 6, drop-shadow `0 0 3px rgba(0,0,0,.6)`; circles r=5 fill `#f2d58a`, stroke `#2b2416` 1.5;
text serif 700 12px fill `#f6e7bd`, stroke `#1b2220` 3px painted under (paint-order stroke). Text at `y+21`, centred: "①/②/③ + label".
TRAIL (L641): ① 入落云宗 (luoyun) → ② 试剑大会 (lingyan) → ③ 子母峰洞府 (zimu).

**.chrome** base (L88): absolute, bg `rgba(17,31,29,.9)`, border 1px `rgba(120,160,150,.22)`, radius 12, text `#ebe5d4`, backdrop blur 8, shadow `0 8px 24px rgba(0,0,0,.28)`.

**#mtitle** (L112–114) top 20 centred, no chrome bg/border/shadow, pointer-events none: `b` "溪国 · 云梦山舆图" brush 30px shadow `0 0 8px rgba(10,20,18,.9)`;
`span` "天南 · 天道盟" 12px letter-spacing .4em --chrome-dim. Hidden ≤640px.

**#mtop** (L89–90) top-left 16/16 (≤640px: top 70px so it clears #modeSwitch), row gap 10:
- `.seal` "人界" 46×46, 19px, line-height 18, radius 7.
- `#search.chrome` (L91–95): height 46, width `min(360px, 100vw−210px)` (≤640px: `100vw−98px`), padding 0 12, row gap 8. Magnifier SVG 18×18 (circle r6.5 at 10.5,10.5 + line 15.5→21, stroke 2, opacity .85),
  `input#q` type search, transparent, serif 15px, placeholder "搜索地名，如 落云宗" (colour --chrome-dim), `kbd` "/" 12px with 1px line border radius 4 padding 1×6 (hidden ≤640px).
- `#results.chrome` (L96–100): absolute below search (top 52, left/right 0), padding 6, column gap 2, hidden unless `.show`. Buttons: flex space-between, radius 8, padding 8×10, 14px, `<small>` type in --chrome-dim; hover/`.act` bg `#1c302c`.

**#mlegend** (L101–108) bottom-left 16/16, transparent wrapper, row gap 10, wraps. Two `.grp` pills (padding 4, gap 2, chrome bg/border/radius 12, blur 8):
- grp 1: `#btnTrail` `⋰ 韩立行迹` aria-pressed false.
- grp 2 `#legend`: `[sect-bar] 宗门` · `◆ 城池` · `✦ 秘境` · `△ 山川` · `[force-swatch] 势力` (data-cat sect/city/secret/mount/force), aria-pressed true.
- Buttons: radius 8, padding 8×12 (≤640: 7×8, 13px), 15px, gap 7; hover bg --chrome-2; `aria-pressed=false` → opacity .42.
- `.ico` 12px wide; `.ico.sect` 6×15 bar `#57799e` radius 2; `.ico.force` 13×10 radius 2 diagonal split `linear-gradient(135deg,#c75b4a 50%,#d9a34c 50%)`.
- ≤640px: the first group's text label span is hidden (`#mlegend .grp:first-child button span{display:none}` – note this hides *both* spans incl. the ⋰ icon span).

**#mzoom** (L109–111) bottom-right 16/16, column, padding 4 gap 2: three 40×40 buttons radius 8 20px: `+` (#zin 放大), `−` (#zout 缩小), `⌂` (#zhome 归位, 15px).

**#unroll** (L115, DOM L262) "舆图展开中": fixed centre, z 12, brush 22px, letter-spacing .5em, chrome-text, shadow `0 0 12px rgba(10,20,18,.9)`, opacity transition .4s.

### 1.8 Info card `#panel` (L116–138, L178, DOM L257–261)

`aside.chrome.live#panel`, fixed, z 22, top 78 / right 16 / bottom 16, width `min(420px, 100vw−32px)`, column flex.
Closed: `transform:translateX(24px); opacity:0; pointer-events:none`; `.open`: none / 1 / auto; transition transform .35s, opacity .35s. ≤640px: `top:auto; height:62vh` (bottom sheet).
- `.close` #pclose "×": absolute top 14 right 14, 32×32, radius 8, 22px dim; hover bg --chrome-2.
- `.scroll` #pbody: overflow-y auto, padding 22/24/12, flex 1.
- footer: row gap 10, padding 14/24/18, top border --chrome-line. Buttons radius 9, padding 8×14, 14px, border --chrome-line, bg `rgba(255,255,255,.03)`; `.go` (#pgo "御空前往") bg/border `#3f9b86`, text `#f4fffb`; #pcopy "复制地名" (→ "已复制" for 1.4 s). Hover `brightness(1.12)`.
Body template (fillCard L14414–14425):
```
.meta  (13px dim, row gap 10): <span>{type}</span> [<span.pill>{ally}</span>]     pill: 1px rgba(160,200,190,.35) border, 999px radius, 2×10, 12px, ::before 6px jade-hi dot
h2     {name minus ' ↗'}       brush 44px, line-height 1.15, margin 10 0 2
.crumb {crumb}                 13px dim
.lead  {lead}                  17px/1.75, 600, margin 18 0 10
p×N    {body[i]}               15px/1.85 #d9d4c6, mb 12
[if note] .sub "图中所绘"  [img.pic BASE.cards[id] – width 100%, radius 8, ring rgba(255,255,255,.06)]  .q {note}
         .sub: 13px dim, letter-spacing .2em, margin 18 0 10, followed by a 1px flex line (::after)
         .q: left border 2px jade, bg rgba(255,255,255,.04), padding 10×14, radius 0 8 8 0, 14px/1.8 #cfd6d2
[if chips] .sub "境内"  .chips (wrap gap 8): buttons bg rgba(255,255,255,.04), border line, 999px radius, padding 5×12, 14px → selectPoi(POI_BY[name], true)
```

### 1.9 Touch controls (L139–141, L202, input L14561–14575)

- `#pad`: left 26 / bottom 26, 116×116 circle, bg `rgba(246,240,224,.35)`, border 1px `rgba(60,50,30,.25)`. Knob `i` 46×46 centred, bg `rgba(63,155,134,.55)`, border 1px `rgba(255,255,255,.6)`.
  Knob travel radius m = 46 px; `TOUCH.mx = dx/46`, `TOUCH.mz = −dy/46` (up = forward). Release recentres.
- `#boostBtn` "疾": right 26 / bottom 64, 70×70 circle, bg `rgba(63,155,134,.45)`, white brush 22px; hold → `TOUCH.boost = true`.
- Both `display:block` only `@media (pointer:coarse)`, which also hides `#hint`.

### 1.10 Toast (L148–149, toast() ~L14873)

Created lazily; fixed top 18 centred, z 30, chrome bg/border, radius 10, padding 8×14, 13px, letter-spacing .06em; hidden state `translate(-50%,-8px)` opacity 0;
`.on` slides to 0 with opacity 1 (transition .4s). Auto-hides after 3.4 s. Only message: `帧率偏低（{avg}），渲染倍率降到 ×{ratio}`.

### 1.11 Debug panel `#dbg` (CSS L151–168, L194–199; JS L14619–14830)

Fixed top 78 / left 16, z 25, width `min(330px, 100vw−32px)`, max-height `100vh−110px`, overflow auto, chrome style, 13px, display none → `.on` block.
- sticky header (bg `#13221f`, bottom border, padding 12/14/8): `b` "调试面板" brush 20px; buttons "恢复默认" (reset) and "×" (close) – 1px line border, radius 7, padding 3×9, 12px.
- `.grp` padding 8/14/4; `.gt` group titles 11px letter-spacing .3em dim.
- `label` = 3-col grid `84px 1fr 60px` gap 8: name (`#d9d4c6`), `<input type=range>` (accent jade) or `<input type=color>` (100%×22), `<output>` right-aligned, jade-hi 12px tabular.
- 工具 group: `.row` buttons "打点模式" (toggle, `.on` = jade), "导出参数", "复制"; select "打点记到" (`#dbgPickTo`, options: （只看坐标） + every POI except region/state/alliance/sea); `textarea#dbgOut` 96px tall, bg `#0d1917`, text `#cfe`, mono 11px/1.45.
- After the sliders: "宗门间飞行时间（中空）" table `#dbgTravel` (row: `A ↔ B | d 丈 | t 息 | 疾 t 息`), then `.stats` `#dbgStats` (11px, 1.7 line height).
Full slider list in §6.3.

### 1.12 Responsive rules summary

- `@media (pointer:coarse)` (L202): show #pad and #boostBtn, hide #hint.
- `@media (max-width:640px)` (L203): intro centred (padding-top 96); #mtop top 70; #search width `100vw−98px`; #mtitle hidden; brand subtitle hidden; banner b 34px; search kbd hidden; legend buttons 7×8 13px; first legend group's text hidden; #panel bottom sheet height 62vh.
- `@media (prefers-reduced-motion:reduce)` (L204): no transitions on #map, #panel, .hud; JS also skips the intro to `duration − 0.3` (L14599).

### 1.13 Godot mapping: UI node tree

Root scene `Main.tscn`:
```
Main (Node3D)
├─ World (Node3D)                         # terrain, water, props… all using the shared "map_k" global shader uniform (see §4)
├─ MapPlane (MeshInstance3D)               # PlaneMesh, shader map2d.gdshader (§5)
├─ Camera3D                                # driven by FlightController / MapController
├─ PostFX (CanvasLayer layer=0 or a CompositorEffect)   # tilt-shift, grade, edge ink (from other sections)
├─ Overlay (CanvasLayer layer=1)           # non-interactive screen overlays
│  ├─ Silk (TextureRect, stretch tile, material blend_mul, modulate.a driven)
│  └─ Vignette (ColorRect + radial gradient shader)
├─ Hotspots (CanvasLayer layer=4)          # Control (full rect, mouse_filter IGNORE) with HotspotTag instances
├─ Hud (CanvasLayer layer=5)
│  ├─ Brand (HBoxContainer, anchor TL, offset 16,16, separation 10) → Seal(PanelContainer) + VBox(Label brush26, Label serif12)
│  ├─ Banner (VBoxContainer, anchor top-centre, y=70) → Label(brush44) + Label(13, spacing) + ColorRect(44×2 #b8392a, a .8)
│  ├─ Hint (PanelContainer, anchor BL) → GridContainer(columns=2, h_sep 12, v_sep 4) of KeyCap/Label
│  └─ Readout (VBoxContainer, anchor BR, alignment end) → HBox(Label brush18 roAlt, Label roAltL) + Label roSpd
├─ Touch (CanvasLayer layer=6)             # VirtualStick (Control 116×116) + BoostButton (TouchScreenButton or Button 70×70)
├─ MapChrome (CanvasLayer layer=10)        # whole layer's modulate.a tweened 0↔1 over 0.7 s; mouse_filter IGNORE when hidden
│  ├─ Plate (Control, custom _draw: 4 big dark rects around rect + gold frames + corner brackets)
│  ├─ Labels (Control) → MapLabel instances + MeMarker
│  ├─ Trail (Control, custom _draw: dashed polyline, circles, outlined text)
│  ├─ MTitle (VBox, top-centre y=20)
│  ├─ MTop (HBox TL 16,16) → Seal 46 + Search(PanelContainer h46) → HBox[TextureRect icon, LineEdit q, Label "/"] ; Results (PanelContainer + VBox of Buttons), positioned y+52
│  ├─ MLegend (HBoxContainer BL, separation 10) → 2 × PanelContainer(HBox of toggle Buttons)
│  └─ MZoom (PanelContainer BR) → VBox of 3 Buttons 40×40
├─ Unroll (CanvasLayer 12) → Label centred brush 22, spacing .5em
├─ Intro (CanvasLayer 15) → MarginContainer(top max(9vh,64), left max(12vw,24)) → HBox(sep 18)[Seal34, VerticalLabel brush clamp(56..96), VerticalLabel 15]
├─ Skip (CanvasLayer 16) → Label bottom-centre
├─ ModeSwitch (CanvasLayer 20) → PanelContainer TR → HBox(sep 2)[Button 御空, Button 收图] (ButtonGroup, toggle_mode)
├─ InfoCard (CanvasLayer 22) → PanelContainer (anchor right, top 78, bottom 16, width min(420, w−32)) → VBox[ScrollContainer→VBox body, HSeparator, HBox footer] + close Button
├─ Debug (CanvasLayer 25) → PanelContainer TL(16,78) → ScrollContainer → VBox of groups (HBox: Label 84 | HSlider | Label 60)
├─ Toast (CanvasLayer 30)
└─ Loading (CanvasLayer 31)
```
Notes:
- **Vertical text** (`writing-mode:vertical-rl`): Godot `Label` has no vertical mode. Either insert `"\n"` between characters (`"云\n梦"`) with `horizontal_alignment = CENTER`
  and tune `theme_override_constants/line_spacing` to reproduce letter-spacing (e.g. 14px font × .2em → line_spacing ≈ 3), or use a RichTextLabel per char. Two-char seals: "云\n梦", "人\n界".
- **letter-spacing**: Godot 4 `FontVariation.spacing_glyph` (px) = em × font size (e.g. 13px × .3em ≈ 4 px).
- **text-shadow glows** (`0 0 8px #f6f0e0`): `Label.label_settings` with `shadow_size = 8, shadow_color = #f6f0e0, shadow_offset = (0,0)` (Godot shadow is blurred when shadow_size > 0 in 4.x LabelSettings, use outline_size for the hard dark 3px halos on map labels: `outline_size = 3, outline_color = #1b2523`).
- **backdrop-filter blur**: a `ColorRect` behind the panel with a `hint_screen_texture` + `textureLod` blur shader, or skip (fill alpha .9 already dominates).
- **Fonts**: download `MaShanZheng-Regular.ttf` and `NotoSerifSC-{Regular,SemiBold,Bold,Black}.otf` (or the variable `NotoSerifSC[wght].ttf` and use FontVariation `variation_opentype = {"wght": 600}`).
  Theme default font = Noto Serif SC Regular 14 px; a `FontVariation` "Brush" = Ma Shan Zheng; fallbacks: add system KaiTi/SimSun via `SystemFont` as fallbacks.

Theme (`ui_theme.tres`) StyleBoxFlat values:
```
Chrome panel  : bg_color=Color(0.067,0.122,0.114,0.9)  border_width=1  border_color=Color(0.471,0.627,0.588,0.22)  corner_radius=12  shadow_color=Color(0,0,0,.28) shadow_size=12 shadow_offset=(0,8)
Chrome hover  : bg_color=#1c302c corner_radius=8
Seal          : bg_color=#b8392a corner_radius=6 (40) / 7 (46);  border inset ring: border_width=2 border_color=Color(1,.925,.863,.35) (draw_center true, border inside)
Sect tag      : bg_color=#57799e corner_radius=3 border_width=1 border_color=#83a3c4 shadow_size=5 shadow_offset=(0,3) shadow_color=Color(0,0,0,.35)  content_margin t8 l3 r3 b6
Sect tag near : bg_color=#3f9b86 border_color=#6fe0c0 shadow_color=Color(.435,.878,.753,.55) shadow_size=14
Sect tag minor: bg_color=#5d7a72 border_color=#87a59c
Hint panel    : bg_color=Color(.965,.941,.878,.72) border 1 Color(.314,.259,.173,.18) radius 10 content_margin 14/10
KeyCap        : bg Color(.149,.137,.122,.08) border 1 (bottom 2) Color(.149,.137,.122,.2) radius 5 content_margin_h 5
Go button     : bg #3f9b86 border #3f9b86 radius 9 font_color #f4fffb
Footer button : bg Color(1,1,1,.03) border 1 chrome-line radius 9 content_margin 14/8
Chip          : bg Color(1,1,1,.04) border 1 chrome-line radius 999 content_margin 12/5
Pill          : bg transparent border 1 Color(.627,.784,.745,.35) radius 999 content_margin 10/2
Quote (.q)    : bg Color(1,1,1,.04) border_width_left=2 border_color=#3f9b86 corner_radius tl0 bl0 tr8 br8 content_margin 14/10
Toast         : chrome, radius 10, content_margin 14/8
Debug header  : bg #13221f border_width_bottom 1
Touch pad     : bg Color(.965,.941,.878,.35) border 1 Color(.235,.196,.118,.25) radius 58 (circle)
Knob          : bg Color(.247,.608,.525,.55) border 1 Color(1,1,1,.6) radius 23
Boost         : bg Color(.247,.608,.525,.45) border 1 Color(.235,.196,.118,.25) radius 35
Focus         : StyleBoxFlat draw_center=false border 2 #6fe0c0 expand_margin 2
```

---------------------------------------------------------------------------------------------------------------------------------

## 2. State machine

### 2.1 State variables (L14080–14095)

```
APP    = { t, dt, last, freeCam:false, ready:false, zoomBy }
PLAYER = { pos:V3 (ground point under the light, y=0), vel:V3, A (altitude, smoothed), At (altitude target), boostK, light:V3,
           drag:null|{grab,last,v}, boosting, clear (smoothed ground clearance), dunK, flare, lastBoost }
CAMERA_RIG = { target:V3 (ground point the camera frames), Aeff (camera altitude, ≥ A) }
KEYS[code] = bool;  TOUCH = { mx, mz, boost }
ST = { mode:'loading', t, skipping, trans, transDur:2.4, from:{pos,quat,fov}, lastBanner, bannerT, hintT:18, near, mapCooldown }
MAP = { cx, cz, view, fov:20, sel, trail:false, hidden:Set, goal:null|{cx,cz,view} }
CARD = { open, poi, fromFlight }   (L14412)
```

### 2.2 Modes

`ST.mode ∈ { 'loading', 'intro', 'flight', 'toMap', 'map', 'toFlight' }`. Dispatch in `updateApp` (L14602–14611):
```
intro → updateIntro; flight → updateFlight; toMap|toFlight → updateTransition; map → updateMap
if mode != flight: #hot opacity 0
MAP2D.mesh.visible = uMap > 0.001
every SANDBOX mesh.visible = uMap < 0.999          (SANDBOX list L14613–14617: land chunks, plains, banks, water, props, trees, falls, formations, sect meshes/domes/isles, glow pts, roads, streams, settlements, lore, city)
```

```
 loading ──boot() done──► intro ──t ≥ 4.6 s (or skip ×4 speed)──► flight
   ▲ any key: skipIntro                         │          ▲
                                                │ M / modeSwitch / At > 11000 (cooldown ≤ 0)
                                                ▼          │ 2.0 s
                                              toMap ──2.4 s──► map ──M / Esc / modeSwitch / 御空前往 / wheel-in past minView──► toFlight
 intro: any key (M too) → skipIntro (×4); only the 收图 button → finishIntro() then startTransition('map')   (keydown L14527, toggleMap L14307)
```
Transitions:
- `toggleMap()` (L14306–14310): intro → finishIntro + map; flight → map; map → set `PLAYER.At = PLAYER.A = min(A, mapAt×0.8 = 8800)` then flight. (Ignored in toMap/toFlight/loading.)
- `startTransition(to)` (L14311–14324): snapshot camera pose into `ST.from`; `trans = 0`; duration 2.4 s (map) / 2.0 s (flight).
  - to map: `MAP.goal = null`; hide HUD (brand/readout/hint opacity 0); zero velocity; hide banner; `MAP.cx = PLAYER.pos.x`, `MAP.cz = PLAYER.pos.z − 0.15·A`, `MAP.view = clamp(1.15·A, 2400, 42000)`; close the card if it was opened in flight.
  - to flight: remove `#map.on` (chrome fades out over .7 s immediately), close card, `CAMERA_RIG.target = PLAYER.pos`, `Aeff = A`, `ST.mapCooldown = 1.2` s (prevents instantly re-triggering the auto map at high altitude).
  - mode switch highlight updated.
- End of transition (L14339): mode = map / flight; entering flight calls `setHud(true)`.

### 2.3 Intro (L14140–14178)

`introSetup()`: `uFocus = startPos`; `uIntroScale = 9000·S` (≈ 22 236); three wash seeds `(x, z, radius, delay)`: 落云宗 (2600·S, 0.0), start (3600·S, 0.1), 灵眼之树 (2400·S, 0.2) — consumed by `GLSL_INTRO` (L4255–4276): ink lines spread radially from uFocus as `uInk` rises, tones 0.18 behind; colour blooms from the seeds with noisy wet fronts as `uWash` rises (darkened fringe at the front).

`updateIntro(dt)`: `ST.t += dt × (skipping ? 4 : 1)`; with t:
```
uInk     = smoothstep(0.05, 1.35, t)
uWash    = smoothstep(1.0, 3.05, t)
uCloudIn = smoothstep(2.7, 3.8, t)
k        = easeInOut(clamp(t / 4.6, 0, 1))
A = At   = exp(lerp(ln 2700, ln 1650, k))          // camera descends from 2700 to 1650 丈
Aeff     = A
target   = (pos.x, 0, pos.z − 0.25·A·(1−k))         // starts framing a bit north, settles on the player
camera   = flightPose()
li       = smoothstep(3.35, 4.55, t)                 // the light flies in
from     = pos + (−1.3A, lightHeight·A·1.8 (y), +0.9A)   // lower-left, behind
to       = lightPos()
p        = lerp(from, to, easeOut(li)); p.y += sin(easeOut(li)·π)·0.12A   // arc
vel      = (to − from)·1.2·(1 − e) while li < 1 (horizontal only)  → feeds the light's trail
#intro .t opacity = (0.15 < t < 3.3) ? 1 : 0 (CSS 1.2 s fade)
t ≥ 4.6 → finishIntro(); setHud(true)
```
`finishIntro()`: mode flight, all three reveal uniforms = 1, #skip opacity 0, #intro display none, A = At = 1650, target = pos, pose applied.
During boot the title is forced visible (L14897) while the world generates. `?skip` in URL or reduced-motion → `ST.t = 4.3` (L14599).
Skip triggers: canvas pointerdown, wheel, any keydown in intro/loading, touch pad press.

### 2.4 Banner (updateBanner L14253–14263)

Each flight frame: nearest POI with a `banner` radius whose horizontal distance `d < p.banner` (radii 900–1800 丈, see L565–635). On a new id: set text (name, sub), `bannerT = 4.2`.
Leaving: lastBanner cleared once `d > 1.25·banner` (hysteresis), so re-entering shows it again.
`opacity = clamp(min(bannerT, 4.2 − bannerT) × 1.5, 0, 1)` → 0.667 s fade-in, ~2.87 s hold, 0.667 s fade-out. Reset to 0 when going to the map.

### 2.5 Hotspots & E-to-land (L14281–14302, L14433–14440, L14536)

```
show = mode=='flight' ? 1 − smoothstep(0.85·4200, 4200, A) : 0          // fades out between 3570 and 4200 丈
#hot.opacity = show
near = the hotspot POI with min horizontal distance < 700 丈 → ST.near
for each: screen = project(pos.x, (labelY||60)·(1−uMap), pos.z)          // labelY = top of that place's tallest model + 30 (L6802)
   hidden if behind (ndc.z>1), x<−80, x>w+80, y<−120, y>h+60, or show<0.02
   class 'near' on the near one; transform translate(x,y) translate(−50%,−100%)
auto-close: if CARD.open && CARD.fromFlight && dist(player, card poi) > 2.4·700 = 1680 → closePanel()
```
`E` (only in flight with ST.near): toggles card for that POI (close if same POI open, else `openCard`). Clicking a hotspot tag also calls `openCard` (flight only).
`openCard(p)`: `CARD.fromFlight = true`, `MAP.sel = p`, fillCard, hide "御空前往" (`#pgo.hidden = true`), **velocity × 0.25** (brakes).

### 2.6 Info card in map; 御空前往; copy

`selectPoi(p, center)` (L14426–14431): `MAP.sel = p`, fromFlight false, fillCard, `#pgo.hidden = !canFly(p)` (canFly: not mapOnly and cat ∉ {region, state, alliance, sea, edge}).
If center and in map: `MAP.goal = { cx: p.x, cz: p.z, view: min(MAP.view, (region/sea/alliance/edge ? 5200 : 2600)·S) }` – only zooms in, never out.
`closePanel()` clears open/sel/poi/fromFlight. Close via ×, Esc, or flight auto-close.
`flyTo(p)` (御空前往, L14442–14447): `PLAYER.pos = (p.x, 0, p.z + 320)` (320 丈 south so the place is in view to the north), vel 0, `A = At = 1650`, banner reset, reset light trail (`DG.reset()`), dunK/flare 0, `startTransition('flight')`.
"复制地名": clipboard ← name minus " ↗"; button text "已复制" 1.4 s.

### 2.7 Search (L14449–14456, keys L14528–14538)

- `/` in map mode focuses `#q`.
- On `input`: trimmed query q; `POIS.filter(name.includes(q) || crumb.includes(q) || lead.includes(q)).slice(0, 8)` (plain substring, case-sensitive, Chinese).
  Results: `<button>{name}<small>{type}</small></button>`; the first has `.act`. Empty → one disabled button `没有找到「q」`.
- Enter (while typing in #q): click the first result. Escape: blur + clear results.
- Clicking a result: `selectPoi(p, true)`, clear input, hide list. Any canvas pointerdown hides the list.
- While any INPUT/SELECT/TEXTAREA is focused, flight keys are ignored (L14182, L14525).

### 2.8 Legend filters & trail & zoom (L14552–14559)

- Legend button toggles `aria-pressed`; pressed=false adds its cat to `MAP.hidden`. Label hidden iff `MAP.hidden.has(LEGEND_OF[cat])`.
  `LEGEND_OF` (L638): sect→sect, city→city, secret→secret, mount→mount, **feat→mount**, region/state/alliance/sea/edge→**force**.
- `#btnTrail` toggles `MAP.trail`; trail drawn only when `MAP.trail && uMap > 0.6`.
- `#zin` / `#zout`: `MAP.goal = {cx, cz, view: clamp(view ÷/× 1.5, 2400, 42000)}`. `#zhome`: goal = MAP_HOME.
- Minor labels (MINOR ids: tingyun, feilian, guxiu, sunshi, yingxian, dimai) hidden when `MAP.view > 3400·S ≈ 8400`.

### 2.9 Input mapping (setupInput L14465–14576)

| input | flight | map | intro/loading |
|---|---|---|---|
| W/↑, S/↓ | forward (north) / back | – | skip |
| A/←, D/→ | west / east | – | skip |
| Space / Q | climb / descend (log-rate 0.95/s) | – | skip |
| Shift (L/R) | boost ×3 (only while moving) | – | skip |
| wheel | `At *= exp(deltaY·0.0013)` (down = higher) | `view *= f`, or drop to flight if zooming in at minView | skip + (applies) |
| drag (1 pointer) | grab-the-ground pan with fling | pan: `cx −= dx·wpp`, `cz −= dy·wpp`, wpp = 2·cam.y·tan(fov/2)/innerHeight | skip |
| pinch (2 pointers) | `zoomBy(prevDist/dist)` | same | |
| E | land/toggle card at near hotspot | – | |
| M | to map | to flight | skip (×4), like any key — the 收图 button finishes the intro and opens the map |
| H | toggle hint (hintT = 30 or −1) | (sets hidden) | |
| / | – | focus search | |
| Esc | close card | close card, else back to flight | |
| ` (Backquote) | toggle debug (always, even typing) | same | same |
| window blur | clear all KEYS | | |
Space and arrow keys `preventDefault`. Debug pick mode: left click on canvas → `DEBUG.pickAt` instead of dragging.
Flight drag (L14474–14507): pointerdown raycasts the y=0 plane → `drag.grab`. Each move: new hit g; `d = g − grab`; `pos −= d; target −= d`; re-pose camera, re-raycast to update grab
(ground point stays under the finger). Velocity estimate `v = −d / dtt` (dtt = ms since last move, ≥1 ms). On release: if last move was < 90 ms ago `vel = v × fling (0.85)` else 0. While dragging, keyboard velocity integration and glide decay are suspended (`!PLAYER.drag`).
Note the drag plane is y=0, not the terrain – panning speed matches the ground at sea level.
Map-mode wheel-in drop (L14515–14519): if `f < 1 && view ≤ 2400·1.01`: `pos = (cx, 0, cz + 288)`, vel 0, `A = At = clamp(3840, 950, 8800) = 3840`, `startTransition('flight')`.

### 2.10 Godot mapping: state machine

```gdscript
# game_state.gd (autoload)
enum Mode { LOADING, INTRO, FLIGHT, TO_MAP, MAP, TO_FLIGHT }
signal mode_changed(mode)
signal near_changed(poi)          # for hotspot highlight + E prompt
signal card_requested(poi, from_flight)
signal banner(poi)
var mode := Mode.LOADING
var map_k := 0.0:                 # == uMap
	set(v): map_k = v; RenderingServer.global_shader_parameter_set("map_k", v)

func _process(dt):
	dt = min(dt, 0.05)
	match mode:
		Mode.INTRO: intro.update(dt)
		Mode.FLIGHT: flight.update(dt)
		Mode.TO_MAP, Mode.TO_FLIGHT: transition.update(dt)
		Mode.MAP: map_ctl.update(dt)
	map_plane.visible = map_k > 0.001
	world.visible = map_k < 0.999
```
Use `_unhandled_input` for keys so focused `LineEdit`/sliders swallow them (mirrors the "typing" check); handle `ui_cancel` (Esc) and `/` there.
Use `Input.is_physical_key_pressed` / InputMap actions: `fly_fwd (W, Up)`, `fly_back (S, Down)`, `fly_left (A, Left)`, `fly_right (D, Right)`, `climb (Space)`, `descend (Q)`, `boost (Shift)`, `land (E)`, `map (M)`, `hint (H)`, `debug (QuoteLeft)`, `search (Slash)`.
Clear held state on `NOTIFICATION_APPLICATION_FOCUS_OUT`.

---------------------------------------------------------------------------------------------------------------------------------

## 3. Flight model (updateFlight L14181–14236)

### 3.1 Altitude = zoom

"Altitude" A is the camera height; everything scales with it ("高处飞得快、低处飞得细，屏幕上的快慢不变" L403): speed ∝ A, light height ∝ A, so on-screen speed is constant.
```
u = (Space) − (Q)
if u: At *= exp(u · 0.95 · dt)                         // ≈ ×2.59 per second
(wheel: At *= exp(deltaY · 0.0013); pinch: At *= prev/cur)
if At > 11000 and mapCooldown ≤ 0: At = 11000; startTransition('map'); return
At = clamp(At, 950 /*minAltitude = zoom.low*/, 11000·1.02)
A  = exp(lerp(ln A, ln At, 1 − exp(−dt / 0.28)))      // log-space smoothing, τ = zoom.ease
mapCooldown −= dt
```
Band label (bandName L14105): `A < 1300` 低空; `A < 4825` 中空; else 高空.

### 3.2 Horizontal motion

```
f = clamp((W|↑) − (S|↓) + TOUCH.mz, −1, 1)
s = clamp((D|→) − (A|←) + TOUCH.mx, −1, 1)
boost = Shift || TOUCH.boost
cruise = 0.12 · A · (boost ? 3.0 : 1)                  // 198 丈/s at A = 1650, 594 boosted
w = (s, −f)  (x east, z: forward = −z = north); if |w| > 1: normalise
if |w| > 0.01:  k = 1 − exp(−dt / 0.5);  vel += (w·cruise − vel)·k          // first-order approach, τ = accel 0.5 s
elif !drag:     vel *= exp(−dt / 1.25)                                       // glide: exponential decay τ = 1.25 s (coasts ≈ v·1.25 丈)
if !drag:       pos += vel·dt
```
No yaw: W is always north; the camera never rotates (see 3.5).
World edge (L14203–14207): margin m = 900; soft box `[x0+900, x1−900] × [z0+1620, z1−900]` (north margin 1.8 m). Outside: `pos += overshoot · min(1, 3·dt)` and that axis's `vel *= 0.9` per frame; then hard clamp to the rect.

### 3.3 Boost, escape light state

```
boosting = boost && |w| > 0.01
boostK  = lerp(boostK, boosting, 1 − exp(−2.5 dt))
flare   = 1 on the rising edge of boosting; flare −= dt/0.4 (≥0)
dunK    = lerp(dunK, boosting, 1 − exp(−dt / (boosting ? 0.22 : 0.55)))
DG.update(dt, lightPos, vel, camera, A, boost, FIG ? dunK + 0.7·flare : 1, 1)     // FIG null (figure.on=false) → light always fully lit
```

### 3.4 Terrain clearance of the light (not the player)

The player has no collision body; only the light's height and the camera react to terrain.
```
groundClear(x,z,vx,vz) = relief · max over samples hAt(x+ox, z+oz) for offsets
     (0,0) (±90,0) (0,±90) (0.6v) (1.2v)                 // around and ahead along velocity (L14124)
     plus 天柱山 pillar: if dist < P.r + 260 → max(h, P.h + 190)
updateClearance: want = groundClear(pos, vel)
     clear = want > clear ? lerp(clear, want, 1−exp(−6dt))   // rise fast
                          : lerp(clear, want, 1−exp(−1.2dt)) // sink slowly
lightPos():
     still = 1 − smoothstep(0.05, 0.3, |vel_xz| / max(1, 0.12·A))
     bob   = sin(1.7 t) · A · 0.012 · bob(1.0) · (0.4 + 0.6 still)
     y     = max(0.24·A, clear + 70) + bob
     x     = pos.x + sin(0.9 t) · A · 0.004 · still       // idle sway
     z     = pos.z
```
At A=1650 the light floats at 396 丈 unless the ground (+70) is higher.

### 3.5 Camera: fixed north heading, pitch by altitude

`pitchOf(A)` (L14099–14104), piecewise in log altitude with smoothstep:
```
A ≤ 1650 : lerp(38, 45, smoothstep(ln 950,  ln 1650,  ln A))
A ≤ 8000 : lerp(45, 54, smoothstep(ln 1650, ln 8000,  ln A))
else     : lerp(54, 60, smoothstep(ln 8000, ln 11000, ln A))
```
`flightPose(target, A)` (L14107–14113):
```
p    = radians(pitchOf(A))
lead = 0.1 · A
pos  = (target.x, A, target.z − lead + A / tan p)      // south of the target
quat = Euler(−p, 0, 0, 'YXZ')                          // pitch only, yaw = roll = 0 always
fov  = 40
```
The optical axis hits the ground at `target.z − lead`, i.e. it frames a point 0.1·A north of the target ("look a little past the light, toward the ranges in the north").
Why no rotation: the design treats the land as a painted scroll / map – north stays up in both flight and 舆图 so the two views register 1:1 and the fly↔map transition is a pure pitch-down + rise (L408 comment "镜头：永远朝北，不转向").

Camera rig per frame (L14217–14224):
```
want = max(A · (1 + 0.1·boostK), sightLift(A))
Aeff = want > Aeff ? lerp(Aeff, want, 1−exp(−dt/0.35)) : lerp(Aeff, want, 1−exp(−dt/1.4))     // rise fast, settle slowly
ahead  = (pos.x + vel.x·0.6, 0, pos.z + vel.z·0.6)                                              // look-ahead 0.6 s
target = lerp(target, ahead, 1 − exp(−dt/0.3))                                                  // follow τ = 0.3 s
camera = flightPose(target, Aeff); keepCameraClear()
camera.fov = lerp(fov, 40 + 4·boostK, 1 − exp(−3dt))                                             // FOV kick +4° when boosting
```
`sightLift(A)` (L14238–14247): occlusion avoidance. Let `back = A/tan p − 0.1A` (horizontal distance camera→target), `Ly` = light height. For i = 1..7, t = i/8:
sample `g = groundClear(T.x, T.z + back·t) + 50` (points between target and camera); the sight line height there is `Ly + (A − Ly)·t`; if g exceeds it, `need = max(need, Ly + (g − Ly)/t)` (the camera height that would clear it). Returns `min(need, 2.2A)`.
`keepCameraClear()` (L14249–14252): `camera.y = max(camera.y, groundClear(camera.xz) + 120)`.

### 3.6 Readout & hint timer (L14231–14235)

`roAlt = round(A)`; `roAltL = '丈 · ' + bandName(A)`; `roSpd = '遁速 ' + round(|vel|) + ' 丈/息' + (boosting ? ' · 遁光' : |vel| > 0.12·cruise ? ' · 御空' : ' · 悬停')`.
`hintT −= dt`; at < 0 hint opacity 0.

### 3.7 Godot port (GDScript)

```gdscript
# flight_controller.gd
extends Node
@export var cfg: Resource   # mirrors CONFIG.flight / camera / zoom
var pos := Vector3(); var vel := Vector3()
var A := 1650.0; var At := 1650.0
var boost_k := 0.0; var dun_k := 0.0; var flare := 0.0; var last_boost := false
var clear := 0.0; var map_cooldown := 0.0
var rig_target := Vector3(); var a_eff := 1650.0
var drag := {}   # empty when not dragging
@onready var cam: Camera3D = $"../Camera3D"

func _exp_k(dt, tau): return 1.0 - exp(-dt / max(0.02, tau))

func pitch_of(a: float) -> float:
	var la := log(a)
	if a <= 1650.0: return lerp(38.0, 45.0, smoothstep(log(950.0), log(1650.0), la))
	if a <= 8000.0: return lerp(45.0, 54.0, smoothstep(log(1650.0), log(8000.0), la))
	return lerp(54.0, 60.0, smoothstep(log(8000.0), log(11000.0), la))

func flight_pose(target: Vector3, a: float) -> Transform3D:
	var p := deg_to_rad(pitch_of(a))
	var o := Vector3(target.x, a, target.z - 0.1 * a + a / tan(p))
	return Transform3D(Basis.from_euler(Vector3(-p, 0, 0)), o)   # rotation X only → looks toward -Z (north)

func update(dt: float) -> void:
	var f := clampf(Input.get_axis("fly_back", "fly_fwd") + touch.mz, -1, 1)
	var s := clampf(Input.get_axis("fly_left", "fly_right") + touch.mx, -1, 1)
	var u := Input.get_axis("descend", "climb")
	var boost := Input.is_action_pressed("boost") or touch.boost
	if u != 0.0: At *= exp(u * 0.95 * dt)
	if At > 11000.0 and map_cooldown <= 0.0:
		At = 11000.0; GameState.start_transition(GameState.Mode.MAP); return
	At = clampf(At, 950.0, 11220.0)
	A = exp(lerp(log(A), log(At), 1.0 - exp(-dt / 0.28)))
	map_cooldown -= dt
	var cruise := 0.12 * A * (3.0 if boost else 1.0)
	var w := Vector2(s, -f); if w.length() > 1.0: w = w.normalized()
	if w.length() > 0.01:
		var k := _exp_k(dt, 0.5)
		vel.x += (w.x * cruise - vel.x) * k; vel.z += (w.y * cruise - vel.z) * k
	elif drag.is_empty():
		var g := exp(-dt / 1.25); vel.x *= g; vel.z *= g
	if drag.is_empty(): pos += Vector3(vel.x, 0, vel.z) * dt
	_push_from_edges(dt)
	var boosting := boost and w.length() > 0.01
	boost_k = lerp(boost_k, 1.0 if boosting else 0.0, 1.0 - exp(-2.5 * dt))
	if boosting and not last_boost: flare = 1.0
	last_boost = boosting; flare = max(0.0, flare - dt / 0.4)
	dun_k = lerp(dun_k, 1.0 if boosting else 0.0, _exp_k(dt, 0.22 if boosting else 0.55))
	var want := maxf(A * (1.0 + 0.1 * boost_k), sight_lift(A))
	a_eff = lerp(a_eff, want, _exp_k(dt, 0.35 if want > a_eff else 1.4))
	var ahead := Vector3(pos.x + vel.x * 0.6, 0, pos.z + vel.z * 0.6)
	rig_target = rig_target.lerp(ahead, _exp_k(dt, 0.3))
	cam.global_transform = flight_pose(rig_target, a_eff)
	var floor_y := ground_clear(cam.global_position.x, cam.global_position.z) + 120.0
	if cam.global_position.y < floor_y: cam.global_position.y = floor_y
	cam.fov = lerp(cam.fov, 40.0 + 4.0 * boost_k, 1.0 - exp(-3.0 * dt))
	_update_clearance(dt)
	light.update(dt, light_pos(), vel, A, boosting)
```
Godot `Camera3D.fov` is vertical by default (`keep_aspect = KEEP_HEIGHT`) – same as three.js. Set `near = max(5, y·0.05)`, `far = y·40 + 30000` per frame (L14940).
`hAt(x,z)` should be a CPU heightmap sampler (an `Image` of the terrain heights, bilinear) – same data the terrain mesh uses.

---------------------------------------------------------------------------------------------------------------------------------

## 4. The fly ↔ map transition: one space, flattened

### 4.1 Mechanism

There is **one** scene and **one** camera. The 舆图 is *not* a separate 2D screen; it is:
1. The camera moving from the oblique flight pose to a straight-down, narrow-FOV pose (`mapPose`).
2. A single shared uniform `U.uMap` (0 = sandbox, 1 = map, L482) that every sandbox vertex shader uses to **flatten the world**: `wp.y *= 1.0 − uMap` (terrain L720/L4515/L4684, trees L6244, water `wp.y = −depth·(1−uMap)` L5573, clouds `c.y *= 1 − 0.9·uMap` L12131, etc. — 40+ shaders, see grep of `uMap`). Glows, domes, beams, flyers, life multiply alpha by `(1 − uMap)`. Post effects (tilt-shift `k`, cinema grade, edge ink) are multiplied by `(1 − uMap)` (L13111, L13116, L13127).
3. The painted map plane MAP2D (§5) at y = 1, drawn on top (renderOrder 60, no depth test), whose alpha "seeps in" patch by patch as uMap rises.
4. The DOM chrome (#map) fading in at t > 0.8, positioned by projecting world points through the same camera every frame.
5. CSS overlays: silk `opacity = 0.24·(1 − 0.4 uMap)`; vignette `0.38·(1 − uMap)` (L14960–14961).
Once uMap ≥ 0.999 all SANDBOX meshes are hidden (perf); MAP2D hidden when uMap ≤ 0.001.

### 4.2 mapPose (L14114–14118)

```
aspect = W/H; tanH = tan(fov_map/2) with fov_map = 20°
h = MAP.view / (tanH · min(1, aspect))
pos = (MAP.cx, h, MAP.cz); quat = Euler(−90°, 0, 0)  (MAPQ L14094) ; fov = 20
```
`MAP.view` = half-extent of the **shorter** screen side in world units (landscape: half-height; portrait: half-width). Screen up = −z = north.
Map limits: view ∈ [2400, 42000]; centre clamped to rect ± (1500 in x, 2200 in z) (L14348).
`updateMap(dt)` (L14341–14352): if `MAP.goal`: `cx, cz, view = lerp(·, goal, 1 − exp(−4dt))`; goal cleared when within 2 units. Then clamp, applyPose, updateLabels; light updated with zero visibility.

### 4.3 updateTransition (L14325–14340) — timing and easing

```
trans = min(1, trans + dt/transDur)        // 2.4 s to map, 2.0 s to flight
t = trans, e = easeInOut(t)
to = toMap ? mapPose() : flightPose()       // live target (map: MAP.cx/cz/view set at start; flight: rig target/Aeff set at start)
xz:   lerp(from.pos, to.pos, toMap ? easeOut(1.05·t) : e)                // to map: fast start, slows in
y:    exp(lerp(ln max(20, from.y), ln max(20, to.y), e))                 // altitude in log space
rot:  slerp(from.quat, to.quat, easeInOut(clamp(toMap ? 1.2t : 1.1t − 0.1, 0, 1)))
        // to map: pitch reaches straight-down at t = 0.833; to flight: rotation starts at t = 0.09 and finishes at t = 1
fov:  lerp(from.fov, to.fov, e)            // 40° ↔ 20°
uMap: toMap ? smoothstep(0.32, 0.92, t) : 1 − smoothstep(0.04, 0.66, t)
#unroll "舆图展开中" opacity 1 while toMap and 0.25 < t < 0.86 (CSS .4 s fade)
toMap and t > 0.8 → #map.on (chrome fades in over 0.7 s), aria-hidden false
updateLabels(); light: visibility = 1 − uMap
t ≥ 1 → mode = map | flight (+ HUD back on in flight)
```
Typical to-map numbers from A = 1650: start view = clamp(1.15·1650 = 1897.5 → 2400); map height = 2400/tan(10°) ≈ 13 611 (landscape), so the camera rises 1650 → 13 611 in log space while pitching from 45° to 90° and narrowing FOV 40→20 (a dolly-zoom-like flattening). Auto map from 11 000: view = 12 650 → h ≈ 71 742.
Leaving the map from a large view: toggleMap clamps A ≤ 8800 so you descend into high flight.

### 4.4 Godot mapping

- Global shader uniform `map_k` (Project Settings → Shader Globals, type float). In every world shader's `vertex()`:
  ```glsl
  global uniform float map_k;
  void vertex() {
      vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
      wp.y *= 1.0 - map_k;
      VERTEX = (inverse(MODEL_MATRIX) * vec4(wp, 1.0)).xyz;   // or use world_vertex_coords render mode and write VERTEX = wp
  }
  ```
  `render_mode world_vertex_coords;` makes this one line (`VERTEX.y *= 1.0 - map_k;`). Fade glows with `ALPHA *= 1.0 - map_k`.
  Shadows/normals: the flattened terrain's normals are stale; three.js's stylised lighting tolerates it because the map plane covers it by uMap ≈ 0.6.
- Transition driver: a `Node` with `_process` (do not use Tween for position – the target pose is live). Use `Quaternion.slerp`. Cubic easings as functions.
- Map chrome fade: `create_tween().tween_property(map_chrome_root, "modulate:a", 1.0, 0.7)`; set `mouse_filter` of interactive children to STOP only when on.
- Overlays: `silk.modulate.a = 0.24 * (1.0 - 0.4 * map_k)`; `vignette.modulate.a = 0.38 * (1.0 - map_k)`.
- Hide the world when `map_k >= 0.999` (`world.visible = false`) and the map plane when `map_k <= 0.001`.

---------------------------------------------------------------------------------------------------------------------------------

## 5. Map labels projection and the 舆图 painting (section 10)

### 5.1 World → screen (L14381–14409, L14293–14298, L14373–14380)

```
ndc = project(world, camera)          // three: Vector3.project → NDC in [−1,1], z>1 = behind/past far
x = (ndc.x·0.5 + 0.5)·innerWidth
y = (−ndc.y·0.5 + 0.5)·innerHeight
```
- Map labels project `(p.x, 0, p.z)` (ground level; the world is flat at uMap=1). Visible only when `uMap > 0.6`, not filtered by legend, not minor-at-large-view.
  Off-screen culling margins: x ∈ [−120, w+120], y ∈ [−80, h+80]. Sect anchor (−50%, −100%), others (−50%, −50%). `.sel` when `MAP.sel === p`.
- ME marker projects `(PLAYER.pos.x, 0, PLAYER.pos.z)`; hidden when uMap < 0.3; opacity `smoothstep(0.3, 0.8, uMap)`.
- Plate: project rect corners `(x0,0,z0)` and `(x1,0,z1)` → left/top/width/height. Updated in updateLabels (i.e. during transitions and map mode).
- Trail: SVG regenerated every frame from projected TRAIL points.
- Hotspots (flight) project `(x, (labelY||60)·(1−uMap), z)`; margins x ∈ [−80, w+80], y ∈ [−120, h+60].
Godot: `cam.unproject_position(world)` returns pixels directly; `cam.is_position_behind(world)` replaces the z>1 test. Labels as `Control` children positioned with
`position = screen − size * Vector2(0.5, 1.0)` (sect) or `size * 0.5` (others). Re-run each frame in `_process` after the camera moves (process_priority after the controller).
Plate in Godot: a Control whose `_draw()` fills four rects around the projected rect with `Color(0.043,0.086,0.094,0.94)`, then `draw_rect(rect, Color(0.839,0.706,0.431,0.35), false, 1)`, `draw_rect(rect.grow(7), Color(…,0.55), false, 1)`, corner brackets (18 px, 2 px, alpha .7, at −12 px), and an inner shadow (a gradient texture or skip).

### 5.2 The painted map plane: geometry (buildMap2D L13250–13270)

- `PlaneGeometry(size, size)` with `size = 3 × max(rect width, rect depth)`, rotated flat, centred on the rect centre, y = 1. Covers far past the world so the silk extends everywhere.
- ShaderMaterial: transparent, `depthTest:false`, `depthWrite:false`, renderOrder 60, frustumCulled false, initially invisible.
- Uniforms: `tLand` (RG half-float: **R = terrain height in 丈**, **G = height box-blurred by r=5 cells ≈ 200 丈**, 1.5 texels per 40-丈 grid cell, L5389–5425), `tWater` (RGBA8: **R = signed distance to shore, `sd = (R·255 − 128)·2` 丈, positive in water**, **A = sea flag**), `tGround` (RGBA8: **R = woods**, **G = fields**), `tOver` (2048×(2048·depth/width) CanvasTexture overlay), `uMap`, `uReady` (0 until paintMap), `uTexel = 1/(nx, nz)`, `uRect = (x0, z0, w, d)`, `uCell = WORLD.g` (= terrain.grid 40).
- Vertex shader passes world xz as `vP`.

### 5.3 Fragment shader MAP_FS (L13149–13249), step by step

`wuv = (vP − rect.xy)/rect.zw`; `inside` = wuv ∈ [0,1]²; `q = clamp(wuv)`; `h = tLand.r`. `ink = (0.2, 0.22, 0.25)`.
1. **Silk**: `mott = 0.6·fbm3(vP·0.00021+3) + 0.4·fbm3(vP·0.0011+9)`; silk = mix((0.9,0.85,0.72), (0.84,0.78,0.63), smoothstep(.35,.75,mott)); darken up to 10% within 18% of the sheet edge (noisy).
2. **Water** colour: `water = smoothstep(−4, 4, sd)`; `deep = smoothstep(20, 320, sd)·(0.4 + 0.6 sea)`; wcol = mix((.64,.73,.70), (.42,.56,.60), deep); rivers/lakes greener: mix toward (.6,.72,.73) by (1−sea)·0.5.
3. **鱼鳞纹 wave scales** on the sea: grid `sq = vP/130`, odd rows offset by 0.5; in each cell an arc `|length((fract−(.5,0))·(1,1.4)) − 0.46|`, antialiased by `fwidth`, upper half only, fading out when cells shrink below ~1–2 px (`1 − smoothstep(.08,.2,fwidth)`); ink at 22%, only where `sd > 40..160` (away from shore). Pale strand band (0.9,0.93,0.9) 25% within 40 丈 of shore at sea.
4. **Plains**: base mix((.84,.80,.63),(.76,.76,.58), 0.7·fbm3(vP·0.00048)); fields green tint by tGround.g; **点苔 woods dots**: 46-丈 cells, jittered centres, dot radius ~0.16–0.22 cell, density `0.25 + 0.6·wood`, antialiased and faded when cells < ~0.5 px; woods tint (.5,.6,.47)·0.32, dots (.3,.42,.34)·0.75.
5. **Painted mist** at mountain feet: domain-warped fbm `cf = 0.7·fbm3(warped) + 0.45·smoothstep(2, 70, blurredHeight)`; fill (.93,.91,.84) 60% where `cf > .56–.7`; a grey edge line (.58,.62,.64) 30% at `cf ≈ .57` — not on water.
6. **Ranges** (flat-tone painting): `hs = mix(h, blurred, .45)`; central differences with step 2.2 texels on the same mix → normal `N = normalize(−dx/cell, 1, −dz/cell)` with `cell = uCell·4.4`; light `Ld = normalize(−.6, .5, −.6)` (from north-west, upper-left on screen); `tone = N·Ld`; **two flat tones** `lit = smoothstep(.5−tw, .5+tw, tone)`, tw = max(1.5·fwidth(tone), .03).
   Colour by height `hk = clamp((hs−120)/320)`: 石绿 (.46,.64,.52) → 石青 (.26,.46,.56); 赭石 foot (.66,.58,.44) below h≈3–50; snow (.88,.92,.92) 50% above 600–850; shade ×(.74,.77,.82) vs lit ×(1.12,1.1,1.02).
   **Hatching** on shaded flanks: stripes along the contour direction `sAlong = dot(vP, perp(grad))`, spacing `max(6·fwidth(sAlong), 2)` (≈ 6 px at any zoom), broken by noise, 50% ink, only for h > 10–50.
   **Ridge line**: ink 60% where `|tone − .5|` < 2.2·tw (the lit/shade terminator), h > 12–60.
   `rangeK = smoothstep(2, 8, h)`; c = mix(plain, range, rangeK); **foot outline** ink 55% × `1 − |2·rangeK − 1|`.
7. Composite water over land; **shore ink line** 60% within 1.8 px of sd = 0 (`|sd|/fwidth(sd)`).
8. **Overlay** `tOver` (roads/villages/cities) alpha-blended inside the rect. `uReady` mixes from plain silk. Outside the rect: silk × 0.97.
9. **Silk weave**: `fib` from anisotropic vnoise (0.36×0.016 and 0.016×0.36) → ×(0.97 + 0.05 fib); large blotches −5%; warm wash ×(1,.95,.86) 35% within 30% of the frame edge.
10. **Ink-seep reveal**: `sn = 0.75·fbm3(vP·0.00018 + 2.3) + 0.25·vnoise(vP·0.0016)`; `alpha = smoothstep(sn − .14, sn + .06, uMap·1.3 − .15)` → the map appears in irregular patches between uMap ≈ 0.1 and 1.0 rather than a uniform fade.

Noise functions (GLSL_NOISE L492–500): `hash12`, `hash22` (Dave Hoskins hash), `vnoise` (value noise with smooth interpolation), `fbm3` (3 octaves, lacunarity ≈2.03/2.01, offsets 17.1/5.3, normalised /0.875) – port verbatim to Godot shader language.

### 5.4 The overlay canvas (paintMap L13273–13305)

2D canvas, `C(x,z)` maps world → canvas px over LAYOUT.rect. Drawn once after world build:
- streams: 1.2 px `rgba(80,118,128,.85)`.
- roads: main dashed [7,5] 2.2 px, others [3,4] 1.3 px, `rgba(122,74,46,.78)`.
- 天道盟小国 border (GEO.border, L340): dashed [9,6], 2.4 px `rgba(70,150,120,.8)`, plus label "天道盟小国" bold `N/110` px (≈ 19 px) `rgba(60,120,100,.9)` near the middle vertex, offset (+N/60, −N/160).
- villages: r 4.2 circle fill `rgba(214,196,160,.95)` stroke `rgba(110,70,44,.9)` 1.2.
- post stations: 5×5 squares `rgba(128,58,40,.9)`.
- 市镇 towns: 9×7 rects fill `rgba(222,204,166,.95)` stroke `rgba(110,62,40,.95)` 1.4.
- arrays (传送阵): ring r 4.5 stroke `rgba(70,120,118,.9)` 1.4 + centre dot r 1.6.
- city POIs: square of half-size s (city plan's half extent, or N·0.006; 封日城 0.008), fill `rgba(230,214,180,.92)`, stroke `rgba(128,58,40,.95)` 2.2, cross of streets 1.1.
Then `uReady = 1`.

### 5.5 Godot mapping

- `MapPlane`: `MeshInstance3D` + `PlaneMesh(size = 3·max(w,d))` at rect centre, y = 1. Material `ShaderMaterial` with `render_mode unshaded, depth_test_disabled, depth_draw_never, blend_mix, cull_disabled;` and `render_priority = 60` (transparent sort).
- Inputs: bake `land.exr` (RG float: height, blurred height), `water.png` (R signed distance encoded `sd/2 + 128`, A sea), `ground.png` (R woods, G fields) from Blender/your terrain generator, or generate in GDScript into `ImageTexture` (FORMAT_RGH for half floats).
- Overlay: draw it once into a `SubViewport` (size 2048×2048·d/w, `render_target_update_mode = UPDATE_ONCE`, transparent bg) with a Control that uses `draw_polyline`/`draw_dashed_line`/`draw_circle`/`draw_rect`/`draw_string`, and use `SubViewport.get_texture()` as `t_over`. Or pre-render to PNG.
- `fwidth` exists in Godot shaders; `texture2D` → `texture`; varyings via `varying vec2 v_p;` set in vertex from `(MODEL_MATRIX * vec4(VERTEX,1)).xz`.
- Uniform `map_k` = global; `alpha = smoothstep(sn - .14, sn + .06, map_k*1.3 - .15)` → `ALPHA`.

---------------------------------------------------------------------------------------------------------------------------------

## 6. Boot, main loop, auto quality, debug, test API (section 14 & 13)

### 6.1 Renderer setup (L14834–14848)

`THREE.ColorManagement.enabled = false`; renderer `antialias:false, powerPreference:'high-performance', preserveDrawingBuffer: ?test, stencil:false, depth:false` (the composer's render target has depth);
`outputColorSpace = LinearSRGBColorSpace` (palette sRGB hex values pass straight through, i.e. no gamma conversion anywhere); clear `#dcddd6`; MSAA samples for post = min(4, maxSamples) (0 in `?lite`); camera `PerspectiveCamera(40, aspect, 5, 200000)`.
`?lite` → `look.pixelRatio = 0.5`. `?test` → no RAF loop (driven by `__ym.render`), no auto-quality.
Godot: since colours are authored as sRGB and output untouched, either use the `Compatibility`/`Mobile` renderer with sRGB-correct `Color.html()` values and tonemap `Linear`, exposure 1, or mark shader colour uniforms `source_color`. Disable glow/SSAO etc. by default.

### 6.2 boot() order (L14882–14929)

1. applyPixelRatio; `#loading.on`; intro title visible.
2. Load `hotspots.json` (2.5 s timeout) → applyHotspots (moves POIs/sects before generation).
3. Start async: asset pack, ground textures, eco atlas.
4. `await buildWorld(progress → "展卷中 N%")`; buildLand; buildWater.
5. "运模型": wait pack/ground/eco (20 s timeout; 60 s in test); late arrivals ignored.
6. buildProps, buildMirrors, buildGlow, buildClouds, buildCloudSea, buildSky, buildAtmos, buildFlyers, buildLife, `DG = buildLight`, FIG (only if figure.on), **buildMap2D, paintMap**, `composer = buildPost`, collectSandbox, resize listener, onResize, **startApp**, DEBUG.init.
7. Hide loading; start RAF loop; `__ym.ready = true`.
8. Optional brushwork (cloud textures, formation patterns, card images) then buildFormations, collectSandbox again; `__ym.loaded = true`.
`startApp()` (L14590–14601): pos = startPos; clear = groundClear; A = At = 2700; target = pos; setupSilk, setupInput, buildLabels, buildHotspots; HUD hidden; introSetup; mode intro.
Godot: run world generation in a `WorkerThreadPool` task or spread across frames with `await get_tree().process_frame`, updating a ProgressBar/Label "展卷中 N%".

### 6.3 Main loop (renderFrame L14931–14969, loop L14970–14975)

```
dt = min(0.05, (now − last)/1000)
APP.t += dt; uTime = APP.t
if !freeCam: updateApp(dt)                                   // §2.2
A = (flight|intro) ? CAMERA_RIG.Aeff : max(Aeff, camera.y·0.8);  uAlt = A
camera.near = max(5, cam.y·0.05); camera.far = cam.y·40 + 30000
updateLand(camera) → updateWater → updateMirrors → updateProps(A) → updateClouds(dt,cam,A,vel) → updateCloudSea(A) → updateSky
→ updateSects(dt,A) → updateCities → updateLore → updateFlyers → updateLife → updateGlow → updateAtmos
tilt-shift focus: fy = clamp(lerp(0.5, lightNDC.y·0.5+0.5, 0.4), 0.3, 0.7)   // focus band pulled 40% toward the light
updatePost(A, fy)                                             // tilt strength k = (0.32 + 0.5·lowK)·(1 − 0.8·smoothstep(mid,high,A))·tiltShift·(1−uMap)·uCloudIn, lowK = 1 − smoothstep(low, mid, A)
#silk.opacity, #vignette.opacity (see §4.1)
composer.render
QUALITY.dtAvg = lerp(dtAvg, dt, 0.05); QUALITY.sample(dt); DEBUG.tick(dt)
```
Exceptions stop the loop and set `__ym.error`.
Godot: put mode update in an autoload with `process_priority = -10`, world updates after, label projection last (`process_priority = 100`). Clamp `delta` to 0.05.

### 6.4 Auto quality (QUALITY L14850–14866, applyPixelRatio L14867–14871)

```
base()  = min(devicePixelRatio, 1.25) · look.pixelRatio
sample: only in steady flight, never in test. cool = 4 s initial delay.
  accumulate frames for 2.5 s → fps; history keeps last 3
  if history ≥ 2 and avg < 48 fps and scale > 0.6:
       scale = max(0.6, scale·0.8); history = []; cool = 3 s; applyPixelRatio(); toast("帧率偏低（avg），渲染倍率降到 ×(base·scale)")
applyPixelRatio: renderer.setPixelRatio(base·scale); setSize(innerW, innerH); composer resize
```
Downscale only (0.8 steps, floor 0.6, i.e. 1 → 0.8 → 0.64 → 0.6); never scales back up. Resize recomputes aspect and pixel ratio.
Godot: `get_viewport().scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR` (or FSR) and set `scaling_3d_scale = clamp(base*scale, 0.5, 2.0)`; UI stays crisp because CanvasLayers aren't scaled. Use `Engine.get_frames_per_second()` or your own accumulator.

### 6.5 Debug panel (DEBUG L14620–14830)

Toggle with Backquote (always). Panel swallows pointerdown/wheel; sliders/textarea/select stop keydown propagation.
`get/set(k)` walk a dotted path in CONFIG. `apply(row)`: write CONFIG, update output text, then side effects:
- `look.pixelRatio` → applyPixelRatio(); `look.ground` → `LU.uDetail` (if ground textures loaded);
- `zoom.low` / `zoom.mapAt` → re-clamp `PLAYER.At`;
- `palette.*` → refreshPalette();
- `regen:true` (clouds.amount, clouds.mist, clouds.wall) → debounce 250 ms `buildClouds(scene)`;
- `rebuild:'flyers'` (lore.flyers, lore.flyerSpeed) → debounce 250 ms buildFlyers; `rebuild:'motes'` (life.motes) → buildMotes;
- always refresh the travel table.
All other sliders are read live by their systems every frame (they read CONFIG directly).
`reset()`: deep-restore CONFIG_DEFAULT, applyPixelRatio, buildClouds, sync.
Pick mode: crosshair cursor; click → ground raycast (y=0 plane) → base-map px via `FRAME.toBase` → `#pickDot` (14×14 white ring + `#b8392a` outer ring) at the click; textarea shows `底图像素 [x, y]   世界 (X, Z)`; if a POI is selected in "打点记到", record into `picks`, `applyHotspots({id: xy})` live, and print a hotspots.json snippet (`// 存为 hotspots.json 放在页面旁边即可生效`).
"导出参数" → `JSON.stringify(CONFIG, null, 2)` into textarea; "复制" → clipboard ("已复制" 1.2 s).
Stats every 0.5 s: `{fps} 帧 · 渲染倍率 · 绘制 N 次 · Nk 面 / 山体 · 三宗山域 · 殿宇 · 群峰 簇 · 树 · 生成 ms / 位置 世界 x,z · 底图像素 / 高度 A 丈 · 俯角 pitch° · 移轴 k`.

Slider table (key, label, min–max, step, display) L14623–14732:
```
飞行
 flight.speed       飞行速度   0.05–0.4   0.005  "0.120×高"
 flight.boostMul    疾遁倍数   1.2–5      0.1    "×3.0"
 flight.accel       起步惯性   0.05–2     0.05   "0.50 秒"
 flight.glide       滑翔距离   0.1–4      0.05   "1.25 秒"
 flight.fling       拖动甩出   0–1.5      0.05
 flight.lightHeight 离地高度   0.05–0.5   0.01   "×高"
 flight.bob         上下浮动   0–3        0.1
镜头与缩放
 camera.lookAhead   超前看     0–2        0.05   秒
 camera.follow      跟随缓动   0.02–1.5   0.02   秒
 camera.boostPull   疾遁拉远   0–0.4      0.01   "+10%"
 camera.fov         视场角     20–70      1      °
 camera.pitchLow    低空俯角   25–70      1      °
 camera.pitchMid    中空俯角   25–75      1
 camera.pitchHigh   高空俯角   30–85      1
 camera.pitchTop    最高处俯角 30–89      1
 zoom.low           低空高度   400–1600   10     丈
 zoom.mid           中空高度   800–3000   10
 zoom.high          高空高度   3000–11000 50
 zoom.mapAt         收图高度   6000–16000 100
 zoom.wheel         滚轮灵敏度 0.0003–0.004 0.0001 (×1000 shown)
 zoom.keyRate       升降速度   0.2–2.5    0.05
 zoom.ease          升降缓动   0.02–1     0.02   秒
山与水
 terrain.relief 山高倍数 0.3–2 · look.ground 地表纹理 0–2 · terrain.soft 山体柔和 0–1 ("硬切面" < .05) · terrain.cun 顺坡皴笔 0–2 · terrain.strata 崖壁岩层 0–2
 terrain.creaseInk 皴线墨色 0–1.5 · terrain.footInk 山脚墨线 0–1.5 · water.ripples 墨线水纹 0–2 · water.waves 波浪 0–3 · water.seaMotion 海面动态 0.2–4
 water.steps 水色色阶 1–8 (int) · trees.density 树木疏密 0–1.5 · trees.size 树木大小 0.4–2.5 · trees.sway 树随风动 0–2.5 · eco.ground 花草疏密 0–1.5
日照
 sun.azimuth 太阳方位 90–330° · sun.elevation 太阳高度 15–70° · sun.shadow 山影浓淡 0–1 · sun.contrast 明暗反差 0–1.6 · sun.ao 谷底压暗 0–1
宗门与护山大阵
 sects.dome 大阵浓淡 0–2 · sects.flow 阵纹流速 0–3 · sects.ripple 灵气波纹 0–2 · sects.glow 阵眼灯火 0–2.5
修仙点缀
 lore.flyers 来往遁光 0–16 道 (rebuild) · lore.flyerSpeed 遁光速度 120–900 丈/息 (rebuild)
城池与人间烟火
 city.beams 护城光柱 0–2 · city.terraces 山坡梯田 0–1.5 · life.amount 行人车船 0–1 · life.scale 人与车船大小 0.5–2.5 · life.far 人烟可见距离 1000–6000 丈 · life.motes 灵气光点 0–1500 (rebuild)
云海
 cloudSea.amount 0–1.2 · height 云顶高度 80–320 丈 · billow 0–2 · speed 0–3 · thick 60–300 丈 · density 0.3–3 · steps 体积步进 4–20
遁光
 light.size 0.3–3 · light.tail 0.2–3 · light.intensity 0.2–1.6 · light.breath 0–0.3 · light.shadow 0–1 · light.speedLines 0–1.5 · light.core 核心色 (color)
修士
 figure.size 0.4–2.5 · figure.lean 0–60° · figure.boostLean 30–90° · figure.bank 0–45° · figure.fade 0–1 · flight.dunIn 0.05–1 秒 · flight.dunOut 0.1–2 秒 · light.glow 光晕色 (color)
云
 clouds.amount 0–2 (regen) · clouds.speed 0–4 · clouds.mist 0–1 (regen) · clouds.nearEvery 2–40 秒 · clouds.nearOpacity 0–1 · clouds.shadows 0–0.4 · clouds.wall 0–1.5 (regen)
画面
 look.tiltShift 0–2.5 · look.focusBand 0–0.4 · look.paper 0–0.8 · look.vignette 0–1 · look.edgeFade 0.005–0.2 · look.haze 0–1.5 · look.edgeInk 0–1.5 · look.pixelRatio 0.5–2
全局视角（随高度渐入）
 cinema.grade 0–1.5 · cinema.warmth 0–1 · cinema.valleyMist 0–1.5 · cinema.shafts 0–2 · cinema.cirrus 0–1.5 · cinema.vignette 0–1
```
Godot: build the panel from the same table at runtime (Array of Dictionaries). Each row: `HBoxContainer[Label(min_size.x=84), HSlider(min,max,step, size_flags EXPAND), Label(min_size.x=60, align right, color #6fe0c0)]`; `value_changed` → `Config.set_path(k, v)` and emit `config_changed(k)` for systems needing rebuild (use a 0.25 s one-shot `Timer` for debounce). Colour rows → `ColorPickerButton`. Store CONFIG as a `Resource` (`.tres`) so "导出参数" = `ResourceSaver.save` or `JSON.stringify(dict, "  ")`.

### 6.6 Test API `window.__ym` (L14977–15005)

Exposes CONFIG, LAYOUT, U, POIS, BASE, WORLD, LAND, PROPS, CLOUDS, FRAME, PLAYER, ST, MAP, LORE, FLYERS, SKY, CITY, LIFE, LU, PACK; flags `ready`, `loaded`, `error`.
| method | does |
|---|---|
| `render(n=1, dt=1/60)` | step renderFrame n times (used with `?test`) |
| `state()` | `{mode, t, A, pos[x,z], vel, map(uMap), near(id), card, tilt(POST.k), pitch, light(y)}` |
| `skip()` | finish intro, HUD on |
| `intro(t)` | restart intro at time t |
| `fly(x, z, A=1650)` | hard-set flight at a spot: exits intro, closes card, uMap 0, shows sandbox, hides map plane, resets light/velocity/clearance/rig, HUD on |
| `flyTo(id, A, dz=320)` | fly() to POI id, dz south |
| `key(code, down)` | synthesise keydown/keyup + KEYS |
| `layers({clouds, tilt, light, paper})` | toggle cloud layers & cloud sea, tilt-shift, light intensity, paper+vignette |
| `wheel(dy)` | zoomBy(exp(dy·wheel)) |
| `toggleMap()`, `mapNow()` | toggle / jump to the end of a to-map transition |
| `select(name)` | selectPoi(POI_BY[name], true) |
| `debug(on)`, `set(k, v)` | debug panel / set a CONFIG key through its slider (with side effects) |
| `info()` | renderer calls, tris, textures, geometries, pixel ratio, MSAA samples |
| `topView(view)` | freeCam straight-down over the whole rect at map fov (for overlaying the 舆图) |
| `look(px,py,pz, tx,ty,tz, fov=38, A=1200)` | fly() to target for streaming/LOD, then a free camera lookAt |
| `cam(...)` | free camera without moving the player; `freeCam(on)` |
| `showMapPlane(on)` | show map plane / hide sandbox |
| `cloudCover()`, `biomeMap(scale)` | instance counts / biome PNG data URL |
| `fig()`, `player()`, `dev.{cloudFall, seaDist, hAt, waterAt, sdAt, densityAt, sects, marks, pois, life, lowAt, seaTop, seaDens}` | samplers for headless checks |
Godot: expose the same through a `DebugAPI` autoload and drive it from GUT/gdUnit4 tests or a `--test` command-line flag (`OS.get_cmdline_user_args()`), stepping with a fixed `delta` (`Engine.physics_ticks_per_second` not needed; call `update(1.0/60)` manually).

---------------------------------------------------------------------------------------------------------------------------------

## 7. Godot mapping by topic: extra snippets

### 7.1 Banner

```gdscript
var banner_t := 0.0; var last_banner := ""
func update_banner(dt):
	var best = null; var bd := 1e9
	for p in Pois.all:
		if not p.has("banner"): continue
		var d := Vector2(flight.pos.x - p.pos.x, flight.pos.z - p.pos.z).length()
		if d < p.banner and d < bd: bd = d; best = p
	if best and best.id != last_banner:
		last_banner = best.id; banner_t = 4.2
		$Hud/Banner/Name.text = best.name; $Hud/Banner/Sub.text = best.get("sub", "")
	if best == null and last_banner != "":
		var p = Pois.by_id[last_banner]
		if Vector2(flight.pos.x - p.pos.x, flight.pos.z - p.pos.z).length() > p.banner * 1.25: last_banner = ""
	banner_t -= dt
	$Hud/Banner.modulate.a = clampf(min(banner_t, 4.2 - banner_t) * 1.5, 0.0, 1.0)
```

### 7.2 Hotspot tag (scene `HotspotTag.tscn`)

```
HotspotTag (VBoxContainer, alignment center, mouse_filter PASS)
├─ Tag (PanelContainer, StyleBoxFlat sect) → Label (vertical text, 14px bold #f4f6f8)
├─ Pin (Panel 7×7, StyleBoxFlat white bg, border 2 #2d4560, radius 4)
└─ Prompt (PanelContainer pill) → Label "按 E 落脚"   (modulate.a tweened 0↔1, .3 s)
signal pressed(poi)
func set_near(on): tag.add_theme_stylebox_override("panel", NEAR if on else BASE); create_tween().tween_property(prompt, "modulate:a", 1.0 if on else 0.0, 0.3)
```
Position each frame: `var s := cam.unproject_position(Vector3(p.x, p.label_y * (1.0 - map_k), p.z)); tag.position = s - Vector2(tag.size.x * 0.5, tag.size.y_of_tag_and_pin)` (the anchor is the bottom of the pin, the prompt hangs below it – so measure Tag+Pin height, not the whole VBox).

### 7.3 Info card open/close animation

```gdscript
func open_card():
	card.visible = true; card.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := create_tween().set_parallel(); tw.tween_property(card, "modulate:a", 1.0, 0.35); tw.tween_property(card, "position:x", home_x, 0.35)
func close_card():
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw := create_tween().set_parallel(); tw.tween_property(card, "modulate:a", 0.0, 0.35); tw.tween_property(card, "position:x", home_x + 24, 0.35)
```
(CSS default transition timing function is `ease` – use `Tween.TRANS_CUBIC, EASE_OUT` as a close match, or a Curve (0.25,0.1,0.25,1).)
Body: `RichTextLabel` with BBCode is easiest for the paragraphs (`fit_content = true`, `autowrap_mode = WORD_SMART`); header Labels separately; chips in an `HFlowContainer` (Godot 4.x) with `h_separation = 8`.

### 7.4 Search

```gdscript
func _on_q_text_changed(t: String):
	t = t.strip_edges(); for c in results.get_children(): c.queue_free()
	if t == "": results_panel.hide(); return
	var hits := Pois.all.filter(func(p): return p.name.contains(t) or p.get("crumb","").contains(t) or p.get("lead","").contains(t)).slice(0, 8)
	if hits.is_empty(): results.add_child(_disabled_button("没有找到「%s」" % t))
	for p in hits: results.add_child(_result_button(p))   # first one styled .act
	results_panel.show()
func _on_q_text_submitted(_t): if results.get_child_count() and not results.get_child(0).disabled: results.get_child(0).pressed.emit()
```
Godot `LineEdit` emits `text_submitted` on Enter; on Escape call `release_focus()`.

### 7.5 Map controller

```gdscript
var cx := 39652.0; var cz := -14000.0; var view := 36077.0; var goal = null
func map_pose() -> Transform3D:
	var aspect := get_viewport().get_visible_rect().size.aspect()
	var h := view / (tan(deg_to_rad(20.0) * 0.5) * min(1.0, aspect))
	return Transform3D(Basis.from_euler(Vector3(-PI / 2, 0, 0)), Vector3(cx, h, cz))
func update(dt):
	if goal:
		var k := 1.0 - exp(-dt * 4.0)
		cx = lerp(cx, goal.cx, k); cz = lerp(cz, goal.cz, k); view = lerp(view, goal.view, k)
		if absf(view - goal.view) < 2.0 and Vector2(cx - goal.cx, cz - goal.cz).length() < 2.0: goal = null
	cx = clampf(cx, rect.x0 - 1500, rect.x1 + 1500); cz = clampf(cz, rect.z0 - 2200, rect.z1 + 2200)
	cam.global_transform = map_pose(); cam.fov = 20.0
func pan(rel: Vector2):     # InputEventMouseMotion.relative while dragging
	var wpp := 2.0 * cam.global_position.y * tan(deg_to_rad(20.0) * 0.5) / get_viewport().get_visible_rect().size.y
	cx -= rel.x * wpp; cz -= rel.y * wpp; goal = null
```
Note `Basis.from_euler(Vector3(-PI/2,0,0))` makes camera −Z point to world −Y and camera +Y (screen up) point to world −Z (north) – same as three's MAPQ.

### 7.6 Flight drag (grab the ground)

```gdscript
var plane := Plane(Vector3.UP, 0.0)
func ground_at(screen: Vector2):
	return plane.intersects_ray(cam.project_ray_origin(screen), cam.project_ray_normal(screen))
func _drag_start(sp): var g = ground_at(sp); if g: drag = {grab = g, last = Time.get_ticks_msec(), v = Vector3()}
func _drag_move(sp):
	var g = ground_at(sp); if g == null: return
	var d: Vector3 = g - drag.grab
	var now := Time.get_ticks_msec(); var dtt := max(1, now - drag.last) / 1000.0
	drag.v = Vector3(-d.x / dtt, 0, -d.z / dtt); drag.last = now
	pos.x -= d.x; pos.z -= d.z; rig_target.x -= d.x; rig_target.z -= d.z
	cam.global_transform = flight_pose(rig_target, a_eff)
	var g2 = ground_at(sp); if g2: drag.grab = g2
func _drag_end():
	var fresh := Time.get_ticks_msec() - drag.last < 90
	vel = Vector3(drag.v.x * 0.85, 0, drag.v.z * 0.85) if fresh else Vector3.ZERO
	drag = {}
```
(three's `flightPose()` with no args uses the current `Aeff`, as here.) Pinch: track two `InputEventScreenTouch/Drag` indices; `zoom_by(prev_dist / dist)`; wheel: `InputEventMouseButton` WHEEL_UP/DOWN → deltaY ≈ ∓100 (browser line delta) → factor `exp(±100·0.0013) ≈ ×1.139 / ×0.878`; `InputEventPanGesture` (trackpads) → `exp(delta.y·k)`.

### 7.7 Virtual stick

```gdscript
extends Control   # 116×116
@onready var knob := $Knob   # 46×46
var touch_id := -1
func _gui_input(e):
	if e is InputEventScreenTouch:
		if e.pressed and touch_id == -1: touch_id = e.index; _move(e.position)
		elif not e.pressed and e.index == touch_id: touch_id = -1; Touch.mx = 0; Touch.mz = 0; knob.position = (size - knob.size) / 2
	elif e is InputEventScreenDrag and e.index == touch_id: _move(e.position)
func _move(p):
	var d: Vector2 = (p - size / 2).limit_length(46.0)
	knob.position = size / 2 + d - knob.size / 2
	Touch.mx = d.x / 46.0; Touch.mz = -d.y / 46.0
```
Show only when `DisplayServer.is_touchscreen_available()` (≈ `pointer:coarse`); then hide the Hint.

### 7.8 Silk overlay texture (setupSilk L14579–14588)

256×256 white canvas; every 2nd row a 1-px horizontal line `rgba(120,96,60, 0.03–0.08)`; every 2nd column a 1-px vertical line `rgba(120,96,60, 0.02–0.06)`; 40 random bezier fibres 0.6 px `rgba(110,90,60, .05–.12)`; 8 radial stains r 30–100 `rgba(170,140,90, .04–.09)` → transparent. Seeded mulberry32(9). Tiled at 256 px, `multiply` blend.
Godot: generate once into an `Image` (or bake a PNG), `TextureRect` with `stretch_mode = TILE`, `CanvasItemMaterial.blend_mode = BLEND_MODE_MUL`; drive `modulate.a`. Note a MUL blend ignores alpha in Godot – instead lerp the texture toward white in a tiny shader: `COLOR = vec4(mix(vec3(1.0), tex.rgb, opacity), 1.0)` with `blend_mul`.

### 7.9 Vignette

ColorRect full-rect with shader:
```glsl
shader_type canvas_item; render_mode blend_mix;
uniform float opacity = 0.38;
void fragment(){
	vec2 p = (UV - vec2(0.5, 0.46)) / vec2(1.25, 1.0) * 2.0;   // ellipse 125% × 100% at 50% 46% (CSS radial-gradient farthest-corner semantics approx.)
	float r = length(p) / length(vec2(0.5/1.25, 0.54) * 2.0);
	float a = smoothstep(0.56, 1.0, r) * 0.42;
	COLOR = vec4(70.0/255.0, 62.0/255.0, 44.0/255.0, a * opacity);
}
```
(CSS sizes the gradient relative to the box, so the exact radius normalisation is approximate; tune visually.)

---------------------------------------------------------------------------------------------------------------------------------

## 8. Gotchas and details easy to miss

- The camera's **y** rises above A when `sightLift`/boostPull kick in (Aeff ≥ A); pitch is computed from `Aeff`, not A (flightPose default arg L14107), while speed and light height use A.
- Auto-to-map happens on the *target* `At` crossing 11 000, before clamping (L14192); the 1.2 s `mapCooldown` after returning stops ping-pong.
- `openCard` (flight) hides "御空前往"; `selectPoi` (map, chips, search) shows it when canFly. Chips call `selectPoi(.., true)` even in flight – they recentre only in map mode.
- Selecting from the map never zooms out (`min(MAP.view, …)`).
- The hotspot layer only shows in `flight` mode, the label layer only at `uMap > 0.6` – during transitions hotspots vanish instantly (L14607) while the labels appear at 60% map.
- The card element sits outside `#map` (v3) at z 22, so it can open over flight (L177–178); `pointer-events:none!important` when closed.
- `#fog`, `#riverSvg` content and `body.night` are present in markup/CSS but not driven by code in this file.
- `FIG` is null by default (`figure.on: false`, v4.4): the player is only the 遁光 (escape light, built in section 08); light is always fully lit in flight.
- Labels and hotspots are DOM, updated every frame with `translate3d` – in Godot, keep them as plain Controls (no containers as parents, or set `top_level`) so the per-frame `position` writes aren't overridden by container layout.
- Map wheel direction: wheel down (deltaY > 0) → f > 1 → zoom out / climb; wheel up → zoom in / descend.
- Minimum flight altitude is `zoom.low` = 950 丈; the light can still go much lower relative to the camera (0.24·A ≈ 228 丈 at 950) but never under ground + 70.
