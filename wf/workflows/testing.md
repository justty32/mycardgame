# testing — 啟動與擴充驗證

[WORKFLOWS](../WORKFLOWS.md)｜[INDEX](../INDEX.md)｜[環境](dev-env.md)

驗證基於上游 `4dac5abe` 加本地修復、Godot 4.7.x（2026-10-19 起；4.6 為歷史基準，引擎政策與遷移比對見 [upstream.json](../../tools/upstream.json) 的 `engine_policy`）。最新狀態見 [資源生命週期報告](../../analysis/slay-the-robot/architecture/05_resource_lifecycle.md)；[04 報告](../../analysis/slay-the-robot/architecture/04_regression_validation.md) 保留前次功能與資源限制，不代表所有玩法或發行版已通過。

新任務依 [變更類型選驗證](game-dev/validation.md) 決定現有檢查與需補的測試；原生崩潰、記憶體讀取錯誤或異常退出走 [native-crash](game-dev/native-crash.md)。

## 目前執行邊界

目前有效授權只允許檔案修改與不開視窗的背景檢查；不得操作 UI／桌面、截圖、切換焦點、開啟 GUI，或干預既有程序。原生崩潰調查已依使用者要求擱置。後續任務依當時有效授權判斷；`game.ps1 -Mode Run` 會開啟視窗，不自動執行，歷史 capture 指令也不適用。

背景驗證優先使用下節的 `test_game.py`，選擇與變更相關的 suite；它使用隔離副本及 headless 引擎，避免直接在 `game/` 建立遊戲進度。純文件修改只跑文件 lint，不為更新流程而啟動 Godot。

## Smoke 契約

首次匯入或資源變動需要 Import，隔離 runner 會處理；框架、資料格式、載入流程變動需 Smoke。檢查 [framework_smoke.gd](../../tests/framework_smoke.gd) 的主場景、主選單、角色與起手牌、Array append，以及真實 FileLoader 的 example_mod 新卡、起手牌追加和 script takeover。mod 清單只在測試記憶體覆寫，不修改 game/external/mod_list.json；測試不開始 run。

Smoke 必須 exit 0、有 SMOKE PASS 標記、無 SCRIPT ERROR 或 FAIL。腳本有 45 秒事件迴圈 timeout；若程序同步卡死，外層需停止該測試程序。`--force-failure`（ps1 為 `-ForceFailure`）是失敗出口控制，必須 exit 1，不能列為正常驗證失敗。

Dictionary merge 已修正，Smoke 的四種策略現在是會使測試失敗的 assertions。完整 JSON patch 邊界由下方 Dictionary 回歸涵蓋，不能只靠 Smoke 代表所有序列化契約。

## 隔離回歸與流程驗證

從專案根執行跨平台 runner [test_game.py](../../tools/test_game.py)（Python 3.10+）；Windows 也可用沿用舊參數的薄包裝 [test-game.ps1](../../tools/test-game.ps1)，判定規則相同。

```bash
python3 tools/test_game.py --suite All
# 可選 Dictionary、Smoke、Combat、SaveLoad、ResourceLifecycle、CombatVictory、CombatDefeat
python3 tools/test_game.py --suite SaveLoad
# Windows 包裝：./tools/test-game.ps1 -Suite SaveLoad
```

exit 0 為通過、1 為驗證失敗（含強制失敗）、2 為找不到引擎等執行前錯誤。引擎探測與各平台隔離見 [dev-env](dev-env.md)。

每個 suite 建立唯一 artifacts/verification/ 副本，排除 Git/cache 與既有 profile、settings、saves，另隔離 user://。來源與測試先保存快照／hash，包含尚未提交的修復，再 Import 並執行。SaveLoad 的 write／read／rejected 三個程序共用同一副本；其他 suite 及戰鬥勝敗分開。不需清理使用者存檔，也不直接在 game/ 跑流程測試。

runner 為每個程序設外層期限（預設 180 秒，`--timeout-seconds` 可調），只停止本次程序樹；檢查 exit、完成標記、SCRIPT ERROR／FAIL 與引擎錯誤。預設不放行退出 resource 或 ObjectDB leak。冷匯入若遇指定 SoundManager UID，建立快取後必須再次匯入通過（4.6 每次冷匯入都出現，2026-10-19 Linux 4.7.2 未出現，規則仍保留）；rejected 分支只放行十個逐項核對的預期拒絕訊息。日誌、命令及 results.json 留於唯一輸出目錄，不覆蓋舊證據。歷史重現開關不作修復後通過標準。

runner 逐階段落盤 PID／時間／退出碼、來源與測試 hash、crash 標記，啟動前確認 log 可寫；欄位與 wrapper PID 限制見 [native-crash](game-dev/native-crash.md)。[合成測試](../../tests/test_runner_diagnostics.py)（`python3 tests/test_runner_diagnostics.py`，134 項）以假引擎程序驗 runner，包含資源訊息即使 exit 0 也須失敗；不啟動 Godot，也不證明使用者 crash 已重現／修復。

[Dictionary](../../tests/dictionary_regression.gd) 走 JSON patch API；[Combat](../../tests/combat_flow.gd) 跑單場戰鬥及獎勵；[SaveLoad](../../tests/save_load_flow.gd) 驗跨程序語意還原與續玩；[ResourceLifecycle](../../tests/resource_lifecycle.gd) 驗 processor、async／取消與 Root 清理。fixture 與結果見報告；測試設定不代表所有卡牌／遭遇或自訂內容已驗證。

## 新內容如何接到 runner

目前 suite 是上面列出的固定集合，沒有 Custom 或任意 script 參數；題材內容包用 `--pack`／`--pack-tests` 裝入隔離副本並由 Smoke 呼叫其 probe，見 [題材內容包](game-dev/content/pack.md)。runner 複製其專案 `tests/` 頂層所有 `.gd` 到每個隔離 suite 的 tests 目錄，再執行固定入口；新增 helper 只會被複製，必須由既有入口明確呼叫才有驗證。

新 mod 的可操作範例見 [第一個 mod](game-dev/content/bootstrap.md)：將專屬 helper 放 tests，以執行中腳本的相鄰路徑載入，於 Smoke 的 autoload ready 後、example_mod probe 前呼叫，交由既有 `_check()` 累計及退出。保留失敗傳遞、timeout、資源清理與完成標記。新 suite 需另改 runner 的選單、入口、標記與隔離契約，不可僅在文件寫出新命令。

`--source-game`（ps1 `-SourceGame`）只換遊戲來源，不換 tests；完整候選演練須把 tools 與 tests 一併放到獨立候選根，再以 `--project-root` 指向它。source_hashes 目前是 15 個框架檔的清單，新內容另記檔案雜湊。Combat 的五張原生牌 fixture 會覆寫角色起手 append；SaveLoad 也有自己的語意情境。這些 suite 通過不等於新增卡／敵人／事件／音效已被實際執行，報告須列明新 assertion 及到達入口。

## 文件檢查（修改後必跑）

從專案根以 bash 加 python3 執行；`python3 --version` 須實際成功，不能只看命令存在。

```bash
python3 --version && bash wf/tools/wf-lint.sh --strict . && python3 tools/boundary_lint.py
```

Linux／macOS 直接用原生 bash；Windows 經 WSL 或 Git Bash，步驟與商店別名／Win32 error 5 處理見 [dev-env/windows](dev-env/windows.md)。2026-10-19 Manjaro 原生與 Windows WSL 皆回傳全部零項。

WSL 的 CRLF 錯誤依 [版本控制](version-control.md) 查 shell 換行。

exit 0 且 broken、residue、oversize、biglist、querycmd 均為 0。新增分析仍納入根目錄掃描。此檢查不能證明遊戲玩法正確。

## 已知訊息與尚未覆蓋

舊 icon UID 退回文字路徑、外部 image 載入警告仍需如實記錄，不把 exit 0 寫成零警告。過去 ObjectDB／resource 保留屬 04 的歷史問題，修復後不再作為可忽略基準；新增 ERROR、SCRIPT ERROR 或退出保留都須調查。

已驗單場戰鬥勝利到獎勵／回地圖、敗北到結算，以及跨程序存讀後進入下一個遭遇；仍未驗完整多幕通關、所有卡牌／敵人、發行匯出或所有教學自訂 mod。UI handler／signal 的自動化不證明實際滑鼠命中；程式渲染、流程 assertions 與人工互動結果須分開記錄。

headless 通過不驗證 GPU、視窗呈現或原生 GUI 穩定性。某一程序 exit 0 只描述該次執行，不能排除其他實例崩潰。Dictionary 行為缺陷、資源保留訊息與原生 crash 是不同觀察；未建立程序／時間／故障模組證據鏈前，不宣稱共同根因或已修復。

## Done when

對應自動檢查通過，日誌中的限制與新增問題明列，來源／分析與 [code-map](common/code-map.md) 同步。只有實際需要使用者親自操作的項目才放 [WAIT_USER](../WAIT_USER.md)。
