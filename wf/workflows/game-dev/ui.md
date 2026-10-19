# ui — 畫面、文字與互動接線

[遊戲開發入口](README.md)｜[子流程目錄](ui/README.md)｜[圖像素材](art-assets.md)｜[驗收分流](validation.md)｜[呈現架構](../../../analysis/slay-the-robot/design/presentation.md)

將玩家任務轉成可操作畫面；狀態和效果由既有資料／Action 負責，UI 不另存一套遊戲真相。

**何時用**：Godot scene、介面腳本、版面、theme、文字、可讀性、輸入與呈現接線。

**何時不用**：製作圖像走 art-assets；卡牌／敵人／事件定義走 [content](content.md)；傷害、回合與預覽規則走 [mechanics](mechanics.md)。

## Done when

本次規格與結果檔存在，記錄入口、狀態、操作、資料結果、viewport／語系、改動及未驗項。[專項驗證](ui/verification.md) 選出的測試回傳預期結果，受影響分析同步且 strict lint 回傳 0。背景接線、視覺與實際輸入分開記錄；沒有後兩者證據，不宣稱完整 UI 驗收。

目前遵守 [使用者邊界](../common/user.md)：只檔案修改與背景檢查，禁止桌面、視窗、焦點、截圖、UI 操作及 GUI 啟動。本次文件任務也不啟動 Godot；下列引擎驗收是後續實作的契約，須符合當次授權。

## 流程

### 先寫玩家任務與狀態

先用一段話寫「在哪個畫面、玩家看什麼、做什麼、完成後去哪」。沒有 UI 規格時，自行提出可回退的最小方案：沿現有畫面與滑鼠流程、以 1200×700 為基準，列本次正常／空值／不可用／選取／確認／取消／離開狀態及文字來源；標清候選 viewport、最低字級、焦點順序是提案。不要為未定美術方向停止讀碼和接線準備。

若缺資訊會改變核心規則（例如獎勵可否跳過、取消是否付費、何時結算），保留未決與可選方案，向使用者釐清該規則；其餘布局／元件查核繼續。規格放該任務的 spec（`design/specs/`），批次狀態清單依 [資料契約](../common/data-files.md)；不把全部未決丟到 WAIT_USER。

### 沿真實 scene 與資料入口定位

需求是完整對話、商店、戰鬥、地圖、獎勵或選單時，先由 [場景與用途](ui/screens/README.md) 選完整玩家旅程；每篇把組合元件、素材包、資料、狀態及聲音／動畫 cue 一起接起來，再按需用以下共同技術流程。

從 [project.godot](../../../game/project.godot) → [Root.tscn](../../../game/scenes/Root.tscn) → 附掛腳本查起。戰鬥 HUD、卡牌／敵人選取、tooltip、獎勵／modal 接 [互動與狀態](ui/interaction-states.md)。共用卡牌、theme、容器、HUD 層級接 [元件與版面](ui/components-layout.md)。主選單／結算、繁中字型及多尺寸接 [選單與文字](ui/menus-localization.md)。

改節點名稱先查 `$NodePath`、`%UniqueName`、scene connection、動畫 track 與測試。現有 Root 把多個 overlay 直接內嵌；不能假設每個 overlay 都有獨立 tscn 或共用 modal 基底。動態戰鬥 UI 另走 CustomUIData → BaseCombatant → BaseCustomUI，保留 owner／退出清理。

### 實作版面與文字

記錄容器、anchor／offset、minimum size、theme／局部 override 與可見性；先找現有元件，再決定共用或局部。Card 場景 144×184 與 Hand 的 CARD_WIDTH／pivot／間距相依；panel_theme.tres 是 StyleBoxFlat。完整改法與長文字限制在 components-layout，不靠全域縮字掩蓋問題。

資料提供的卡名／描述改資料，保留變數與 BBCode；固定 UI 字串、enum 類型字串與 tooltip 也在翻譯範圍。本版沒有已接好的多語／繁中字型方案；可讀性、字形與視覺對比須獨立證據。圖像引用與來源接 art-assets；新卡跨領域接線見 [素材流程](art-assets.md#一張新卡的跨領域接線)。

### 輸入、動畫與生命週期

追 input action → Control 命中／focus → signal → handler → Action；既有 left_click／right_click 不等於鍵盤／控制器可玩。Card 是釋放點選流程，沒有已核實的卡牌拖放。新的 focus／cancel 契約、重入與 teardown 按 interaction-states，不只改按鈕外觀。

Card 延後一 frame 刷新，文字與費用預覽會生成 Action／Interceptor；重複刷新不得改遊戲能量、牌堆或具名 RNG，不能留下等待 action。await 後、切場與 owner 移除都需檢查有效性。動畫與 tween 變動另接其領域流程；生命週期接 [resource-lifecycle](resource-lifecycle.md)。

### 驗收與證據

先做本機引用與文件驗證；後續實作依 [UI 專項驗證](ui/verification.md) 接入 Smoke 或 Combat 呼叫鏈，不只新增無人呼叫的 helper。場景載入、handler、幾何、字型涵蓋、視覺與真實輸入各自記錄；Smoke 不涵蓋任意新畫面，發 signal 不證明滑鼠命中或焦點導航。

## 交接

交內容作者：ID、文字／圖像來源、取得入口；交美術作者：顯示框、裁切／遮擋區及狀態變體；交機制作者：輸入到 Action、預覽、拒絕／取消契約；交驗收者：scene、fixture、呼叫鏈、viewport、日誌與未驗項。新增責任入口交整合 owner 更新 code-map，核實事實回寫呈現分析。
