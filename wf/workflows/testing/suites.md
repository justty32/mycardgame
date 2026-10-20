# testing/suites — 隔離回歸 runner 與 suite

[testing](../testing.md)｜[環境](../dev-env.md)｜[WORKFLOWS](../../WORKFLOWS.md)

從 testing 抽出的 runner 細則與 suite 清單；執行邊界、Smoke 契約、文件檢查與 Done when 留在父檔。

## 隔離回歸與流程驗證

從專案根執行跨平台 runner [test_game.py](../../../tools/test_game.py)（Python 3.10+）；Windows 也可用沿用舊參數的薄包裝 [test-game.ps1](../../../tools/test-game.ps1)，判定規則相同。

```bash
python3 tools/test_game.py --suite All
# 可選 Dictionary、Smoke、Combat、SaveLoad、ResourceLifecycle、CombatVictory、CombatDefeat、Ctb、Board、Wave、Field、DualBoard、Boardless
python3 tools/test_game.py --suite SaveLoad
# Windows 包裝：./tools/test-game.ps1 -Suite SaveLoad
```

exit 0 為通過、1 為驗證失敗（含強制失敗）、2 為找不到引擎等執行前錯誤。引擎探測與各平台隔離見 [dev-env](../dev-env.md)。

每個 suite 建立唯一 artifacts/verification/ 副本，排除 Git/cache 與既有 profile、settings、saves，另隔離 user://。來源與測試先保存快照／hash，包含尚未提交的修復，再 Import 並執行。SaveLoad 的 write／read／rejected 三個程序共用同一副本；其他 suite 及戰鬥勝敗分開。不需清理使用者存檔，也不直接在 game/ 跑流程測試。

runner 為每個程序設外層期限（預設 180 秒，`--timeout-seconds` 可調），只停止本次程序樹；檢查 exit、完成標記、SCRIPT ERROR／FAIL 與引擎錯誤。預設不放行退出 resource 或 ObjectDB leak。冷匯入若遇指定 SoundManager UID，建立快取後必須再次匯入通過（4.6 每次冷匯入都出現，2026-10-19 Linux 4.7.2 未出現，規則仍保留）；rejected 分支只放行十個逐項核對的預期拒絕訊息。日誌、命令及 results.json 留於唯一輸出目錄，不覆蓋舊證據。歷史重現開關不作修復後通過標準。

runner 逐階段落盤 PID／時間／退出碼、來源與測試 hash、crash 標記，啟動前確認 log 可寫；欄位與 wrapper PID 限制見 [native-crash](../game-dev/native-crash.md)。[合成測試](../../../tests/test_runner_diagnostics.py)（`python3 tests/test_runner_diagnostics.py`；2026-10-20 Windows 為 141 項，依平台可不同）以假引擎程序驗 runner，包含資源訊息即使 exit 0 也須失敗；Windows 驗無窗啟動、APPDATA 隔離、逾時清理本次程序樹及引擎路徑探測，不啟動 Godot，也不證明使用者 crash 已重現／修復。另跑 `python3 tests/test_link_pack.py` 驗 CRLF／BOM 逐位元組還原與 Windows 真實 junction；2026-10-20 Windows 6 tests 全通過。沙箱拒絕建立 junction 時保留失敗日誌並走環境核准，不跳過後宣稱通過。

[Dictionary](../../../tests/dictionary_regression.gd) 走 JSON patch API；[Combat](../../../tests/combat_flow.gd) 跑單場戰鬥及獎勵；[Ctb](../../../tests/ctb_flow.gd)（fixture [ctb_fixture.gd](../../../tests/ctb_fixture.gd)，標記 `CTB PASS:`，在 All 中排在 CombatDefeat 與 SaveLoad 之間）驗 CTB 時間軸：不同速度的行動順序與刻數、`combat_tick_advanced`、EVERY_N_TICKS 狀態、行動開始清格擋、turn_count＝主角行動數、TimelineBar／TurnOverlay 文字與中途離樹後 Director 停止；[Board](../../../tests/board_flow.gd)（cases [board_cases.gd](../../../tests/board_cases.gd)、fixture [board_fixture.gd](../../../tests/board_fixture.gd)，標記 `BOARD PASS:`，在 All 中排在 Ctb 與 SaveLoad 之間）驗 7×5 棋盤：移動點與付費移動延遲、障礙與繞路、射程／CROSS／LINE_PIERCE／2×2 佔格、突進／推／拉近／交換／閃現、定身、召喚最近空格、KEEP_RANGE／CHARGE／APPROACH 移動與 ThreatPreview 等於實際受傷；[Wave](../../../tests/wave_flow.gd)（cases [wave_cases.gd](../../../tests/wave_cases.gd)、fixture [wave_fixture.gd](../../../tests/wave_fixture.gd)，標記 `WAVE PASS:`，在 All 中排在 Board 與 SaveLoad 之間）驗三波遭遇：wave_started／wave_cleared 的刻數、波間格擋牌不被短路、登場延遲與錯開、WAIT_UNTIL_FREE 重試後改最近空格、FAIL_SKIP 跳過、雜兵不擋清波、每波 wave_on_cleared_actions 加錢，以及最後一波清空才 combat_ended；[SaveLoad](../../../tests/save_load_flow.gd) 驗跨程序語意還原與續玩；[ResourceLifecycle](../../../tests/resource_lifecycle.gd) 驗 processor、async／取消與 Root 清理。fixture 與結果見報告；不代表所有卡牌／遭遇或自訂內容已驗證。

[Field](../../../tests/field_flow.gd) 與 [DualBoard](../../../tests/dual_board_flow.gd) 分別使用 `FIELD PASS:`／`DUAL_BOARD PASS:`，依序在 Wave 後、SaveLoad 前執行。前者驗場域、ZOC、位移、位置條件與 ordered lifecycle；後者從正常新局走預設雙盤、A targeting、原子 transfer/swap、兩盤場域與本體站格。各自的實際 assertions／執行結果見 [雙盤驗收表](../../../analysis/slay-the-robot/design/dual-board/verification.json)；工程仍在整合時不可引用舊 All 代替新增 suite。Board／Wave 的既有單盤案例以顯式 SINGLE 保持距離契約，DUAL 為正常新局預設。

[Boardless](../../../tests/boardless_flow.gd) 在 All 的 DualBoard 後執行；四個程序共用隔離副本，以 `--boardless-phase=write/read/defeat/scene_off` 分別驗關閉棋盤的戰鬥、存讀、死亡及場景開關。逐階段要求整行 `BOARDLESS PASS: <phase>`，任一失敗停止。

## 新內容如何接到 runner

框架 suite 使用固定入口；內容包可用 Smoke probe 或下述 PackScenario，見 [題材內容包](../game-dev/content/pack.md)。runner 複製框架 `tests/` 頂層所有 `.gd`；新增 helper 必須由入口呼叫才有驗證。

新 mod 的可操作範例見 [第一個 mod](../game-dev/content/bootstrap.md)：將專屬 helper 放 tests，以執行中腳本的相鄰路徑載入，於 Smoke 的 autoload ready 後、example_mod probe 前呼叫，交由既有 `_check()` 累計及退出。保留失敗傳遞、timeout、資源清理與完成標記。新 suite 需另改 runner 的選單、入口、標記與隔離契約，並同步 ps1 的 `ValidateSet` 與合成測試案例（Ctb 即照此加入），不可僅在文件寫出新命令。

`--source-game`（ps1 `-SourceGame`）只換遊戲來源，不換 tests；完整候選演練須把 tools 與 tests 一併放到獨立候選根，再以 `--project-root` 指向它。source_hashes 涵蓋來源修復與雙盤／場域核心檔（實際清單見 runner 的 SOURCE_HASH_PATHS），新內容另記檔案雜湊。Combat 與 Ctb 的五張原生牌 fixture 會覆寫角色起手牌（含 append）；SaveLoad 也有自己的語意情境。這些 suite 通過不等於新增卡／敵人／事件／音效已被實際執行，報告須列明新 assertion 及到達入口。

## PackScenario

`--suite PackScenario --content-profile pack --pack DIR --pack-tests DIR` 不在 All 內；多包可疊載，但只接受一個 tests 目錄，其 `scenario.json` 格式固定：

```json
{"schema":"pack-scenario/1","entry":"entry.gd","phases":["write","read","defeat"]}
```

只允這三個鍵；entry 為目錄內 POSIX 相對 `.gd` 路徑，拒絕絕對路徑、穿越、連結與缺檔。phases 為 1–64 個唯一識別字，符合 `[a-z][a-z0-9_-]{0,63}`。全部 tests 檔複製至 `res://pack_tests/`，manifest 保存 scenario 與包／測試 hash。入口須拒絕未知 phase，失敗印 FAIL 並非零退出。

依序以 `--scenario-phase=<id>` 啟動全新 headless 程序，共用隔離 game／user://／appdata，每階段有獨立 deadline、log、exit 與錯誤檢查。成功須獨立整行 `PACK SCENARIO PASS: <id>`；任一失敗停止後續。不得使用 historical-baseline 或 no-isolate-appdata；沒有 SaveLoad 預期拒絕的例外。

已準備副本的輸入條件見 [內容包](../game-dev/content/pack.md)。純 Python 合成回歸：`python3 -I tests/test_pack_scenario.py`，不啟 Godot。
