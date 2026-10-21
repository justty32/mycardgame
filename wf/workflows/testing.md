# testing — 啟動與擴充驗證

[WORKFLOWS](../WORKFLOWS.md)｜[INDEX](../INDEX.md)｜[環境](dev-env.md)

**何時用**：改完要驗證、選要跑的 suite、判讀 runner 或文件 lint 的結果。

**何時不用**：決定某類變更該補哪些測試 → [validation](game-dev/validation.md)；安裝環境與引擎探測 → [dev-env](dev-env.md)。

上游與引擎基準見 [dev-env](dev-env.md#環境與來源)。最新驗證狀態見 [資源生命週期報告](../../analysis/slay-the-robot/architecture/05_resource_lifecycle.md)；[04 報告](../../analysis/slay-the-robot/architecture/04_regression_validation.md) 保留前次功能與資源限制，不代表所有玩法或發行版已通過。

新任務依 [變更類型選驗證](game-dev/validation.md) 決定現有檢查與需補的測試；原生崩潰、記憶體讀取錯誤或異常退出見 [原生崩潰調查](../notes/investigations/godot-native-crash.md)（已依使用者要求擱置）。

## 執行邊界

操作邊界見 [user.md](common/user.md#桌面與程序邊界)。需要 GUI 的驗收（`game.ps1 -Mode Run`、歷史 capture 命令）標記為未執行，不自動跑。

背景驗證用隔離 runner 選擇與變更相關的 suite，不直接在 `game/` 建立遊戲進度。純文件修改只跑文件 lint，不為更新流程而啟動 Godot。

## Smoke 契約

首次匯入或資源變動需要 Import，隔離 runner 會處理；框架、資料格式、載入流程變動需 Smoke。檢查 [framework_smoke.gd](../../tests/framework_smoke.gd) 的主場景、主選單、角色與起手牌、Array append，真實 FileLoader 的 example_mod 新卡、起手牌追加和 script takeover，以及戰鬥框架 [probe](../../tests/unit_registry_probe.gd)。mod 清單只在測試記憶體覆寫，不修改 game/external/mod_list.json；測試不開始 run。

Smoke 必須 exit 0、有 SMOKE PASS 標記、無 SCRIPT ERROR 或 FAIL。腳本有 45 秒事件迴圈 timeout；若程序同步卡死，外層需停止該測試程序。`--force-failure`（ps1 為 `-ForceFailure`）是失敗出口控制，必須 exit 1，不能列為正常驗證失敗。

[file_loader_probe.gd](../../tests/file_loader_probe.gd) 在兩種 content profile 共用執行，使用隔離 fixture 走真實 mod_list／mod_info／資料載入，驗 `.json`／`.JSON`、排序 patch、非 JSON／備份排除、非遞迴與 Global 表還原。只看最後 PASS 不足：載入佔位檔的 ERROR 即使 assertions 通過，runner 仍須拒絕。

Dictionary merge 已由本地修復修正，Smoke 的四種策略由最初的診斷提升為會使測試失敗的 assertions。完整 JSON patch 邊界由 [Dictionary 回歸](testing/suite-coverage.md#dictionarycombatsaveloadresourcelifecycle) 涵蓋，不能只靠 Smoke 代表所有序列化契約。

## 隔離回歸 runner 與 suite

runner 是 `python3 tools/test_game.py --suite <名稱>`（WSL 下改用 Windows 的 `python.exe` 或 ps1，副本不可放 UNC 路徑，見 [dev-env](dev-env.md#背景驗證)）。怎麼跑、隔離與判定、新內容／新 suite 怎麼接進 runner 見 [testing/suites](testing/suites.md)；各 suite 實際驗了什麼見 [suite-coverage](testing/suite-coverage.md)。棋盤相關改動兩種模式都要驗，見 [validation](game-dev/validation.md#棋盤開關兩種模式都要驗)。

## 文件檢查（修改後必跑）

從專案根以 bash 加 python3 執行；`python3 --version` 須實際成功，不能只看命令存在。

```bash
python3 --version && bash wf/tools/wf-lint.sh --strict . && python3 tools/boundary_lint.py
```

Linux／macOS 用 bash；Windows 經 WSL 或 Git Bash，步驟與商店別名／Win32 error 5 處理見 [dev-env/windows](dev-env/windows.md)。2026-10-19 Manjaro 原生與 Windows WSL 皆回傳全部零項。

WSL 的 CRLF 錯誤依 [版本控制](version-control.md) 查 shell 換行。

exit 0 且 broken、residue、oversize、biglist、querycmd 均為 0；broken 任何時候都使 exit 1，`--strict` 另把其餘四項算失敗。在 git 工作樹內只掃已追蹤與未忽略的新檔，`artifacts/` 等 .gitignore 路徑不掃（WSL `/mnt/c` 全量約半分鐘）；boundary lint 把 `examples/` 當框架目錄檢查。新增分析仍納入根目錄掃描。lint 自身的合成測試為 `python3 wf/tools/test_wf_lint.py` 與 `python3 tests/test_boundary_lint.py`。此檢查不能證明遊戲玩法正確。

## 已知訊息與尚未覆蓋

舊 icon UID 退回文字路徑、外部 image 載入警告仍需如實記錄，不把 exit 0 寫成零警告。過去 ObjectDB／resource 保留屬 04 的歷史問題，修復後不再作為可忽略基準；新增 ERROR、SCRIPT ERROR 或退出保留都須調查。

已驗單場戰鬥勝利到獎勵／回地圖、敗北到結算、單一主角的 CTB 行動順序，以及跨程序存讀後進入下一個遭遇；仍未驗完整多幕通關、所有卡牌／敵人、發行匯出或所有教學自訂 mod。UI handler／signal 的自動化不證明實際滑鼠命中；程式渲染、流程 assertions 與人工互動結果須分開記錄。

headless 通過不驗證 GPU、視窗呈現或原生 GUI 穩定性。某一程序 exit 0 只描述該次執行，不能排除其他實例崩潰。Dictionary 行為缺陷、資源保留訊息與原生 crash 是不同觀察；未建立程序／時間／故障模組證據鏈前，不宣稱共同根因或已修復。

## Done when

對應自動檢查通過，日誌中的限制與新增問題明列，來源／分析與 [code-map](common/code-map.md) 同步。只有實際需要使用者親自操作的項目才放 [WAIT_USER](../WAIT_USER.md)。
