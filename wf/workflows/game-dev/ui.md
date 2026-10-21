# ui — 畫面、文字與互動接線

[遊戲開發入口](README.md)｜[場景與用途](ui/screens/README.md)｜[圖像素材](art-assets.md)｜[驗收分流](validation.md)｜[呈現架構](../../../analysis/slay-the-robot/design/presentation.md)

將玩家任務轉成可操作畫面；狀態和效果由既有資料／Action 負責，UI 不另存一套遊戲真相。

**何時用**：Godot scene、介面腳本、版面、theme、文字、可讀性、輸入與呈現接線；或已定義玩家任務，需要找到實際場景、狀態、元件與測試接點。

**何時不用**：製作或替換圖像走 art-assets；卡牌／敵人／事件定義走 [content](content.md)；傷害、回合、預覽與結算規則走 [mechanics](mechanics.md) 或 [整局流程](game-flow.md)。

## Done when

- 任務 spec（`games/<game>/design/specs/`）與驗證紀錄（`games/<game>/design/plans/`）存在，記錄入口、狀態、操作、資料結果、viewport／語系、改動及未驗項。
- [專項驗證](ui/verification.md) 選出的測試回傳預期結果，受影響分析已同步；文件 lint 通過（見 [testing](../testing.md)）。
- 背景接線、視覺與實際輸入分開記錄；沒有後兩者的證據，不宣稱完整 UI 驗收，也不以背景結果代替手把可玩性。

操作邊界見 [user.md](../common/user.md#桌面與程序邊界)；下列引擎驗收是實作時的契約，需要 GUI 的項目標記為未執行。

## 子流程導航

完整畫面需求先讀 [場景與用途](ui/screens/README.md)：戰鬥、對話、商店／休息、獎勵／選牌、地圖、選單／收藏各有整套玩家旅程與音畫接線。下表是共用技術子流程，不能取代完整場景規格。

<!-- wf-nav -->
| 任務 | 子流程 |
|---|---|
| 戰鬥 HUD、卡牌可用性、敵人目標、新 modal、確認取消與鍵盤／手把 | [互動與狀態](ui/interaction-states.md) |
| tooltip 顯示與卡面延後刷新 | [tooltip 與延後刷新](ui/tooltip-refresh.md) |
| 選牌 Action、獎勵、draft 與 Back／Skip 語意 | [選牌與獎勵的取消語意](ui/card-pick-modal.md) |
| 共用 theme／components、HUD 層級、容器、長文字、無障礙與 viewport 規格 | [元件與版面](ui/components-layout.md) |
| 主選單／結算改版、繁中、字型與尺寸 | [選單、文字與尺寸](ui/menus-localization.md) |
| 背景 fixture 接入、HUD／modal 斷言、既有套件範圍與待驗證據 | [UI 專項驗證](ui/verification.md) |

先沿實際資料與控制流程選互動與元件兩篇，需要主選單／結算才加選單篇；最後由專項驗證定義證據。

## 流程

### 先寫玩家任務與狀態

先用一段話寫「在哪個畫面、玩家看什麼、做什麼、完成後去哪」。沒有 UI 規格時，自行提出可回退的最小方案：沿現有畫面與滑鼠流程、以 1200×700 為基準，列出正常／空值／不可用／選取／確認／取消／離開狀態及文字來源；候選 viewport、最低字級、焦點順序要標清是提案。不要因為美術方向未定就停止讀碼和接線準備。

若缺的資訊會改變核心規則（例如獎勵可否跳過、取消是否付費、何時結算），保留未決與可選方案，向使用者釐清該規則；其餘布局／元件查核繼續。規格放該任務的 spec（`games/<game>/design/specs/`），批次狀態清單依 [資料契約](../common/data-files.md)；不把全部未決丟到 WAIT_USER。

### 沿真實 scene 與資料入口定位

需求是完整對話、商店、戰鬥、地圖、獎勵或選單時，先由 [場景與用途](ui/screens/README.md) 選完整玩家旅程；每篇把組合元件、素材包、資料、狀態及聲音／動畫 cue 一起接起來，再按需用上表的共同技術流程。

從 [project.godot](../../../game/project.godot) → [Root.tscn](../../../game/scenes/Root.tscn) → 附掛腳本查起。

改節點名稱前先查 `$NodePath`、`%UniqueName`、scene connection、動畫 track 與測試。現有 Root 把多個 overlay 直接內嵌；不能假設每個 overlay 都有獨立 tscn 或共用 modal 基底。動態戰鬥 UI 另走 CustomUIData → BaseCombatant → BaseCustomUI，保留 owner／退出清理。

### 實作版面與文字

記錄容器、anchor／offset、minimum size、theme／局部 override 與可見性；先找現有元件，再決定共用或局部。Card 場景 144×184 與 Hand 的 CARD_WIDTH／pivot／間距相依；panel_theme.tres 是 StyleBoxFlat。完整改法與長文字限制在元件與版面篇，不靠全域縮字掩蓋問題。

資料提供的卡名／描述改資料，保留變數與 BBCode；固定 UI 字串、enum 類型字串與 tooltip 也在翻譯範圍。本版沒有已接好的多語／繁中字型方案；可讀性、字形與視覺對比須有獨立證據。圖像引用與來源接 art-assets；新卡跨領域接線見 [素材流程](art-assets.md#一張新卡的跨領域接線)。

### 輸入、動畫與生命週期

追 input action → Control 命中／focus → signal → handler → Action；既有 left_click／right_click 不等於鍵盤／控制器可玩。Card 是釋放點選流程，沒有已核實的卡牌拖放。新的 focus／cancel 契約、重入與 teardown 按互動與狀態篇處理，不只改按鈕外觀。

Card 延後一 frame 刷新，文字與費用預覽會生成 Action／Interceptor；重複刷新不得改遊戲能量、牌堆或具名 RNG，也不能留下等待中的 action。await 之後、切場與 owner 移除時都要檢查有效性。動畫與 tween 變動另接其領域流程；生命週期接 [resource-lifecycle](resource-lifecycle.md)。

### 驗收與證據

先做本機引用與文件驗證；實作時依 [UI 專項驗證](ui/verification.md) 接入 Smoke 或 Combat 呼叫鏈，不只新增無人呼叫的 helper。場景載入、handler、幾何、字型涵蓋、視覺與真實輸入各自記錄；Smoke 不涵蓋任意新畫面，發 signal 也不證明滑鼠命中或焦點導航。

## 交接

交內容作者：ID、文字／圖像來源、取得入口；交美術作者：顯示框、裁切／遮擋區及狀態變體；交機制作者：輸入到 Action、預覽、拒絕／取消契約；交驗收者：scene、fixture、呼叫鏈、viewport、日誌與未驗項。新增責任入口交整合 owner 更新 code-map；靜態來源事實回寫呈現分析。
