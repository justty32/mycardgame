# 裝配、失敗與退出

[架構入口](README.md)｜[資料與介面](contracts.md)｜[遷移計畫](../../plans/multi-board/README.md)

## 單一開始邊界

概念流程是 `停止上一場 → 純準備／驗證 → 裝配 → setup → 單位 admission → waves／CTB`。Combat 是場景組裝 owner；Director 保留戰鬥執行 owner。準備不得發布棋盤訊號、改 registry、扣費或寫占格；遇錯保留作者可理解的代碼與欄位路徑，返回可再次開始的已停止狀態。

對合法 0 盤，裝配結果沒有 BoardCombatModule；Controller、ThreatPreview、FieldController、BoardView、actor helper 與盤面輸入都不存在。普通人物容器與通用 adapter 照常工作。不得用空 Battlefield、隱藏視圖或 SINGLE 代替 0。

正盤 setup 建立本場資源，完成盤驗證與必要初始部署後，才讓 Director 啟動單位／波次／時間軸。現有 `BoardController.setup` 在部署主角前已呼叫 `FieldController.create_field`，後者發出 `field_created`，之後部署仍可能失敗；clear 無法撤回已發的事件。須把可失敗驗證前置，暫存資源成功後才公開，提交前不得發遊戲效果訊號。對無法純驗的失敗，定義本次資源的補償範圍，不能承諾任意效果都能回滾。

現有 Combat 在 setup 前已重設 energy／開啟 HUD，Director setup 失敗只呼叫 `_stop()`。新開始結果必須回到場景 owner，由它恢復 HUD／輸入／adapter 及本次啟動改動；清理新建單位、時間軸與 pending spawns，但不掃上一場以外的全域狀態。失敗不發勝敗或 `combat_ended` 假裝正常結束，準備成功前也不標記地圖節點完成。這些都是實作前需核對的交易邊界。

## 所有權與取消

Combat 擁有掛載 Node；模組擁有每場 runtime 與呈現；Director 僅引用當前有效模組。保留 instance identity、模組 generation 與 Director generation：同 Node clear/setup 也使舊請求失效，舊 Node 延遲 `_exit_tree` 不得 detach 新模組。準備結果與 runtime 的 generation 不相混；不可只靠相同 board_id 判斷請求仍有效。

完整 clear 先關閉輸入與預覽回呼、使 generation 失效，再解除訊號／adapter、還原角色呈現，釋放本模組占格與場域，最後解除引用。只清自己擁有的單位位置，不掃其他場景 registry。clear 須可重入、可重複呼叫，也可在 setup 中途失敗時執行。

玩家死亡的暫停與完整退出分開：沿用 preserve presentation，停止玩法但保留已提交的死亡畫面，直到戰鬥結束／新場／離樹才完整回收。下一場 0 盤不能繼承上一場 anchor、縮放、父子呈現控制或盤面滑鼠區域。這是既有模組責任的延伸，不另造死亡／費用流程。

排隊中的盤面牌在卸載或換場後，由既有 adapter lifetime 檢查拒絕；入隊費用前拒絕不扣費，出隊拒絕只走 HandManager 一次退款。普通牌繼續使用通用策略。模組不得額外清空整個 action queue 或自行退款以「保證乾淨」。

## 失敗不能混成 0

合法空集合、能力不可用、錯誤盤資料、部署找不到目的盤及生成暫時滿格分別回報。舊格式缺檔／關旗標沿既有 BoardRemoved／Boardless 契約；新格式明確正盤但缺能力則拒絕開場。能力可用但資料錯誤時同樣中止。有效盤上的生成滿格依既有 WAIT_UNTIL_FREE／NEAREST_EMPTY／FAIL_SKIP 處理，不能把單位無格出生當作 fallback。

setup 失敗後核對沒有發布新場行動、沒有孤立視圖／訊號、沒有占格或 mutable alias；再用有效遭遇重開。這些是待補驗收，不宣稱現有 `_stop()` 已完整滿足全部原子性。

## 最小驗收情境

同一場景用 0→既有 DUAL→0→另一正盤配置，核對實例有無、盤 ID／占格、普通卡／意圖／波次與結束；正盤內用任意命名與不同順序驗資料身分不依顯示順序。新正盤配置必須顯式供給部署資料或測試政策，不能把測試 fixture 的敵我分盤升為產品預設。

另驗無效 ID／未知目的盤／部署失敗後重開、setup 中途 clear、排隊後卸載／重掛、同 Node 再 setup、舊 Node 延遲退出。觀察只退一次與普通牌可繼續；退出日誌不能新增 ObjectDB／resource 保留。純 layout 驗重排／viewport 改變不改遊戲位置；人工畫面、命中與可讀性另驗，headless 不替代。
