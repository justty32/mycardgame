# ui — 畫面、文字與互動接線

[遊戲開發入口](README.md)｜[圖像素材](art-assets.md)｜[驗收分流](validation.md)｜[呈現架構](../../../analysis/slay-the-robot/design/presentation.md)

將玩家任務轉成可操作的畫面與狀態，保留資料、場景、規則各自的責任。

**何時用**：Godot scene、介面腳本、版面、theme、文字、可讀性、輸入與動畫接線。

**何時不用**：製作圖像走 art-assets；卡牌／敵人／事件定義走 [content](content.md)；傷害、回合、狀態與預覽規則走 [mechanics](mechanics.md)。只查架構不先改 UI。

## Done when

存在本次 UI 規格與結果紀錄，列出畫面入口、狀態、操作、預期資料變化、目標 viewport／語系、修改檔案及未驗項。對應場景載入／實例化與 handler／signal 測試回傳預期結果；受影響分析和文件存在且 strict lint 回傳 0。完整 UI 驗收還需有實際尺寸的視覺與輸入命中證據；未取得時只能交付「背景接線已驗、視覺／實際輸入待驗」。

目前遵守 [使用者邊界](../common/user.md)：只檔案修改與背景檢查，禁止桌面、視窗、焦點、截圖、UI 操作及 GUI 啟動。下列視覺／實際輸入步驟僅在之後有效授權允許時執行，不由歷史 capture 範例推導授權。

## 流程

### 先寫玩家任務與狀態

定義玩家需要看懂什麼、可做什麼及完成後去哪裡。列正常、空值、不可用、選取、確認／取消與離開畫面的狀態；只保留本次相關項。戰鬥畫面特別區分出牌、選目標、選牌與等待 action，modal 開啟時底層不可同時操作。先沿既有元件做小範圍修改，新增畫面才另定資訊層級與導航。

規格寫在本次設計資料旁；如需批次畫面／狀態紀錄，依 [data-files](../common/data-files.md) 儲存。未定美術方向交 art-assets；未定規則交 mechanics，不用 UI 暫存欄位偷偷另建一套遊戲狀態。

### 沿真實 scene 與資料入口定位

讀 [project.godot](../../../game/project.godot) 的 main scene、display、input，再由 [Root.tscn](../../../game/scenes/Root.tscn) 找到 scene 與附掛 script。現有設定為 1200×700、不可調整視窗大小與 GL compatibility；這不是實際 viewport、DPI 或支援多解析度的證據。

卡牌對照 [Card.tscn](../../../game/scenes/ui/card/Card.tscn)、[Card.gd](../../../game/scripts/ui/card/Card.gd) 和 [Hand.gd](../../../game/scripts/ui/Hand.gd)。Card 為 144×184，圖框 96×96；改牌寬須同步 Hand 的 `CARD_WIDTH`、間距、pivot 與 tween。透明 CardButton 的命中框、畫面框和 hover 動畫是不同節點，不能只改插圖尺寸。

主選單由 [MainMenu.gd](../../../game/scripts/ui/menus/MainMenu.gd) 與 [TitleScreen.gd](../../../game/scripts/ui/menus/TitleScreen.gd) 接線；動態戰鬥 UI 從 [CustomUIData](../../../game/data/readonly/modding/CustomUIData.gd)、[BaseCustomUI](../../../game/scripts/ui/custom/BaseCustomUI.gd) 及 BaseCombatant 的註冊／移除入口追蹤。只有資料欄位存在不代表已接畫面，例如角色背景欄位目前未見消費端；實作前以 rg 重查。

### 實作版面與文字

記錄目標節點的 container、anchor、offset、scale、minimum size、theme 與可見性。容器管理子節點時，不用任意 offset 抵消其 layout；改名先查 `$NodePath`、`%UniqueName`、動畫 track、scene connection 與測試。改共享 theme 前列出實際使用畫面；`panel_theme.tres` 實際是 StyleBox，不能只按檔名視為 Theme。

文字由資料提供就改資料；動態數值保留變數與 BBCode。卡牌名稱／描述使用 RichLabelAutoSizer，最小字級預設 1，能塞進框不代表可讀。先定最小可讀字級，再處理換行、摘要或版面，不能以全域縮字掩蓋長文。測最長卡名、升級後名稱、變動費用、負數／多段數值、關鍵字與 `[energy_icon]`；不要在卡圖烘入規則文字。

本版未配置翻譯資源，卡名描述與 enum 類型字串直接顯示；新增繁中／多語時需定文字來源、翻譯 key／fallback 及字型涵蓋，不可只改 locale。新增字型記授權，核對常用繁中與標點。顏色之外保留文字或形狀訊號，避免只靠紅綠區分可用性／數值改善。視覺對比與 glyph 顯示尚需實際呈現驗收。

圖像來源／裁切／透明規格接 art-assets；外部素材由 FileLoader 載入且有快取，scene／theme 的 `res://` 資源走 Godot Import。替換時同步引用、UID 與資料路徑。新增解析度或縮放能力要連同根容器與全部相關畫面驗，不由 anchors 存在就宣稱支援。

### 輸入、動畫與生命週期

沿 input action、Control `mouse_filter`、focus、遮罩、signal／handler 追蹤。Card 在 `left_click`／`right_click` 釋放時發信號，Hand 再處理出牌或選牌；hover 經 timer 展開關鍵字。換透明 overlay、容器或圖像後核對 hit area、z 順序及 tooltip 遮擋。需要鍵盤／手把才明確加入導航順序、焦點可見狀態與取消行為；既有兩個滑鼠 action 不等於已支援控制器。

選一條成功與一條禁止／取消路徑，記錄結果只發生一次；離開再進入或重複 init 不可重複 connect。新動態 UI 同時檢查持有者死亡、戰鬥結束與移除，補 [資源生命週期](resource-lifecycle.md) 的適用驗證。動畫 track 改名與 tween 目標一起追；await frame／動畫結束後確認目標仍有效，不能假設畫面永不離開。

卡牌更新會延至下一 frame，描述與費用預覽會走 Action／Interceptor。只改畫面也不能讓刷新消耗能量、改牌堆、消耗 RNG 或留下 action；涉及此邊界接 mechanics 與生命週期回歸，不把預覽當成純字串替換。

### 驗收與證據

依 [validation](validation.md) 在隔離副本做背景匯入、目標 scene 載入／實例化、引用與相關 handler 狀態斷言。需要動態更新時等實際 process frame；禁止為測試便利干預既有遊戲程序。直接呼叫 handler／emit signal 只驗接線與資料結果，不驗滑鼠命中、鍵盤焦點或渲染。

現有 [framework_smoke.gd](../../../tests/framework_smoke.gd) 驗主場景與主選單初始化，不涵蓋任意新畫面、卡牌拖曳、鍵盤導航與新 viewport。共享主選單／載入流程變更加 Smoke；其他修改加目標斷言，不以跑全套無關測試替代核心驗收。

之後可做視覺驗收時，以實際 viewport／語系檢查文字裁切、最小字級、重疊、空狀態、disabled 與 modal；以實際輸入證據驗命中、hover、取消及重進畫面。取得圖像證據須確認是目標狀態與完成 frame；截圖本身不能證明按鈕有效。未測尺寸／輸入方式保留未驗，不寫成通過。

## 交接

交內容 agent：ID、文字／圖像欄位、取得入口與預期顯示。交 art-assets agent：實際顯示框、遮擋／裁切區、狀態變體與對比需求。交 mechanics agent：預覽、輸入到 action 的契約及拒絕／取消結果。交後續驗收者：scene、fixture、狀態、viewport、背景日誌與待驗項。新增責任入口同步 [code-map](../common/code-map.md) 與呈現分析；最後執行 [文件 strict lint](../testing.md)。
