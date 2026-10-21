# 對話與商店 — 內容展示到操作結果

[共通契約](README.md)｜[美術入口](../../art-assets.md)

**何時用**：製作對話或商店的完整畫面序列。

**何時不用**：只改布局／互動走 [UI 畫面](../../ui/screens/README.md)。標「新增」者為待實作。

## Done when

用途記錄及所需素材／控制器檔存在，包含時間段、輸入與還原政策；專項日誌列實際斷言及退出碼。未落地者標「僅規格」，視覺未驗明列；文件 lint 通過（見 [testing](../../../testing.md)）。

## 流程

先讀共通責任，再按以下實碼確認現況，選一個用途建立候選；每次只讓一個 owner 寫同一屬性。

### 對話框：頭像、姓名、文字、選項、關閉

**現況**：[DialogueOverlay](../../../../../game/scripts/ui/DialogueOverlay.gd) 控制 RunScreen/DialogueOverlay，下有 DialogueNameLabel、DialoguePromptLabel、DialogueTextureRect、DialogueOptionContainer。start_dialogue 先 reset、visible=true，取 event_dialogue_object_id／初始 state 後 populate；文字 parse_bbcode 一次顯示，選項立即建立。沒有 Tween、逐字播放或說話者入場。

名稱取 DialogueData.dialogue_name_bbcode，是整個對話名稱，不是 speaker 系統；圖片取 state.dialogue_state_dialogue_texture_path，是提示圖，不是自動定位的頭像。新狀態圖片空字串不清前張，reset 才回 icon.svg；這要明選「沿用」或「清空」。欲有每位說話者姓名、表情與立繪轉場，先由 UI／內容新增映射與節點，不能把既有欄位描述成完整角色對話 schema。

**新增製作順序**：美術交面板／邊框、頭像或立繪表情、姓名牌、提示圖與選項狀態，註明共同基準、裁切與文字安全區。先完成一個狀態的靜態排版，再定「面板顯示→姓名／圖同步→本文出現→合法選項開放」。時間值由用途記錄指定，不能推定原版預設動畫；一般文字顯示與減少動態版直接使用完整本文。

若新增逐字控制，本文 owner 綁 dialogue ID＋state ID＋generation；文字揭露期間點擊究竟是補全文或選項需明定，建議先補全文，下一次才執行選擇。不要用字串長度切 BBCode 產生半個 tag，需依已核實的 RichTextLabel API 實作並測 emoji／富文字。選項先按 validator 決定存在／禁用，延後出現不能繞過 option_enabled。拒絕選項保留文字狀態且零 actions。

**操作到下一狀態**：[DialogueOption](../../../../../game/scripts/ui/general/DialogueOption.gd) 目前在 left_click pressed 發訊號；Overlay 建 actions，必要時等 actions_ended，再檢查存活與 next state。新增「選中強調→鎖本次選項→效果完成→換場或關閉」時，先在 handler 接受點擊時鎖住重複提交，await 後驗 generation；途中死亡／換地點／run_ended 應直接取消文字、表情、音訊與延後選項。現有 reset 不等於已有這套重入保護。

致死 action 的 await 返回後仍會 end_dialogue 並發 dialogue_ended；正常收尾須再驗生存、generation 與結束原因，不能僅由該 signal 判成功。

**驗收**：長文、無圖與換圖、隱藏／禁用選項、無有效選項 fallback、連點、本文 skip、分支 action 後死亡、等待途中關閉再開新對話；舊回呼不得改新狀態、成功 action 僅一次，下一次打開回到完整基準 alpha／輸入。音訊 owner 與取消 token 依 [對話 cues](../../audio/dialogue-cues.md)，UI fixture 依 [對話畫面](../../ui/screens/dialogue.md)。

### 商店：商品入場、購買成功、拒絕與售罄

**現況**：商店根是 RunScreen/ShopOverlay（[ShopOverlay](../../../../../game/scripts/ui/ShopOverlay.gd)），目前沒有商品入場、拒絕搖晃或成交演出。清空重建、買不起的呈現、purchased 與扣款的先後、售罄與 Continue 的程式行為只記在 [商店的程式事實](../../ui/screens/shop-rest.md#商店的程式事實)，本節只寫動態的時點與 owner。

美術先交商品／價籤／面板、hover／disabled、成功提示與售罄標記。動畫根應是商品的內層視覺或新增快照層，Container 仍負責布局。定「資料到位→商品揭示→可購買」，重建清單時只播放新入場的一輪；不要每次價格刷新讓所有商品重新飛入。減少動態版立即完整顯示，用文字與靜態標記表示狀態。

**接受不是交易全部完成**：cue 須分為「提交待定→接受／拒絕→效果完成／重建」；若成功文字宣稱錢與物品已到位，要在後續 actions 完成後核對實際結果，單憑 button_up 不得播放成交演出。

新增控制器在提交即禁同一商品重按；成功時先快照視覺，避免重建 queue_free 使 Tween 失去目標，僅由交易邏輯扣款／移庫存。拒絕（不足錢、滿槽、無效庫存）維持原商品與可再嘗試狀態，需新增可識別結果事件或明確驗證結果；不要把「沒收到 purchased」經任意 timer 當拒絕。想保留 SOLD OUT 標記需新增商品槽／售罄資料呈現，不是單加貼圖。

**驗收**：一筆正常交易、錢不足、空槽不足、同商品連點、刷新後 hover、接受但等待途中離店、重回同商店與已售商品；檢查錢／物品／庫存與成功 cue 各一次。關閉使舊重建回呼失效，所有商品控制器釋放，下一次依真實庫存重建，不回滾已接受交易。聲音依 [商店 cues](../../audio/shop-cues.md)，業務 fixture 依 [商店／休息](../../ui/screens/shop-rest.md)。


## 專項驗收

依每節驗收建立有限 timeout 的 fixture；另驗中斷後重開、新資料覆蓋舊資料、減少動態同樣可完成操作。畫面根關閉後零自建Tween／timer／音訊cue殘留。測試接入與驗收判讀沿 [共通契約](README.md#驗證)。

## 交接

交付素材分層、節點根、cue事件與身分、玩法提交點、重播／取消／減少動態、命令／日誌及未驗。下一 agent 先實作一個用途控制器與對應helper，不把文件規格當成已有功能。
