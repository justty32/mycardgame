# spec：隊伍制 CTB 戰鬥框架（棋盤為可選模組；Slay-The-Robot 框架通用能力）

[INDEX](../../INDEX.md)｜[planning](../../workflows/planning.md)

狀態：草案。Phase 0（基礎重構）、Phase 1（CTB + 單一主角）、Phase 2（棋盤 + 移動 + 範圍／形狀卡）、Phase 3（波次）與 Phase 2b（場域格與控制區，9ced42f，suite `Field`）已完成；Phase 4 起未動工。棋盤現為戰鬥場景的可選模組，掛載時採雙盤 A，見下方「方向更新」節。已完成階段（0–3、2b）的分檔與驗收 plan 已封存，現況見下方「方向更新」節的雙盤與模組契約；未動工階段見 [08 分階段](08-phases.md)。
「移動規則增補」（11–15 檔）已併進 Phase 2、Phase 2b 與 [10-pack-requirements](10-pack-requirements.md)；題材回饋的待補清單見 [09-risks-decisions.md](09-risks-decisions.md)。

題材中立——所有題材名詞、數值與角色皆由內容包（JSON mod）提供；本 spec 只定義框架的資料類別、迴圈、訊號、介面與分階段計畫。需求來源為使用者決定的目標（見 [01](01-goals-current-state.md)）；題材概念目錄只當需求樣本，不進本 spec。
落點：框架級 spec／plan 放 `wf/specs/`、`wf/plans/`，題材級放 `games/<game>/design/`；題材樹只放「需求與驗收」一頁連回本 spec。每階段開工時在 `wf/plans/` 開同名 plan 記錄實際驗收。
程式碼引用：以 `類別.函式` 為準；殘留的 `檔案:行` 是開工前（2026-10-19）舊樹的位置，僅供考古，查現況請以函式名搜尋。原文的節號（§1–§7）保留在各檔標題，正文內的 §3.4 之類交叉引用照節號找檔。

## 檔案

<!-- wf-nav -->
| 檔 | 原節 | 內容 |
|---|---|---|
| [01-goals-current-state.md](01-goals-current-state.md) | §1–§2 | 目標、非目標、現況 |
| [02-data-party-rules.md](02-data-party-rules.md) | §3.1.1–3.1.2 | 隊伍、規則物件 |
| [03-data-board-encounter.md](03-data-board-encounter.md) | §3.1.3–3.1.6 | 棋盤、遭遇波次、卡牌／意圖、AI 傾向 |
| [04-combat-loop-signals.md](04-combat-loop-signals.md) | §3.2、§3.4 | Director 迴圈與要點、訊號遷移 |
| [04b-unit-piles.md](04b-unit-piles.md) | §3.3 | 每單位牌堆 |
| [05-intent-and-ai.md](05-intent-and-ai.md) | §3.5–§3.6 | 意圖顯示、AI 決策 |
| [06-meta.md](06-meta.md) | §3.7 | 招募、牌獎、購卡、升階、存檔、UI |
| [07-tradeoffs.md](07-tradeoffs.md) | §4 | 設計取捨 |
| [08-phases.md](08-phases.md) | §5 | Phase 0–6 索引、共同驗證、移動增補分配；未動工階段在 08f（已完成階段分檔已封存） |
| [09-risks-decisions.md](09-risks-decisions.md) | §6 | 風險、待補、已決事項指向 |
| [10-pack-requirements.md](10-pack-requirements.md) | §7 | 題材包需提供的資料 |
| [11-movement-active.md](11-movement-active.md) | 移動草案 §1 | 移動增補：主動移動（移動點、付費移動、尋路、預覽） |
| [12-movement-displace-zoc.md](12-movement-displace-zoc.md) | 移動草案 §2–§3 | 強制位移、控制區 |
| [13-movement-fields-position.md](13-movement-fields-position.md) | 移動草案 §4–§5 | 格子屬性與場域格、位置條件與效果 |
| [14-movement-intent-spawn.md](14-movement-intent-spawn.md) | 移動草案 §6–§7 | 敵人移動意圖擴充、波次進場格被佔 |
| [15-movement-cards.md](15-movement-cards.md) | 移動草案 §8 | 卡牌移動關鍵字與 Action 積木 |

## 已決事項

原六項開放問題（遺物觸發歸屬、隊員倒下、舊存檔、戰術指令、戰前部署、spec 落點）已全部決定，決定與取捨見 [decisions.json](../../workflows/decisions.json) 第 12–17 列；在本 spec 落到哪些欄位與章節見 [09-risks-decisions.md](09-risks-decisions.md#已決)。

## 方向更新：雙盤 A 與可選棋盤模組（取代 G4 原文）

**本 spec 的單盤描述已部分過時**：G4「雙方同一張棋盤」已被兩項決定取代（[decisions.json](../../workflows/decisions.json) 第 18、21 列）——(1) 棋盤是戰鬥場景可選掛載的模組，未掛載時普通抽牌、費用、出牌、結算照常，棋盤專屬效果費用前拒絕；(2) 掛載時採雙盤 A。新工作須同時驗未掛棋盤（`--suite Boardless`）與雙盤（`--suite DualBoard`），見 [validation](../../workflows/game-dev/validation.md#棋盤開關兩種模式都要驗)。模組操作見 [board-module](../../workflows/game-dev/mechanics/board-module.md)。

使用者選定的雙棋盤 A、特殊跨盤移動／交換、方向型限制及角色本體站格見 [雙盤契約](../dual-board/README.md)（落點依 decisions 第 22 列）。本目錄保留原單盤設計脈絡；涉及位置身分、選格與跨盤事件時以新契約為準，實際接線／回歸見 [驗證矩陣](../dual-board/verification.json)，不是以 Phase 2b 八條摘要取代完整需求。
