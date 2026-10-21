# 可攜驗證證據

[分析入口](../README.md)｜[資源生命週期報告](../architecture/05_resource_lifecycle.md)

本目錄只收錄供版本管理的精選文字證據，不包含遊戲副本、引擎、快取、使用者存檔或畫面。原始 artifacts 保留在本機，不因發布副本而修改。這些是對應來源版本的執行結果，不表示任意後續工作目錄都已重新驗證。

## 2026-10-20 Windows 4.7.2 Mono

[可選棋盤模組最終證據](2026-10-20/board-module/README.md) 保存 All 1809 checks、真正無棋盤戰鬥、949 檔重建及工具驗證；以下是同日較早基準。

[雙棋盤 A／Phase 2b 最終證據](2026-10-20/dual-board/README.md) 保存本輪 All 1470 checks、來源重建與 runner 143 項結果；包含角色本體站格、場域／控制區及跨程序存讀。以下 768 項結果為同日較早基準。

[本輪精選證據](2026-10-20/README.md) 保存修後 All 768 checks、強制失敗出口、Windows runner／junction 合成驗證與引擎來源；詳細行為與限制見 [Windows 報告](../architecture/06_windows_validation.md)。原始 import 日誌、修前 All 與紅測留本機；發布內容以日期目錄的轉換清單核對來源及副本 hashes，不混用舊來源結果。

## 2026-10-19

[轉換清單與雜湊](2026-10-19/manifest.json) 記錄各原件的專案相對位置、原件與發布副本 SHA-256、大小及轉換方式。檔案解碼為 UTF-8、統一 LF；JSON 重新排版，字串內的原專案絕對位置替換為 `{PROJECT_ROOT}`，個人家目錄替換為 `{USER_PROFILE}`。這些代號是證據遮罩，不是可直接執行的命令或新的實測位置。

原日誌的斷言、退出碼、錯誤與警告保留。歷史工具轉錄的兩個 Markdown 連結另按發布位置重算；所有轉換均列在清單，副本雜湊不應與原件相同。

## 相同副本去重

2026-10-21 起，內容逐位元組相同的發布副本只留一份：同一 run 各 suite 相同的 import 日誌，以及跨 run 相同的主日誌。共刪 37 份，[去重索引](dedup-index.json) 逐列記錄 `removed_copy`（原發布位置）、`canonical_path`（保留副本）、SHA-256、bytes 及所屬轉換清單。各轉換清單的對應列保留原件位置與兩組 hash，`published_path` 改指保留副本，原位置記在 `removed_copy`；從原檔名查索引或清單即可找到內容。三份 0 bytes 的 version.log 去重不省空間，照舊保留。

## 事故與診斷

[歷史工具輸出轉錄](2026-10-19/crash-prior-tool-evidence.md) 保留先前 signal 11 與後續編譯錯誤的證據邊界；其引用的 [早期 editor import 日誌](2026-10-19/startup-import.log) 是另一事件，不是 crash 的前文。舊 PowerShell runner 的 [32 項合成檢查](2026-10-19/runner-diagnostics-results.json) 驗證背景程序診斷，沒有啟動 Godot；不能當成原生崩潰已修復。

## 112 項資源生命週期回歸

[紅測試日誌](2026-10-19/resource-lifecycle-red.log)、[綠測試日誌](2026-10-19/resource-lifecycle-green.log) 與 [綠測試 manifest](2026-10-19/resource-lifecycle-green-results.json) 保留當時的修前／修後結果與來源 hashes。它們屬獨立 ResourceLifecycle suite；不取代本輪稍後完成的全套流程驗證，也不主張所有執行情境均無資源殘留。

## 最終 498 項整合驗證

[最終 All manifest](2026-10-19/final-all-results.json) 對應原始 run `20261019-141014-31bb0cb1`，21 個程序階段均 exit 0，整體 verdict 為 PASS。其每個階段的實際 engine log 保存於 `2026-10-19/final-all/`，包含初次／再次 import 的完整訊息；各 suite 相同的 import 日誌只留 CombatDefeat 一份，其他 suite 經轉換清單或去重索引查到同一副本。

[ResourceLifecycle](2026-10-19/final-all/ResourceLifecycle/resourcelifecycle.log) 127、[Dictionary](2026-10-19/final-all/Dictionary/dictionary.log) 47、[Smoke](2026-10-19/final-all/Smoke/smoke.log) 43、[勝利](2026-10-19/final-all/CombatVictory/combatvictory.log) 82、[敗北](2026-10-19/final-all/CombatDefeat/combatdefeat.log) 42 項，全部零失敗。

SaveLoad 的 [write](2026-10-19/final-all/SaveLoad/save-write.log) 28、[read](2026-10-19/final-all/SaveLoad/save-read.log) 56、[rejected](2026-10-19/final-all/SaveLoad/save-rejected.log) 73 項亦零失敗，合計 498 項。21 份日誌沒有 ObjectDB leak 或退出資源殘留訊息；rejected 的明示拒絕與冷匯入重查仍保留，不宣稱所有日誌完全沒有 ERROR。

最終斷言的修前證據見 [127 項紅測試](2026-10-19/resource-lifecycle-127-red.log) 與 [其 manifest](2026-10-19/resource-lifecycle-127-red-results.json)；較早 Map 退場問題另保留 [紅日誌](2026-10-19/map-transition-red.log) 與 [manifest](2026-10-19/map-transition-red-results.json)。[runner 44 項合成檢查](2026-10-19/runner-diagnostics-44-results.json) 是後續診斷覆蓋，舊 32 項結果仍保留為歷史證據。

## Godot 4.7.2（Linux）重跑

引擎基準升 4.7.x 後，2026-10-19 在 Manjaro 原生以 Python runner 重跑 All：[4.7.2 All manifest](2026-10-19/final-all-4.7.2-linux-results.json) 對應原始 run `20261019-194556-becc58ea`，引擎為發行版套件 `4.7.2.stable.mono.arch_linux.ed1daf0bf`（經 PATH 探測），15 個程序階段均 exit 0，verdict 為 PASS。各 suite 的 import 與主日誌在 `2026-10-19/final-all-4.7.2-linux/`，相同的 import 日誌只留 CombatDefeat 一份；例如 [Smoke](2026-10-19/final-all-4.7.2-linux/Smoke/smoke.log) 43、[ResourceLifecycle](2026-10-19/final-all-4.7.2-linux/ResourceLifecycle/resourcelifecycle.log) 127 項；各 suite 斷言數與上節 4.6 結果一致，合計同為 498 項零失敗。

冷匯入沒有出現指定的 SoundManager UID 錯誤，因此沒有 import-verified 階段；CombatVictory 的 combat_won STATE 診斷行多出 `"enemy_health":0`，不是斷言。比對摘要見來源鎖 `engine_policy.migration_from_4_6`。路徑遮罩規則同上，Linux 的專案與家目錄前綴同樣替換為代號。此次未實測 Windows 端 runner。

## 發布前的來源鎖說明

最終 All 後只更新 `tools/upstream.json` 的 layout 描述，以區分發布 snapshot 與本機可能保留的獨立 upstream checkout。因此目前來源鎖檔案 SHA-256 與該次 manifest 的 `source_lock_sha256` 不同；原始與可攜 manifest 均保留當時的值。遊戲及測試內容雜湊不變，資源生命週期補丁 SHA-256 仍為 `ed27f763e8492d193c03324954d1533c2e9f03aa33a2a7bc115f6a7189610c8c`。這是發布描述更新，不補寫成另一次 runtime 驗證。
