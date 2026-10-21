# 雙棋盤 A 與 Phase 2b：最終驗證證據

[證據入口](../../README.md)｜[雙盤契約](../../../../../wf/specs/dual-board/README.md)｜[場域分析](../../../architecture/07_fields_zoc.md)｜[轉換清單](manifest.json)

2026-10-20，公司 Windows、官方 Godot `4.7.2.stable.mono.official.ed1daf0bf`，僅隔離 headless。正常新局使用雙棋盤與實際角色站格；舊局部規則測試明確採 SINGLE。

## 最終 All

[results](final-all-results.json) 對應 `20261020-095502-c16de721`：**1470 checks、零失敗，25 個程序階段均 exit 0**。Field 355、DualBoard 344；其餘為 ResourceLifecycle 127、Dictionary 47、Smoke 110、CombatVictory 90、CombatDefeat 48、Ctb 53、Board 88、Wave 48，以及 SaveLoad write／read／rejected 28／59／73。

各 suite 的 import 與引擎日誌保留於 `final-all/`；11 份相同的 import 日誌只留 `Board/import.log`，另有 5 份主日誌與棋盤模組 run 相同而只留該處。manifest 的 `published_path` 指向保留副本，原位置記在 `removed_copy`，另見 [去重索引](../../dedup-index.json)；需求與具體測試對照見 [驗證映射](../../../../../wf/specs/dual-board/verification.json)。SaveLoad rejected 保留十個刻意損毀／缺失存檔的 ERROR 診斷，runner 明確識別預期拒絕；沒有未預期錯誤、ObjectDB leak 或退出資源殘留。此結論限當次 freeze，不表示任何未來改動自動通過。

[雙盤日誌](final-all/DualBoard/dualboard.log) 包含正常新局、跨盤與交換、費用前拒絕、NEAREST／FARTHEST、第二 run 及真實 sprite 腳底檢查。動畫庫的唯讀 track 診斷證實 run_start 使用 offset -150→0；首次 ready 保存 position＋offset 後，第二 run 的腳底與首次一致。headless 的虛擬 viewport 依正式設定為 1200×700，保留畫面範圍與祖先裁切斷言，未操作實體視窗。

## 來源、工具與發布副本

[重建報告](reconstruction-report.json) 驗證純上游 `4dac5abe` 按來源鎖套用十個補丁後，940 個遊戲檔 raw-byte hash 與本輪 freeze 相同，mismatch／drift 均為零。第九補丁補齊已發布的 4.7 專案特性基準；第十補丁涵蓋雙盤與 Phase 2b，SHA-256 為 `b1ea6fbb71cce8982cd49b5e40f43d22a26d6ca6ad3aba9e0130dab3d1c2ccb1`。snapshot 已含結果，不應再套補丁。

All 的來源鎖 hash 為 `53a2c63e6016b2f9de37e92f88873d67a0b0a8310bf17d790100cf0a3b625f12`；results 保存實際來源與測試 hashes，重建報告另保存全部 940 檔。後續只有分析／工作流整理，沒有改遊戲或測試。

[runner 合成結果](runner-diagnostics-results.json) 為 143 項通過；它檢查 runner 自身的錯誤、期限、隔離與清理分支，沒有將故意注入的事故當成實際引擎崩潰。此工具版本後續未改，沿用同輪結果。

既有內容包另以預設 profile 與 pack-only profile 跑 Smoke，分別 117／88 checks、零失敗，run 為 `20261020-100126-8e797849`／`20261020-100223-8fdc7a97`。原始結果留在本機 artifacts，不把題材 probe 原文放入框架樹。

28 份原始證據以 UTF-8、LF 保存發布副本，JSON 重新排版，專案及家目錄前綴遮罩為 `{PROJECT_ROOT}`／`{USER_PROFILE}`。manifest 分別記錄原件及副本大小、SHA-256 與轉換；原始 artifacts 原樣保留。題材包原文不放入框架證據。

## 未驗範圍

未操作桌面、螢幕、鍵盤、滑鼠或 GUI；未驗人工觀感、實際命中、GPU、聽感、完整多幕通關或發行匯出，也不宣稱先前原生崩潰已修復。Phase 4 AI、原創素材與豐富中性示範內容另列後續工作。
