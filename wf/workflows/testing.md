# testing — 啟動與擴充驗證

[WORKFLOWS](../WORKFLOWS.md)｜[INDEX](../INDEX.md)｜[環境](dev-env.md)

驗證基於上游 `4dac5abe` 加本地修復、Godot 4.7.x（2026-10-19 起；4.6 為歷史基準，引擎政策與遷移比對見 [upstream.json](../../tools/upstream.json) 的 `engine_policy`）。最新狀態見 [資源生命週期報告](../../analysis/slay-the-robot/architecture/05_resource_lifecycle.md)；[04 報告](../../analysis/slay-the-robot/architecture/04_regression_validation.md) 保留前次功能與資源限制，不代表所有玩法或發行版已通過。

新任務依 [變更類型選驗證](game-dev/validation.md) 決定現有檢查與需補的測試；原生崩潰、記憶體讀取錯誤或異常退出走 [native-crash](game-dev/native-crash.md)。

## 目前執行邊界

目前有效授權只允許檔案修改與不開視窗的背景檢查；不得操作 UI／桌面、截圖、切換焦點、開啟 GUI，或干預既有程序。原生崩潰調查已依使用者要求擱置。後續依當時授權判斷；`game.ps1 -Mode Run` 會開視窗，不自動跑，歷史 capture 命令亦不適用。

背景驗證優先使用 [suites](testing/suites.md) 的 `test_game.py`，選擇與變更相關的 suite；它使用隔離副本及 headless 引擎，避免直接在 `game/` 建立遊戲進度。純文件修改只跑文件 lint，不為更新流程而啟動 Godot。

## Smoke 契約

首次匯入或資源變動需要 Import，隔離 runner 會處理；框架、資料格式、載入流程變動需 Smoke。檢查 [framework_smoke.gd](../../tests/framework_smoke.gd) 的主場景、主選單、角色與起手牌、Array append，真實 FileLoader 的 example_mod 新卡、起手牌追加和 script takeover，以及戰鬥框架 [probe](../../tests/unit_registry_probe.gd)。mod 清單只在測試記憶體覆寫，不修改 game/external/mod_list.json；測試不開始 run。

Smoke 必須 exit 0、有 SMOKE PASS 標記、無 SCRIPT ERROR 或 FAIL。腳本有 45 秒事件迴圈 timeout；若程序同步卡死，外層需停止該測試程序。`--force-failure`（ps1 為 `-ForceFailure`）是失敗出口控制，必須 exit 1，不能列為正常驗證失敗。

[file_loader_probe.gd](../../tests/file_loader_probe.gd) 在兩種 content profile 共用執行，使用隔離 fixture 走真實 mod_list／mod_info／資料載入，驗 `.json`／`.JSON`、排序 patch、非 JSON／備份排除、非遞迴與 Global 表還原。只看最後 PASS 不足：載入佔位檔的 ERROR 即使 assertions 通過，runner 仍須拒絕。

Dictionary merge 已修正，Smoke 的四種策略現在是會使測試失敗的 assertions。完整 JSON patch 邊界由 [suites](testing/suites.md) 的 Dictionary 回歸涵蓋，不能只靠 Smoke 代表所有序列化契約。

## 隔離回歸 runner 與 suite

runner `python3 tools/test_game.py --suite <名稱>`（Windows 包裝 `./tools/test-game.ps1 -Suite <名稱>`）的 suite 清單（含 CTB 時間軸的 Ctb、棋盤的 Board、波次的 Wave）、隔離副本、期限與退出碼判定、合成測試，以及新內容／新 suite 怎麼接進 runner，見 [testing/suites](testing/suites.md)。

## 文件檢查（修改後必跑）

從專案根以 bash 加 python3 執行；`python3 --version` 須實際成功，不能只看命令存在。

```bash
python3 --version && bash wf/tools/wf-lint.sh --strict . && python3 tools/boundary_lint.py
```

Linux／macOS 用 bash；Windows 經 WSL 或 Git Bash，步驟與商店別名／Win32 error 5 處理見 [dev-env/windows](dev-env/windows.md)。2026-10-19 Manjaro 原生與 Windows WSL 皆回傳全部零項。

WSL 的 CRLF 錯誤依 [版本控制](version-control.md) 查 shell 換行。

exit 0 且 broken、residue、oversize、biglist、querycmd 均為 0。新增分析仍納入根目錄掃描。此檢查不能證明遊戲玩法正確。

## 已知訊息與尚未覆蓋

舊 icon UID 退回文字路徑、外部 image 載入警告仍需如實記錄，不把 exit 0 寫成零警告。過去 ObjectDB／resource 保留屬 04 的歷史問題，修復後不再作為可忽略基準；新增 ERROR、SCRIPT ERROR 或退出保留都須調查。

已驗單場戰鬥勝利到獎勵／回地圖、敗北到結算、單一主角的 CTB 行動順序，以及跨程序存讀後進入下一個遭遇；仍未驗完整多幕通關、所有卡牌／敵人、發行匯出或所有教學自訂 mod。UI handler／signal 的自動化不證明實際滑鼠命中；程式渲染、流程 assertions 與人工互動結果須分開記錄。

headless 通過不驗證 GPU、視窗呈現或原生 GUI 穩定性。某一程序 exit 0 只描述該次執行，不能排除其他實例崩潰。Dictionary 行為缺陷、資源保留訊息與原生 crash 是不同觀察；未建立程序／時間／故障模組證據鏈前，不宣稱共同根因或已修復。

## Done when

對應自動檢查通過，日誌中的限制與新增問題明列，來源／分析與 [code-map](common/code-map.md) 同步。只有實際需要使用者親自操作的項目才放 [WAIT_USER](../WAIT_USER.md)。
