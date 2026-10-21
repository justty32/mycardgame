# testing/suites — 隔離回歸 runner 與 suite

[testing](../testing.md)｜[環境](../dev-env.md)｜[各 suite 涵蓋範圍](suite-coverage.md)

本檔是 runner 的操作細則：怎麼跑、怎麼判定、怎麼把新內容或新 suite 接進去。執行邊界、Smoke 契約、文件檢查與 Done when 留在父檔 [testing](../testing.md)；每個 suite 實際驗了什麼見 [suite-coverage](suite-coverage.md)。

**何時用**：要跑背景回歸、讀懂 runner 的退出碼與日誌，或替新內容／新 suite 接上 runner。

**何時不用**：決定某類變更該補哪些測試 → [validation](../game-dev/validation.md)；引擎探測與各平台隔離 → [dev-env](../dev-env.md)。

## 怎麼跑

從專案根執行跨平台 runner [test_game.py](../../../tools/test_game.py)（Python 3.10+）。Windows 也可用沿用舊參數的薄包裝 [test-game.ps1](../../../tools/test-game.ps1)，判定規則相同。

```bash
python3 tools/test_game.py --suite All
# 可選 Dictionary、Smoke、Combat、SaveLoad、ResourceLifecycle、CombatVictory、CombatDefeat、Ctb、Board、Wave、Field、DualBoard、Boardless
python3 tools/test_game.py --suite SaveLoad
# Windows 包裝：./tools/test-game.ps1 -Suite SaveLoad
```

`All` 依序執行 ResourceLifecycle → Dictionary → Smoke → CombatVictory → CombatDefeat → Ctb → Board → Wave → Field → DualBoard → Boardless → SaveLoad（以 runner 的 `ALL_SUITES` 為準）。PackScenario 不在 All 內，見下方專節。

退出碼：0 為通過，1 為驗證失敗（含強制失敗），2 為找不到引擎等執行前錯誤。

## 隔離與判定

每個 suite 建立唯一的 artifacts/verification/ 副本，排除 Git、cache 與既有 profile、settings、saves，另外隔離 user://。來源與測試先保存快照與 hash（包含尚未提交的修復），再 Import 並執行。SaveLoad 的 write／read／rejected 三個程序共用同一副本；其他 suite 以及戰鬥勝、敗兩場各自分開。因此不需要清理使用者存檔，也不要直接在 game/ 跑流程測試。

runner 為每個程序設外層期限（預設 180 秒，可用 `--timeout-seconds` 調整），逾時只停止本次建立的程序樹。判定時檢查 exit、完成標記、SCRIPT ERROR／FAIL 與引擎錯誤；預設不放行退出時的 resource 或 ObjectDB leak。

兩個特例：

- 冷匯入若遇到指定的 SoundManager UID 訊息，建立快取後必須再次匯入通過。Godot 4.6 每次冷匯入都會出現；2026-10-19 Linux 4.7.2 未出現，但規則保留。
- SaveLoad 的 rejected 分支只放行十個逐項核對過的預期拒絕訊息。

日誌、命令及 results.json 留在唯一輸出目錄，不覆蓋舊證據。歷史重現開關不能當作修復後的通過標準。

## 診斷紀錄與 runner 自身的測試

runner 逐階段落盤 PID、時間、退出碼、來源與測試 hash、crash 標記，啟動前先確認 log 可寫；欄位與 wrapper PID 的限制見 [原生崩潰調查](../../notes/investigations/godot-native-crash.md)。

runner 本身用假引擎程序做 [合成測試](../../../tests/test_runner_diagnostics.py)：`python3 tests/test_runner_diagnostics.py`（2026-10-20 Windows 為 141 項，依平台可能不同）。它驗證資源訊息即使 exit 0 也必須判失敗；在 Windows 另驗無窗啟動、APPDATA 隔離、逾時只清理本次程序樹，以及引擎路徑探測。這組測試不啟動 Godot，也不證明使用者遇到的 crash 已重現或修復。

`python3 tests/test_link_pack.py` 驗 CRLF／BOM 逐位元組還原與 Windows 真實 junction（2026-10-20 Windows 6 tests 全通過）。沙箱拒絕建立 junction 時，保留失敗日誌並走環境核准，不能跳過後宣稱通過。

## 新內容如何接到 runner

框架 suite 使用固定入口；內容包可以用 Smoke probe 或下方的 PackScenario，見 [題材內容包](../game-dev/content/pack.md)。runner 會複製框架 `tests/` 頂層所有 `.gd`，但新增的 helper 必須由入口呼叫才算有驗證。

新 mod 的可操作範例見 [第一個 mod](../game-dev/content/bootstrap.md)：把專屬 helper 放在 tests，以執行中腳本的相鄰路徑載入，在 Smoke 的 autoload ready 之後、example_mod probe 之前呼叫，交由既有的 `_check()` 累計結果並退出。要保留失敗傳遞、timeout、資源清理與完成標記。

新增 suite 時，要同時改 runner 的選單、入口、標記與隔離契約，並同步 ps1 的 `ValidateSet` 與合成測試案例（Ctb 就是照此加入的）；不能只在文件裡寫出新命令。

`--source-game`（ps1 為 `-SourceGame`）只換遊戲來源，不換 tests。完整的候選演練要把 tools 與 tests 一起放到獨立的候選根目錄，再以 `--project-root` 指向它。source_hashes 涵蓋來源修復與雙盤／場域核心檔（實際清單見 runner 的 `SOURCE_HASH_PATHS`），新內容要另記檔案雜湊。

Combat 與 Ctb 的五張原生牌 fixture 會覆寫角色起手牌（含 append），SaveLoad 也有自己的語意情境。所以這些 suite 通過，不等於新增的卡、敵人、事件或音效已被實際執行；報告須列明新增的 assertion 與到達入口。

## PackScenario

`--suite PackScenario --content-profile pack --pack DIR --pack-tests DIR` 不在 All 內。可以疊載多個包，但只接受一個 tests 目錄，其中的 `scenario.json` 格式固定：

```json
{"schema":"pack-scenario/1","entry":"entry.gd","phases":["write","read","defeat"]}
```

只允許這三個鍵。entry 是目錄內 POSIX 相對 `.gd` 路徑，絕對路徑、路徑穿越、連結與缺檔都會被拒絕。phases 為 1–64 個不重複的識別字，須符合 `[a-z][a-z0-9_-]{0,63}`。全部 tests 檔會複製到 `res://pack_tests/`，manifest 保存 scenario 與包／測試的 hash。入口必須拒絕未知 phase，失敗時印 FAIL 並以非零值退出。

runner 依序以 `--scenario-phase=<id>` 啟動全新的 headless 程序，共用隔離的 game、user:// 與 appdata；每個階段各有 deadline、log、exit 與錯誤檢查。成功須印出獨立整行 `PACK SCENARIO PASS: <id>`，任一階段失敗就停止後續階段。不得使用 historical-baseline 或 no-isolate-appdata，也沒有 SaveLoad 那種預期拒絕的例外。

已準備副本的輸入條件見 [內容包](../game-dev/content/pack.md)。純 Python 的合成回歸為 `python3 -I tests/test_pack_scenario.py`，不啟動 Godot。
