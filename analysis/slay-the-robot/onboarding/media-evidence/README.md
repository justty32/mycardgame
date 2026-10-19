# 呈現演練的可攜證據

[本輪說明](../media.md)｜[情境記錄](../media-scenarios.json)

保存本輪五位領域 agent 的初讀報告，供沒有本機 artifacts 的 checkout 查核。原件是 `artifacts/media-audit/*-initial.md`；副本採 `.md.txt`，保留報告中的路由原文，不將其中路徑誤當此目錄的導航。這些是修補前發現與後續明示更正，不能當作獨立復走或 runtime 通過證據。

來源與雜湊記在 [manifest.json](manifest.json)（5 列初讀、2 列獨立復走）。`id`／`kind` 識別報告；`original_location`／`original_sha256` 保存本機來源；`copy_path`／`copy_sha256` 指向發布副本並驗內容；`bytes` 記副本大小，`transform` 記轉換。本批副本逐 byte 相同，未遮罩、未改寫，因此原件與副本雜湊一致。

之後獨立 reviewer 完成才加入對應報告與 manifest 列，再將情境的 reviewer／status／evidence 更新為實際結果。未完成或首次斷鏈必須保留；不以修補者的局部檢查代填 pass。既有 onboarding/evidence 的 9 情境與 runtime 證據保持原狀。
