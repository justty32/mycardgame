# Windows 接手驗證（2026-10-20）

[分析入口](../README.md)｜[背景驗證](../../../wf/workflows/testing.md)｜[Windows 環境](../../../wf/workflows/dev-env/windows.md)

正式結果與來源雜湊見 [本輪可攜證據](../evidence/2026-10-20/README.md)。原始 artifacts 保留，發布副本統一路徑遮罩與 LF；首輪 All、內容包失敗及 loader 紅測只作本機比較基準。

本輪確認昨晚戰鬥框架 Phase 0–3 與跨平台工具在公司 Windows 的背景執行能力，不擴充玩法。基準為外層 snapshot `5623b56` 與來源鎖列出的上游及本地補丁；首輪 All 使用原有遊戲程式，內容包驗證另發現資料載入缺陷。

## 環境與執行邊界

Windows 11、PowerShell 7.6.5、Python 3.13.0。使用者提供官方 `Godot_v4.7.2-stable_mono_win64.zip`，SHA-512 與來源鎖完全一致；保留原 ZIP，解壓至新的 `.tools/godot-4.7-mono/`。以明確 console 路徑經 PowerShell 包裝呼叫 Python runner，版本為 `4.7.2.stable.mono.official.ed1daf0bf`。

所有引擎階段皆帶 `--headless`，來源複製到本次 artifacts，APPDATA／LOCALAPPDATA／TEMP／TMP 與 user:// 隔離。未操作桌面、鍵盤、滑鼠、視窗、既有程序或原有存檔；沒有啟動舊 `game.ps1 -Mode Run`。來源 game、既有上游 checkout 與 playtest 均保留。

## 隔離 All 結果

**修後正式驗證為 768 checks、0 failures，21 個程序階段全部 exit 0。** Smoke 由 88 增至 110，新增 22 項資料檔載入回歸；其他 suite 斷言數與下列基準一致。完整 All 在修改 FileLoader 與加入新測試後重跑，並記錄各 suite 的來源及測試 hashes。

修正資料載入前，PowerShell 包裝執行 All 回傳 0，21 個程序階段全部通過，合計 **746 checks、0 failures**：ResourceLifecycle 127、Dictionary 47、Smoke 88、CombatVictory 90、CombatDefeat 48、Ctb 53、Board 88、Wave 48；SaveLoad write／read／rejected 分別 28／56／73。數量與昨晚 Phase 3 記錄一致，涵蓋時間軸、棋盤／移動／範圍卡、波次、勝敗及跨程序續玩。此首輪來源與之後修補分開記錄，不把舊來源結果冒充修後驗證。

仍有舊 icon UID 回退文字路徑及外部 image 載入警告；SaveLoad rejected 保留十個預期拒絕訊息。沒有新 SCRIPT ERROR、FAIL、ObjectDB leak 或退出 resource 殘留。不可把預期拒絕中的 ERROR 當作全套失敗，也不宣稱日誌零警告。

`tools/upstream.json` 的 Windows verified_builds 在 All 完成後追加，因此目前來源鎖 hash 與 All manifest 不同；該次 manifest 原值保留，遊戲、測試與補丁 hashes 未隨這項紀錄變動。

PowerShell 的 `-Pack`／`-PackTests` 實際載入通過 **117 checks**；加 `-ContentProfile pack`、不生成框架範例資料時通過 **88 checks**。兩者皆有 probe 完成標記，且所有 ERROR／SCRIPT ERROR／資源殘留判定通過。題材原始日誌留本機 artifacts，不將題材內容複製進框架證據。

`-ForceFailure` 為 111 checks、1 個刻意失敗，PowerShell 正確回傳 1；日誌唯一 FAIL 是要求的失敗出口控制。它驗 wrapper 傳遞失敗，不代替上述 loader 紅測。

## 工具修復

內容包首輪 Smoke 的 95 個 assertions 都通過，但 Windows 把資料夾中的 `.gitkeep` 列入檔案，原 loader 嘗試解析並產生 ERROR，runner 因而回傳 1。修復在 `load_read_only_data()` 限定副檔名為 JSON（大小寫不敏感）；不修改通用列檔、目錄遞迴、合法 JSON 排序與解析錯誤。

新增 `file_loader_probe.gd`，在兩種 profile 共用走真實 mod pipeline。舊來源配新 Smoke 的紅測為 **110 checks、2 failures**，具體失敗為非 JSON 備份誤註冊與多餘物件，另有佔位檔及文字檔解析 ERROR；修後同測為 **110 checks、0 failures**。紅測使用首輪保留副本而非回退正式 game；修補另存 `json-data-files.patch`，可在 Phase 3 樹套用。

`link_pack.set_enabled()` 原本用文字讀取，會把 CRLF 正規化成 LF，因此 enable／unlink 無法逐位元組還原。現在保留原始位元組與 BOM，依插入位置的換行格式寫入；LF／CRLF／混合換行各含有／無 BOM 皆回歸通過。原版 CRLF 紅測另留紀錄。

繁中 `cmd` 與 `tasklist` 的 OEM 輸出曾造成 UTF-8 解碼失敗，遮蔽真正的環境錯誤；改採 OEM 解碼及錯誤出口。正式 runner 的唯讀 Git、合成測試的孫程序及 tasklist 也補齊無窗旗標。Python 3.10／3.11 缺 `os.path.isjunction` 時以 `lstat().st_reparse_tag` 辨識 junction，避免隔離副本跟入連結內容；此退路在 Python 3.13 模擬缺 API，並用真實 junction 驗證。

runner diagnostics 通過 141 checks，涵蓋失敗與崩潰標記、APPDATA 隔離、逾時清理本次建立的程序樹、Windows 引擎路徑選擇與 link 啟停；link-pack 專項 6 tests 全過且無 skip，涵蓋空白路徑、junction fallback、unlink 保留 target 與拒絕真目錄。另有 new-pack 14 checks、boundary-lint 19 checks 通過。初次沙箱拒絕建立 junction，經環境核准重驗成功；兩次結果均保留，不能把權限錯誤當作玩法缺陷。

## 驗收範圍

Headless 不證明 GPU、UI 觀感、實際點擊、聲音或原生 GUI 穩定性；未執行完整多幕通關、所有卡牌／敵人、發行匯出或 C# 專案編譯。內容包載入不代表已有完整遊戲內容。原生記憶體崩潰調查仍擱置。

逾時合成測試只證明本次仍存活的 wrapper 程序樹可清理；wrapper 提早退出而孫程序留住輸出 handle 的情況，目前 runner 會判失敗，尚未證明能回收該孫程序。沒有藉此操作既有程序。
