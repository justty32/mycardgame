# 冷接手與候選 mod 的可攜證據

[演練紀錄](../README.md)｜[首 mod 核實](../../design/mod-bootstrap.md)

這裡只保存必要證據副本；沒有加入候選遊戲、引擎、快取、個人資料或全部工具輸出。路徑中的專案根／家目錄改為 `{PROJECT_ROOT}`／`{USER_PROFILE}`，統一 UTF-8 LF。原始及副本雜湊、轉換說明在 [manifest.json](manifest.json)（8 列）；source_file 是未追蹤 raw 的來源標識，不要求 fresh clone 存在該路徑。

## 獨立文件復走

[世界與整局報告](world-review.md) 記錄 3 個靜態情境。A/B 首次因關卡 owner 尚未 freeze、非戰鬥分析缺檔而中斷；文件完成後由相同獨立 reviewer 重走原入口，兩案 recheck pass。C 的整局路由 pass。每案有修改檔、候選 ID、接線順序、真實命令、需新增測試與未決條件。這是導航可執行證據，沒有 runtime 結果。

[內容與呈現報告](content-review.md) 記錄 6 案：首 mod、卡牌實作、評量、新機制、卡片圖音接線、選單／繁中／尺寸。新機制案首次因 Card 預覽拒絕／描述映射契約不足而 blocked；修補後由未參與寫入的原 reviewer 重讀 source，追加 recheck pass，保留初次失敗。六案最終均可列出開工計畫。連同世界三案，共 9/9 靜態路由 pass；不是 9 項已完成遊戲功能。

本輪保留三次中斷：關卡文件尚未 freeze、新機制預覽橋接不足，以及下述 runtime certificate store 錯誤。各自原因、修補或重試與結果均分開記錄，不把它們統稱為框架缺陷，也不回填為首次成功。

## 候選 mod 的背景執行

2026-10-19 專責 agent 依凍結的 bootstrap 與新手指南，在獨立候選建立重擊 mod 和 Smoke helper，再由現有 runner 建隔離執行副本。它在文件 ready 前曾提供 runner 根路徑／APPDATA 的靜態回饋，也由協調者指定 recipe，因此這是文件引導的實作驗證，不能算完全盲目的首次接手。

首次 run `20261019-143847-d79d0ff8` 的 [結果](first-results.json) 與 [import log](first-import.log) 顯示引擎 exit 0，但出現 root certificate store ERROR，runner 正確拒絕、completed=false。Smoke 和八項新斷言尚未執行；這不是已證實的 mod 缺陷。依工具核准流程，以相同候選及未修改的 runner 重跑，沒有放寬錯誤白名單。

重試 run `20261019-144001-1a30d2da` 的 [最終結果](final-results.json) 為 completed=true／PASS；version、import、import-verified、smoke 四階段 exit 0 且 passed=true。[Smoke 日誌](final-smoke.log) 有八項 `PASS: MOD:` 及 `SMOKE PASS: 52 checks, 0 failures`。冷快取 SoundManager UID 經 runner 規則重新匯入後通過；Smoke 仍有 20 條舊 icon UID fallback 與 2 條 image/export warning，沒有 ERROR／SCRIPT ERROR／FAIL、ObjectDB leak 或退出 resource 保留。

[結構判定](recipe-manifest.json) 記錄原 game/tools/tests 的 868 個非 cache／個資檔案前後 SHA-256 相同，候選內容與執行副本逐位元一致。候選及文件快照的 [輸入雜湊](candidate-inputs.json) 共 14 筆，`file` 是候選內識別字、`sha256` 是當次內容雜湊。這些識別字不指向正式遊戲中的實作；重擊和 helper 只存在於未追蹤候選。

本次只驗註冊、資料欄位與起手引用。未驗出牌效果、費用扣除、傷害、目標合法性、預覽、升級、卡包取得、平衡、存讀、整局、GUI、音訊播放或匯出。52 項是本次 Smoke；先前 498 項屬歷史基準，未在本次重跑。
