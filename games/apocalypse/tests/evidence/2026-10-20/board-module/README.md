# 棋盤模組改版：既有內容包雙 profile 回歸

[題材聲明](../../../../NOTICE.md)｜[既有 probe](../../../apocalypse_probe.gd)｜[原件與副本對照](manifest.json)

本目錄記錄 2026-10-20 框架棋盤模組拆分後，既有內容包的載入回歸；沒有新增或修改題材玩法、內容資料或 probe。兩次測試由整合 owner 在獨立副本以 headless 執行，發布副本只保留 results 與 Smoke 主日誌。

## 實際結果

[Overlay results](overlay-results.json) 與 [Smoke 日誌](overlay-smoke.log) 對應 `20261020-115010-d3ab82db`：content_profile=`test`，130 checks、0 failures，3 階段均 exit 0，verdict PASS。

[Pack-only results](pack-results.json) 與 [Smoke 日誌](pack-smoke.log) 對應 `20261020-115148-e417eb83`：content_profile=`pack`，88 checks、0 failures，3 階段均 exit 0，verdict PASS。兩份日誌均包含既有題材 probe 的 `PASS: APO:` 斷言。

來源 checkout、內容包／probe 雜湊、引擎版本及命令保留在各自 results；兩份結果描述各自取樣的來源，不將它們合併成同一次 All 執行。

## 可攜轉換與範圍

原始 artifacts 原樣保留。發布副本轉為 UTF-8、LF，JSON 重新排版，專案與家目錄前綴分別遮罩為 `{PROJECT_ROOT}`、`{USER_PROFILE}`。manifest 用原件／副本各自 SHA-256 與位元組數記錄四個檔案；斷言、程序退出碼、診斷與警告不刪改。

此處證明兩個 profile 下既有 probe 的載入與資料契約仍通過；不是完整題材遊戲流程、平衡或新玩法驗收。未操作桌面、視窗、螢幕、鍵盤、滑鼠或 GUI；未驗人工觀感、聽感、GPU 或發行匯出。
