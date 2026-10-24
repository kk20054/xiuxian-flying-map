> **Research dossier** (appendix to [docs/terrain](../README.md)). Compiled with limited web access: most page
> contents and numbers come from search-engine extracts of the linked pages, and every item carries its source tag
> ([V] page opened, [S#]/[N]/[H]/[W]/[F]/[D] source kinds, "(unverified — from memory)", "(derived)"). Check a page
> before relying on a single number or quote.

# 《凡人修仙传》 geography dossier: 天南 › 溪国 › 云梦山, plus the 天道盟 coast and 七灵岛

Research for the terrain rebuild of `xiuxian-flying-map`. Compared against `docs/02-world-data-and-coordinates.md` §6.1 and
`godot/data/world/places.json` (lead / body / note). The repository was not modified.

---

## 0. Method, source levels and caveats (read this first)

**Access in this session**
- **WebFetch failed for every host.** Baidu Baike, moegirl, bilibili, Wikipedia, qidian and wuxiaworld all gave `getaddrinfo ENOTFOUND`.
- **Shell egress was blocked.** `curl` got 403 from the egress proxy for Baike, moegirl, fandom, bilibili and Wikipedia.
- **GitHub was not available.** Attaching `youlanstudio/RMJI` (a "凡人修仙传相关内容" repo) was denied by the permission classifier. I did not try to get around that.
- **WebSearch worked** for about 45 queries. Then the shared per-turn search budget ran out, so some items are still unsearched (see §6).
- **Consequence:** every "quote" below is an excerpt as the search engine returned it in its result summary for the linked page. I could not open any page to check exact wording, punctuation or the full context.
  - Some excerpts from the traditional-Chinese site hjwzw came back in simplified characters, which shows the tool rewrites text.
  - So treat the quotes as near-verbatim at best. Before anything ships, they need checking against the page.
- I did not invent any chapter numbers. Chapter numbers differ between sites (see the next point), so each one is cited with its site.

**Chapter numbering differs by site.** The same chapter carries different numbers:

| Site | Chapter number | Title |
|---|---|---|
| hjwzw | 第594章 | 落云宗 |
| wuxiaworld | ch. 597 | Drifting Cloud Sect |
| qidian | 第596章 | 入门（上） |
| wuxiaworld | ch. 599–600 | Entering the Sect (1)/(2) |

**Source-level tags used below**

| Tag | Meaning | Weight |
|---|---|---|
| **[N]** | Novel text: a chapter page on hjwzw (黄金屋) or the wuxiaworld official English translation, or a qidian catalog title | Canon |
| **[H]** | 《凡人必备手册》第二版 (地理篇 / 宗门篇 / 年历表). A reader-compiled handbook that appears as "chapters" in the novel's own qidian chapter list (book 107580). Mirrors: quanben5, sina blog, bookresource.qq | Near-canon. It condenses the novel and is the direct source of most of our current lore lines |
| **[W]** | Encyclopedia or fan wiki: Baidu Baike, or the English fan wiki rmji.fandom.com, which uses "Dreamcloud Mountains / Drifting Cloud Sect / Spirit Well Tree" | Secondary |
| **[F]** | Fan articles (sohu, 163, qq news, zhihu, weqoocu 酷口家数字花园) | Weak |
| **[D]** | The 2020 donghua: TheTVDB synopses and episode-recap news | Donghua only |
| **[M]** | My own memory, **unverified** | Use only as a lead |

**About the map itself.** Positions and coastlines come from the fan map "selfmate 人界舆图" (map.selfmate.cn); see `demo/index.html` L277 and L391. The demo's own comment (L413–414) says which landmarks are which:
- **selfmate's own:** 天柱山 and the 云梦山 main summit.
- **"the lore's":** 绿踪沼泽, 灵眼之树 and 子母峰.
- **The demo's route stops:** the six 途中地名, each placed "within a few hundred 丈 of the straight line between two sects".

---

## 1. Verdict table

| # | Place | Canonical? | Best source found | One-line finding |
|---|---|---|---|---|
| 1 | 古剑门 | **Novel** | [H] 宗门篇, [F], [D] | 云梦山 **主脉**; 御剑; 镇派绝学 太白剑诀; 大长老 金武环 (三口金剑); 火龙童子. I found no landscape description. |
| 2 | 落云宗 | **Novel** | [H], [W] Baike, [N] wuxiaworld | 云梦山 **东脉**; 丹道 (定灵丹); lowest entry bar. Six 奇峰 天泉/火云/白凤/幻石/锁烟/隐剑; the sect's restriction formation is mist-filled. |
| 2a | the six peaks | **Novel/[H]** | [H] 地理篇, [W] rmji | The handbook lists all six. rmji lists a **"Main Peak"** and leaves out 锁烟 (see conflict C2). |
| 3 | 百巧院 | **Novel** | [H], [N] hjwzw 乾坤塔, [N] wuxiaworld 599 | 云梦山 **西脉**; 炼器. A mountain-girt plaza, a five-storey tower like a giant 石塔 (~百丈), a cliff riddled with holes, and a 地肺火池 inside the mountain. |
| 4 | 云梦山 | **Novel** | [H], [W] | 溪国西部的灵气圣脉 with the 灵眼之树 deep inside. Baike/rmji put it in **湳州** (Nan Province), western 溪国. |
| 5 | 天柱山 | **[H] (novel text not seen)** | [H] 地理篇 | West of 云梦山: "孤零零一座陡峭山峰，高有万余丈". |
| 6 | 灵眼之树 | **Novel** | [N] hjwzw 第628–629章 | The tree is inside a **huge stalactite cavern** (數百丈 × 數百丈, 二三十丈 high) amid stone columns. It is an **arm-thick, pale-green straight stem that looks like a 青石柱**, under a pale-gold light dome. |
| 7 | 绿踪沼泽 | **Novel** | [H] 地理篇, [N] qidian catalog chapter title | "第五卷 名震一方 第六百零四章 绿踪沼泽". It lies on the 落云宗–古剑门 border: remote, with miasma all year. |
| 8 | 子母峰 | **Novel ([H])**; donghua differs | [H] 地理篇, [D] | [H]: 韩立's 洞府 in 落云宗. Donghua: he gets **天泉峰 + two 次峰**, reportedly renamed **青竹峰**. Our "一主三小" shape is unverified. |
| 9 | 听云亭 | **Not found → demo invention** | demo L413–414 | A route stop. |
| 10 | 飞练崖 | **Not found → demo invention** | demo L413–414 | A route stop. |
| 11 | 古修洞府 | **Not found as a 云梦山 place → demo invention** | demo L413–414 | A route stop. "古修士洞府" is a generic novel trope. |
| 12 | 笋石林 | **Not found → demo invention** | demo L413–414 | A route stop. Note that canon *does* have a 石林 of columns, but it is inside the 灵眼之树 cavern. |
| 13 | 迎仙松 | **Not found → demo invention** | demo L413–414 | A route stop. |
| 14 | 地脉灵眼 | **Not found as a place → demo invention.** The *term* 灵眼 is canon. | hjwzw has a chapter titled 第二百二十章 靈眼之泉 | A route stop. |
| 15 | 韵州城 | **Demo invention** (places.json says so itself) | — | — |
| 15b | 韵州 | **Unverified** | — | I could not confirm the "原著第627章" mention, and no search found 韵州 in the text. Canon puts 云梦山 in **湳州** (C4). |
| 16 | 溪国 | **Novel** | [H] 地理篇 | The northernmost state of 天南, slightly smaller than 越国, with 7 州. 闵州 is the largest and borders 无边海. |
| 17 | 天道盟 | **Novel** | [H] 宗门篇, [F] | A loose league of about a dozen northern states formed against 正道/魔道. Members include 落云宗, 百巧院, 古剑门, 鸾鸣宗… |
| 18 | 无边海 | **Novel** | [H], [F] | The sea north of 天南 / 溪国. |
| 19 | 封日城 / 闵州 | **[H] (novel text not seen)** | [H] 地理篇 | 闵州 is 溪国第一大州 and borders 无边海; 封日城 is its 州府 and largest city. Its layout is the demo's. |
| 20 | 鸾鸣宗 | **Novel ([H])** | [H] 宗门篇, [F] | One of the 天道盟三大宗门; 龙晗 and 凤冰 are 元婴中期顶峰. Location and terrain are the demo's. |
| 21 | 倪航斋 | **Probably novel ([H] mention)** | [H] 宗门篇 (per search summary) | It appears beside 鸾鸣宗/古剑门 in the handbook. I verified no details. Location and terrain are the demo's. |
| 22 | 水影宗 | **Unverified** (not searched; budget gone) | — | The 徐长景 detail is unverified. Location and terrain are the demo's. |
| 23 | 七灵岛 | **Novel** | [H] 地理篇, [W] Baike 至阳上人 | Seven islands that surfaced after the vortex's qi purified the sea. |
| 24 | 灵鳌岛 | **Novel** | [H], [W] | "三大修士送于韩立之岛". Baike spells it **灵鳖岛**. |
| 25 | 灵龟岛 | **Novel** | [H] | Occupied by 太真门. |
| 26 | 灵凤岛 | **Novel** | [H] | Occupied by 合欢宗. |
| 27 | 大漩涡 | **Novel** | [H], [W] | Formed in the 无边海 near 溪国 when the eye of an ancient sealing array was destroyed by 古魔; it spews pure qi. |

---

## 2. Place-by-place

### 2.1 云梦山 (the range)
- **Canon status:** novel.
  - [H] 地理篇: 溪国西部的灵气圣脉, and deep inside it, reportedly, stands a legendary 灵眼之树 ([qidian 地理篇](https://m.qidian.com/chapter/107580/27199943/); mirror [quanben5](https://www.quanben5.com/n/fanrenxiuxianchuan/3687.html)).
- **Where it is**
  - [W] Baike 落云宗 places the sect in "天南地区溪国**湳州**云梦山脉" ([Baike 落云宗](https://baike.baidu.com/item/%E8%90%BD%E4%BA%91%E5%AE%97/61133759)).
  - [W] rmji: the range is "situated in the Nan Province located in the western portion of the State of Xi" ([rmji Dreamcloud Mountains](https://rmji.fandom.com/wiki/Dreamcloud_Mountains)).
  - [H]: 天柱山 is west of it.
- **Structure: three "veins".** [H] 宗门篇:
  - 古剑门 holds the **主山脉**, 落云宗 the **东脉** and 百巧院 the **西脉** ([qidian 宗门篇](https://m.qidian.com/chapter/107580/27199947/)).
  - [N] wuxiaworld ch. 599 talks of "the three sects controlling the sacred spirit veins", with 百巧院's share "in the west" ([wuxiaworld 599](https://www.wuxiaworld.com/novel/rmji/rmji-chapter-599)).
- **Climate and look**
  - [F] "终年云雾缭绕宛如仙境" and "绵延千里" come from a fan site ([weqoocu 云梦山](https://weqoocu.com/1809.html)). I did not see them in the novel text.
  - The 湳州 terrain description ("丘陵密林多不胜数… 沼泽瘴气时常出没"; "溪國七州中第二大州，地處偏遠的溪國西部") came back in **one** search summary. A follow-up exact-phrase search found nothing, so it is **unconfirmed**. Another summary even mixed it up with 越国's 建州.
- **Politics shapes the land**
  - [W] rmji: the grand elders' sparring sets the three sects' relative rank, and the rank decides "the division of mountain peaks and shared cultivation resources".
  - [F]: the ranking flipped after 韩立 beat 金武环, putting 落云宗 first, 古剑门 second and 百巧院 last.
- **[F] History:** 三宗 have split the range since a 动乱 about 200 years earlier (weqoocu). Unverified.

### 2.2 古剑门
- **Canon status:** novel. [H] 宗门篇: on the 云梦山 主山脉; "擅长御剑之术，镇派绝学为太白剑诀" (as quoted in the search summary of [qidian 宗门篇](https://m.qidian.com/chapter/107580/27199947/)).
- **Character**
  - [F] It recruits by aptitude: 古剑门 and 百巧院 "招收弟子的要求高很多，注重看灵根资质", which is why the 伪灵根 韩立 could not join ([163](https://www.163.com/dy/article/K1SDQJ5K05359PNN.html) / [qq](https://news.qq.com/rain/a/20250612A07RCX00)).
  - [F] It had 3–4 元婴 ([weqoocu 古剑门](https://weqoocu.com/2129.html)).
- **People:** 大长老 **金武环 / 金老怪**, 元婴中期, "本命法宝三口金剑" ([H] 次要人物, per search summary; [qidian 次要人物1](https://m.qidian.com/book/107580/27199901.html)). 元婴长老 **火龙童子** ([F]; [D] ep. 153).
- **Events**
  - At 百巧院's 乾坤塔认主 ceremony, 韩立 defeated 金武环 with 乾蓝冰焰 ([F] sohu; [H] 年历表 for the timing: 252岁, 元婴中期, after 灵渺园). The 云梦三宗 ranking was reordered.
  - [D] ep. 153: on the way to the 灵眼之树 after the 三宗大比, the party meets 火龙童子 ([TheTVDB](https://thetvdb.com/series/384640-/episodes/11252089)).
- **Landscape:** **none found.** No search returned a description of 古剑门's mountain.
  - Our "太白峰 (highest point)", the 太白/剑阁/东岭 peaks, the snow, the granite and the "灵石矿 ceded" are not attested (C6).
  - 太白 is attested only as the sword art 太白剑诀.

### 2.3 落云宗 (+ six peaks, fog barrier)
- **Canon status:** novel.
  - [H] 宗门篇: on the 云梦山东脉; "功法杂而不精", but its 炼丹术 is well known.
  - [W] Baike: "与古剑门、百巧院并称溪国三大修仙大派，三派同属于天南地区修士联盟——天道盟"; "那有助于修士安心定魂和减少心魔入侵的定灵丹，也只有落云宗几位长老能炼制".
  - [W] Baike: before 韩立 it was the weakest of the three, with only 程天坤 and 吕洛 at 元婴初期.
- **Six peaks**
  - [H] 地理篇 (sina mirror): 落云宗六奇峰 are 天泉 (峰主 辛师祖, 副 宇山安), 火云 (段, 黎), 白凤 (宋玉, 副 柳眉), and 幻石 / 锁烟 / 隐剑 ("不详"). 洗心殿 is where 天泉峰 disciples meet ([sina 地理篇](https://blog.sina.com.cn/s/blog_b3af6a390101d57n.html); [sina 宗门篇](https://blog.sina.com.cn/s/blog_b3af6a390101d57l.html)).
  - [F] White Phoenix: "白凤峰… 位于落云宗的最东边" (bilibili fan article, as summarised; [bilibili opus](https://www.bilibili.com/opus/1133201110745481220)).
  - [W] rmji ([Drifting Cloud Sect](https://rmji.fandom.com/wiki/Drifting_Cloud_Sect)) lists **Main Peak, Dayspring, White Phoenix, Firecloud, Hidden Sword, Illusion Stone**. 锁烟 is missing and a "Main Peak" stands in its place.
    - **Main Peak:** the tallest ("10+ km" in the summary; unclear). "The top half of the mountain is enveloped in a faint purple fog concealing the residences of the elders and sect master." **The lower half held a city.**
    - **White Phoenix:** "the shortest peak, situated far away from the other peaks in solitude"; the most beautiful; men need the lord's permission to enter.
    - **Dayspring and Firecloud:** known for talismans (Dayspring for pills too).
- **Fog barrier**
  - [N] wuxiaworld ch. 1173: at the sect's restriction formation, "the mist permeating throughout the entire restriction tumbled before slowly dissipating", and "The entire formation around the sect was being deactivated." ([wuxiaworld 1173](https://www.wuxiaworld.com/novel/rmji/rmji-chapter-1173/)).
  - So the canon gives a **mist-filled protective formation** around the sect.
  - Our "遮断神识的白雾，雾里却是…草木葱茏、鸟语花香" is **not verified**. It may come from Baike, which I could not open.
- **韩立's arc**
  - **Why 落云宗, not 百巧院:** [N] ch. 599: "the most optimal choice for Han Li wasn't the Drifting Cloud Sect but the Hundred Possibilities Sect, which was known for tool refinement". He passed on it because "a union of the five most powerful cultivator clans … had monopolized the sect's allocated section of the Dreamcloud Mountain's spirit veins in the west".
  - **How he got in:** [F]/[D]: he hid his cultivation, posing as a 炼气期 disciple, and guarded a 药园 under 慕沛灵 (筑基). [N] ch. 600 is the entrance test (Senior Martial Brother Qiu).
  - **Formed his 元婴** in the sect, then [D] ep. 156: 程天坤 and 吕洛 court him.
  - **Became an elder** ([N] wuxiaworld ch. 642 "Sect Elder").
  - **Later rise:** he beat 金武环 and 落云宗 rose to first among the three. Under 韩立, 落云宗 grows into 天南's leading sect.
    - The novel's ending for 落云宗 exists in **two versions**. The author amended it; see wuxiaworld "[Amendments to Chapter 2448](https://www.wuxiaworld.com/announcements/rmji/amendments-to-chapter-2448)" ("one Nascent Soul Stage elder after another") and the [163 article](https://www.163.com/dy/article/HMRHGM600537HSMD.html).
  - **Spies:** [F] 正魔两道 planted spies in the three sects to take the 灵眼之树's 醇液 and revive a withered 玄天仙藤 ([sohu](https://www.sohu.com/a/919262421_122477903)).
- **Donghua [D]**
  - The party (with 紫灵 and 梅凝) arrives as the three sects are recruiting ([qq](https://news.qq.com/rain/a/20250531A06IQ000)).
  - ep. 158 "重返天南6" (2025-08-30): "程天坤吕洛二人前来帮韩立选择新洞府,赠其天泉峰和两座次峰" ([TheTVDB](https://thetvdb.com/series/384640-/episodes/11300780)).

### 2.4 百巧院
- **Canon status:** novel.
  - [H] 宗门篇: on the 云梦山西脉; good at refining 法器 of every grade, and holds the methods for several legendary top 法宝. 燕家's 乾坤塔 符宝 comes from them.
  - [F]: its disciples come mostly from 世家.
  - [N] ch. 599: five clans monopolise its western vein share.
- **Landscape** ([N] hjwzw 第八百六十三章 乾坤塔, [hjwzw](https://tw.hjwzw.com/Book/Read/1644,410156); excerpts as returned):
  - The party enters through the 禁制大陣: "韓立等人穿過禁制大陣，進入到了百巧院的上空".
  - They do *not* land at "四面环山的中间广场". They land on "一面依山壁而建的巨大平台".
  - On it: "平台中间有一座高约百丈的阁楼，足有五层之多，猛一看不像楼台，倒像一座巨大石塔".
  - "阁楼后方的山壁上到处都是密密麻麻的大小孔洞，里面不时有百巧院的弟子进进出出".
  - 程天坤 explains that deep inside the mountain is a top-grade **地肺火池**, which is why the 炼器室 and senior disciples' 洞府 are cut into the 山腹. The 付 elder flies them to the top of the cliff.
  - 乾坤塔 is one of the 三大镇院之宝.
- **Event:** the 乾坤塔认主 ceremony, hosted by 大长老 烈火 (天火决, [H] 次要人物), where 韩立 beats 金武环.

### 2.5 灵眼之树
- **Canon status:** novel. [H]: one of the 三大神木; about every 200 years 醇液 seeps from its roots.
- **Location and landform.** [N] hjwzw **第628章 靈眼之樹** ([hjwzw](https://tw.hjwzw.com/Book/Read/1644,409917)) and **第629章 詭變** ([hjwzw](https://tw.hjwzw.com/Book/Read/1644,409918)):
  - A giant **钟乳石洞窟** full of standing columns that form a maze. The tree is at the centre of the 石林.
  - "此石窟長寬數百丈，高二三十丈". That is about 1–2 km across and 65–100 m high, at 1 丈 ≈ 3.3 m.
  - The tree: "這根手臂粗細、顏色淡綠地筆直東西，說它是一根青石柱，恐怕大部分人都會相信".
  - "石柱外面，更是有一層淡金色光罩，將它從頂部到根部全都罩的嚴嚴實實". The roots are inside the dome too (ch. 629). 韩立 sends 银月 to slip in **from underground** to take a piece of 灵根.
- **Access**
  - [F] (fan article, apparently quoting the text): "从传送阵上下来后，韩立便发现四处一片白雾茫茫…将通往灵眼之树的道路用阵法遮蔽了" ([sohu](https://www.sohu.com/a/913495037_122415633)).
  - [F]: the top ten of the 三派大比 may go "去圣山" to wipe their eyes with 明清灵水.
  - [F]: on a 石台 behind the tree 韩立 found the recipes for 定灵丹 and 明清灵水.
- **Nectar rules.** [W] rmji: the Sword Trial Assembly winner "obtains half of the wine nectar. The remaining two sects each receive a quarter."
- **Donghua:** [D] ep. 154 is the 醇液 fight. ep. 155: 韩立 slips into the 灵眼之树 site while 天道盟 is busy fighting the attackers ([weqoocu 154](https://weqoocu.com/2207.html)).

### 2.6 绿踪沼泽
- **Canon status:** novel.
  - [N] qidian catalog: "第五卷 名震一方 第六百零四章 绿踪沼泽", followed by 第六百零五章 狐现 and 第六百零六章 追匿 ([qidian catalog](https://m.qidian.com/book/107580/catalog/)).
  - [H] 地理篇: on the border of 落云宗 and 古剑门 territory; remote; miasma all year ([sina 地理篇](https://blog.sina.com.cn/s/blog_b3af6a390101d57n.html)).
- **Events (inferred, not read)**
  - The chapter titles and the [H] 年历表 entry ("追踪雪云狐，遭遇尸魈… 银月现身吞噬尸魈元神") point to the early 落云宗 mission. 韩立 hunts what he thinks is a 雪云狐 but is really a 四瞳 fox. [W] rmji ([Ling Long](https://rmji.fandom.com/wiki/Ling_Long)) says 雪玲/银月 eats its soul and gains a body.
  - The donghua version (ep. 148): a 灵狐 with four pupils, a 五行迷踪阵, and 韩立 using 玉如意 土遁 ([weqoocu 148](https://weqoocu.com/1740.html)).

### 2.7 子母峰
- **Canon status:** novel ([H] 地理篇: 韩立在落云宗的洞府). [F] says he later failed a 化神 breakthrough in seclusion at 子母峰.
- **Shape:** unverified. Our "一座主峰四周环着三座低矮小峰" was **not** found. The name means a "mother" peak with "child" peak(s).
- **Donghua:** 天泉峰 plus "两座次峰" ([D] TheTVDB ep. 158). A recap article (one of [qq 2025-09-03](https://news.qq.com/rain/a/20250903A069BJ00) / [163](https://www.163.com/dy/article/K0VQARU205359PNN.html); the summary did not say which) states "程长老就把天泉峰送给韩立，改名为青竹峰，原来的天泉峰搬到其他山峰上". A Douban review of the donghua mentions "这青竹峰上".
- **Placement:** "east of 落云宗" is the demo's choice (demo L414).

### 2.8 天柱山
- **Canon status:** [H] 地理篇: "天柱山：云梦山西边，孤零零一座陡峭山峰，高有万余丈". One garbled summary also said "高数百丈", so check the page.
- I saw no novel passage. The cloud belt around its waist in our lore is the demo's.

### 2.9 溪国, 闵州, 封日城, 湳州, 韵州
- **溪国** [H]: "天南地区最北部的国家,面积比越国稍小一些,被化分为了七个州府,其中闵州紧邻无边海,是溪国七州最大的一州".
- **闵州** [H]: 溪国第一大州, 紧邻无边海.
- **封日城** [H]: 闵州的州府, 也是闵州最大的一座城市. I did not search whether the novel text names it.
- **湳州**: [W] Baike/rmji: 云梦山 is in it, in western 溪国. The terrain claim is unconfirmed (§2.1).
- **韵州**: unverified. One search summary hinted that a 韵州 entry exists in [H] 地理篇 as a 溪国 州, but nothing confirmed it.
- **Other [H] 地理篇 entries seen in passing:** 溪州 (越国's smallest 州), 建州 (越国's second largest, 多山川丘陵), 湳郡 (大晋).

### 2.10 天道盟 and its eastern sects
- **天道盟** [H] 宗门篇: a fairly loose league formed to resist 正道 and 魔道. Main sects: 落云宗, 百巧院, 古剑门, 鸾鸣宗…
- [F]: it is made of "北方十几个国家" ([bilibili opus](https://www.bilibili.com/opus/1109413516027101201); [toutiao](https://www.toutiao.com/zixun/7506329610293119016/)).
- [F] One fan map lists 花雨国, 刹云国 and 溪国 among its states ([xuanhuan.skin 天南舆图](https://xuanhuan.skin/maps/rmjz-tiannan/)). Unverified.
- **鸾鸣宗:** [H] one of the 天道盟三大宗门. [F] the strongest, with 龙晗 and 凤冰 at 元婴中期顶峰 ([163](https://www.163.com/dy/article/KG8JKDIH0552H59B.html)).
- **倪航斋:** appears in [H] 宗门篇 next to 鸾鸣宗/古剑门 (per search summary only).
- **水影宗:** not checked.
- **Unverified details:** 鸾鸣宗 "主持边界大战", the 鸾鸣 "联合之术" imagery, 倪航斋's 况 elder and 乾土功, and 水影宗's 徐长景.
- **Demo inventions:** all three sects' locations (鸾水, 东部山地, 天水入海处, "封日城以东") and terrain (river-plain hill, loess 塬, tower-karst lake). Nothing I found locates these sects.

### 2.11 无边海, 大漩涡, 七灵岛 and its islands
- **大漩涡** [H]: "溪国附近的无边海面上，上古封印大阵阵眼被破坏后形成的漩涡。漩涡向外喷发大量精纯灵气。"
- **七灵岛** [H]: "大漩涡喷出的灵气净化海面后，浮出的七座灵岛。"
  - 灵凤岛: "七灵岛之一，被合欢宗占据。"
  - 灵龟岛: "七灵岛之一，被太真门占据。"
  - 灵鳌岛: "七灵岛之一，三大修士送于韩立之岛。" (All as quoted in the search summary of [qidian 地理篇](https://m.qidian.com/chapter/107580/27199943/).)
- **Event** [W] Baike 至阳上人: 古魔 血焰 broke the ancient array on the 无边海 and sealed qi leaked out. 至阳 went to 溪国 to invite 韩立, who had just returned to his sect. 韩立 went to 七灵岛 to help seal the 阵眼, and "至阳等人将灵鳖岛赠与韩立". Also: "太真门本是大晋真极门分支" ([Baike 至阳上人](https://baike.baidu.com/item/%E8%87%B3%E9%98%B3%E4%B8%8A%E4%BA%BA/9818844)).
- **Timing** [H] 年历表: 252岁, 元婴中期, out of 灵渺园, back at 落云宗; then the 百巧院 ceremony and 七灵岛.
- **Which islands selfmate names:** selfmate gives names to 4 of the 7 islands (demo L289). I found no canonical names for the other three.
- **Where they sit:** canon says only "near 溪国" in the 无边海. Putting the islands *south of* the vortex is the demo's choice.

---

## 3. Macro: 天南 and its neighbours

- **Four powers of 天南** [F]: **魔道六宗**, **正道盟**, **九国盟**, **天道盟**. 天道盟 is the northern league ([sohu](https://www.sohu.com/a/932489039_122415633); [sohu](https://www.sohu.com/a/932529650_122094388)).
  - [M] 魔道六宗 = 合欢宗, 鬼灵门, 御灵宗, 天煞宗, 千幻宗, 魔焰门, with 合欢老魔 as chief. The fan summary ties 魔道's leader to 天罗国's 合欢老魔.
  - [F] 九国盟 includes 北凉国, 虞国, 丰原国 and others; its leader is 魏无涯.
- **Bounds**
  - [F] "北接无边海，西邻极西之地，南靠慕兰草原" ([163](https://www.163.com/dy/article/K73V9KI80552H59B.html), [Baike 天南](https://baike.baidu.com/item/%E5%A4%A9%E5%8D%97/67059055) per summary).
  - **Contradiction:** another summary has 九国盟 resisting "北方慕兰草原". Where 慕兰草原 lies is **unresolved**. Most fan maps put it on the 九国盟 side of 天南, away from 溪国.
  - [F] 慕兰人 (慕兰族, 突兀族) live on a resource-poor steppe and have invaded repeatedly; 九国盟 repelled them with the 阗天城 上元灭光阵.
- **越国** [F]: a mid-sized state in **central** 天南 with seven sects (黄枫谷, 掩月宗, 灵兽山… [M] plus 清虚门, 化刀坞, 巨剑门, 天阙堡). Neighbours are 元武国 and 车骑国, with the 金鼓原 border field ([F]).
  - [H] 韩立 was born in 越国镜州青牛镇.
- **溪国** [H]: the northernmost state, on the 无边海, which makes it the 天道盟 heartland.
  - From the north: 闵州 is the large coastal province (封日城); 湳州 is the remote western one (云梦山).
- **Other regions of 人界** [F]: 天南, 天澜草原, 大晋 and 乱星海 ([163](https://www.163.com/dy/article/K73V9KI80552H59B.html)). [F] also asks how the 慕兰 relate to 天澜 ([toutiao](https://www.toutiao.com/article/7674967454442848804/)).
  - **乱星海:** "overseas" (第四卷 风起海外 [M]). It is linked to 天南 by an **上古传送阵 in an underground cave in 越国's 大峡谷**: [N] hjwzw 第1198章 星宫來訊, as summarised ([hjwzw](https://tw.hjwzw.com/Book/Read/1644,591673)).
  - **大晋** [M]: a vast, far stronger empire, a very long way off and reached only by long-range teleport. [W]: 太真门 is a lost branch of 大晋's 真极门.
- **Context for the 七灵岛 owners** [M/inference]: "三大修士" = the three great late-元婴 cultivators of 天南 ([M] 至阳上人, 合欢老魔, 魏无涯). That would fit 合欢宗 (魔道) holding 灵凤岛, 太真门 holding 灵龟岛, and 韩立 (天道盟) receiving 灵鳌岛. Unverified.

## 4. 灵脉 / 灵眼 / 灵气 and how sects choose sites

**What the text shows**
- **A 圣脉 is shared out.** 云梦山 is a 灵气圣脉 ([H]). The three sects split its "sacred spirit veins" by sub-range: 主脉, 东脉, 西脉 ([N] 599).
  - Inside a sect, families can **monopolise a vein section**. 百巧院's west share is held by five clans ([N] 599).
  - The split of peaks and resources is **re-negotiated by power**, through grand-elder duels ([W] rmji).
- **Qi sources are placed underground.**
  - 百巧院 builds its forges and senior abodes *into* the mountain because a 地肺火池 lies deep inside ([N] 乾坤塔). This is the clearest site-choice logic: put the workshop on the earth-fire.
  - The 灵眼之树 grows in a sealed **cavern** fed by the range's veins ([W] rmji: "spirit veins feed the Spirit Well Tree"; [N] 628 for the cavern).
- **Protected sites are hidden by mist formations.** The 灵眼之树 path is mist-veiled ([F] quoting text). 落云宗's restriction formation is full of mist ([N] 1173). Mist = 禁制/阵法 is a canon visual cue.
- **The term 灵眼 is canon** (e.g. hjwzw 第220章 靈眼之泉): a spot where a vein's qi wells up. 地脉灵眼 as a *concept* therefore fits canon; as a named place it is the demo's.

**From memory, unverified [M]**
- 洞府 value is graded by local qi density and by closeness to a 灵眼.
- Sects ring their territory with 护山大阵.
- Spirit-stone (灵石) mines follow veins.
- Abode sites with subsidiary peaks or enclosed ground are favoured because they make 禁制 easier to lay out. This logic is behind our 子母峰 line, but I did not find it in the text.

## 5. Landform implications and conflicts

### 5.1 What real landform fits the canon, per place

Units: 1 丈 ≈ 3.3 m. Canon heights are xianxia hyperbole and need stylising.

| Place | Canon constraints | Best-fit real landform (recommendation, not canon) |
|---|---|---|
| 云梦山 | Long range (fan: 绵延千里) in western 溪国. A main spine plus east and west sub-ranges. Hides a giant **karst cavern**. Has **earth-fire** under the west vein. Remote, hilly, forested, swampy province (unconfirmed). | A **composite range**: a crystalline/metamorphic main spine, a **limestone belt** carrying the cavern, and a **volcanic/geothermal** western massif. Humid montane climate with persistent cloud. |
| 古剑门 (主脉) | Main ridge only; no description found. | Free choice. Granite spires/arêtes suit a sword sect, but **canon does not require them**. |
| 落云宗 (东脉) | Six separate 奇峰, spread out (白凤 small, far off, possibly easternmost). A **main peak with a city on its lower half and purple fog on the upper half** ([W]). Mist-filled restriction formation. | A **massif with broad lower slopes** (room for a town) for the main peak. Satellite peaks can be **quartz-sandstone pillars** ("奇峰"), but the main peak cannot be a narrow pillar. Use valley fog / inversion cloud as the "formation mist". |
| 百巧院 (西脉) | A plaza ringed by mountains on four sides; a giant platform against a cliff; a five-storey ~百丈 (~330 m) tower like a 石塔; a cliff honeycombed with holes; a top-grade 地肺火池 in the mountain. | A **caldera or volcanic cirque**: a soft, carvable **welded-tuff cliff** with cave dwellings (Cappadocia-like) and fumarolic heat. Our 熔岩台地/凝灰岩壁 fits well. |
| 灵眼之树 | An underground **stalactite chamber** about 1–2 km across and 65–100 m high, with a **stone-column maze**. The tree is an arm-thick green "stone pillar" under a gold dome. Reached by 传送阵 and a mist-veiled path; the eye-washing is at a "圣山" ([F]). | A **mega karst chamber** (Sarawak Chamber / 苗厅 order of magnitude, about 2× larger) in limestone, with a speleothem forest. The surface above is karst (dolines, a sealed shaft). **Not an open valley.** |
| 绿踪沼泽 | Between the 主脉 (古剑门) and 东脉 (落云宗); remote; perennial miasma. | A **swamp basin** in a structural low or valley floor between the ranges: blackwater, forested, with fog and miasma. |
| 子母峰 | 韩立's abode within 落云宗 land. Shape unknown; the donghua gives 1 main + 2 secondary peaks. | A main summit with subsidiary summit(s): a "mother–child" massif. Any rock type. |
| 天柱山 | West of 云梦山; solitary; sheer; "万余丈" (≈ 33+ km, impossible). | An **inselberg / monolith** (granite bornhardt) or **volcanic neck**, scaled down and stylised. |
| 溪国 / 闵州 | Northernmost state; the big coastal province on the 无边海. | Coastal lowlands and plains facing a northern sea. |
| 封日城 | Capital of 闵州; no site description. | Any harbour site. The hook peninsula is the demo's. |
| 大漩涡 | Offshore near 溪国; a broken seal-array eye; spews qi. | A tidal **maelstrom** (Saltstraumen, Corryvreckan) or a submarine caldera. Magical in origin. |
| 七灵岛 | Seven islands that **surfaced** (浮出) after the sea was purified. | **Newly emerged volcanic islands** (Surtsey-type) or uplifted reef islands. "浮出" favours emergence. |
| 鸾鸣宗 / 倪航斋 / 水影宗 | No canon geography found. | Free; current choices are the demo's. |
| Route stops (6) | None (inventions). | Free. Note: canon's 石林 is the speleothem forest *inside* the 灵眼之树 cavern, if 笋石林 is meant to echo canon. |

### 5.2 Conflicts between our lore and the canon (flagged, not resolved)

- **C1 (major), 灵眼之树 setting and look.**
  - Our note: "神木立在…崖壁环抱的谷地里，树冠透出淡青白的灵光，谷中溪流分几道跌下".
  - Canon [N 628]: inside a giant stalactite cavern, in a stone-column maze. The "tree" is an arm-thick, pale-green, straight 青石柱-like stem under a 淡金色光罩, with no crown. Its access is by 传送阵 and a mist-veiled route.
  - Our body text also says "胜者才有洗目的机会". Canon: the winning *sect* gets ½ of the nectar (others ¼ each, [W]), and the top-10 disciples get the eye-washing ([F]).
- **C2 (major), 落云宗 layout.**
  - Our design: six sandstone-pillar clusters around a cloud-filled basin, halls on **floating islands**, no main peak; the 白雾 is the sea of cloud.
  - Canon/wiki: six named peaks spread out (白凤 far away and shortest), a **main peak with a city on the lower half and a purple fog hiding the elders' residences on the upper half**, and a mist-filled restriction formation.
  - The peak list also disagrees: [H] has 锁烟; rmji has a "Main Peak" instead.
  - "草木葱茏、鸟语花香 inside the fog" is unverified.
- **C3 (medium), 云梦山's province.** Canon puts 云梦山 and 落云宗 in **湳州** (Baike, rmji). Our map has no 湳州. It places an invented 韵州城 7000丈 south of 落云宗 and tags 韵州 as the nearby state. 韵州's canon status and its "第627章" mention are **unverified**.
- **C4 (medium), 子母峰.**
  - Our "一主三小" shape is unverified.
  - "动画中称青竹峰" simplifies: the donghua gives 韩立 **天泉峰 + 2 次峰**, reportedly renamed 青竹峰. So the donghua swaps 子母峰 for 天泉峰.
  - Our "east of 落云宗" placement may clash with [F] "白凤峰位于落云宗的最东边".
- **C5 (minor), 百巧院.**
  - Canon: a plaza "四面环山", and the tower is on a platform **built against the cliff**, "高约百丈".
  - Ours: a horseshoe "朝南敞开", a tower "谷心石台…约九十丈".
  - The 金色晶石 in the guest cave is unverified.
- **C6 (minor), 古剑门.** "太白峰 = highest point of 云梦山", the 太白/剑阁/东岭 peaks, "冻进冰川" and the "让出…主脉的一部分灵石矿" are all unverified. The canon facts are: 金武环 lost to 韩立's 乾蓝冰焰 at 百巧院, and the rankings changed.
- **C7 (minor), the spies.** Our lore says spies "勾结魔道". The fan source says **正魔两道** jointly (to revive 玄天仙藤).
- **C8 (minor), names and positions at sea.**
  - Name variant: 灵鳌岛 vs Baike's **灵鳖岛**.
  - "七灵岛…大漩涡以南" is the demo's placement.
  - "看守封印的是太真门" is not verified. Baike says 至阳上人 organised the sealing and that 太真门 is a branch of 大晋's 真极门.
- **C9 (minor), 落云宗's fate.** The novel has two versions of its ending; the amended version is strong. Our "终成天南第一大宗" follows one reading.
- **C10 (note), 天柱山 "万余丈".** This is canon hyperbole (about 33 km). Our world unit is 1 丈, so a literal build is impossible. The cloud belt is the demo's.
- **C11 (note), 封日城.** Our text says "原著没有写到这座城（只见于《凡人必备手册》）". The handbook entry is confirmed; I did not check whether the novel text mentions it.

## 6. Not done, and what to check next

These were not searched, either because the search budget ran out or because nothing turned up:
- The six route stops individually.
- 水影宗, and 倪航斋's details.
- Any description of 古剑门's landscape.
- Where 慕兰草原 and 大晋 lie relative to 天南 (sources contradict).
- The donghua's visual design of 落云宗, 古剑门 and 百巧院.
- The exact 子母峰 description (likely around qidian 第六三x–六四x章, after 结婴, when the elders offer him abode choices).
- 韵州 (the claimed "第627章").
- The full Baike 落云宗 entry (fog / 鸟语花香).

Suggested follow-ups, if web access returns:
- Open [qidian 地理篇](https://m.qidian.com/chapter/107580/27199943/) and [qidian 宗门篇](https://m.qidian.com/chapter/107580/27199947/) in full. Together they cover most entries.
- Read hjwzw 第594–640章 for the arrival, the six peaks and the abode choice.
- Read hjwzw 第628–629章 in full.

## Sources (as used)
- 《凡人必备手册》第二版: [地理篇 qidian](https://m.qidian.com/chapter/107580/27199943/) · [地理篇 quanben5](https://www.quanben5.com/n/fanrenxiuxianchuan/3687.html) · [地理篇 sina](https://blog.sina.com.cn/s/blog_b3af6a390101d57n.html) · [宗门篇 qidian](https://m.qidian.com/chapter/107580/27199947/) · [宗门篇 sina](https://blog.sina.com.cn/s/blog_b3af6a390101d57l.html) · [次要人物1](https://m.qidian.com/book/107580/27199901.html) · [年历表](https://m.qidian.com/book/107580/27200017.html)
- Novel: [qidian catalog](https://m.qidian.com/book/107580/catalog/) · [hjwzw 594 落云宗](https://tw.hjwzw.com/Book/Read/1644,409883) · [hjwzw 628 靈眼之樹](https://tw.hjwzw.com/Book/Read/1644,409917) · [hjwzw 629 詭變](https://tw.hjwzw.com/Book/Read/1644,409918) · [hjwzw 863 乾坤塔](https://tw.hjwzw.com/Book/Read/1644,410156) · [hjwzw 1198 星宮來訊](https://tw.hjwzw.com/Book/Read/1644,591673) · [qq 596 入门（上）](https://fanrenxiuxianzhuan.bookresource.qq.com/chapter/107580/22978584/) · [wuxiaworld 597](https://www.wuxiaworld.com/novel/rmji/rmji-chapter-597) · [599](https://www.wuxiaworld.com/novel/rmji/rmji-chapter-599) · [600](https://www.wuxiaworld.com/novel/rmji/rmji-chapter-600) · [642](https://www.wuxiaworld.com/novel/rmji/rmji-chapter-642) · [1173](https://www.wuxiaworld.com/novel/rmji/rmji-chapter-1173/) · [Amendments 2448](https://www.wuxiaworld.com/announcements/rmji/amendments-to-chapter-2448)
- Wikis: [Baike 落云宗](https://baike.baidu.com/item/%E8%90%BD%E4%BA%91%E5%AE%97/61133759) · [Baike 至阳上人](https://baike.baidu.com/item/%E8%87%B3%E9%98%B3%E4%B8%8A%E4%BA%BA/9818844) · [Baike 天南](https://baike.baidu.com/item/%E5%A4%A9%E5%8D%97/67059055) · [rmji Dreamcloud Mountains](https://rmji.fandom.com/wiki/Dreamcloud_Mountains) · [rmji Drifting Cloud Sect](https://rmji.fandom.com/wiki/Drifting_Cloud_Sect) · [rmji Ling Long](https://rmji.fandom.com/wiki/Ling_Long) · [rmji Translation Sheets](https://rmji.fandom.com/wiki/Translation_Sheets)
- Donghua: [TheTVDB ep. 153](https://thetvdb.com/series/384640-/episodes/11252089) · [TheTVDB ep. 158](https://thetvdb.com/series/384640-/episodes/11300780) · [qq arrival](https://news.qq.com/rain/a/20250531A06IQ000) · [qq 2025-09-03](https://news.qq.com/rain/a/20250903A069BJ00) · [weqoocu 148](https://weqoocu.com/1740.html) · [weqoocu 154](https://weqoocu.com/2207.html)
- Fan: [weqoocu 云梦山](https://weqoocu.com/1809.html) · [weqoocu 古剑门](https://weqoocu.com/2129.html) · [sohu 灵眼之树](https://www.sohu.com/a/913495037_122415633) · [sohu 卧底](https://www.sohu.com/a/919262421_122477903) · [sohu 四大势力](https://www.sohu.com/a/932489039_122415633) · [163 四大区域](https://www.163.com/dy/article/K73V9KI80552H59B.html) · [163 落云宗结局](https://www.163.com/dy/article/HMRHGM600537HSMD.html) · [163 选落云宗](https://www.163.com/dy/article/K1SDQJ5K05359PNN.html) · [xuanhuan.skin 天南舆图](https://xuanhuan.skin/maps/rmjz-tiannan/)
