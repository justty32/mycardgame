# 完整用途演練證據

[本輪說明](../media-purpose.md)｜[情境表](../media-purpose-scenarios.json)

本目錄保存追加完整場景需求後的四份作者缺口盤點（非獨立盲測），以及獨立用途復走報告。原件位於 artifacts/media-audit，完整副本使用 `.md.txt` 保留原文路徑而不誤解析為本目錄導航。D／E／F 首報判 2 hold、1 pass；A／B／C 首報判 3 pass；D／E followup 判修補後可開工 pass。復查另存，首報 bytes 與 hash 不變。

來源記在 [manifest.json](manifest.json)（8 列：4 份作者盤點、2 份獨立首報、1 份獨立 followup、1 份作者盤點早期快照）。`id`／`kind` 識別報告和證據性質；`original_location`／`original_sha256` 保存來源及捕獲時雜湊；`copy_path`／`copy_sha256` 指向副本及雜湊；`bytes` 為副本大小；`transform` 說明處理。未遮罩，當前原件與副本雜湊一致；早期快照核對捕獲時 hash，不與後來追加註記的原件混比。

`previous_capture_sha256` 只用於動畫作者盤點：早期副本後來補上「同一作者補查、非盲測」一句分類註記，最終副本採 freeze 版本，缺口內容未變。較早 bytes 另存 [prior 快照](animation-scenes-initial.prior.md.txt)，由單句差異還原後與原先捕獲 SHA-256 完全相符。它不是新情境或 review 結果，不涉及獨立首報或判定改寫。

新獨立報告完成才加入 manifest 並更新情境；若有初次阻礙或後續復查，兩者均保留。原技術域的證據目錄與舊 onboarding/evidence 不屬本輪，不以其 pass 代替用途驗收。
