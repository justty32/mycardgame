# 可選棋盤模組：最終驗證

[證據入口](../../README.md)｜[架構與責任](../../../design/board-module.md)｜[驗收映射](../../../design/board-module-verification.json)｜[轉換清單](manifest.json)

2026-10-20 Windows、Godot `4.7.2.stable.mono.official.ed1daf0bf`，僅隔離 headless。[最終 All](final-all-results.json) 對應 `20261020-113027-4ebd60e5`：30 個程序階段全部 exit 0，1809 checks、0 failures；沒有未預期 ERROR、資源保留或原生崩潰訊號。

總數包含一般套件 1373、Boardless 四階段 276、SaveLoad 三階段 160。DualBoard 為 394、Field 為 355；Boardless 同時驗規則關閉與場景開關關閉，並走普通卡、敵意圖、波次、勝敗、獎勵及跨程序 Continue。逐項標籤與測試檔依驗收映射定位，主日誌保存在 `final-all/`。

[來源重建摘要](reconstruction-summary.json) 記錄純上游依序套用 11 個補丁，949 檔全部相符、工作來源漂移為零、實際 index 未變。新增 `optional-board-module.patch` 的 SHA-256 為 `5c02889c919ee0729bb380ee62d40f5cb620303f5a697e46dce799821376d5c3`。完整 949 檔 ledger 留在原始 artifacts；摘要保留其 canonical hash、數量與全符結果。runtime 與重建來源也已核對。

[Runner 合成結果](runner-diagnostics-results.json) 完成 143 項；其中故意注入的錯誤、timeout 與崩潰樣本不是 Godot 事故。[副本工具](prepare-tests.log) 6 項、[情境 runner](scenario-tests.log) 8 項 Python 測試通過。它們沒有啟動 Godot。

收尾曾發現舊 Board fixture 仍直取已搬移的 `Combat/BoardView`；改用相容 getter 並保留有效性與可見性斷言後，最終 All 通過。另一次 All 在 import 啟動前寫 results 時遇 Windows WinError 5；原因未定，原件保留，不能當作產品故障或成功驗證。此處只發布完整最終 run。

`manifest.json` 有 22 列：`raw_artifact` 指原件，`published_path` 指副本，兩個 SHA-256／bytes 欄分別記錄轉換前後內容，`transformation` 記錄遮罩或摘要。專案與家目錄前綴已遮罩，原件未更改；重複 import 日誌留本機，退出碼與命令仍在 results。GUI、音訊、鍵鼠操作感、GPU 及發行匯出未驗。
