# 整局生命週期、存讀與局外進度：來源核實

[設計入口](README.md)｜[整局工作流](../../../wf/workflows/game-dev/game-flow.md)｜[關卡核實](encounters.md)｜[架構](../architecture/01_overview.md)

2026-10-19，靜態查核本機 game/，上游 HEAD 為 4dac5abe0d19382f8ace2cec5ed3fd77e2a0e11d，加 [來源鎖](../../../tools/upstream.json) 的本地修復。本篇沒有啟動 Godot 或操作 UI；既有實測與本次推論分開。原創題材與核心玩法尚未定義，本篇不是產品規格。

## 啟動、角色設定與新局

[Root.tscn](../../../game/scenes/Root.tscn) 長期持有 TitleScreen、RunScreen 與 overlays；[BaseMenu](../../../game/scripts/ui/menus/BaseMenu.gd) 依 scene 配置的 navigation_button_to_menu 綁按鈕，在 menu 間 clear／populate。[TitleScreen](../../../game/scripts/ui/menus/TitleScreen.gd) 由 run_started／run_ended 隱藏／顯示；[RunScreen](../../../game/scripts/ui/menus/RunScreen.gd) 對應顯示／隱藏。這些是訊號與可見性配合，不是單一整局狀態機。

[MainMenu](../../../game/scripts/ui/menus/MainMenu.gd) 的 update_continue_button_visibility 只問 FileLoader.has_save_file：有 save 時顯示 Continue 與 Forfeit、隱藏 New Run；無 save 時相反。Continue 呼叫 autoload。檔案存在不代表內容有效；完整錯誤 UI 與壞檔恢復尚未實測。

[NewRunMenu](../../../game/scripts/ui/menus/NewRunMenu.gd) 列出 Global 所有 CharacterData，自動選第一個，並收集 seed、difficulty、custom modifiers；沒有角色解鎖過濾。Start handler 交 [Global.start_run](../../../game/autoload/Global.gd)。後者從 CharacterData.character_player_id 取 PlayerData prototype，設定起始牌組／遺物／卡包、HP、金錢、難度、RNG seed 與統計引用，執行 run modifiers，再用 prototype 的 player_act_id 生成起始幕；缺欄預設 act_1，location 初值仍為 location_0。2026-10-20 接點先驗角色／player prototype／起始幕存在，空或未知 Act 在牌組、RNG、UID、run signal 與存檔變動前回 false；Continue 仍讀既有 run 的當前 Act。Smoke 已驗負例無副作用，中性包的真自訂幕流程另由 PackScenario 驗證。

新局生成後 autosave，再發 run_started 及 map_location_selected。[RunStartOptions](../../../game/scripts/ui/RunStartOptions.gd) 收到 STARTING 類型時建立選項，選擇後執行 actions、等佇列完成，設定 Map.can_travel 並開地圖。起點選擇不是 start_run autosave 已完成的內容。

## 地圖、戰鬥與非戰鬥節點

[Map](../../../game/scripts/ui/Map.gd) 的按鈕 handler 同時要求 can_travel 與 Global.get_next_locations 鄰接。[ActionVisitLocation](../../../game/scripts/actions/world_interaction_actions/ActionVisitLocation.gd) 是強制訪問入口，本身不重驗鄰接；先改 player_location_id、清 player_shop_data，預設 autosave，再發 map_location_selected。Map 隨後關閉旅行，其他訂閱者按節點類型啟動內容。

[Combat](../../../game/scripts/ui/Combat.gd) 接戰鬥及 chest／shop，EVENT 與 REST_SITE 由 [DialogueOverlay](../../../game/scripts/ui/DialogueOverlay.gd)、[RestOverlay](../../../game/scripts/ui/RestOverlay.gd) 處理。戰鬥完成使 Map 可旅行；寶箱／商店也有各自開放訊號；dialogue_ended 時 Map 確認玩家仍活著才顯示。overlay 關閉、can_travel、action 完成是不同狀態，不能只驗可見性。

事件成本／效果、商店交易、休息選項與寶箱獎勵各有消費端，詳細資料接線見關卡核實。全圖可達、每種節點所有出口與死亡路徑尚未由現有 suite 全面驗證。

## 獎勵、轉幕與正常終局

[RewardOverlay](../../../game/scripts/ui/RewardOverlay.gd) 在 combat_started 先產生允許的獎勵，戰後等 actions 完成，死亡則清除；非終局才顯示一般戰後獎勵。Continue 先在幕末且非整局末尾時呼叫 generate_next_act，再開地圖；若整局已結束則發 run_victory。

最終戰另有更直接的路徑：[RunSummaryOverlay](../../../game/scripts/ui/RunSummaryOverlay.gd) 的 _on_combat_ended 若 Global.is_end_of_run 為 true，直接發 run_victory。因 RewardOverlay 此時不顯示一般獎勵，正常最終 Boss 勝利不需按獎勵 Continue。需求若要求最終戰領獎後才結算，必須修改轉移契約，不能只新增獎勵資料。

Global.is_end_of_act 只看目前位置無後繼；is_end_of_run 再要求 player_act_max > 0 且當前 act 已達上限。[ActionGenerator.generate_next_act](../../../game/autoload/ActionGenerator.gd) 從 act_next_act_ids 選下一幕；陣列為空只報錯，不會自行判勝。非終局 Boss 正常可經 Reward Continue 轉幕，地圖生成會清前幕並保留當前點作新起點。

非戰鬥終點沒有統一轉幕協定：[ShopOverlay](../../../game/scripts/ui/ShopOverlay.gd) 的 Continue 類似 Reward，Rest Continue 只選返回地圖／run_victory、沒有 generate_next_act；Dialogue 結束交 Map 顯示地圖，沒有在該路徑檢查幕末。因而將 REST／EVENT 放在非最終幕無後繼位置，不能假設它們會自動跨幕。這是靜態確認的控制流程限制，未在本次執行重現。

## 勝敗摘要、離開、放棄與再開

RunSummary 在 run_victory 時設 VICTORY，在 player_death_animation_finished 時設 LOSS；End Run 才呼叫 Global.end_run。Global 對 LOSS／VICTORY 刪 run save，呼叫 [StatsHandler](../../../game/autoload/StatsHandler.gd) lose_run／win_run，保存 profile，最後 is_run=false 並發 run_ended。MainMenu 依存檔顯示，NewRunMenu 在沒有存檔時 populate，因此完成結算後直接可設定下一局。

[PauseOverlay](../../../game/scripts/ui/PauseOverlay.gd) 返回標題使用 QUIT：Global 保留 save，不記勝敗，也不另外保存目前記憶體狀態；Continue 從最近 checkpoint 重建。Pause Forfeit 使用 LOSS。MainMenu Forfeit 則由 Global.forfeit_run_from_title 先 load_game(false)，再刪 save、記敗北、存 profile。

摘要可見不等於已持久化結算；在按 End Run 前結束程序，現有 save 仍可能是進點前 checkpoint。重複結算／寫入失敗／在摘要關閉程式的政策尚無完整驗收。_complete_run 有 current_run_stats 為 null 的保護分支，但這不構成檔案與 profile 更新的交易性保證。

## 存讀與局外資料

[FileLoader](../../../game/autoload/FileLoader.gd) save_game 序列化 PlayerData 至 external/saves/save.json；load_game 先檢查檔案、JSON、properties／patch_data 包裝及角色，才替換 Global.player_data、init、恢復 StatsHandler 引用，選擇性發 run_started 與當前位置訊號。這是部分前置拒絕，沒有完整 schema 版本遷移或所有內容 ID 驗證。

[PlayerData](../../../game/data/prototype/PlayerData.gd) 保存永久牌組／升級、HP、金錢、幕／地圖、池、RNG 與局內統計等 @export 欄位；energy/block 沒有 export。HandManager 的戰鬥牌堆、場上敵人、action queue 與待領獎勵 UI 也不是整個 SceneTree 快照。因此基本契約是重新進入節點，不是任意戰鬥中途續接。

全 game 的 autosave 呼叫靜態搜尋只找到 Global.start_run 及 ActionVisitLocation。起點選擇、領獎、購物、休息、事件完成、跨幕生成及 QUIT 沒有新增 autosave。這些改動在下一次進點前可能因載入回退；例如戰後領卡後直接返回標題，保存檔仍可停在該戰鬥進點前。這是依程式推論的預期邊界，本輪未實跑此案例；既有 SaveLoad 測例不能代替全部中斷點的實證。

[ProfileData](../../../game/data/mutable/ProfileData.gd) 跨局保存勝敗、各角色勝敗、連勝敗、時間、最高通過難度與 RunStats 歷史；Settings 為另一檔 external/user_settings.json。profile 沒有通用角色／卡牌解鎖或永久能力成長欄位；run 的永久牌組只跨戰鬥，不跨新局。autosave／autoload 尚有 profile implementation TODO，不能宣稱支援多 profile 或多 run 存檔槽。

## 已見框架缺口與規劃影響

NewRunMenu.set_selected_difficulty_level(value) 在 ENABLE_ALL_DIFFICULTIES=false 分支使用 min(selected_difficulty_level, highest)，未用傳入 value；_on_character_selected 也沒有重新計算難度。加上最高通過難度預設 0，不能由欄位存在宣稱正常難度解鎖曲線已實現。這是靜態缺陷，需以選單遞增／遞減、換角色及勝利後再開的回歸確認再修；本次未修改。

Global.forfeit_run_from_title 不檢查 load_game 是否成功，後面仍執行刪檔與 StatsHandler.lose_run。底層載入拒絕保護不等於這個 caller 有安全失敗分支；壞檔放棄可能刪檔並使用既存或空統計，需要專項回歸。主選單只看檔案存在，亦缺已驗的壞檔恢復 UX。這些是程式能力／驗收缺口，不是只補導航即可修復。

空 next-act 與非終局幕尾、不同非戰鬥節點的轉幕不一致，以及完整中途快照不支援，皆須在最小版本規劃選擇避開或明確擴充。文件不替使用者新增局外成長，也不把未修功能寫成保證。

## 現有實測與本輪限制

[combat_flow.gd](../../../tests/combat_flow.gd) 以真實新局 handler、起點選擇、地圖按鈕、出牌及敵方攻擊，驗單場勝利→獎勵→回地圖與敗北→摘要→End Run；敗北分支確認刪 run save、profile loss／history 增加及 profile 檔案存在。[save_load_flow.gd](../../../tests/save_load_flow.gd) 驗跨程序語意、RNG、MainMenu Continue 後下一遭遇與拒絕保護。

最新 [資源生命週期報告](../architecture/05_resource_lifecycle.md) 記錄 498 checks／0 failures；這是既有整合證據，本篇未重跑。尚無完整多幕正常通關、最終 Boss 勝利 profile、所有非戰鬥、結算後再開及所有 checkpoint 中斷點的測試保證。headless handler 接線不證明滑鼠命中、視覺、GPU 或成品 export；本次禁止桌面／視窗／截圖／GUI 與干預既有程序。
