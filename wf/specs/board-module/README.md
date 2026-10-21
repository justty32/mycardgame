# 棋盤是可選的 Combat 模組

[設計分析入口](../../../analysis/slay-the-robot/design/README.md)｜[工作流](../../workflows/game-dev/mechanics/board-module.md)｜[雙盤 A 契約](../dual-board/README.md)｜[棋盤大小](board-size.md)｜[驗收矩陣](verification.json)

2026-10-20 核實，2026-10-21 依審查改為相依層面可移除。[證據](../../../analysis/slay-the-robot/evidence/2026-10-20/board-module/README.md) 對應矩陣 8 列：scope 是需求，test_file／assertion_ids 是測例，status／run_path 是實證；2026-10-21 的 All（含新 suite BoardRemoved）與 PackScenario 結果只存本機 artifacts/verification/，未另選入 evidence。

## 裝配與責任

本節描述現有程式。2026-10-21 已決定盤數由每場 Encounter 決定（含 0 盤）；目前遷移 A 已集中每場準備與裝配資料，但尚未接上新盤數 schema。缺口基準見 [盤數調查](../../notes/investigations/2026-10-21-multi-board-feasibility.md)，後續依 [解耦架構](../multi-board/README.md) 漸進遷移，不能把目前旗標開關當作 0~N 已完成。

遷移 B 的 [盤定義、部署與排版](../../../analysis/slay-the-robot/architecture/09_board_setup_layout.md) 已分責：Battlefield 消費正規化集合，舊 mode 由 BoardSetup 相容轉譯，部署政策與畫面矩形各有獨立入口。正式內容仍走舊格式，內部任意 ID／矩形與不受畫面槽限制的生成專項不等於 C 已完成。

Combat 開戰時先建立 PreparedEncounter，再裝配並交 Director；`_ready` 不預掛載。Director 保存唯一 active prepared，場景相容重掛只讀它，停止後無參數裝配不復活舊場。規則／Event／Encounter 使用獨立資料快照；普通卡規則與 Director 共用當場值，下場準備另讀配置來源，詳見 [核實分析](../../../analysis/slay-the-robot/architecture/08_combat_preparation.md)。

```mermaid
flowchart TD
  Combat[Combat 場景裝配] --> Core[Director / CTB / 波次]
  Combat -->|檔案存在才 load| Optional[BoardCombatModule extends CombatModule]
  Core -->|只呼叫 CombatModule hooks| Optional
  Hand[Hand / HandManager 原出牌流程] --> Adapter[CardPlayAdapter 核心：缺模組內容費用前拒絕]
  Optional -->|掛載時提供| BoardAdapter[BoardCardAdapter / Input]
  Adapter -.子類.-> BoardAdapter
  Req[CombatContentRequirements 資料標記] --> Adapter
  Optional --> World[BoardController / Field / Threat]
  Optional --> View[BoardCombatPresentation]
```

[Combat.gd](../../../game/scripts/ui/Combat.gd) 是場景裝配點。其 `board_module_enabled` 與 [CombatRulesData](../../../game/data/readonly/CombatRulesData.gd) 的 `board_enabled` 都為 true、且 `BOARD_MODULE_SCRIPT` 檔案存在時，才以路徑 load [BoardCombatModule](../../../game/scripts/combat/board/BoardCombatModule.gd) 成為 child。兩個旗標預設為 true，以保留已有棋盤內容與雙盤 A 決策（場景旗標＝此畫面有沒有裝模組，規則旗標＝內容要不要棋盤；尚無遭遇層級開關）。關閉任一旗標稱為 NONE：沒有棋盤模組實例，也不建立 BoardController、FieldController 或 ThreatPreview；SINGLE 仍是一個真正存在的共用棋盤，不能拿它冒充 NONE。

[CombatDirector](../../../game/scripts/combat/CombatDirector.gd) 保留 CTB、行動等待、generation、角色控制器、波次與勝敗流程，獨立保存 Encounter。它只認識核心的 [CombatModule](../../../game/scripts/combat/CombatModule.gd) 介面（setup／clear、單位進出、行動開始、時鐘、出牌、目標解析、敵人意圖、威脅與位置放置 hooks），不引用任何棋盤類別。`board_module`、`board_controller`、`battlefield`、`field_controller`、`board` 與 `threat_preview` 是無型別相容轉送，未掛載時回 null。移動、Undo、移動預算與放置 API 屬於模組；Director 只提供 `can_request_player_input()` 輸入時機閘。

模組擁有 [BoardController](../../../game/scripts/combat/board/BoardController.gd)、ThreatPreview 和 [BoardCombatPresentation](../../../game/scripts/ui/BoardCombatPresentation.gd)，處理站格、移動額度、場域反應與到期、出牌後 undo 失效與移動限制。這是單一固定的可選元件介面，不是動態 plugin registry。

模組檔案範圍：`scripts/combat/board/`、`scripts/actions/board_actions/`、`scripts/validators/board/` 與 `scripts/ui/Board{View,ActorPresentation,CombatPresentation}.gd`。runner 的 BoardRemoved suite 在隔離副本刪除這些檔案，驗 import 無錯、規則與場景都要求棋盤時仍以普通戰鬥完成出牌、意圖輪替與勝敗。

[CombatActionPhases](../../../game/scripts/combat/CombatActionPhases.gd) 只在模組存在時通知 `on_action_reset`、`on_action_started`。普通狀態觸發、能量、抽牌、棄牌、格擋與既有回合訊號仍由原流程執行。時間軸推進也始終處理普通 tick 狀態，場域時鐘則委派模組。

## 普通戰鬥與棋盤戰鬥

[UnitSpawner](../../../game/scripts/combat/UnitSpawner.gd) 經 CombatModule 的放置 hooks（zone id＋anchor）定位；在 NONE 仍建立真正敵人：首波沿用事件的自動排版或指定顯示位置與出生延遲，後續波次照時間表加入 CTB。它不要求占格成功，也不以假座標或隱藏棋盤維持功能。掛載模式找不到指定盤或合法落格時仍按原來的拒絕／重試規則處理，不能把缺少 membership 視作 NONE。

[EnemyIntentController](../../../game/scripts/combat/controllers/EnemyIntentController.gd) 在掛載模式委派 [BoardEnemyIntent](../../../game/scripts/combat/board/BoardEnemyIntent.gd)，保留移動、射程與命中規劃。NONE 執行普通攻擊、格擋、音效及自訂 actions；預設目標為存活主角，SELF 指向自己。含盤面自訂效果的整份意圖由能力檢查拒絕，不先執行普通傷害再跳過位移；被拒後不保留該意圖（2026-10-21 前會設 keep_intent 造成永久停擺），`Enemy.decide_next_intent` 也跳過需要未掛模組的意圖（上限為意圖數）。只帶 `spawn_cells`、沒有 `spawn_slots` 的召喚視為盤面內容。NONE 不重解 NEAREST、FARTHEST 等幾何目標規則。

[Player](../../../game/scripts/combatants/Player.gd) 先問模組 `incoming_damage_for`（棋盤以 ThreatPreview 提供盤面命中與時序）；NONE 則加總存活敵人的普通意圖，排除 SELF 與能力檢查拒絕項。後者不是 CTB 時窗預測。

## 出牌接點與費用原義

[CardPlayAdapter](../../../game/scripts/combat/CardPlayAdapter.gd) 是核心出牌策略：以 [CombatContentRequirements](../../../game/scripts/combat/CombatContentRequirements.gd) 的資料標記（`requires_modules`、`card_values.board`、舊 `card_*` 棋盤欄位、board action／validator 路徑、RESOLVED_SHAPE／UNITS_IN_RANGE／UNITS_ON_FIELD）判定缺模組內容：手牌變灰（`Card.can_play_card`）、點擊時玩家提示、入隊／出隊費用前回 `board_module_required`，原因寫 `request.rejection_reason`。掛載時模組提供 [BoardCardAdapter](../../../game/scripts/combat/board/BoardCardAdapter.gd) 子類，加入選格、範圍、盤身份與請求生命週期檢查；棋盤輸入在 BoardCardInput，經 Hand 的公開狀態 API，不讀 Hand 私有成員。

[HandManager](../../../game/autoload/HandManager.gd) 保有扣費、保留能量、出隊與退費責任。adapter 在入隊扣費前驗證，出隊再次驗證；其同步 hooks 不自行扣費、退費、抽牌或排 actions。出隊拒絕沿既有 refundable energy 流程回復保留費用。`resolve_play` 只提供執行資料；普通、免費、重複出牌與牌堆去向由 [boardless_card_cases](../../../tests/boardless_card_cases.gd) 對原出牌路徑回歸。

棋盤 request 核對模組 instance、模組 generation 與 Director generation（棋盤選格存於 request 的 `module_contexts.board`，由 BoardCardOptions 讀寫）。模組每次 clear 遞增自己的 generation，拒絕同一 Node 重用後的舊請求；普通 CTB generation 與非棋盤工作保留。這個上下文屬於請求，不寫入永久卡牌內容。BaseAction 的範圍／場域目標枚舉保留數值相容，幾何解析透過 Director 委派 [BoardActionTargets](../../../game/scripts/combat/board/BoardActionTargets.gd)。

## 內容與相容

新內容的棋盤選項放在既有 `card_values.board` 字典，使用 `range`／`shape`／`target_faction`；[BoardCardOptions](../../../game/scripts/combat/board/BoardCardOptions.gd) 讀取後交空間查詢。舊 CardData 的同名 `card_*` 欄位仍可反序列化，僅在沒有具名選項時回退；`card_move_distance` 只由 adapter 相容轉譯，示範新牌使用顯式 MoveUnit。普通打擊與格擋不帶 board 選項，保持原選敵／自動出牌。

兩個既有複製出牌 interceptor 透過 `CardPlayRequest.copy_selection_context_from` 複製選取：字典／陣列容器獨立，但 unit 身分相同，模組 lifetime 原樣繼承。`card_values` 仍由原工廠重新取當時牌值，沒有改成舊快照。殘留耦合（刻意保留）：CardData 的 `card_range`／`card_shape`／`card_target_faction`／`card_move_distance` 與 BaseCombatant／Enemy 的位置與移動欄位、EncounterData 的盤設定、`BaseCombatant.BOARD_ANCHOR_NONE`、BaseAction 的空間 TARGET_OVERRIDES 數值、Signals 的盤事件宣告與 Scripts.gd 的模組路徑字串。它們是序列化資料或常數，不造成編譯相依，搬離會破壞既有存檔與內容包 schema。

## 停止與重建

模組 clear 先停止呈現輸入，再清除自己棋盤的占格與角色 anchor，最後清 BoardController。FieldController.clear 會更新 generation 並關閉 active，使舊場域反應不能續寫新戰鬥。清理只碰本模組的盤，不掃除其他場景 registry。下一場 setup 會先清舊資源，再建立新一場的盤、場域及呈現。

主角死亡可能早於死亡動畫完成。Director 的死亡停止使用 preserve presentation：立刻停輸入、移動與場域，但保留已提交的死亡目的位置；直到 combat ended、run ended、下一次 setup 或 scene exit 才恢復／釋放呈現。

Director 的模組 getter 排除 freed、queued for deletion 與已離開場景樹的實例；模組 exit 依 instance 身份解除引用，不清除後來裝配的新實例。[dual_board_adapter_cases](../../../tests/dual_board_adapter_cases.gd) 經公開出牌佇列驗同 Node clear/setup、queue_free 後續行普通 CTB、換新模組後拒絕舊請求，以及保留費用只退一次、普通防禦牌仍執行。這涵蓋明確的卸載與重掛邊界，不代表提供任意元件的熱切換平台。

## 回歸範圍與限制

[boardless_flow](../../../tests/boardless_flow.gd) 與 [campaign](../../../tests/boardless_campaign.gd) 從正常選角、教學、地圖入口驗普通出牌、敵人反擊、勝利獎勵、跨程序 Continue 與死亡流程，並檢查規則旗標及場景旗標各自關閉時沒有盤面資源或 UI。[晚波回歸](../../../tests/boardless_wave_cases.gd) 用戰前宣告的兩波 fixture，驗延遲出生、registry 身份、CTB 行動與末波勝利；[意圖回歸](../../../tests/boardless_intent_cases.gd) 驗 SELF、普通效果順序、巢狀盤面效果整份拒絕，以及拒絕後輪替到普通意圖且實際行動。BoardRemoved 以同一批 boardless 測例（removed、defeat 兩階段）在刪除模組檔的副本中執行。

掛載模式仍使用 Board、DualBoard、Field、Wave 與資源生命週期回歸，[審查回歸](../../../tests/review_regression_cases.gd) 補驗步數語義預檢、付費格最少路徑、點格執行＝預覽路徑、閒置幀不重算與空場域時鐘批次；複製出牌的容器隔離與 lifetime 繼承另見 [dual_board_duplicate_cases](../../../tests/dual_board_duplicate_cases.gd)。這些是固定情境的功能證據，不是平衡統計。GUI 畫面、音訊及人工操作感受尚未驗證；本輪維持僅檔案操作與隔離 headless 的邊界。
