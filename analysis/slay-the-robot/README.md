# Slay-The-Robot 分析與教學

[專案地圖](../../wf/INDEX.md)｜[專案背景](../../wf/PROJECT.md)

本目錄是 mycardgame 自行維護的 Slay-The-Robot 知識入口。2026-10-19 已將既有分析完整複製至此，後續閱讀、修訂與新增分析都在本專案進行，不需要 PAS 工作區。

## 閱讀入口

<!-- wf-nav -->
- [新手指南](tutorial/beginner_guide_zh.md)：資料驅動概念、卡牌、敵人、角色、mods 與起始牌組。
- [進階指南](tutorial/senior_guide.md)：自訂 Action、Interceptor、Signals、patch_data、ActionHandler 與除錯。
- [架構總覽](architecture/01_overview.md)：啟動、資料載入、UI、戰鬥與存檔的真實流程。
- [擴充方式](architecture/02_extension_points.md)：資料、action、攔截器與 mod 的邊界。
- [啟動驗證](architecture/03_startup_validation.md)：Godot 實跑、畫面渲染、mod 測試與已知缺陷。
- [回歸與流程驗證](architecture/04_regression_validation.md)：Dictionary／存讀修復、單場戰鬥勝敗、跨程序續玩與資源清理限制。
- [資源生命週期](architecture/05_resource_lifecycle.md)：退出資源問題的後續修復與驗收狀態，和原生崩潰調查分開記錄。
- [設計與呈現能力](design/README.md)：卡牌、敵人、關卡、圖像／UI 與音訊的實際接線及已知缺口。
- [教學更正紀錄](tutorial/verification.md)：舊範例與目前原始碼的差異。
- [操作日誌](session_log.md)：保留原始遷移紀錄，後續追加本專案進度。

## 來源與狀態

原始來源為 `pas/analysis/slay-the-robot/`，這是來源紀錄，不是外部路徑依賴。最初完整複製三份 Markdown 並以 SHA-256 核對一致；之後依使用者要求核實框架，已在本專案更正兩篇教學並新增架構與執行證據。PAS 原件未修改。

目前核實基準為 Slay-The-Robot commit `4dac5abe0d19382f8ace2cec5ed3fd77e2a0e11d` 加 [來源鎖](../../tools/upstream.json) 所列本地修復、Godot 4.6。靜態核實與 runtime 已驗事項分開記錄；已驗單場戰鬥勝敗、獎勵及跨程序存讀續玩，不代表所有教學自訂玩法或完整多幕通關已測試。原版問題、Dictionary／存讀及後續資源清理結果各自保留在對應驗證報告。

## 後續維護

框架來源與查核背景已收在專案背景頁。更新分析時記下上游 commit、實際程式位置與驗證結果。所有分析導航使用本專案內的相對連結。
