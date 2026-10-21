# Board Lab：可玩流程證據

[遊玩入口](../README.md)｜[九項驗收映射](../verification.json)｜[轉換清單](manifest.json)

2026-10-20 以 Godot `4.7.2.stable.mono.official.ed1daf0bf` 完成兩次獨立 PackScenario。每次都有 version、import、write、read、defeat 五個程序階段，全部 exit 0，257 checks／0 failures，無未預期 ERROR、資源保留或原生崩潰訊號。

[來源安裝結果](standalone-results.json) 對應 `20261020-114335-3af4365d`；[交付副本結果](prepared-results.json) 對應 `20261020-114738-1a266209`。兩者各為 write 94、read 95、defeat 68。write 經新局、真起始牌、第一場示範、自然勝利清理、獎勵及第二場 checkpoint；read 在新程序 Continue、領獎、進 Boss 並正常勝利終局；defeat 經真敵人攻擊敗北及重開。

場域清理斷言直接檢查第一場建立的 FieldController 與 Board 引用：正常勝利後 controller inactive、fields 為空、Director 不再持有 battlefield。測試沒有手動清場。跨盤移動、交換、場域、借機攻擊與普通牌的費用／目標都由真 Hand 入口執行；具體 PASS 標籤見映射與 `standalone/` 日誌；兩次 run 的三份情境日誌逐位元組相同，`prepared/` 副本已去重，原位置與保留副本見 [去重索引](dedup-index.json)。

[準備摘要](prepare-summary.json) 指向可玩副本 `1aa7d00bb8534aff9ef57ec9068aca85`，位於 ignored `artifacts/playable/`，不加入版本庫。準備工具沒有啟動引擎；runner 先核其完整 manifest、984 個輸出檔及 39 個包檔，再在隔離快照中執行情境。兩次結果的來源鎖、程式、內容包及測試 hash 完全相同；可玩副本的 944 個框架來源檔與重建來源相符。從 repo 重建自己的副本依遊玩入口操作。

結果矩陣刻意放在 tests 目錄外，填入 PASS 不會改變被驗輸入 hash。曾有清理斷言文字替換未命中；核對實檔後補上並重新完成這兩次驗證，較早 256 checks 不作最終證據。

`manifest.json` 有 9 列：原件位置、發布位置、原件／副本 SHA-256 與 bytes、轉換方式；去重列的發布位置指向保留副本，`removed_copy` 記原發布位置。完整原件保留；主機路徑遮罩、JSON 轉為 UTF-8 LF，準備 metadata 的完整框架 ledger 以數量和 canonical hash 摘要，其餘行為證據保留。這不是平衡或人工遊玩測試；畫面、音效、鍵鼠操作感與發行匯出未驗。
