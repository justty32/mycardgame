# content — 卡牌與內容擴充

[遊戲開發入口](README.md)｜[驗收分流](validation.md)｜[testing](../testing.md)

**何時用**：新增／調整卡牌、敵人、角色、遺物、事件，以及它們的卡包、事件池與 mod 資料。**何時不用**：需要新行為原語時接 [mechanics](mechanics.md)；只改畫面接 [ui](ui.md)；單純查證先走 investigation。

## Done when

新 ID 可由實際載入流程取得，且從指定角色／獎勵／事件入口確實可到達；數值、行為與使用者需求一致。既有內容不因補丁遺失必要欄位；受影響的存檔與內容池有明確相容結果。相關驗收有命令、輸出或互動證據，文件與 code map 已同步。

## 先讀來源

先讀 [Global.gd](../../../game/autoload/Global.gd) 的 `SCHEMA`、`_ready()` 與 `start_run()`，再讀 [FileLoader.gd](../../../game/autoload/FileLoader.gd) `load_read_only_data()`。目前先產生測試資料再載入 JSON；不要新增資料後卻在另一條產生流程尋找結果。模組登記參考 [example_mod/mod_info.json](../../../game/external/mods/example_mod/mod_info.json) 與 [mod_list.json](../../../game/external/mod_list.json)。

依本次內容選讀 [CardData](../../../game/data/prototype/CardData.gd)、[EnemyData](../../../game/data/prototype/EnemyData.gd)、[CharacterData](../../../game/data/readonly/CharacterData.gd)、[ArtifactData](../../../game/data/prototype/ArtifactData.gd) 或 [EventData](../../../game/data/readonly/EventData.gd)。以 [GlobalTestDataGenerator.gd](../../../game/autoload/GlobalTestDataGenerator.gd) 的相近真實內容為範本，沿引用讀其行動與 validator；不要只複製外觀相似的 JSON。

## 操作流程

1. 寫下內容 ID、玩家取得入口與可觀察結果，用 `rg` 查 ID 及關聯引用，確認新增或修改既有內容。先定義一個最小可到達的測試情境，例如固定起始牌組或指定戰鬥事件。
2. 依既有自訂內容位置增量修改；新模組須登記資料夾、class 與 Global table，並在 mod 清單啟用與設定優先順序。使用新 ID 區隔新內容；使用相同 ID 時逐欄說明補丁意圖。
3. 完成下列適用的接線與驗證，完整重啟以重建載入與卡包快取。測試起始配置使用新 run；不要把舊存檔未出現新起手牌誤判為載入失敗。

卡牌需核對 action 路徑、參數、目標、能量、升級及 `card_values`。抽牌參數是 `draw_count`，多段 action 有 stack 順序，必要時接 mechanics。除了「資料已註冊」，還要檢查 [CardPackData](../../../game/data/readonly/CardPackData.gd) 的顏色、稀有度、類型、validator 與 `card_appears_in_card_packs`；起始牌組和獎勵卡包是不同入口。

敵人需有 `enemy_intents` 的初始狀態、可到達後續狀態、血量上下界與適用難度。以 `EventData.event_weighted_enemy_object_ids` 引用敵人，並核對位置／數量。事件需透過 [EventPoolData](../../../game/data/readonly/EventPoolData.gd)、[ActData](../../../game/data/readonly/ActData.gd) 或指定位置接入地圖；對話事件另核對 dialogue ID、選項與結束路徑。

新角色同時需要 `CharacterData` 與 `PlayerData` prototype，透過 `character_player_id`／`player_character_object_id` 接線；核對角色選擇、血量、起手牌、遺物與各類卡包。遺物資料需有取得入口；新增腳本則核對 `artifact_script_path`、signal 生命周期、重開局與移除效果，參考 [BaseArtifact.gd](../../../game/scripts/artifacts/BaseArtifact.gd)。

## 補丁、池與存檔

[SerializableData.gd](../../../game/data/SerializableData.gd) 的普通 JSON Dictionary 合併已由本地修復寫回 `patched_dictionary`，並以 [公開 API 回歸](../../../tests/dictionary_regression.gd) 驗證 `merge_keep`／`merge_overwrite`。這是淺合併，Dictionary 不支援 append；從純上游重建必須套用本地補丁。Array append 已有基準驗證，recursive/native 巢狀物件仍需按實際分支測試，不能推定所有字典都套同樣策略。

改名／刪除內容 ID、改可存欄位或池生成方式時，沿 [PlayerData.gd](../../../game/data/prototype/PlayerData.gd) 的 deck、artifact、event pool 與 RNG 狀態及 FileLoader 存讀函式追蹤。先複製測試存檔，在隔離目錄做載入—保存—再載入；明列舊存檔是維持相容、需轉換或無法繼續。不要直接修改玩家唯一存檔，也不要把起始資料修改當成存檔遷移。

## 驗收與同步

現有 [framework_smoke.gd](../../../tests/framework_smoke.gd) 涵蓋基準場景、角色起手牌 ID、Array append 與 example_mod 載入／腳本替換；它沒有開始 run，也未驗證本次新增內容的戰鬥、出現機率或存讀往返。

由 agent 依 [validation](validation.md) 選擇本次檢查：新增資料先斷言 ID／引用可解析，再進指定入口觀察結果；卡牌測目標和資源變化，敵人測意圖與回合，事件測到達與離開，角色測新局配置，遺物測觸發與結束。只有涉及存檔／池的變更才擴及相應往返／抽樣驗證；不要以跑全套無關檢查替代核心效果驗收。

新增檔案或責任邊界同步 [code-map](../common/code-map.md)；新的資料契約、擴充限制或反例同步 [教學](../../../analysis/slay-the-robot/tutorial/verification.md) 與相關分析。保留命令、失敗修復及未驗證範圍，最後執行文件 strict lint。
