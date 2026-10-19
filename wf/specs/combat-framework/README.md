# spec：隊伍制 CTB 戰棋戰鬥框架（Slay-The-Robot 框架通用能力）

[INDEX](../../INDEX.md)｜[planning](../../workflows/planning.md)

狀態：草案，第 6 節開放問題已由使用者 2026-10-19 決定（見 [09-risks-decisions.md](09-risks-decisions.md)）。Phase 0、Phase 1（CTB + 單一主角）、Phase 2（棋盤 + 移動 + 範圍／形狀卡）、Phase 3（波次）已於 2026-10-19 實作，驗收見 [Phase 0 plan](../../plans/combat-framework/phase-0.md)、[Phase 1 plan](../../plans/combat-framework/phase-1.md)、[Phase 2 plan](../../plans/combat-framework/phase-2.md)、[Phase 3 plan](../../plans/combat-framework/phase-3.md)；與原文的偏差以「修訂」標在 phases.json 與各節；Phase 2b、Phase 4 起尚未動工；2026-10-19 併入「移動規則增補」（11–16 檔，已併進 phases.json 第 2 列與新增的 Phase 2b 列、10-pack-requirements；題材回饋的待補清單見 09-risks-decisions.md）。題材中立——所有題材名詞、數值與角色皆由內容包（JSON mod）提供；本 spec 只定義框架的資料類別、迴圈、訊號、介面與分階段計畫。
需求來源：使用者 2026-10-19 決定（見 01 的目標表）；題材概念目錄只當需求樣本，不進本 spec。
落點（已決，使用者 2026-10-19）：框架級 spec／plan 放 `wf/specs/`、`wf/plans/`，題材級放 `games/<game>/design/`；題材樹只放「需求與驗收」一頁連回本 spec。每階段開工時在 `wf/plans/` 開同名 plan 記錄實際驗收。
程式碼引用格式 `檔案:行`，以 2026-10-19 工作樹為準（`tests/framework_smoke.gd`、`tools/test_game.py`、`tests/test_runner_diagnostics.py` 當時正由另一 agent 修改，本 spec 不碰）。原文的節號（§1–§7）保留在各檔標題，正文內的 §3.4 之類交叉引用照節號找檔。

## 檔案

<!-- wf-nav -->
| 檔 | 原節 | 內容 |
|---|---|---|
| [01-goals-current-state.md](01-goals-current-state.md) | §1–§2 | 目標、非目標、現況 |
| [02-data-party-rules.md](02-data-party-rules.md) | §3.1.1–3.1.2 | 隊伍、規則物件 |
| [03-data-board-encounter.md](03-data-board-encounter.md) | §3.1.3–3.1.6 | 棋盤、遭遇波次、卡牌／意圖、AI 傾向 |
| [04-combat-loop-signals.md](04-combat-loop-signals.md) | §3.2–§3.4 | Director 迴圈、牌堆、訊號遷移 |
| [05-intent-and-ai.md](05-intent-and-ai.md) | §3.5–§3.6 | 意圖顯示、AI 決策 |
| [06-meta.md](06-meta.md) | §3.7 | 招募、牌獎、存檔、UI |
| [07-tradeoffs.md](07-tradeoffs.md) | §4 | 設計取捨 |
| [08-phases.md](08-phases.md) | §5 | Phase 0–6 計畫 |
| [09-risks-decisions.md](09-risks-decisions.md) | §6 | 風險、已決事項 |
| [10-pack-requirements.md](10-pack-requirements.md) | §7 | 題材包需提供的資料 |
| [11-movement-active.md](11-movement-active.md) | 移動草案 §1 | 移動增補：主動移動（移動點、付費移動、尋路、預覽） |
| [12-movement-displace-zoc.md](12-movement-displace-zoc.md) | 移動草案 §2–§3 | 強制位移、控制區 |
| [13-movement-fields-position.md](13-movement-fields-position.md) | 移動草案 §4–§5 | 格子屬性與場域格、位置條件與效果 |
| [14-movement-intent-spawn.md](14-movement-intent-spawn.md) | 移動草案 §6–§7 | 敵人移動意圖擴充、波次進場格被佔 |
| [15-movement-cards.md](15-movement-cards.md) | 移動草案 §8 | 卡牌移動關鍵字與 Action 積木 |
| [16-movement-phasing.md](16-movement-phasing.md) | 移動草案 §9 | 移動項目的分階段分配與 Phase 2b |

## 已決事項（使用者 2026-10-19）

- 遺物觸發歸屬：每件遺物在資料指定，未指定時歸主角。
- 隊員倒下：本場退場、戰後以 1 HP 回歸；主角倒下＝敗北。
- 舊存檔：不支援，拒絕載入並提示；不做 v1→v2 遷移。
- 戰術指令介面：第一版不做，Phase 5 之後再加。
- 戰前部署：先用遭遇資料的預設格，不做部署 UI。
- 落點：`wf/specs/`、`wf/plans/`。
