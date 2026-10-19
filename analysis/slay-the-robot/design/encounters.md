# 敵人、遭遇與關卡：來源核實

[敵人工作流](../../../wf/workflows/game-dev/enemy-design.md)｜[關卡工作流](../../../wf/workflows/game-dev/level-design.md)｜[非戰鬥與設施](noncombat.md)｜[架構](../architecture/01_overview.md)

2026-10-19 靜態查核本機 `game/`，HEAD `4dac5abe0d19382f8ace2cec5ed3fd77e2a0e11d`，另有本地修復。本筆記依程式與資料接線歸納，沒有啟動 Godot、執行新敵人／完整 act 測試或操作 UI。設計工作流中的節奏、budget 與評量建議是供後續任務使用的方法，不是框架已內建的平衡規則。

## 敵人資料與意圖時序

[EnemyData.gd](../../../game/data/prototype/EnemyData.gd) 是 prototype，保存血量範圍、初始格擋／狀態、種類、minion 與死亡 actions；`enemy_intents` 是嵌入式 EnemyIntentData 字典，`enemy_intent_current_id` 初值為 `intent_initial`。[EnemyContainer.gd](../../../game/scripts/ui/EnemyContainer.gd) 複製 prototype、套難度、以 `rng_enemy_health` 隨機 HP，再實例化 Enemy。修改唯讀 prototype 不等於修改場上已生成敵人。

[EnemyIntentData.gd](../../../game/data/readonly/embedded/EnemyIntentData.gd) 定義攻擊值、次數、格擋、音效、impact、custom actions 與下一意圖權重；建構器將高難度物件 ID 加 `_d<難度>`，另留原始 `enemy_intent_overrides_id`。這是加權有向圖，沒有通用「HP 低於多少換階段」或智能選牌欄位；需要時透過既有 action／validator 或新增機制實現。

[Enemy.gd](../../../game/scripts/combatants/Enemy.gd) 在 `player_turn_started` 切下一意圖，以 `rng_enemy_attack_patterns` 抽選；敵回合由 [Combat.gd](../../../game/scripts/ui/Combat.gd) `perform_enemy_turn()` 讀目前意圖。程式先建立 custom actions，接 attack-generator、block、reset-block，再用 ActionHandler stack 執行；因此一般次序是 reset → block → attack → 逆序 custom actions。狀態還有整個敵方回合及各意圖前後的處理時點；巢狀排隊會影響執行，不宜把這個摘要當所有 action 的絕對次序。（2026-10-19 戰鬥框架 Phase 1 後：意圖改在敵人進入時間軸等待時由 CombatDirector 呼叫 `decide_next_intent()` 切換；執行改由 `CombatDirector.perform_enemy_intent` 以 `Enemy.build_intent_actions_data` 組裝，次序相同；每個敵人自己的行動處理 PRE_ENEMY_TURN → PRE_ENEMY_INTENT → 意圖 → POST_ENEMY_INTENT → POST_ENEMY_TURN。）

意圖預告數字在 Enemy.update_enemy_intent 經兩次 preview interception 計算 damage 與 number_of_attacks。圖示由 intent 的 display types 控制；推導只辨識 attack、block、召喚及部分狀態腳本。建構器的 `intent_display_types` 參數未直接賦到欄位，且 `infer_intent_display_types()` 只追加、不先清空；JSON patch 後也不能假設會重新推導。自訂內容應明確核對最終載入的圖示陣列與數字。只設 damage=0 而保留預設 attacks=1 仍會被推導為攻擊型。

## 敵人能力的現有缺口

`EnemyData.apply_enemy_difficulty_modifiers()` 對一般屬性確實迭代 0..玩家難度，欄位名保留上游拼字 `enemy_difficulty_to_enemy_modfiers`。但其後建立 `_intent_override_cache` 時遍歷全部 intent，只比較哪個 difficulty 較高，沒有篩掉高於玩家難度者。因此註解宣稱的門檻切換不能當作現有保證；需要用低難度與門檻兩側的實際回歸定位、再修原語。這是靜態確認的控制流程缺口，尚未在本任務跑行為測試。

`cycle_next_intent_state()` 遇空權重只記警告，接著仍呼叫 [Random.get_weighted_selection](../../../game/autoload/Random.gd)，該 helper 在空字典回傳 null；不符合「留在原狀態」註解。全零／負值權重也不會被驗證成合法機率，helper 可回傳第一個 key。設計資料應有存在的目標、非負權重及正總和；要停留使用明確自迴圈。

[ActionSummonEnemies.gd](../../../game/scripts/actions/combatant_actions/enemy_actions/ActionSummonEnemies.gd) 按 spawn_slots 找空位，跳過活敵，替換死敵，從 random_enemy_object_ids 洗牌後取第一個。註解限定 positional event；初始自動配置並未為每個敵人配置獨立 slot，因此不能當通用自動排版召喚介面。需有足夠位置、正確 slot 與數量上限測例。Combat 在敵人死亡動畫結束後檢查是否仍有非 minion，剩 minion 可結束戰鬥；不能只測所有敵人清空的情境。

## 遭遇、池與資料接線

[EventData.gd](../../../game/data/readonly/EventData.gd) 的 `event_weighted_enemy_object_ids` 是「每槽一個加權字典」，戰鬥框架 Phase 2 起由 CombatDirector 逐槽抽樣（同一 RNG、同順序）並經 EnemyContainer 生成；有 `event_encounter_object_id` 時改讀 [EncounterData](../../../game/data/readonly/EncounterData.gd) 的第 0 波與棋盤格，沒有則合成北側一列；同一敵人可以跨槽重複。自動配置用 HBoxContainer，指定配置用 positions；指定位置少於生成槽會記錯誤並停止超界生成。初始／戰後 actions、獎勵開關與 dialogue ID 同在 EventData，場景種類則在 [LocationData.gd](../../../game/data/mutable/LocationData.gd)。

[EventPoolData.gd](../../../game/data/readonly/EventPoolData.gd) 是事件 ID 陣列及 fallback。[PlayerData.get_next_event_object_id_from_pool](../../../game/data/prototype/PlayerData.gd) 補池時去重並用 `rng_event_pool` 洗牌，依序取第一個 validator 通過者、移除該 ID。全部不通過時直接取 fallback；fallback 本身不再驗 validator。這不是帶權重的事件池，重複 ID 無法提高機率。

失敗策略 enum 有 KEEP／REMOVE／APPEND／REINSERT／BLACKLIST，但 `failed_event_object_ids` 宣告後從未 append，後續策略 loop 實際沒有項目。補池也沒有依 `player_event_blacklisted_ids` 過濾。故「拒絕後移除／黑名單」是未完成的控制流程，設計依賴時必須先補原語與回歸；本次沒有趁文件任務改遊戲。

LocationData 只在 event ID 空且 pool 非空時抽選並寫入 event ID，已有固定 event 優先。不應為了列舉資料隨意呼叫 `get_location_event_object_id()`，它會消耗池／RNG。查表用 Global getters；真正走訪再用訪問入口。

目前內建敵人／遭遇／act 的具體範例在 [GlobalTestDataGenerator.gd](../../../game/autoload/GlobalTestDataGenerator.gd)，包含三槽普通戰鬥、帶狀態循環的 enemy_4、boss 及預留召喚位置。`game/external/data/` 查到的是 [mod_info.json](../../../game/external/data/mod_info.json) 的 enemies/events/event_pools/acts class/table 映射，不能宣稱那裡已有可複製的敵人 JSON。新內容 JSON envelope 與 mod 登記按 content 工作流及實際 SerializableData 載入分支，typed embedded intents 不能當普通字典深合併。

## 地圖生成、路線與終局

[ActData.gd](../../../game/data/readonly/ActData.gd) 指定五類事件池、next-act IDs、背景／音樂及生成 action 路徑。[ActionGenerator.generate_act](../../../game/autoload/ActionGenerator.gd) 只傳 act_id、act_number，建立 action 後直接 perform；[ActionGenerateAct.gd](../../../game/scripts/actions/world_generation_actions/ActionGenerateAct.gd) 才讀樓層、每層點數、隱藏及非戰鬥比率。這些不是 ActData JSON 原生欄位；要不同生成規則可替換 act_action_script_path，需另外驗真實供值管線。

預設 10×5 網格，k=0..2 easy，k=3 shop、4 miniboss、5 treasure、6 rest、其餘 hard，另加 boss。普通相鄰層連同欄及左右欄，起點全接首層、末層全接 boss；combat 有機率改成 EVENT，combat/treasure 可隱藏類型。縮短 floors_per_act 不會自動重新配平固定樓層安排。第一幕另建 starting node；後續幕清空前幕地圖但保留當前位置，再接新首層。

[Map.gd](../../../game/scripts/ui/Map.gd) 的點擊 handler 同時檢查 can_travel 與 Global.get_next_locations；[ActionVisitLocation.gd](../../../game/scripts/actions/world_interaction_actions/ActionVisitLocation.gd) 本身是強制訪問，不重查鄰接。若測試直接用 action 指定遠處 location，不能拿它證明玩家真的能走到該處。

[Global.gd](../../../game/autoload/Global.gd) `is_end_of_act()` 只看後繼位置為空；`is_end_of_run()` 再看 player_act_max（<=0 為 endless）與目前 act。故 ActData 註解「沒有 next act 就結束 run」不完整：未達 act_max 時，generate_next_act 遇空陣列只記錯誤。設計正常結局、分支或 endless 應一起指定終點、max 與 next IDs。

## 獎勵、overlay 與存檔邊界

[RewardOverlay.gd](../../../game/scripts/ui/RewardOverlay.gd) 在 combat_started 且允許獎勵時生成獎勵；非終局戰的 combat_ended 等 actions 完成後顯示，玩家死亡則清除。非終局幕 Boss 經 Continue 生成下一幕；最終戰由 [RunSummaryOverlay.gd](../../../game/scripts/ui/RunSummaryOverlay.gd) 的 combat_ended 直接發 run_victory，RewardOverlay 不顯示一般獎勵。Continue 的 run_victory 分支不能概括為最終戰的必經出口。[Random.gd](../../../game/autoload/Random.gd) 依節點種類選卡牌／遺物稀有度，金錢固定 25–49；沒有 EventData 的通用 reward budget 欄位。

Combat 的訪問 handler 啟動戰鬥或顯示 chest/shop；[DialogueOverlay.gd](../../../game/scripts/ui/DialogueOverlay.gd) 與 [RestOverlay.gd](../../../game/scripts/ui/RestOverlay.gd) 各自接 EVENT、REST_SITE。選項 schema、validator/action 時序、商店價格／購買、休息次數與寶箱未完成欄位見 [非戰鬥核實](noncombat.md)。Shop／Reward Continue 有轉幕分支，Rest Continue 沒有 generate_next_act，Dialogue 結束只回 Map；EVENT／REST 作幕尾不能假定與 Boss 同樣轉幕。此補充於 2026-10-19 靜態核對，未跑新流程測試。

ActionVisitLocation 先更新位置、清 shop、autosave，才發訪問訊號。[FileLoader.load_game](../../../game/autoload/FileLoader.gd) 還原 PlayerData 後重發 run_started 與訪問目前位置。PlayerData 匯出地圖、池、RNG 等，但 player_energy/block 未保存，場上敵人與 action queue 亦不在其快照；這是位置邊界續玩，不能宣稱戰鬥中途完整還原。

## 後續驗證範圍

現有 [combat_flow.gd](../../../tests/combat_flow.gd) 與 [save_load_flow.gd](../../../tests/save_load_flow.gd) 提供單場勝敗、獎勵及跨程序續玩基準，不能證明全部敵人、全 act 拓撲或平衡。新增內容需按工作流補圖結構不變條件、固定 seed 與操作序列、分支／難度／召喚、boss 轉幕／終局及存讀後下一步測例。GUI 可讀性與視聽節奏在目前禁止視窗操作的邊界下留為未驗。
