# 選單、繁中文字型與多尺寸

[UI 入口](../ui.md)｜[呈現核實](../../../../analysis/slay-the-robot/design/presentation.md)｜[測試](../../testing.md)

**何時用**：主選單或結算改成原創風格、加入繁中、調整不同畫面尺寸。

**何時不用**：只換卡圖回圖像流程；改結算規則或 run 結束時機接機制流程。

## Done when

任務 plan（`games/<game>/design/plans/`）記有畫面／狀態、文字與字型來源、目標尺寸、改動及證據；適用的既有 suite 和新增斷言回傳預期結果；文件 lint 通過（見 [testing](../../testing.md)）。視覺、字形呈現、實際命中或尺寸未測者明列，不能以背景結果代替完整 UI 驗收。

## 流程

### 先找畫面與返回路徑

從 [Root.tscn](../../../../game/scenes/Root.tscn) 定位 `TitleScreen/MainMenu` 與 `RunScreen/RunSummaryOverlay`。主選單由 MainMenu.gd 決定新局／繼續／放棄的可見性，導航由 [BaseMenu.gd](../../../../game/scripts/ui/menus/BaseMenu.gd) 的 `navigation_button_to_menu` 與 button_up 綁定。改節點階層時同查腳本 NodePath、匯出導航字典及測試；只改外觀時保留這些狀態契約。

[RunSummaryOverlay.gd](../../../../game/scripts/ui/RunSummaryOverlay.gd) 收 `run_victory` 與 `player_death_animation_finished`，切換勝敗 Label、訊息、統計和 `player_run_end_state`；EndRunButton 呼叫 `Global.end_run()`。目前按鈕寫 Back To Main Menu，但既有敗北回歸實際要求返回 `TitleScreen/NewRunMenu`。先定義預期目的地，不從文字推測行為。通關勝利結算與一般戰鬥獎勵不同，不能拿單場勝利到地圖當成結算已驗。

原創風格 brief 先決定背景、色彩、字級、按鈕狀態與對比；需圖像才接 art-assets，沒有工具不妨礙先做 scene/theme 接線。title_screen_theme.tres 被多個選單節點引用，先搜尋使用者再判斷共用或局部修改；它不是全專案預設字型。結算另有局部字級與 RichTextLabel，需逐一確認繼承。

### 文字與字型一起盤點

以此次兩個畫面的實際字串建立字元集合，包含 tscn 固定文字、RunSummaryOverlay 的 `VICTORY_MESSAGE`／`SUMMARY_TEMPLATE`、EventData 的死亡 BBCode、數值、繁中標點及長字串。只改本次畫面的文字；需要多語才另定翻譯 key／fallback，不把改 locale 當成文字已翻譯。

字型輸入須有檔案、作者／授權、版本與需要的字重。先盤點可用的離線字型解析工具；可用時將字元集合對照 cmap，記缺字，沒有能力就列未驗。字型檔存在、cmap 有字與實際字形可讀是不同證據。場景背景測試還需確認 Label/RichTextLabel 實際取得的字型與最低字級，避免局部 override 或 fallback 讓新字型沒有生效；不靠縮到極小字塞入長繁中。

改結算文字同時查 [combat_flow.gd](../../../../tests/combat_flow.gd)：目前敗北分支以 `contains("Damage Taken")` 驗統計。翻譯 SUMMARY_TEMPLATE 後，應改為本次語系的預期字串或與顯示分離的統計語意斷言；保留「實際產生統計」的保護，不能只刪除 assertion。這是文案耦合，不代表翻譯改壞戰鬥。

### 尺寸與最小背景驗證

先列支援的 viewport 與縮放政策；未指定時將目前 1200×700 作基準，再提議一個較小尺寸和一個不同長寬比作候選，不能把候選當成已承諾支援。project.godot 目前 resizable=false；RunSummaryOverlay 和背景是固定 1200×700，統計為三欄，光改視窗旗標不會修好內部版面。從根容器、overlay、訊息區和按鈕逐層調 anchor／container／minimum size，保留必要的安全邊距。

先用 `python3 tools/test_game.py --suite Smoke` 驗共享主場景，用 `--suite Combat` 保留現有敗北結算／返回流程。這兩者都沒有多尺寸、字型或通關勝利結算專項。新增場景 helper 的 UI 接法見 [專項驗證](verification.md)，候選副本見 [內容 bootstrap](../content/bootstrap.md)：僅新增 tests/*.gd 不會自動執行，也沒有 UI suite。

專項先準備有效 run statistics 與 EventData fixture，避免空資料走 breakpoint；分別觸發勝利、敗北及 EndRunButton handler，核對 Label、訊息、end state 和目的地。每個目標尺寸先讓 layout／延後字級更新完成，再斷言關鍵 rect 在可用區域內、必要元件可見、最小字級與文字值符合規格。這些是待實作的針對性斷言，不是既有工具能力；需要截圖或真實焦點的項目標記未執行（操作邊界見 [user.md](../../common/user.md#桌面與程序邊界)）。

## 交接

交付 scene／script／theme／字型路徑、文字來源、尺寸及狀態、測試 helper 接入點、執行日誌與待驗項。背景幾何不證明字形、裁切、視覺對比、DPI 或輸入命中，這些列為未驗。新增可重用事實回寫呈現分析，導航由整合 owner 同步。
