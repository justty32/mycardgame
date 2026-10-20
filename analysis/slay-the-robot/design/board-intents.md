# 棋盤意圖、位置條件與雙盤目標

[敵人分析](encounters.md)｜[敵人工作流](../../../wf/workflows/game-dev/enemy-design.md)｜[雙棋盤契約](dual-board/README.md)

2026-10-20 靜態核對本輪原始碼與新增測例；headless 執行結果由整合 owner 的交付報告記錄，本頁不以測試檔存在代替通過證據。既有上游意圖輪替、難度與圖示限制仍見敵人分析。

## 可選模組與普通戰鬥

[EnemyIntentController](../../../game/scripts/combat/controllers/EnemyIntentController.gd) 依 `director.board_module` 分派。有掛載時由 [BoardCombatModule](../../../game/scripts/combat/board/BoardCombatModule.gd) 委派 [BoardEnemyIntent](../../../game/scripts/combat/board/BoardEnemyIntent.gd)，後者持有以下移動、幾何及 await 後重查盤身分的責任。有模組卻找不到單位棋盤時拒絕執行，不能當成普通戰鬥繼續攻擊。

未掛載的 NONE 路徑不查棋盤、射程、形狀或移動，不建立 ThreatPreview。它沿 `Enemy.build_intent_actions_data` 執行重設格擋、格擋、攻擊與 custom actions，保留音效及等待／取消管線；SELF 選自己，其餘目標規則沿普通 hero 目標，NEAREST／FARTHEST 在這裡沒有距離含義。

普通路徑在音效與排隊前，以 [BoardContentPolicy](../../../game/scripts/combat/board/BoardContentPolicy.gd) 檢查完整 payload，context 沿 BaseAction 的 `player_values` fallback。明確棋盤 actions、validators 或空間 target override（含巢狀／別名）會令整個意圖拒絕，回報 `board_module_required` 並保留意圖，不能只執行普通攻擊而吞掉棋盤效果。[Player](../../../game/scripts/combatants/Player.gd) 的普通來傷預覽只算存活敵人，排除 SELF 與同一純檢查判定拒絕的意圖；SELF 的數字攔截以敵人自己為目標。這些是本輪模組拆分的原始碼契約，尚不代表新增 NONE 回歸已通過。

## 盤身分與唯一幾何入口

[BoardTargeting](../../../game/scripts/combat/board/BoardTargeting.gd) 的 `board` 參數是目標盤。`geometry()` 取得來源實際盤與 `BoardPosition`，所有形狀／距離合法性交給 [CrossBoardPolicy](../../../game/scripts/combat/board/CrossBoardPolicy.gd)。盤身分以 `board_id` 判斷，與陣營分開；入侵者與敵人在同盤時仍用原同盤距離。

跨盤 A 沒有數字距離。SINGLE、ROW、COLUMN、CROSS、SQUARE_3 與 ALL 在目標盤展開，SELF_AREA 留在來源盤；LINE／LINE_PIERCE 或方向 PUSH／PULL／PULL_ADJACENT 拒絕，不能當成零距離或改成單點。ALL 形狀只處理目標盤，`ALL_OPPONENTS` 是不同的全戰場 target override。

[BoardActionGeometry](../../../game/scripts/combat/board/BoardActionGeometry.gd) 連同卡牌的巢狀 ActionValidator、VariableActionGenerator、RandomSelection payload 檢查，遵循 action → request/card 值與 `custom_key_names`。條件／隨機分支保守檢查全部可能效果；全域隨機目標檢查所有候選，不消耗 RNG。跨盤選格的普通 TO_CELL 或相對移動不能借用另一盤座標；特殊 TELEPORT 須明確 `target_board_id`（可用 `SELECTED`），顯式本盤 `target_cell` 則仍是局部移動。

Hand 的選格與合法性由棋盤 adapter 承擔；[HandManager](../../../game/autoload/HandManager.gd) 呼叫通用 adapter，在加入 queue、保留費用前及出隊時驗證。[BoardCardAdapter](../../../game/scripts/combat/board/BoardCardAdapter.gd) 負責棋盤重查，涵蓋自動／複製出牌。若較早效果改變合法性，當前 request 退保留費用並留 `card_values.board_rejection`；不移到 limbo、不執行卡牌效果。普通卡流程不自行讀棋盤規則。

## 意圖與預覽

[IntentResolver](../../../game/scripts/combat/board/IntentResolver.gd) 回傳來源盤、效果盤、目的格、路徑、命中格／單位與拒絕原因；BoardEnemyIntent 經真正 Action 執行。以下均指模組已掛載的戰鬥。普通移動不跨盤。跨盤目標沒有 APPROACH／FLANK／CHARGE 的局部方向，維持來源盤位置後依 A 攻擊；不能先假設兩盤共享座標。

NEAREST／FARTHEST 先在同盤可比較的敵對單位中比較真實距離；沒有同盤候選時，跨盤候選按穩定 `unit_uid` 選首個。HP 規則仍按 HP，比較相同用 uid 排序。這是 v1 的明確 fallback，不代表跨盤距離為 0。TARGET_RULES 的 RANDOM／MARKED 仍保留既有 HERO fallback，勿與已實作的 TELEPORT 選格規則混淆。

FLANK 在目標相鄰可達格中先減少其他敵對相鄰數，再偏好與已相鄰友軍相對側，最後按成本、y、x；沒有相鄰候選退 APPROACH。CHARGE 允許一步對齊後沿直線前進；只有 `ignores_occupancy` 可穿過單位並執行 `enemy_intent_path_actions`，同一路徑同單位一次。實際移動重驗每步，不能直接相信預覽路徑。

[IntentTeleportResolver](../../../game/scripts/combat/board/IntentTeleportResolver.gd) 的四規則是目標相鄰、離本盤敵對最遠、RANDOM_EMPTY、MARKED_CELL。閃現不受 move_range 限制，但仍查 footprint、占格與禁入場域。跨盤目標沒有「相鄰」格；其他規則只選自己盤。MARKED_CELL 優先明確 `enemy_intent_marked_cell`，缺省再查 `enemy_intent_marked_field_tag`（預設 `marked`）。RANDOM_EMPTY 以 uid、intent ID、next_action_tick 的穩定 hash 選排序候選，重畫預覽不抽遊戲 RNG。

`enemy_intent_move_after` 為 true 時以原位置計算命中、先攻擊再重解析移動；否則先移動、從實際落點判定攻擊。移動或攻擊等待結束後重新取得敵人實際盤；場域與 custom actions 可把活單位轉盤，不能保留 await 前的盤參考。[跨盤反應回歸](../../../tests/dual_board_intent_reaction_cases.gd) 驗轉盤後射程與 move_after 再解析。移動預覽會以 preview 模式攔截，rooted／teleport_blocked 與真正執行共用拒絕條件。[ThreatPreview](../../../game/scripts/combat/board/ThreatPreview.gd) 分盤保存計畫，並提供 `position_costs(unit, anchor)` 的 hazard 與離格借機傷害；它是後續 AI 的只讀接點，不是 Phase 4 AI 已完成。標準 path_actions 的數值預覽與任意自訂腳本的完整效果模擬不可混為一談。

## 位置值與 listener 範例

[BoardPositionQueries](../../../game/scripts/combat/board/BoardPositionQueries.gd) 按 footprint 查相鄰並去重；中立單位不提供敵對包圍。PINCER 要求攻擊者本人與另一活友軍貼在目標相對的四向邊；垂直相鄰但非相對邊不算。SURROUND 只計目標所在盤的相鄰敵對數。假想 anchor 查詢不搬動任何真實單位。

[ActionComputeBoardValue](../../../game/scripts/actions/board_actions/ActionComputeBoardValue.gd) 保留七鍵：distance、adjacent_allies、adjacent_opponents、target_adjacent_opponents、cells_moved_this_action、cells_displaced_this_action、is_flanked。跨盤純查詢的 distance 為 -1，表示無可用幾何；含此 Action 的跨盤卡在費用前整體拒絕，實際 Action 亦不寫無效值。本輪沒有新增 requested_keys 或讓跨盤距離參與傷害數學的契約。

框架沒有 `CardData.card_listeners` 欄位；既有擴充點是 BaseCardDecorator 的 signal 訂閱。[field_move_listener](../../../tests/field_move_listener.gd) 是可重用測試範例：以 WeakRef 指向 owner，只在卡仍在手牌且移動者是 owner 時回應，結束時明確 disconnect。[field_intent_cases](../../../tests/field_intent_cases.gd) 對應位置值、四種閃現、rooted、move_after、CHARGE 與 listener 生命週期；雙盤費用／拒絕測例由本輪專項補齊。
