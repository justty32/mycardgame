# 第一個 mod 的接線與驗收邊界

[分析入口](../README.md)｜[內容流程](../../../wf/workflows/game-dev/content.md)｜[可執行步驟](../../../wf/workflows/game-dev/content/bootstrap.md)

2026-10-19 核對上游 4dac5abe 加本地修復；本篇先靜態核實，再記錄專責 agent 的隔離候選實跑。冷接手演練從 wf/WORKFLOWS 進入 agent-session、dev-env、content、validation 及新手指南，確認資料樣例足夠，但新內容與現有 runner 之間缺少明確的 helper 接線。操作細節已補在內容子流程，不在此重複維護。

## 實際來源契約

[Global._ready()](../../../game/autoload/Global.gd) 先註冊 schema、產生測試資料，再由 [FileLoader.load_read_only_data()](../../../game/autoload/FileLoader.gd) 讀 mod_list、依 priority 載入 mod_info 指定資料夾，最後建 card pack cache。因此 game 根下的 mod 路徑、啟用登記、資料夾映射及 object_id 都不可省略；角色 append 要避免在同一程序反覆 reload。

[新手指南](../tutorial/beginner_guide_zh.md) 提供三個最小 JSON：mod_info、重擊卡、紅色角色補丁。它使用既有 AttackGenerator，暫不參與卡包，只追加到新局起手。這是可實作的範例設計，不是正式遊戲需求或已驗玩法。

## 測試真正執行哪裡

[test-game.ps1](../../../tools/test-game.ps1) 只接受固定 Suite。它以工具所在專案為根，複製頂層 tests/*.gd 後只執行固定入口；`-SourceGame` 不改 tests 的來源。操作篇因此讓完整候選根保存 game、tools、tests，專屬 helper 在 Smoke autoload ready 後、官方 example_mod probe 前取得已載入資料，將八項結果交給既有 `_check()`。

[framework_smoke.gd](../../../tests/framework_smoke.gd) 原有的 example_mod 動態 FileLoader 與 script takeover 證明官方範例，不證明新 mod。新增 helper 的程式只是文件範例；沒有放入 tests 並插入呼叫之前，不會被 runner 執行。

[combat_fixture.gd](../../../tests/combat_fixture.gd) 將紅色起始牌組覆寫為三張 Basic Attack、兩張 Basic Block；[combat_flow.gd](../../../tests/combat_flow.gd) 的勝敗、能量與傷害斷言依賴此配置。故新卡起手 append 加上既有 Combat PASS，仍不證明新卡可出牌；需要專屬情境與數值斷言。[SaveLoad](../../../tests/save_load_flow.gd) 的語意往返同樣要確認包含本次新 ID，不能用原生卡的存讀結果代替。

## 證據與限制

來源 manifest 的 source_hashes 目前固定列出 13 個框架檔；新 mod 檔、mod_list 及修改測試需額外記錄 hash。測試腳本雖會保存 hash，仍要核對真正執行的新 assertion、退出碼、完成標記及資源錯誤，不以檔案存在代替執行。

本輪文件修補的 PowerShell 範例已以 Parser 靜態解析。載入、出牌、視覺、音效、存讀及發布各自需要適用證據；headless 不涵蓋 GUI、輸入命中或原生視窗穩定性。候選副本試驗不等於已把 mod 納入正式 game，歷史 498 項 All 也不包含這份新範例。

## 文件引導的候選實跑

專責 agent 按操作篇與其新手指南連結建立唯一候選 `artifacts/cold-start/recipe-20261019-143746-3005575c`，將文件中的 helper 接到候選 Smoke。作者另讀實際 manifest 及日誌核對結果；未在原專案 game／tools／tests 寫入 mod。執行者在文件 ready 前曾回饋 runner 根路徑與 APPDATA 前提，因此這是文件引導的實作復走，不稱為完全盲目的第二輪冷啟動。

首次 run `20261019-143847-d79d0ff8` 的 version exit 0；import 引擎 exit 0，卻因 `ERROR: Failed to read the root certificate store.` 被 runner 判為失敗，八項新斷言尚未執行。原始 first-attempt.md 與失敗 manifest 保留；此為環境觀察，不能推定 mod 缺陷，也未放寬白名單。

相同候選與 runner 在工具核准的背景權限下重試，run `20261019-144001-1a30d2da` 為 `completed=true`、`verdict=PASS`，Godot `4.6.stable.official.89cea1439`。version、import、import-verified、smoke 四階段皆 exit 0；SMOKE PASS 為 52 checks／0 failures，八項 `PASS: MOD:` 全部存在。指定 cold UID 經重驗，退出資源與 native crash 標記皆空；Smoke 仍有 20 次 icon UID fallback、2 次 image/export 警告。

候選 recipe-manifest.json 記錄輸入 hash 與原專案 868 檔前後一致；另存 candidate-input-hashes.csv，補足 runner 未記新 mod hash 的範圍。[可攜證據](../onboarding/evidence/README.md) 保存原始／副本 hash 與遮罩說明，完整原件仍保留於上述候選根。此輪只驗註冊、欄位、起手引用與 action 路徑，未驗出牌、預覽、存讀、GUI、音效或正式發布，不能加計到歷史 All 498 或宣稱正式遊戲已加入重擊。
