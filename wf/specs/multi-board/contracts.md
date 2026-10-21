# 資料契約與責任遷移

[架構入口](README.md)｜[生命週期](lifecycle.md)｜[遷移計畫](../../plans/multi-board/README.md)

以下名稱描述內部角色，屬提案，非已存在的 class 或最終 JSON schema。

## 每場準備結果

由 Event、規則快照及同一次取得的 Encounter 產生只讀的 `PreparedEncounter`。它持有核心波次資料與模組設定描述，不含 Node、FieldController、單位物件或可寫 registry。來源資料不得被 setup、預覽或排版寫回。GDScript Dictionary／Array 本身可變，實作時以明確複製與單一擁有者保證外部不持有可變 alias，不能只用「只讀」註解。

通用準備入口只處理核心資料、通用能力描述與失敗結果。棋盤專屬正規化器在模組檔案存在時才按路徑載入，不能讓 EncounterData、CombatDirector 或核心準備類以型別／preload 依賴 `combat/board/`。目前核心已保留的序列化盤欄位可留在 EncounterData，逐步把尺寸／部署／盤 ID 規則移至棋盤正規化器；先保留轉送 API 供既有測例與作者檢查使用。

準備結果區分「輸入沒有指定（相容轉譯）」、「明確有效空盤集合」、「明確有效正盤集合」及「無效」。空集合是合法 0；解析錯誤不能轉成空集合。另獨立記錄模組能力是否可用及未掛原因（場景關閉、規則關閉或檔案缺失），不可讓它們改寫內容的原始意圖。提案採新格式明確要求正盤但能力不可用時回報 unavailable；既有關閉／刪模組走普通戰鬥的 fallback 限於舊格式相容，棋盤專用內容照原能力檢查拒絕，不暗改 BoardRemoved 既有契約。

當舊旗標或檔案缺失使棋盤能力不可用，核心不需要解析模組幾何；仍驗通用 envelope 與核心波次。能力可用且要求正盤時，棋盤正規化／驗證失敗就回錯誤，不可藉「無法建盤」降級成普通戰鬥。新格式應以版本或可選區塊的明確標記區分省略與空集合：不能只給 exported Array 預設 `[]`，因 SerializableData 載入後可能已丟失兩者差別。新舊欄位混用需定單一優先／拒絕規則並測試；明確指定不存在的 Encounter ID 也不能沿現有 Global fallback 悄悄合成別場。

## 棋盤設定與執行狀態

正規化 `BoardSetup` 以唯一非空 ID 索引盤定義，另存顯示順序與部署政策輸入；盤數唯一來源是定義集合大小。單位的空間位置是 `board_id + anchor`，不從 faction 反推目前位置。`BoardPosition`／既有跨盤事件可沿用；換盤不改 faction，換視圖不改 ID。

純驗證先檢查 ID 重複、未知引用、尺寸、盤外格與政策輸入。部署政策只產出位置要求與明確錯誤，無盤、未指定、找不到盤、滿盤是不同結果；滿盤的等待／最近空格／略過沿既有生成契約處理。新格式不能讓「第一個盤」「最後一個盤」默默成為任何陣營的預設；要使用預設時由明確政策定義。舊 SINGLE／DUAL 轉譯器可保留現有 shared／party／enemy 與首個部署格規則。

「本場無棋盤」與「有棋盤但某單位尚無 membership」分開。後者不能自動當普通單位，也不能靠 faction 補進某盤。是否支援盤內／盤外單位混合是後續政策能力；目前沿現有 admission，缺必要位置就明確拒絕，不由結構提案默認新增此玩法。

`CombatBattlefield` 擁有本場各 BoardData 及占格索引；`BoardController` 擁有每盤 FieldController、移動與共享借機狀態；`BoardCombatModule` 擁有兩者的生命週期、adapter 與 presentation。它們只消費完成驗證的設定，不各自重新解析 mode。世界定義、單位狀態、呈現矩形各有一份真相；不要把相同資訊複製成可各自變動的 count、home 與 index。

## 現有檔案如何改

`Global.get_event_encounter_data` 與 `EncounterData.synthesize_from_event` 保留查找／合成責任；新的準備入口只呼叫一次。`Combat._ready` 不先假設某場需要棋盤；`_on_combat_started` 先準備，成功後裝配，再將同一份準備結果交 `CombatDirector.begin_combat`。Director 不另查 Encounter，也不解析盤 schema；它繼續只經 CombatModule hooks 執行。

`EncounterData.get_board_ids`、`get_board_config` 與 `validate_configuration_detail` 的舊邏輯逐步集中至相容轉譯與棋盤驗證；Smoke 的 `unit_registry_probe` 與既有純物件測試也改走同一入口，避免測試與 runtime 接受不同資料。`CombatRulesData.BOARD_MODES` 留作舊資料數值相容，不再新增 N 盤分支；尺寸限制仍是棋盤設定的約束。

`CombatBattlefield.default_board_id` 與 `BoardController.setup` 的主角部署從世界幾何移到部署政策；`BoardCombatModule.resolve_spawn_location`、`prepare_spawned_unit`、波次預設盤與召喚必須共用它。UnitSpawner 保留生成與 admission，政策不得再次生成或直接發動行動。已在盤上的單位查詢、移動與交換不再經初始部署 fallback。

`EnemyContainer.spawn_event_enemy` 目前會在畫面 positions 用盡時回 null，`UnitSpawner.spawn_first_wave` 隨即 break。新棋盤生成路徑須分開實體創建與螢幕放置，不能讓 layout slot 數限制盤面單位數；舊 positional event 的截斷行為留在相容路徑，不能在重構中無聲改掉。

`BoardCombatPresentation.view_position` 的雙槽常數成為相容 layout；新 layout 為純計算 `board_id → Rect2`，`BoardView.compute_layout` 接受槽尺寸後取格，`BoardActorPresentation` 依視圖映射角色。重排不重建規則世界；若只改 viewport 也要能更新矩形，不能再只靠盤 ID 清單改變才刷新。

`CrossBoardPolicy` 沿用 A，`BoardTargeting`／`IntentResolver`／Field／ZOC 以實際盤 ID 查詢；新政策共享同一解析入口供預檢、執行、預覽與 AI，不能各自猜盤關係。`HandManager`、ActionHandler、普通 CardPlayAdapter 的費用與結算不動。單盤相容 getter 先保留並列出呼叫點，N 盤新程式禁止再用它猜主盤。

## 已核實依據

基準 `7eba093`：Combat.gd 的 `_ready`、`_on_combat_started`、`_compose_board_module`；CombatDirector.gd 的 `begin_combat`／`detach_module`；EncounterData.gd 的 `get_board_ids`／`validate_configuration_detail`（目前最後一盤作預設波次盤）；CombatBattlefield.gd 的 `default_board_id`；BoardController.gd 的 `setup`／`get_spawn_board`；BoardCombatPresentation.gd 的 `view_position`／`sync_board_views`。原始碼導航由 [code map](../../workflows/common/code-map/combat-framework.md) 進入；原始調查的 H0–H12 是缺口證據，不是本草案已實作的證明。
