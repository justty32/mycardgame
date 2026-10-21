# 架構總覽：以匯入原始碼為準

[分析入口](../README.md)｜[擴充方式](02_extension_points.md)

核實日期：2026-10-19；版本、行號與 content profile 條件於 2026-10-21 重核（行號會漂移，以函式名搜尋為準）。基準 commit：`4dac5abe0d19382f8ace2cec5ed3fd77e2a0e11d`。本篇為靜態程式碼查核；啟動、畫面與操作是否成功，須另看本輪執行驗證，不由本篇推論。以下原始碼連結相對於本專案，函式名可直接搜尋。

## 啟動與資料來源

[project.godot](../../../game/project.godot) 的 `[application]` 指向 `res://scenes/Root.tscn`，`config/features` 標記 Godot 4.7（2026-10-19 起的引擎基準；上游基準 commit 時為 4.6）；渲染器為 `gl_compatibility`。`[autoload]` 依序提供 Signals、Scenes、Scripts、FileLoader、Random、Global、兩個資料生成器、ActionHandler 等單例。

真正的資料啟動入口是 [Global.gd](../../../game/autoload/Global.gd) 的 `_ready()`（2026-10-21 核對約 188 行），不是只有 `extends Control` 的 [Root.gd](../../../game/scripts/Root.gd)。依原碼順序：

1. `_generate_schema()` 由 `SCHEMA` 建立型別與資料表映射，接著建立 SerializableData 的 script cache。
2. 載入 profile 與 user settings。
3. 只有 `get_content_profile() == CONTENT_PROFILE_TEST`（預設 `test`；可由 `--content-profile=` 或專案設定 `game/content_profile` 改為 `pack`）時才執行 `GlobalTestDataGenerator.generate_test_data()`；`pack` 略過，只用外部資料與啟用的 mod。production generator 的呼叫目前被註解。測試資料生成不是自動測試套件。
4. `FileLoader.load_read_only_data()` 載入外部資料與 mod，能修補前一步生成的同 ID 物件。
5. 註冊 custom signals、建立卡牌／遺物／消耗品 pack 的 filter cache、生成動畫。

因此「遊戲內容全由現成 JSON 載入」不符合這份版本。主要範例內容在 [GlobalTestDataGenerator.gd](../../../game/autoload/GlobalTestDataGenerator.gd) 的 `generate_test_data()`；[GlobalProdDataGenerator.gd](../../../game/autoload/GlobalProdDataGenerator.gd) 有 production 入口，但預設未啟用。JSON 匯出也是 `_ready()` 中尚未啟用的 `export_read_only_data()`。

## 資料模型與狀態

[SerializableData.gd](../../../game/data/SerializableData.gd) 以 `get_serializable_properties()`／`set_serializable_properties()` 處理具有 storage 標記的欄位（一般為 `@export`），支援巢狀 SerializableData 與部分 Godot 原生型別轉換。不是任意腳本變數都會存檔。

[PrototypeData.gd](../../../game/data/PrototypeData.gd) 的 `get_prototype()` 深複製資料並生成 `object_uid`；`object_id` 表示內容種類，`object_uid` 區別執行期實例。卡牌、敵人、遺物與玩家使用此層。Global 的 `get_card_data()` 取得模板，`get_card_data_from_prototype()`（2026-10-21 核對約 708 行）才取得可修改的卡牌副本。

[Global.gd](../../../game/autoload/Global.gd) 的 `start_run()` 從 CharacterData 指定的 PlayerData 模板建立 run，填入起始牌組、遺物、pack IDs、血量、金錢及難度；`player_data` 是當前 run 的中心。手牌與戰鬥牌堆則由 [HandManager.gd](../../../game/autoload/HandManager.gd) 管理，`generate_combat_deck()` 與 `reset_deck()` 處理戰鬥副本。不要假設每一個戰鬥瞬間都完整保存在 PlayerData。

## 場景、UI 與遊戲邏輯

[Root.tscn](../../../game/scenes/Root.tscn) 組合 TitleScreen、RunScreen、Combat、Map 及選牌／獎勵／對話等 overlays；[Scenes.gd](../../../game/autoload/Scenes.gd) 快取 Card、Enemy、Player、StatusEffect 等可實例化場景。這不是以場景切換器不停更換整個遊戲場景的結構。

[RunScreen.gd](../../../game/scripts/ui/menus/RunScreen.gd) 監聽 `run_started`／`run_ended` 切換可見性；[Combat.gd](../../../game/scripts/ui/Combat.gd) 的 `_ready()` 接線 HUD 並在檔案存在時組裝可選棋盤模組（[CombatModule](../../../game/scripts/combat/CombatModule.gd) 介面，見 [棋盤模組](../../../wf/specs/board-module/README.md)），`_on_map_location_selected()` 決定戰鬥、寶箱或商店，並更新背景／音樂；回合／行動迴圈在 [CombatDirector](../../../game/scripts/combat/CombatDirector.gd)。[Map.gd](../../../game/scripts/ui/Map.gd) 選點後呼叫 ActionGenerator 的 `generate_visition_location()`（名稱保留上游拼法）。

戰鬥框架 Phase 0（本地補丁，見 [spec](../../../wf/specs/combat-framework/README.md)）加了 `UnitRegistry` autoload。`Global.get_player()` 取它登記的主角，`get_alive_enemies()` 取 ENEMY 陣營並依場景樹順序排列，所以結果仍和原本的群組查詢相同。開局能量與抽牌數改讀 `CombatRulesData`，預設值即原行為。舊回合流程只對主角發 `unit_action_started/ended`。

戰鬥規則與 UI 有直接耦合：[BaseCombatant.gd](../../../game/scripts/combatants/BaseCombatant.gd) 繼承 Control，包含狀態、動畫與生命介面；[Enemy.gd](../../../game/scripts/combatants/Enemy.gd) 同時負責傷害、intent 推進及顯示。[HandManager.gd](../../../game/autoload/HandManager.gd) 的 `_play_card()` 會存取 `hand.player`、呼叫手牌 tween。新增無畫面模擬器不能只 new 一個 PlayerData 就假設整套戰鬥可執行。

## 出牌與 action 路徑

[Card.gd](../../../game/scripts/ui/card/Card.gd) 的 `can_play_card()` 檢查出牌條件；[Hand.gd](../../../game/scripts/ui/Hand.gd) 處理點選／目標，交給 HandManager 的 `add_card_to_play_queue()`。`_play_card()` 先建立可攔截的假 ActionCardPlay，移牌到 limbo、發出 `card_play_started`，再建立 `card_play_actions` 與 ActionCardPlayEnd，最後等 actions 完成並移牌到目的牌堆。

[ActionGenerator.gd](../../../game/autoload/ActionGenerator.gd) 的 `create_actions()` 將 `{script_path: values}` 字典轉成 BaseAction 實例並 `init()`，本身不執行它們。[ActionHandler.gd](../../../game/autoload/ActionHandler.gd) 的 `add_actions()`／`_perform_actions()` 是「queue 的 stack」：預設逐項壓棧，後加先執行；`enqueue=true` 才將項目排入目前 queue。每個 queue 由前往後執行，async action 等待 `action_async_finished`，另有 delay timer。

並非所有 action 都一定經過排程器：`generate_visition_location()` 明確直接呼叫 action 的 `perform_action()`。ActionCardPlay 本身僅供攔截，不執行；這兩個例外分別見 ActionGenerator 與 [ActionCardPlay.gd](../../../game/scripts/actions/card_actions/card_play_actions/ActionCardPlay.gd)。

歷史紀錄（已隨 2026-10-19 替換消失）的回合排程欄位不一致：上游 Combat.gd `queue_end_turn()` 第 516 行在已有 `end_turn_object` 時讀取 `end_turn_queue_value`，但 CombatEndTurn.gd（已刪除）第 12 行宣告的是 `end_turn_queue_immediacy`。這是靜態確認的獨立缺陷；目前單次結束回合測試沒有涵蓋等待中再次要求結束回合的優先序判斷。本輪未修改，也不把它當作已驗修復或資源保留原因。（2026-10-19 戰鬥框架 Phase 1 以 [CombatDirector](../../../game/scripts/combat/CombatDirector.gd) `request_end_action()` 與 [CombatEndAction.gd](../../../game/scripts/ui/CombatEndAction.gd) 取代 queue_end_turn／CombatEndTurn，新碼統一讀 `immediacy` 欄位，此不一致隨之消失；這是替換造成的結果，不是另行驗證的獨立修復，「等待中再次要求結束」的優先序仍無專項測試。）

## 存檔與重新進入

[FileLoader.gd](../../../game/autoload/FileLoader.gd) 的 `save_game()`／`load_game()`（2026-10-21 核對約 411／418 行）序列化 PlayerData 到 `external/saves/save.json`。載入後設定 Global.player_data、呼叫 `player_data.init()`、恢復 StatsHandler 引用，再發出 `run_started` 與 `map_location_selected` 重建所在位置；不是保存整個 SceneTree。

本地 load_game 已先驗證指定檔案、JSON 與必要包裝／角色，拒絕時不替換目前 run；這不是完整 schema 遷移。跨程序還原與 Continue 後進入戰鬥的實測見 [回歸報告](04_regression_validation.md)。

`AUTOSAVING_ENABLED=true`。位置移動的保存時機見 [ActionVisitLocation.gd](../../../game/scripts/actions/world_interaction_actions/ActionVisitLocation.gd) 的 `perform_action()`；載入戰鬥位置會由 Combat 的 signal handler 啟動戰鬥，不能據此聲稱能恢復任意戰鬥中途狀態。

設定與 profile 分別存於 `external/user_settings.json`、`external/profile.json`，使用普通 properties 格式；run save 使用 `properties`／`patch_data` 包裝。FileLoader `_ready()` 在未標記 `exported` 時以 `res://` 為根，帶該 feature tag 的匯出版改用執行檔所在目錄。匯出需要帶上 external 目錄；目前未驗證正式發行版。
