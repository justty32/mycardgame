# 裝配、失敗與退出

[架構入口](../../../analysis/slay-the-robot/architecture/10_multi_board_encounters.md)｜[資料與介面](encounter-contracts.md)｜[整合實證](../../../analysis/slay-the-robot/architecture/10_multi_board_encounters.md)

## 單一開始邊界

現行流程是 `停止上一場 → 純準備／驗證 → 裝配 → 暫存 setup／部署可放性 → 成功通知 → 提交場域與部署 → waves／CTB`。Combat 是場景組裝 owner；Director 保留戰鬥執行 owner。準備不得發布棋盤訊號、改 registry、扣費或寫占格；遇錯保留作者可理解的代碼與欄位路徑，返回可再次開始的已停止狀態。

對合法 0 盤，裝配結果沒有 BoardCombatModule；Controller、ThreatPreview、FieldController、BoardView、actor helper 與盤面輸入都不存在。普通人物容器與通用 adapter 照常工作。不得用空 Battlefield、隱藏視圖或 SINGLE 代替 0。

正盤 setup 建立未公開資源，預驗主角 footprint 的合法落點及初始場域。成功提交時才依原順序 create 正式場域，保留 STACK、REPLACE、零時長在 callback 當時可觀察的狀態。失敗只清 trial resources，不發 `field_created`／`field_removed`。已發布事件不能撤回，因此不承諾任意 listener 副作用回滾。

`combat_started` 是成功通知：前置驗證通過才重設 energy／開啟 HUD，發通知讓原 HandManager、Stats、Player、RewardOverlay 各自初始化一次。部署驗證失敗不清牌、改 stats／status 或排獎勵；場景關 HUD／輸入、解除模組並回到可重試狀態，不發假勝敗。只有戰鬥節點 visited 延至開始成功；旅行位置、事件抽取與進站存檔不屬本次回滾，非戰鬥節點語意不變。

Director 在 stage 成功時保存模組 instance 與 generation，必須在成功通知之前取得 token；通知後再次核對，不能將 listener 清理後的新 generation 當舊請求有效。每個可重入初始場域 emit 之後也核對 identity／generation，取消立即停止後續場域、waves 與 CTB。這是既有生命週期防護，沒有另建通用交易框架。

## 所有權與取消

Combat 擁有掛載 Node；模組擁有每場 runtime 與呈現；Director 僅引用當前有效模組。保留 instance identity、模組 generation 與 Director generation：同 Node clear/setup 也使舊請求失效，舊 Node 延遲 `_exit_tree` 不得 detach 新模組。準備結果與 runtime 的 generation 不相混；不可只靠相同 board_id 判斷請求仍有效。

完整 clear 先關閉輸入與預覽回呼、使 generation 失效，再解除訊號／adapter、還原角色呈現，釋放本模組占格與場域，最後解除引用。只清自己擁有的單位位置，不掃其他場景 registry。clear 須可重入、可重複呼叫，也可在 setup 中途失敗時執行。

玩家死亡的暫停與完整退出分開：沿用 preserve presentation，停止玩法但保留已提交的死亡畫面，直到戰鬥結束／新場／離樹才完整回收。下一場 0 盤不能繼承上一場 anchor、縮放、父子呈現控制或盤面滑鼠區域。這是既有模組責任的延伸，不另造死亡／費用流程。

排隊中的盤面牌在卸載或換場後，由既有 adapter lifetime 檢查拒絕；入隊費用前拒絕不扣費，出隊拒絕只走 HandManager 一次退款。普通牌繼續使用通用策略。模組不得額外清空整個 action queue 或自行退款以「保證乾淨」。

## 失敗不能混成 0

合法空集合、能力不可用、錯誤盤資料、部署找不到目的盤及生成暫時滿格分別回報。舊格式缺檔／關旗標沿既有 BoardRemoved／Boardless 契約；新格式明確正盤但缺能力則拒絕開場。能力可用但資料錯誤時同樣中止。有效盤上的生成滿格依既有 WAIT_UNTIL_FREE／NEAREST_EMPTY／FAIL_SKIP 處理，不能把單位無格出生當作 fallback。

setup 失敗後核對沒有發布新場行動、沒有孤立視圖／訊號、沒有占格或 mutable alias；再用有效遭遇重開。對應實場與取消測例見 [整合分析](../../../analysis/slay-the-robot/architecture/10_multi_board_encounters.md)，不將此邊界擴大解讀為任意全域副作用可回滾。

## 最小驗收情境

同一場景用 0→既有 DUAL→0→另一正盤配置，核對實例有無、盤 ID／占格、普通卡／意圖／波次與結束；正盤內用任意命名與不同順序驗資料身分不依顯示順序。新正盤配置必須顯式供給部署資料或測試政策，不能把測試 fixture 的敵我分盤升為產品預設。

另驗無效 ID／未知目的盤／部署失敗後重開、setup 中途 clear、排隊後卸載／重掛、同 Node 再 setup、舊 Node 延遲退出。觀察只退一次與普通牌可繼續；退出日誌不能新增 ObjectDB／resource 保留。純 layout 驗重排／viewport 改變不改遊戲位置；人工畫面、命中與可讀性另驗，headless 不替代。
