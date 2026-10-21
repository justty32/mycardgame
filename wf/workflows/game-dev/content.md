# content — 卡牌與內容擴充

[遊戲開發入口](README.md)｜[驗收分流](validation.md)｜[testing](../testing.md)

**何時用**：新增／調整卡牌、敵人、角色、遺物、事件，以及它們的卡包、事件池與 mod 資料。

**何時不用**：需要新行為原語時接 [mechanics](mechanics.md)；只改畫面接 [ui](ui.md)；單純查證先走 investigation；卡牌定位與平衡先走 [卡牌設計](card-design.md)／[評量](card-evaluation.md)。

## Done when

新 ID 可由實際載入流程取得，且從指定角色／獎勵／事件入口確實可到達；數值、行為與使用者需求一致。既有內容不因補丁遺失必要欄位；受影響的存檔與內容池有明確相容結果。相關驗收有命令、輸出或互動證據，文件與 code map 已同步。

## 子流程

本入口處理既有資料調整、ID 接線、補丁及相容性；需要完整操作鏈的具體任務放在 `content/` 子流程，避免把細節堆進共同入口。

<!-- wf-nav -->
| 子流程 | 負責範圍 |
|---|---|
| [第一個 mod](content/bootstrap.md) | 從空目錄建立 mod、候選副本、JSON 登記 |
| [第一個 mod：probe 與命令](content/bootstrap-probe.md) | Smoke helper 接線、執行命令與交付範圍；載入通過不證明出牌效果或存讀 |
| [題材內容包](content/pack.md) | `games/<game>/pack/` 以 runner `--pack` 隔離載入、題材 probe 與 PackScenario |
| [編輯器載入與邊界檢查](content/pack-tools.md) | 本機 link 內容包、boundary lint 規則 |
| [可玩副本](content/playable-copy.md) | 交付可手動遊玩的隔離副本；中性實例見 [棋盤示範包](../../../examples/board-lab/README.md) |

包的完整新局／戰鬥／存讀流程由 PackScenario 驗證，不以載入 probe 代替；教學成功也不能代替產品需求的真實取得入口與專項驗收。

## 先讀來源

先讀 [Global.gd](../../../game/autoload/Global.gd) 的 `SCHEMA`、`_ready()` 與 `start_run()`，再讀 [FileLoader.gd](../../../game/autoload/FileLoader.gd) `load_read_only_data()`。目前先產生測試資料再載入 JSON；不要新增資料後卻在另一條產生流程尋找結果。模組登記參考 [example_mod/mod_info.json](../../../game/external/mods/example_mod/mod_info.json) 與 [mod_list.json](../../../game/external/mod_list.json)。

依本次內容選讀 [CardData](../../../game/data/prototype/CardData.gd)、[EnemyData](../../../game/data/prototype/EnemyData.gd)、[CharacterData](../../../game/data/readonly/CharacterData.gd)、[ArtifactData](../../../game/data/prototype/ArtifactData.gd) 或 [EventData](../../../game/data/readonly/EventData.gd)。以 [GlobalTestDataGenerator.gd](../../../game/autoload/GlobalTestDataGenerator.gd) 的相近真實內容為範本，沿引用讀其行動與 validator；不要只複製外觀相似的 JSON。

## 操作流程

首次從空目錄建立 mod，先照 [第一個 mod 與隔離驗收](content/bootstrap.md)：它串起最小檔案、登記、候選副本及 Smoke helper 接線。下列規則適用後續內容擴充；不要把既有 example_mod 通過當成本次內容證據。

1. 寫下內容 ID、玩家取得入口與可觀察結果，用 `rg` 查 ID 及關聯引用，確認新增或修改既有內容。先定義一個最小可到達的測試情境，例如固定起始牌組或指定戰鬥事件。
2. 依既有自訂內容位置增量修改；新模組須登記資料夾、class 與 Global table，並在 mod 清單啟用與設定優先順序。使用新 ID 區隔新內容；使用相同 ID 時逐欄說明補丁意圖。
3. 完成下列適用的接線與驗證，完整重啟以重建載入與卡包快取。測試起始配置使用新 run；不要把舊存檔未出現新起手牌誤判為載入失敗。

卡牌的 schema 與數值讀取依 [卡牌設計](card-design.md#用實際-schema-寫最小版本)，卡包篩選與起手／獎勵兩種入口依 [取得入口](card-design/acquisition.md)。敵人的意圖圖、血量與難度依 [enemy-design](enemy-design.md)；遭遇、事件與對話的池／Act／位置接線依 [關卡設計](level-design.md) 的子流程。

新角色同時需要 `CharacterData` 與 `PlayerData` prototype，透過 `character_player_id`／`player_character_object_id` 接線；核對角色選擇、血量、起手牌、遺物與各類卡包。遺物資料需有取得入口；新增腳本則核對 `artifact_script_path`、signal 生命周期、重開局與移除效果，參考 [BaseArtifact.gd](../../../game/scripts/artifacts/BaseArtifact.gd)。

## 補丁、池與存檔

JSON patch 策略（[SerializableData](../../../game/data/SerializableData.gd) 的本地修復、淺合併、Dictionary 不支援 append、recursive/native 分支另測）見 [RNG 與資料契約](mechanics/rng-data.md#序列化與-patch-策略)；從純上游重建必須套用本地補丁。

改名／刪除內容 ID、改可存欄位或池生成方式時，沿 [PlayerData.gd](../../../game/data/prototype/PlayerData.gd) 的 deck、artifact、event pool 與 RNG 狀態及 FileLoader 存讀函式追蹤。先複製測試存檔，在隔離目錄做載入—保存—再載入；明列舊存檔是維持相容、需轉換或無法繼續。不要直接修改玩家唯一存檔，也不要把起始資料修改當成存檔遷移。

## 驗收與同步

Smoke 的涵蓋範圍見 [validation](validation.md#現有基準與命令)；它沒有開始 run，也未驗證本次新增內容的戰鬥、出現機率或存讀往返。

由 agent 依 [validation](validation.md) 選擇本次檢查：新增資料先斷言 ID／引用可解析，再進指定入口觀察結果；卡牌測目標和資源變化，敵人測意圖與回合，事件測到達與離開，角色測新局配置，遺物測觸發與結束。只有涉及存檔／池的變更才擴及相應往返／抽樣驗證；不要以跑全套無關檢查替代核心效果驗收。

新增檔案或責任邊界同步 [code-map](../common/code-map.md)；新的資料契約、擴充限制或反例同步 [教學](../../../analysis/slay-the-robot/tutorial/verification.md) 與相關分析。保留命令、失敗修復及未驗證範圍，最後跑文件 lint（見 [testing](../testing.md#文件檢查修改後必跑)）。
