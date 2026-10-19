# shop-cues — 瀏覽、購買、拒絕與退出商店

[聲音場景入口](README.md)｜[商店 UI](../ui/screens/shop-rest.md)｜[完整場景交付](../scene-pack.md)

**何時用**：要交付含商品瀏覽、價格、交易、售罄與離場的完整商店聲包。
**何時不用**：只調商品價格或取得規則走內容／關卡流程；休息與獎勵聲包走 [screen-cues](screen-cues.md)。

## Done when

商店聲包及交易語意紀錄存在，含進場、瀏覽、購買接受／完成、拒絕、商品移除與退出。fixture 記三類商品、失敗原因、快速連按、刷新與重訪的播放次數及狀態斷言；未執行音訊測試不標完成播放驗收。

## 流程

### 聲包與規格

將開店提示、商店曲／環境層、商品瀏覽、購買確認、買不起／欄位滿拒絕、商品移除與退出作為一包。聲包可合併成交與商品移除為一聲；不要為每次價格重繪都配音。瀏覽音短且低優先，交易提示要清楚，環境層不遮價格／結果文字；規格記每次瀏覽的最短間隔、是否同商品重入重播、確認尾音、單次／循環及併發限制，格式／來源沿 README。

視覺替代保留商品圖、價格、金錢、消耗品空位、不可購原因及已移除商品的結果；只把價格變紅不足以代表所有失敗原因，相關 UI 改動交 shop-rest。不得只用音高區分買不起與背包滿。

### 進場與瀏覽

[ShopOverlay](../../../../game/scripts/ui/ShopOverlay.gd) 收 `shop_opened` 顯示及 populate；`shop_visited_first_time` 是另一種狀態，不要同時讓兩者播同一開店音。明定同店重訪是否重播歡迎語；循環 music 已沿地點選擇處理，商店環境由單一 scene owner 啟停。

商品控件會在 populate_shop 清除並重建；瀏覽音只能從當前可互動商品的實際 hover／鍵盤選取語意發出，不能在 init 或重繪播放。現 BaseShopButton 沒有通用 hover 聲或鍵盤聲協定，要由各卡／遺物／消耗品控件接共同 adapter，舊控件離樹後 listener 失效。若只支援現有輸入，明列未覆蓋鍵盤導航，不杜撰事件。

### 交易接受、完成與拒絕

[BaseShopButton._on_button_up](../../../../game/scripts/ui/shop/BaseShopButton.gd) 只把 action_on_click 排隊，尚未表示買到。[ActionShopPurchaseItems](../../../../game/scripts/actions/shop_actions/ActionShopPurchaseItems.gd) 重新查當前商店、價格與金錢，消耗品另查欄位；成功後排入扣錢與取得 actions、移除商品，再 emit `card_purchased/artifact_purchased/consumable_purchased`。因此這些 signal 可當「交易已接受」，不是後續效果已全部完成。

需要完成確認時，由交易 owner 關聯本次商品／request，等 actions_ended 並核對金錢／牌組或物品結果後播一次；ShopOverlay 本來也等待 actions_ended 後刷新，不把刷新當新成交。若採接受時播確認，就不要在 money_changed、card_added_to_deck 或刷新再播同音。相同 domain signal 可能在不同場景使用，聲音 owner 需驗本次商店狀態及交易識別。

買不起、消耗品欄滿、無商店與攔截取消沒有統一 purchase_failed signal；應在實際判定出口回報原因與 request ID，並交 UI 顯示。不能用按鈕紅色價格或延時「沒收到 purchased」猜失敗，更不能每次金錢更新都播拒絕。快速連按須驗同一商品只接受一次；現有 action 未提供音訊交易 token 或通用庫存存在防重契約，音訊冷卻不能修掉重複購買。

售罄目前主要以移除商品、重新 populate 表示，沒有 sold_out 音訊事件。若要「最後一件賣光」提示，定義是單商品移除或整店某分類清空，交易完成後比較同一份庫存，再由同一 owner 發一次 cue。不要在空列表每次 populate 都播售罄，也不要讓 item.remove 與成交確認兩聲無意疊加。

### 退出與中斷

continue 會 show_map 或發 run_victory，不一定立即隱藏 ShopOverlay；map_location_selected 才隱藏，combat_started／player_killed 另有清理。聲音停止以有效可互動場景狀態決定，不只等 visible=false。明定打開地圖覆蓋時商店環境暫停或延續、到訪新節點必停；離場後仍在等待交易的 callback 必須檢查 generation，不能把舊商店確認播到戰鬥。

正常退出短音與死亡／run_ended／離樹中斷分開。環境音 stop、pending cue 取消、signal 斷線與池回收按 music／mixing；框架目前沒有把這套商店聲音生命週期自動接好。

### 測試接法

先遵守 [mixing](mixing.md) 無聲門檻。新 shop fixture 由既有 Smoke 在 Root ready 後呼叫，或沿固定旅行情境延伸已接入 suite；沒有 Shop／Audio suite 可直接跑。先建固定價格、金錢、三種商品與欄位，再走真實 BaseShopButton→ActionShopPurchaseItems；recorder 觀察接受、完成及拒絕出口，並同步斷言金錢／取得／庫存，不以 sound count 單獨證明交易成功。

驗足額各一筆、少一元零成功音、消耗品滿欄零成交、雙擊一商品不得兩次成功、購後重繪零新聲、離場時等待中回呼不播、重訪同店符合 brief。售罄需求另驗最後一件與重新 populate；失敗 signal 尚未實作時記為缺口，不虛構綠測。音效去重不能讓錯誤交易被測試忽略。

## 交接

UI、[場景動畫](../art-assets/scene-choreography.md) 與音訊共用交易 request／結果語意，單一 owner 將接受與完成分開。內容／庫存缺陷另交工程 owner；本流程不以泛用按鈕音取代完整商店驗收。
