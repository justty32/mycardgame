# 遊戲開發驗證

[測試入口](../testing.md)｜[原生崩潰調查](native-crash.md)｜[已建立的啟動證據](../../../analysis/slay-the-robot/architecture/03_startup_validation.md)｜[架構](../../../analysis/slay-the-robot/architecture/01_overview.md)

## 現有基準與命令

從專案根使用 [隔離 runner](../../../tools/test-game.ps1)，例如 `./tools/test-game.ps1 -Suite Smoke`；先隔離匯入，再查 exit、完成標記及錯誤。[Smoke](../../../tests/framework_smoke.gd) 涵蓋主場景／選單、資料解析、Array／Dictionary patch 與 example_mod 載入／script takeover，沒有出牌或存讀往返。戰鬥與存讀由 Combat／SaveLoad 驗證；最新狀態見 [05 報告](../../../analysis/slay-the-robot/architecture/05_resource_lifecycle.md)。

本次使用者限制為檔案修改與不開視窗的背景檢查，禁止 UI／桌面操作、截圖、焦點切換、GUI 啟動及干預既有程序；適用邊界見 testing。歷史主選單 capture 只證明該次 viewport 渲染，不證明按鈕互動，也不是本次可重跑的步驟。headless 場景斷言不涵蓋 GPU 或視窗呈現；需要這些證據的部分明列尚未驗證。

## 按變更選驗收

**新卡牌、角色、JSON 或 mod**：必跑 Smoke；新增針對該內容的載入、ID 引用、角色牌組／card pack 歸屬驗證。涉及行為時，還要實際生成並執行該 action，核對費用、目標與結果。官方 example_mod 通過不能代表新 mod 通過，也不保證載入順序／碰撞符合預期。

**戰鬥、Action、Validator、Interceptor**：必跑 Smoke 與受影響規則的針對性測試。用固定 seed 或明確狀態驗證合法與拒絕路徑、執行順序及生命／格擋／能量等結果；依變更覆蓋死亡、回合結束或非同步結束。ActionGenerator 建立物件成功不能證明它執行正確；必要時完整走一次相關戰鬥。

**所有權、回指、async cache 或資源清理**：跑 `-Suite ResourceLifecycle` 並依 [resource-lifecycle](resource-lifecycle.md) 補新增路徑；驗正常、拒絕、預覽及取消，核對受影響完整流程的退出日誌。測試強制 free 產品物件、只減少資源數或放寬白名單，不能當成修復證據。

**UI、場景、資源**：背景檢查可驗資源匯入、場景載入／實例化及 handler／signal 狀態；影響共享主選單或載入流程時加 Smoke。完整驗收還需要目標畫面渲染與適用輸入證據，本次受授權邊界限制，不執行截圖或桌面互動，不把未驗部分寫成通過。後續在有效授權範圍內補驗文字、遮擋、導覽與輸入命中；舊主選單圖不能代表其他畫面。

**存檔、讀檔、設定與遷移**：必跑 Smoke，另以隔離 fixture 做寫入→讀回的語意比較，驗證牌組、升級、seed／RNG 與流程狀態等受影響欄位。依契約驗缺檔、壞檔或舊版本遷移。只比較 JSON 文字相同不足以證明可續玩；續玩變更應載入後執行下一步。

**上游或 Godot 升級**：在獨立工作副本固定新版本，依 [來源記錄](../../../tools/upstream.json) 核對來源，重做隔離 Import、Smoke 及受影響功能驗證；渲染與成品測試仍依有效授權範圍執行。比較新舊日誌與資料格式，不把新錯誤歸入舊基準。若改發行／匯出設定，另驗成品及 external 資料可用；編輯器啟動不涵蓋成品。

**文件或工作流**：依 [testing](../testing.md) 執行 strict lint；純文件改動不必重跑遊戲。測試報告寫清實際版本、命令、結果與未覆蓋範圍，不將待執行檢查寫成已通過。

## Dictionary 回歸契約

本地 [SerializableData](../../../game/data/SerializableData.gd) 已寫回合併結果；[Dictionary 回歸](../../../tests/dictionary_regression.gd) 已在未修上游失敗、修後通過。初值 `{existing:3, shared:1}` 與輸入 `{added:5, shared:9}` 經公開 JSON patch API 後，`merge_keep` 為 `{existing:3, shared:1, added:5}`，`merge_overwrite` 為 `{existing:3, shared:9, added:5}`。

以 `./tools/test-game.ps1 -Suite Dictionary` 重跑；保留 overwrite、erase、未知策略 fallback、空字典、null、typed dictionary、淺合併、輸入不變及 Array 回歸。Dictionary 沒有 append 策略，合併也不是深層遞迴。後續修 bug 同樣先確認新斷言能因目標錯誤失敗，再以相同測試轉綠；舊測成功不代表新邊界已涵蓋。

`-ForceFailure`／`--force-failure` 只測退出碼控制，既不是上述紅測試，也不是任何遊戲行為的回歸證據。

## 存檔保護與日誌判讀

原生啟動的 Global autoload ready 會先讀取或建立 profile／settings；現有 smoke 僅把其後寫入轉至 `artifacts/test-runtime`。它不開始 run，也未隔離讀取既有 save。[FileLoader](../../../game/autoload/FileLoader.gd) 的 save_game／load_game 可傳目錄，但 autosave 使用固定 SAVE_DIR_PATH；只重導 profile 並不能保護遊戲存檔。

涉及 run、刪檔或存讀的測試，先建立獨立工作副本與測試資料目錄，確認所有 autosave／delete 路徑都在該範圍；不要在使用者既有存檔上試驗。備份與 fixture 不作為待清理雜檔自動刪除。測試產物留在 artifacts，避免提交個人進度。

正常測試須 exit 0、完成標記且無 SCRIPT ERROR／FAIL；45 秒 timer 不能攔同步卡死，外層仍需期限。修復後預設拒絕 ObjectDB／resource 保留，不沿用舊退出白名單。icon UID fallback 與外部 image 警告仍存在；cold import 的指定 UID 須重驗，SaveLoad 壞檔只容許已核對的拒絕訊息，詳見 testing。
