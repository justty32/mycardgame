# shop-cues — 瀏覽、購買、拒絕與退出商店

[聲音入口](../audio.md)｜[商店 UI](../ui/screens/shop-rest.md)｜[商店動態](../art-assets/motion/dialogue-shop.md)｜[完整場景交付](../scene-pack.md)

**何時用**：要交付含商品瀏覽、價格、交易、售罄與離場的完整商店聲包。
**何時不用**：只調商品價格或取得規則 → 內容／關卡流程；休息與獎勵聲包 → [screen-cues](screen-cues.md)；只換一個按鈕音 → [sfx](sfx.md)。

商店的程式行為（populate_shop 清空重建、買不起只染紅價格、purchased signal 早於扣款、售罄＝商品消失、Overlay 何時隱藏）以 [商店的程式事實](../ui/screens/shop-rest.md#商店的程式事實) 為準，本檔不重述，只寫聲音在這些事實上的時點與 owner。

## Done when

- 商店聲包及交易語意紀錄存在，含進場、瀏覽、購買接受／完成、拒絕、商品移除與退出。
- fixture 記錄三類商品、失敗原因、快速連按、刷新與重訪的播放次數及狀態斷言；未執行的音訊測試不標為播放驗收完成。

## 流程

### 聲包與規格

把開店提示、商店曲／環境層、商品瀏覽、購買確認、拒絕（買不起／欄位滿）、商品移除與退出當成一包設計。成交與商品移除可以合併成一聲；不要為每次價格重繪配音。瀏覽音短且低優先，交易提示要清楚，環境層不能遮住價格與結果文字。規格記錄每次瀏覽的最短間隔、同商品重入時是否重播、確認音尾音、單次或循環，以及併發限制；格式與來源沿 [audio 入口](../audio.md#來源與製作共同契約)。

視覺替代保留商品圖、價格、金錢、消耗品空位、不可購原因，以及已移除商品的結果。現況失敗只把價格變紅，這不足以區分各種失敗原因，相關 UI 改動交 shop-rest。不得只用音高區分「買不起」與「背包滿」。

### 進場與瀏覽

[ShopOverlay](../../../../game/scripts/ui/ShopOverlay.gd) 收到 `shop_opened` 後顯示並 populate；`shop_visited_first_time` 是另一種狀態，不要讓兩者同時播同一個開店音。要明定同一家店重訪時是否重播歡迎語。循環 music 已由地點選擇處理；商店環境層由單一 scene owner 啟停。

因為商品控件每次 populate 都會重建，瀏覽音只能從當前可互動商品的實際 hover／鍵盤選取語意發出，不能在 init 或重繪時播放。現有 BaseShopButton 沒有通用的 hover 聲或鍵盤聲協定，要由卡牌／遺物／消耗品各控件接一個共同 adapter，舊控件離樹後 listener 隨之失效。若只支援現有輸入方式，就明列鍵盤導航未覆蓋，不杜撰事件。

### 交易接受、完成與拒絕

purchased 系列 signal（`card_purchased`／`artifact_purchased`／`consumable_purchased`）可以當成「交易已接受」，但不代表扣錢與取得的後續 action 已全部執行完。

- **完成確認**：需要時由交易 owner 關聯本次商品／request，等 actions_ended 並核對金錢、牌組或物品的實際結果後播一次。ShopOverlay 也在 actions_ended 後刷新，不要把刷新當成新成交。
- **接受時確認**：若選擇在接受時就播確認音，就不要在 money_changed、card_added_to_deck 或刷新時再播同一音。
- 同一 domain signal 可能在其他場景使用，聲音 owner 要核對當前商店狀態與交易識別。

拒絕方面，買不起、消耗品欄滿、無商店與攔截取消都沒有統一的 purchase_failed signal。應在實際判定的出口回報原因與 request ID，並交 UI 顯示；不能用價格染紅或「延遲一段時間沒收到 purchased」來猜失敗，更不能每次金錢更新都播拒絕音。快速連按要驗證同一商品只被接受一次；現有 action 沒有提供音訊交易 token 或通用的庫存防重契約，音訊冷卻修不掉重複購買。

售罄沒有 sold_out 音訊事件。若要「最後一件賣光」的提示，先定義它指單一商品移除還是整店某分類清空，交易完成後比對同一份庫存，再由同一 owner 發一次 cue。不要在空列表每次 populate 時播售罄，也不要讓商品移除音與成交確認音無意間疊在一起。

### 退出與中斷

Continue 之後 ShopOverlay 不一定立刻隱藏，所以聲音停止要看「有效可互動的場景狀態」，不能只等 visible=false。要明定打開地圖覆蓋時商店環境暫停還是延續；到訪新節點時必須停止。離場後仍在等待交易的 callback 必須檢查 generation，不能把舊商店的確認音播到戰鬥裡。

正常退出短音要與死亡、run_ended、離樹等中斷分開。環境音 stop、pending cue 取消、signal 斷線與池回收照 [music](music.md)／[mixing](mixing.md)；框架目前沒有把這套商店聲音生命週期自動接好。

### 測試接法

先遵守 [mixing](mixing.md) 的無聲門檻。新的 shop fixture 由既有 Smoke 在 Root ready 後呼叫，或沿固定旅行情境延伸已接入的 suite；目前沒有 Shop／Audio suite 可以直接跑。先建立固定的價格、金錢、三種商品與欄位，再走真實的 BaseShopButton → ActionShopPurchaseItems 路徑；recorder 觀察接受、完成及拒絕出口，同時斷言金錢、取得與庫存，不以 sound count 單獨證明交易成功。

要驗的案例：

- 足額購買三類商品各一筆；
- 少一元時零成功音；消耗品欄滿時零成交；
- 雙擊同一商品不得成功兩次；
- 購買後重繪零新聲；
- 離場時等待中的回呼不播；
- 重訪同一家店的行為符合 brief；
- 有售罄需求時，另驗最後一件與重新 populate。

失敗 signal 尚未實作時記為缺口，不虛構綠測；音效去重不能讓錯誤交易被測試忽略。

## 交接

UI、[商店動態](../art-assets/motion/dialogue-shop.md) 與音訊共用交易 request／結果語意，由單一 owner 把「接受」與「完成」分開。內容／庫存缺陷另交工程 owner；本流程不以泛用按鈕音取代完整商店驗收。
