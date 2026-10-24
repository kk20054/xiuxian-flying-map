"""Write the default geological plan of the 云梦山 / 天道盟 map: plan/lithology.png + plan/geology.json.

    python3 tools/terrain/make_plan.py                    # → tools/terrain/plan/
    python3 tools/terrain/make_plan.py --out my_plan      # a copy to paint on

The plan is the editable layer: repaint lithology.png (colours in docs/terrain/04-tools.md, or geology.LITHO) and edit
the structures in geology.json, then run sculpt.py. Every region below says why it is that rock — the geology and the
canon of 《凡人修仙传》 it answers to (see docs/terrain/03-world-plan.md).
"""
import argparse
import json
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from xyterrain import noise                                    # noqa: E402
from xyterrain.fields import box_blur                          # noqa: E402
from xyterrain.geology import LITHO, rgb_from_ids, region_weight  # noqa: E402
from xyterrain.world import World, write_png                   # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))

# name, rock, shape {ellipse: [x, z, rx, rz, rot°]}, why. Later regions paint over earlier ones.
REGIONS = [
    ("云梦山 花岗岩核", "granite", {"ellipse": [-1500, -800, 6500, 4000, 15]},
     "The main ridge (主脉) of 云梦山 with 古剑门 on it: a granite batholith in the core of the fold belt — the hardest rock "
     "stands highest and breaks into joint-bounded sword-like spires (剑峰) and sheer walls: 黄山 / 华山 country for a "
     "sword sect. 飞练崖 and 迎仙松 are its cliff and its crag pine."),
    ("云梦山 西脉 火山岩", "volcanic", {"ellipse": [-14500, 2500, 8500, 6000, 10]},
     "百巧院's 西脉: 'mountains on four sides' in the novel → an old caldera with welded tuff walls; hydrothermal ores and "
     "地火 are what an artifact-refining sect settles on. A cinder-cone field on the rest; 天柱山 at the west end stands "
     "alone as an inselberg (kept as the demo's landmark)."),
    ("笋石林 · 灵眼 喀斯特", "limestone", {"ellipse": [-5800, 3800, 3300, 2300, 20]},
     "A limestone belt between the granite core and the volcanic west: 笋石林's stone shoots are a 石林 (Shilin-type) "
     "pinnacle karst, and the novel puts 灵眼之树 inside a vast stalactite cavern ('石窟长宽数百丈') — the round basin at "
     "灵眼之树 is read as the 天坑 (collapse doline) that opens into it."),
    ("云梦山 东脉 石英砂岩", "quartz_sandstone", {"ellipse": [13800, -500, 7000, 4800, 10]},
     "落云宗's 东脉 (天泉/火云/白凤/幻石/锁烟/隐剑): thick horizontal quartz-sandstone beds cut by two joint sets — the "
     "张家界 peak forest, pillars standing out of the cloud sea. 子母峰 (韩立's abode) is a mother-and-child pair of "
     "pillars; 听云亭 sits on a col of the plateau."),
    ("绿踪沼泽 地堑", "lacustrine", {"ellipse": [4700, 1900, 2000, 1500, 0]},
     "The swamp on the 古剑门–落云宗 border (canon, with miasma): a graben dropped between two faults, poorly drained, "
     "filled with lake and swamp mud. 地脉灵眼 sits on its eastern fault — spirit veins follow deep faults."),
    ("南山 喀斯特", "limestone", {"ellipse": [19500, 11800, 13500, 5200, 5]},
     "The range south of 韵州城: a limestone platform — 峰丛 cones on the uplands, 峰林 towers on the 韵州 plain at the "
     "water table (the Guilin–Yangshuo picture round a city)."),
    ("封日城 花岗岩岬", "granite", {"ellipse": [35700, -13900, 2800, 3200, 0]},
     "The 闵州 headland that 封日城 guards: a granite headland, sea cliffs and stacks (崂山-like)."),
    ("东海岸 喀斯特", "limestone", {"ellipse": [82000, -20300, 4500, 3800, 0]},
     "Coastal limestone hills west of 水影宗: towers at sea level, the drowned ones become stacks (下龙湾-like)."),
    ("水影宗 喀斯特湖", "limestone", {"ellipse": [89000, -22500, 5500, 5500, 0]},
     "水影宗 by the sea: a karst lake ringed by towers (the demo's natKarst sect, kept)."),
    ("倪航斋 黄土", "loess", {"ellipse": [96500, -8500, 7000, 6500, 20]},
     "倪航斋's 乾土功 country: loess tablelands (塬) and gullies draped over the eastern range (the demo's natLoess)."),
    ("鸾鸣宗 丹霞盆地", "redbed", {"ellipse": [70700, 6300, 9000, 6000, -10]},
     "鸾鸣宗 on the eastern plain: a red-bed basin with Danxia hills — 丹 'cinnabar', 霞 'rosy cloud': red walls for a "
     "phoenix (鸾) sect. Uplift edits raise the hills the operator steps into mesas."),
    ("七灵岛 火山岛弧", "volcanic", {"ellipse": [29500, -49500, 13500, 7500, 0]},
     "七灵岛 and 灵鳌/灵龟/灵凤: newly risen islands south of 大漩涡 → a young volcanic island group; 灵龟 a caldera ring."),
]

STRUCTURES = {
    "folds": [
        {"name": "云梦褶皱带", "ellipse": [-1500, 500, 26000, 10000, 15], "strike": 15, "dip": 35, "bed": 300, "wave": 9000,
         "amp": 300, "contrast": 0.6, "note": "ENE-striking fold belt (the demo's relief.trend = 15°): strike ridges, trellis drainage"},
        {"name": "东山褶皱带", "ellipse": [94000, -15000, 9500, 14500, 30], "strike": 30, "dip": 40, "bed": 260, "wave": 8000,
         "amp": 250, "contrast": 0.6},
    ],
    "faults": [
        {"name": "绿踪西缘断层", "pts": [[3300, 300], [3500, 1800], [3300, 3400]], "up": "W", "throw": 0.35, "width": 260, "reach": 4000, "tip": 700,
         "note": "the graben is only as long as the swamp basin, so the ridge south of it — 落云宗's dragon vein — is not dropped"},
        {"name": "绿踪东缘断层", "pts": [[6300, 300], [6100, 2000], [6400, 3400]], "up": "E", "throw": 0.35, "width": 260, "reach": 4000, "tip": 700},
        {"name": "飞练断崖", "pts": [[-7200, -1200], [-4200, -1750], [-1300, -2050]], "up": "N", "throw": 0.4, "width": 200, "reach": 3500,
         "note": "the south-facing scarp 飞练崖's falls drop from"},
        {"name": "云梦北缘断层", "pts": [[-26000, -6800], [-9000, -7700], [8000, -6600], [23000, -6200]], "up": "S", "throw": 0.3, "reach": 9000},
        {"name": "东山山前断层", "pts": [[85000, -30000], [85800, -16000], [86800, -3000]], "up": "E", "throw": 0.3, "reach": 8000},
    ],
    "volcanoes": [
        {"name": "百巧院 古破火山口", "x": -10819, "z": 3174, "r": 3800, "h": 260, "kind": "caldera", "floor": 0.35},
        {"name": "灵鳌岛", "x": 33316, "z": -43580, "r": 1000, "h": 290},
        {"name": "灵凤岛", "x": 27329, "z": -54613, "r": 800, "h": 380},
        {"name": "灵龟岛", "x": 35280, "z": -53254, "r": 1000, "h": 170, "kind": "caldera", "floor": 0.2},
        {"name": "七灵岛 主岛", "x": 30014, "z": -48695, "r": 650, "h": 240},
    ],
    "uplift": [
        {"name": "云梦东脉 龙脉", "pts": [[-630, -3140], [-19, 677], [1000, 4380], [3000, 4140], [5000, 4860], [7000, 4860],
                                       [8000, 1340], [10000, 1620], [11477, -658]], "width": 900, "du": 0.3,
         "note": "落云宗's dragon vein: from the 祖山 above 古剑门 down the 主脉, round the south of 绿踪沼泽 (the saddle at "
                 "x 5000 is its 过峡) and up to the 东脉. Without it the solve's rivers cut the divide (fengshui.py: col −156 丈)"},
        {"name": "鸾鸣丹霞丘", "x": 70700, "z": 6300, "r": 5500, "du": 0.5,
         "note": "Danxia relief 100–300 m (r3 S3/S29) → 30–90 丈 real, ×2 for the walls of a phoenix sect"},
        {"x": 64000, "z": 9000, "r": 2500, "du": 0.35},
        {"x": 76500, "z": 3000, "r": 2600, "du": 0.35},
    ],
    "glacier": {"ela": 650, "note": "a Pleistocene snow line below today's (the demo's snowLine 820): cirques and short troughs on 云梦's top"},
}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", default=os.path.normpath(os.path.join(HERE, "..", "..", "godot", "data", "world")))
    ap.add_argument("--out", default=os.path.join(HERE, "plan"))
    ap.add_argument("--px", type=float, default=80.0, help="丈 per plan pixel")
    ap.add_argument("--seed", type=int, default=7)
    a = ap.parse_args()
    w = World(a.data)
    R = w.rect
    pw = int(round((R["x1"] - R["x0"]) / a.px)); ph = int(round((R["z1"] - R["z0"]) / a.px))
    xs = R["x0"] + (np.arange(pw) + 0.5) * (R["x1"] - R["x0"]) / pw
    zs = R["z0"] + (np.arange(ph) + 0.5) * (R["z1"] - R["z0"]) / ph
    X, Z = np.meshgrid(xs, zs)
    # the base map: folded metamorphic rock under the ranges, alluvium on the plains and the sea floor
    hj = np.clip(((Z - w.z0) / w.cell).round().astype(int), 0, w.H - 1); hi = np.clip(((X - w.x0) / w.cell).round().astype(int), 0, w.W - 1)
    rel = box_blur(np.maximum(w.height, 0), 3)[hj, hi]
    ids = np.where(rel > 25, LITHO["metamorphic"]["id"], LITHO["alluvium"]["id"]).astype(np.uint8)
    # region contacts wander like real ones: the shapes are domain-warped
    WX, WZ = noise.warp(X, Z, 700.0, 2600.0, a.seed + 13)
    for name, rock, shape, _ in REGIONS:
        m = region_weight(dict(shape, feather=1.0), WX, WZ) > 0.5
        ids[m] = LITHO[rock]["id"]
    os.makedirs(a.out, exist_ok=True)
    write_png(os.path.join(a.out, "lithology.png"), rgb_from_ids(ids))
    g = {"version": 1, "seed": a.seed, "px": a.px,
         "legend": {k: {"color": v["color"], "cn": v["cn"]} for k, v in LITHO.items()},
         "regions": [{"name": n, "rock": r, **s, "why": y} for n, r, s, y in REGIONS],
         "structures": STRUCTURES, "operators": {}, "lithology": {}}
    with open(os.path.join(a.out, "geology.json"), "w", encoding="utf-8") as f:
        json.dump(g, f, ensure_ascii=False, indent=1)
    counts = {k: round(float((ids == v["id"]).mean()) * 100, 1) for k, v in LITHO.items()}
    print("plan", pw, "×", ph, "→", a.out, counts)


if __name__ == "__main__":
    main()
