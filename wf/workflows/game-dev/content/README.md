# 內容開發子工作流

[內容入口](../content.md)｜[遊戲開發](../README.md)

內容入口處理既有資料調整、ID 接線、補丁及相容性。本目錄補充需要完整操作鏈的具體任務，避免把所有細節堆入共同入口。

先建立第一個 mod，或演練教學內容時，使用 [從檔案到隔離載入驗收](bootstrap.md)。它串起候選副本、JSON 登記、Smoke helper 及執行命令，並說明載入通過仍不能證明出牌效果或存讀。

題材樹的內容包（`games/<game>/pack/`）以 runner `--pack` 隔離載入並跑題材 probe，見 [題材內容包](pack.md)。

需要交付可手動遊玩的隔離副本，使用 [可玩副本](playable-copy.md)；中性實例見 [棋盤示範包](../../../../examples/board-lab/README.md)。包的完整新局／戰鬥／存讀流程由 PackScenario 驗證，不以載入 probe 代替。

卡牌定位與平衡回 [卡牌設計](../card-design.md)／[評量](../card-evaluation.md)；新行為原語回 [機制](../mechanics.md)。完成後依內容入口交付真實取得入口與適用的專項驗收，不用教學成功代替產品需求。
