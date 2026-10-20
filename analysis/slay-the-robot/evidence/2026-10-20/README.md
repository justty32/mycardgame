# 公司 Windows 背景驗證證據

[證據入口](../README.md)｜[轉換清單與雜湊](manifest.json)

本輪在 Windows 11、Python 3.13，以官方 Godot `4.7.2.stable.mono.official.ed1daf0bf` 完成隔離 headless 驗證。只保留最終結果、各 suite 主日誌及必要工具證據；原始 artifacts 不修改，重複 import／version 日誌、歷史 All 與失敗原件留在本機。原始程序階段的退出碼、命令與來源 hashes 仍完整保留在 results。

## 最終 All

[最終 results](final-all-results.json) 對應 run `20261020-082010-447c566b`：21 個程序階段均通過，768 個 assertions、零失敗。此 run 已包含 JSON 資料檔過濾修正與新增 Smoke 回歸；較早 746 項 run 不作為最終來源驗證。

各 suite 主日誌位於 `final-all/`。數量為 ResourceLifecycle 127、Dictionary 47、Smoke 110、CombatVictory 90、CombatDefeat 48、Ctb 53、Board 88、Wave 48、SaveLoad write／read／rejected 分別 28／56／73。來源與發布檔案的對照、SHA-256、位元組數及轉換方式收於 manifest，不另複製一份逐檔清單。

## 失敗出口與工具回歸

[失敗出口 results](forced-failure-results.json) 對應 run `20261020-082720-d60fec47`，verdict 為 `FORCED_FAILURE_DETECTED`，Smoke exit 1。[Smoke 日誌](forced-failure/Smoke/smoke.log) 有 110 個通過與 1 個刻意失敗，合計 111 個檢查。`completed=false` 表示走預期失敗出口，不可誤讀為另一輪綠測或未觀察到失敗。

[Runner 合成結果](runner-diagnostics-results.json) 為 141 項通過，沒有啟動 Godot；其中故意注入的 blocked-log、timeout、crash 或錯誤樣本不可當作實際引擎事故。[連結工具結果](link-pack-results.json) 為 6 項測試全通過，涵蓋實際 Windows junction、空白路徑、解除連結保留 target、runner 排除 junction 及換行／BOM 還原；原版 CRLF 缺陷另存 `link-pack-baseline-regression.json`。新內容包工具與邊界工具的合成日誌分別為 14、19 項通過。

## 來源與發布轉換

[引擎來源](engine-provenance.json) 與 [引擎探測](discovery.json) 保留本機取得與版本選擇證據。原件轉為 UTF-8、LF，主機專案與使用者家目錄分別遮罩成 `{PROJECT_ROOT}`、`{USER_PROFILE}`；JSON 重新排版。邊界合成測試刻意注入的具體題材路徑只在發布副本換成 `games/<SYNTHETIC_GAME>`；判斷、錯誤及 assertions 保留。每項轉換列於 manifest，原件與副本 hash 分開記錄。

最終 All 當時的來源鎖已含 `json-data-files.patch`。其後只在 `engine_policy.verified_builds` 追加 Windows 執行紀錄，上游與補丁 hashes 不變；因此現行 `tools/upstream.json` 的檔案 hash 可以與 results 的 `source_lock_sha256` 不同。results 保留執行當時值；本機重建的 `artifacts/windows-validation/run-source-lock.json` 已核對與該值完全相符，不補寫原 manifest。

題材內容包原始結果留在本機，不將題材詞彙或 probe 原文放入框架證據。通過範圍限背景程序與自動斷言，不證明 GUI、滑鼠命中、畫面觀感、聽感、完整多幕通關、發行匯出或先前原生崩潰已修復。
