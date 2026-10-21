# 共通踩坑（跨工作流）

[common/README](README.md)｜[經驗提煉](../learning.md)

不專屬任一工作流的坑記 / 查這裡；工作流專屬的坑記在該工作流自己的 `gotchas.md`（長出來後在下表加一列導流）。

**何時用**：使用者說「記個踩坑」「上次也是這樣」；或動手前要查這個現象以前撞過沒。
**何時不用**：專屬工作流已有自己的 `gotchas.md` → 記在那裡；一次且未定位的意外 → 不升格為規則。記錄門檻為第二次遇到，或一次已實證且有明確重用需求，見經驗提煉流程。

## Done when

對應檔存在含現象、對策、適用邊界及證據的段落；新增或修改後文件 lint 通過（見 [testing](../testing.md#文件檢查修改後必跑)）。

下列標「2026-10-19、Godot 4.6」的證據，同日於 Godot 4.7.2（Linux）隔離重跑結果一致，見 [upstream.json](../../../tools/upstream.json) `engine_policy.migration_from_4_6`。

## Godot 冷啟動先建立資源與類別快取

**條件與對策**：fresh checkout 尚無 Godot class／UID cache 時，先執行 [dev-env](../dev-env.md) 的 Import，再啟動或 Smoke。不要在首次解析失敗時直接替換上游 UID 或刪除引用。

**驗收與邊界**：確認匯入完成、Smoke 有 PASS 且無 SCRIPT ERROR；仍保留固定版本的舊 icon UID 警告。此步不保證所有 UID 問題消失，匯入後持續失敗須查資源本身。證據：2026-10-19、Godot 4.6／上游 `4dac5abe`，[啟動驗證](../../../analysis/slay-the-robot/architecture/03_startup_validation.md) 的 cache 與啟動結果；4.7.2 冷匯入未出現指定 UID 錯誤。

## 外部測試入口避開過早解析 autoload 依賴

**條件與對策**：用外部 `--script` 執行 SceneTree 測試、在入口解析階段碰到專案類別／autoload 依賴時，先完成 Import，再將工作 `call_deferred()` 到初始化後，由 `root.get_node()` 取得單例、在執行期 `load()` 需要的腳本。只延後函式呼叫不會延後頂層 preload 或型別解析。

**驗收與邊界**：確認真正主場景完成 ready、子測試完成且無解析錯誤；不要為測試入口改寫遊戲的正常 autoload 設計，也不要假設 deferred 已隔離首次 ready 的檔案副作用。成功方式見 [framework_smoke.gd](../../../tests/framework_smoke.gd) `_initialize()`／`_run()`；證據基準為 2026-10-19、Godot 4.6／`4dac5abe`，適用此測試入口，非所有 Godot 腳本的普遍限制。

## PASS 只能代表斷言涵蓋範圍

**條件與對策**：啟動測試同時列出診斷與已知缺陷時，逐項區分 assertions、observations 與未測項（例：Smoke 的 Dictionary 檢查由診斷提升為斷言的經過見 [testing](../testing.md#smoke-契約)）。Smoke 仍不包含自訂卡牌實際出牌或完整戰鬥，須另選對應 suite。

**驗收與邊界**：看 exit code、PASS 標記、SCRIPT ERROR／FAIL 與已知問題；失敗控制只證明退出碼，修 bug 要證明同一行為斷言在舊碼失敗、修後通過。證據：2026-10-19、Godot 4.6／`4dac5abe` 加本地修復，[回歸紀錄](../../../analysis/slay-the-robot/architecture/04_regression_validation.md) 保留真紅與真綠；4.7.2 重跑斷言數一致。新情境的退出資源數量變化需查明，不能沿用啟動基準一概忽略。

## 修改角色內容須分別核對新開局與舊存檔

**條件與對策**：改角色起始牌組、生命或 pack 時，分開確認新 run 與繼續既有 save 的資料來源。不能從主選單渲染或角色模板已更新推定舊 run 也套用新設定；保留現有存檔，不以刪檔代替相容性驗證。

**證據與驗收邊界**：2026-10-19、`4dac5abe` 加本地修復，[Global.start_run()](../../../game/autoload/Global.gd) 由角色設定建立玩家，[FileLoader.load_game()](../../../game/autoload/FileLoader.gd) 還原 PlayerData。[跨程序測試](../../../tests/save_load_flow.gd) 已驗本版讀寫與續玩，但不代表任意舊版本存檔遷移正常。後續內容修改仍要記下兩條路徑的實際結果。

## 存讀測試在 autoload 之前隔離

**條件與對策**：驗 autosave、Continue 或壞檔時，用 [test_game.py](../../../tools/test_game.py) 先複製乾淨遊戲再啟動；預設 saves、profile、settings 和 user:// 都要隔離。只給 save_game 自訂路徑不能涵蓋 autosave，也不能攔 Global 首次 ready 的寫入（原因見 [validation](../game-dev/validation.md#存檔保護與日誌判讀)）。

**驗收與邊界**：寫入和讀回使用兩個程序，語意比較的欄位與「載入後執行下一步」見同一檔的存檔驗收；另外壞檔失敗須保留原記憶體狀態，不可只檢查檔案存在或 JSON 可解析。證據：2026-10-19 [流程驗證](../../../analysis/slay-the-robot/architecture/04_regression_validation.md)；這是本版 checkpoint 契約，非戰鬥 SceneTree 快照。

## Linux 直接開遊戲與新副本

**條件與對策**：Wayland 視窗收不到點擊要加 `--display-driver x11`；新 worktree 首次開啟前要先 `--editor --import` 建 class cache，否則大量 "Could not find type"。細節與證據見 [dev-env](../dev-env.md)。

## shell heredoc 要加引號

**條件與對策**：用 heredoc 寫入含 `$`、反引號或 `\` 的內容（Markdown、GDScript、JSON）時寫 `<<'EOF'`。未加引號會展開變數並執行命令替換，指令可能卡住或寫進錯的內容。

**驗收與邊界**：寫完用 `git diff` 或讀檔確認內容和原文一致。需要展開變數時才不加引號，並先確認內容沒有反引號。證據：2026-10-19 Manjaro zsh，本專案 session 中未加引號的 heredoc 寫文件時卡住。

## 多 agent 共用 worktree 時 pull --rebase 被擋

**條件與對策**：別的 agent 在同一 worktree 還有未提交修改時，`git pull --rebase` 會報 unstaged changes 並停下。不要替別人 stash、reset 或 checkout。請檔案的 owner 先 commit，或由主 agent 串行做 pull 與 push；寫入範圍大的並行工作各開 worktree。

**驗收與邊界**：pull 後 `git status` 只剩自己的修改，`git log origin/main..` 列出待推的 commit。只有一個 agent 在跑時不受影響。證據：2026-10-19 戰鬥框架 Phase 實作期間，多個子 agent 同時改 repo。
