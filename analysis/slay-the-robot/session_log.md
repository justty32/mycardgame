- 2026-04-15: 遷移 Slay-the-Robot 簡要教學文檔。
- 2026-10-19: 將兩篇教學與原日誌複製至 mycardgame，新增本機導航並解除對 PAS 的依賴；教學內容未變，框架 API 尚待核對。
- 2026-10-19: 匯入固定 commit 4dac5abe 的框架與 Godot 4.6，完成主選單渲染、39 項 smoke 與 example_mod 驗證，更正兩篇教學並新增架構分析；重現 Dictionary merge 缺陷，保留上游未修改。
- 2026-10-19: 以紅綠回歸修復 Dictionary merge、無效存檔覆寫狀態與自訂存檔路徑；新增隔離 runner，驗證單場戰鬥勝敗與跨程序存讀續玩，同步教學與 wf。新增流程發現的退出資源清理問題另列於 architecture/04_regression_validation.md。
- 2026-10-20: 公司 Windows 以官方 Godot 4.7.2 Mono 背景驗證 Phase 0–3 與跨平台工具，修正 FileLoader 只載入直列 `.json` 資料檔，修後 All 768 checks／0 failures（ac37a9a，見 [06](architecture/06_windows_validation.md)）。
- 2026-10-20: 實作雙盤 A（獨立我方／敵方棋盤、版本化跨盤 policy、原子轉移）與場域／ZOC，新增 [07](architecture/07_fields_zoc.md) 與 [雙盤分析](design/dual-board/README.md)；headless All 1470 checks（9ced42f）。
- 2026-10-20: 棋盤改為掛載於既有戰鬥場景的可選模組，普通卡不依賴棋盤，新增中性示範包；headless All 1809 checks（2757e06，見 [可選棋盤模組](design/board-module.md)）。
- 2026-10-21: 依審查同步本目錄：更新 Godot 4.7、`Global._ready()` content profile 條件與行號、runner suite 清單、`reachable_cells()` 歸屬，精簡重複免責語；未跑 Godot。

## 資源生命週期後續（2026-10-19）

processor ownership、async cache／取消及 Root／選單清理的修復與紅綠證據記於 [05 報告](architecture/05_resource_lifecycle.md)。進階教學與工作流同步實際契約；04 保留當時仍有資源的歷史數據。原生 crash 調查擱置，資源修復不代表該事故已解決。
