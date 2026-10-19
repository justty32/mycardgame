# 概念原型：移動相關內容

[design](../README.md)｜[總覽](concept-overview.md)｜[戰鬥 CTB／棋盤](concept-battle.md)｜框架規則見 [移動規則 11](../../../../wf/specs/combat-framework/11-movement-active.md)

**狀態**：概念草案，數值為佔位，未經使用者確認；未標「使用者」的決定皆為「預設，可改」。出處標記沿用概念目錄（`[item pixxx]` 等，見總覽）；標「同人新增」者為原作無。

依概念目錄（戰鬥、角色、敵人）與框架移動規則增補（[11](../../../../wf/specs/combat-framework/11-movement-active.md)–[16](../../../../wf/specs/combat-framework/16-movement-phasing.md)）對應。框架名詞 → 題材用語：「移動點」＝每次行動免費 1 格、「突進」＝**疾行**、「付費移動」＝+20 刻／格（最多 2 格）、「場域格」＝地獄格／聖所格／羅網等、「障礙格」＝水晶柱。

## 0. 題材規則 patch（`combat_rules_default`）

| 欄位 | 題材值 | 依據 |
|---|---|---|
| `free_move_per_action` | 1 | 概念 1.2 §4 |
| `paid_move_max_cells` / `extra_move_delay_per_cell` | 2 / 20 | 同上 |
| `move_split_allowed` | true（出牌前或後皆可） | 同上 |
| `move_adjacency` / `distance_metric` | FOUR / MANHATTAN | 概念 1.2 §3 |
| `move_pass_through_allies` | true（同人新增：隊友可互相穿越，敵人不可） | 站位手感 |
| `zone_of_control` | NONE（原型）；Phase 2b 後考慮 `EXTRA_MOVE_COST` 給「盾衛結陣」 | — |
| `displace_max_footprint_area` | 1（蝗蟲群、蜈蚣、Boss 不可推） | 概念 1.2 §2 |

## 1. 角色移動牌（每人 3–5 張）

延遲：普通 100、〔快〕50、〔重〕150。「既有」＝概念目錄已有、此處補框架對應；其餘為同人新增。

欄位為 費｜延遲｜效果｜取材｜框架積木。已抽到 [movement-cards.json](movement-cards.json)（25 列，五名角色：沈棠支援／殘影／時間軸、商瀾遠程／怨念／封鎖、霍延載具／直線／高機動、薇拉・霍克森前線／霜痕／佔格、蘇小滿高速刺客／沉眠／處決）。欄位：角色、牌、費、延遲、效果、取材、積木。

## 2. 敵人移動模式（對應 `enemy_intent_move` 與單位旗標）

敵人移動模式表已抽到 [movement-enemies.json](movement-enemies.json)（20 列）。欄位：遭遇／單位、移動、意圖移動模式、框架欄位。

波次進場：全部用 `NEAREST_EMPTY`；Boss 召喚物（放蟲、化身降臨）同上但以 100 刻插入。概念表的進場格被我方單位佔住（例如主角衝到 C1）時，鼠人會從 C1 周邊（B1／D1／C2）擠出來——符合「潮水」感，不需 WAIT。

## 3. 場域格用例（`fields/`，id 前綴 `apoc_`）

場域用例表已抽到 [movement-fields.json](movement-fields.json)（10 列）。欄位：場域、來源、時長、觸發、旗標。

AI 傾向對應：〔慎重〕= `ai_position_weights.avoid_hazard` 高（不站地獄格）；〔守護〕= `between_hero_and_enemy` 高並優先把主角身旁敵人「推」開；〔激進〕= 突進／夾擊牌估值加成；〔囤積〕= `far_from_enemy`，配合「退避詛咒」類後撤牌。

## 4. 需回饋框架的缺口

已列入框架 spec 的待補清單（[09-risks-decisions.md](../../../../wf/specs/combat-framework/09-risks-decisions.md)，以中性措辭）：目標規則 `NEAREST_ALLY`／`HIGHEST_VALUE(key)`、對友軍保距的 `KEEP_RANGE` 參照、單位縮格 `resize_footprint`、「代受」屬狀態／攔截器層（只需場域 tag 可查詢）、沿途穿越並作用（`enemy_intent_path_actions`／`UNITS_IN_PATH`，Phase 2b）。原型先用進場格、`HOLD`、停在首個單位前並推它等方式代替，不阻擋 Phase 2。
