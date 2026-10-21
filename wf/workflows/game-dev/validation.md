# 遊戲開發驗證

[測試入口](../testing.md)｜[原生崩潰調查](../../notes/investigations/godot-native-crash.md)｜[已建立的啟動證據](../../../analysis/slay-the-robot/architecture/03_startup_validation.md)｜[架構](../../../analysis/slay-the-robot/architecture/01_overview.md)

## 現有基準與命令

從專案根使用 [隔離 runner](../../../tools/test_game.py)，例如 `python3 tools/test_game.py --suite Smoke`；先隔離匯入，再查 exit、完成標記及錯誤。[Smoke](../../../tests/framework_smoke.gd) 涵蓋主場景／選單、資料解析（含角色起手牌 ID）、Array／Dictionary patch 與 example_mod 載入／script takeover，沒有出牌或存讀往返。戰鬥與存讀由 Combat／SaveLoad 驗證；最新狀態見 [05 報告](../../../analysis/slay-the-robot/architecture/05_resource_lifecycle.md)。

設計類流程（卡牌、評量、敵人、第一個 mod）的靜態核對基準是上游 `4dac5abe0d19382f8ace2cec5ed3fd77e2a0e11d` 加本地修復（2026-10-19 核對），各領域的核實筆記列出實際來源。換版本或更動 schema 後要重新追呼叫鏈，不以分析取代程式。

操作邊界見 [user.md](../common/user.md#桌面與程序邊界)：可跑 headless，不做 GUI。歷史主選單 capture 只證明該次 viewport 渲染，不證明按鈕互動，也不是可重跑的步驟。headless 場景斷言不涵蓋 GPU 或視窗呈現；需要這些證據的部分明列尚未驗證。

## 棋盤開關：兩種模式都要驗

棋盤是戰鬥場景的可選模組（[board-module](mechanics/board-module.md)）。凡改到卡牌、敵人、戰鬥流程、Action 或 UI 出牌路徑，都要同時驗**真正未掛棋盤**與**已掛雙盤**兩種模式；單棋盤不能代替未掛載（使用者要求，見 [user.md](../common/user.md#agent-的持續責任)）。

```bash
python3 tools/test_game.py --suite Boardless   # 未掛棋盤：普通出牌／意圖／波次／勝敗，盤面專屬效果費用前拒絕
python3 tools/test_game.py --suite DualBoard   # 雙盤 A：跨盤移動／交換、方向型拒絕、本體站格
python3 tools/test_game.py --suite Board       # 動到單盤幾何、移動、射程時加跑
python3 tools/test_game.py --suite Field       # 動到場域格／控制區時加跑
```

- **新增推敵卡**（如 `ActionDisplaceUnit` `mode:"PUSH"`）：DualBoard 驗同盤推動與跨盤方向型拒絕；Boardless 驗該卡在未掛載時費用前拒絕、能量與牌堆不變。
- **新增敵人**：Boardless 驗普通意圖（NONE 路徑）可打完一場；DualBoard 驗移動意圖與射程。只靠其中一個 suite 通過不算完成。

## 按變更選驗收

**新卡牌、角色、JSON 或 mod**：必跑 Smoke；新增針對該內容的載入、ID 引用、角色牌組／card pack 歸屬驗證。涉及行為時，還要實際生成並執行該 action，核對費用、目標與結果。官方 example_mod 通過不能代表新 mod 通過，也不保證載入順序／碰撞符合預期。

**戰鬥、Action、Validator、Interceptor**：必跑 Smoke 與受影響規則的針對性測試。用固定 seed 或明確狀態驗證合法與拒絕路徑、執行順序及生命／格擋／能量等結果；依變更覆蓋死亡、回合結束或非同步結束；動戰鬥節奏／時間軸（速度、延遲、行動順序、每 N 刻狀態）另跑 `--suite Ctb`。ActionGenerator 建立物件成功不能證明它執行正確；必要時完整走一次相關戰鬥。

**所有權、回指、async cache 或資源清理**：跑 `--suite ResourceLifecycle` 並依 [resource-lifecycle](resource-lifecycle.md) 補新增路徑；驗正常、拒絕、預覽及取消，核對受影響完整流程的退出日誌。測試強制 free 產品物件、只減少資源數或放寬白名單，不能當成修復證據。

**UI、場景、資源**：背景檢查可驗資源匯入、場景載入／實例化及 handler／signal 狀態；影響共享主選單或載入流程時加 Smoke。完整驗收還需要目標畫面渲染與適用輸入證據；需要 GUI 的部分未執行時標為未驗，不寫成通過。取得 GUI 授權後再補驗文字、遮擋、導覽與輸入命中；舊主選單圖不能代表其他畫面。

**存檔、讀檔、設定與遷移**：必跑 Smoke，另以隔離 fixture 做寫入→讀回的語意比較，驗證牌組、升級、seed／RNG 與流程狀態等受影響欄位。依契約驗缺檔、壞檔或舊版本遷移。只比較 JSON 文字相同不足以證明可續玩；續玩變更應載入後執行下一步。

**上游或 Godot 升級**：在獨立工作副本固定新版本，依 [來源記錄](../../../tools/upstream.json) 核對來源，重做隔離 Import、Smoke 及受影響功能驗證；渲染與成品測試需要 GUI 時，未執行者標為未驗。比較新舊日誌與資料格式，不把新錯誤歸入舊基準。若改發行／匯出設定，另驗成品及 external 資料可用；編輯器啟動不涵蓋成品。

**文件或工作流**：依 [testing](../testing.md#文件檢查修改後必跑) 跑文件 lint；純文件改動不必重跑遊戲。測試報告寫清實際版本、命令、結果與未覆蓋範圍，不將待執行檢查寫成已通過。

## Dictionary 回歸契約

本地 [SerializableData](../../../game/data/SerializableData.gd) 已寫回合併結果；[Dictionary 回歸](../../../tests/dictionary_regression.gd) 已在未修上游失敗、修後通過。初值 `{existing:3, shared:1}` 與輸入 `{added:5, shared:9}` 經公開 JSON patch API 後，`merge_keep` 為 `{existing:3, shared:1, added:5}`，`merge_overwrite` 為 `{existing:3, shared:9, added:5}`。

以 `python3 tools/test_game.py --suite Dictionary` 重跑；保留 overwrite、erase、未知策略 fallback、空字典、null、typed dictionary、淺合併、輸入不變及 Array 回歸。Dictionary 沒有 append 策略，合併也不是深層遞迴。後續修 bug 同樣先確認新斷言能因目標錯誤失敗，再以相同測試轉綠；舊測成功不代表新邊界已涵蓋。

`-ForceFailure`／`--force-failure` 只測退出碼控制，既不是上述紅測試，也不是任何遊戲行為的回歸證據。

## 存檔保護與日誌判讀

原生啟動的 Global autoload ready 會先讀取或建立 profile／settings；現有 smoke 僅把其後寫入轉至 `artifacts/test-runtime`。它不開始 run，也未隔離讀取既有 save。[FileLoader](../../../game/autoload/FileLoader.gd) 的 save_game／load_game 可傳目錄，但 autosave 使用固定 SAVE_DIR_PATH；只重導 profile 並不能保護遊戲存檔。

涉及 run、刪檔或存讀的測試，先建立獨立工作副本與測試資料目錄，確認所有 autosave／delete 路徑都在該範圍；不要在使用者既有存檔上試驗。備份與 fixture 不作為待清理雜檔自動刪除。測試產物留在 artifacts，避免提交個人進度。

日誌判讀（exit 0、完成標記、SCRIPT ERROR／FAIL、外層期限、預設拒絕 ObjectDB／resource 保留、已知警告與冷匯入 UID 重驗）以 [testing](../testing.md) 與 [suite 說明](../testing/suites.md) 為準；SaveLoad 壞檔階段只容許已核對的拒絕訊息。
