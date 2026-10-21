# screen-cues — 獎勵、地圖、休息與選單聲包

[聲音場景入口](../audio.md)｜[完整場景交付](../scene-pack.md)｜[UI 場景入口](../ui/screens/README.md)

**何時用**：為非戰鬥畫面交付完整進入、互動、結果與離開聲音流程。
**何時不用**：對話與商店各走 [dialogue-cues](dialogue-cues.md)、[shop-cues](shop-cues.md)；非 draft 的牌庫 VIEW／SELECT 走 [selection-cues](selection-cues.md)；單一短音加工走 sfx。

## Done when

該畫面的組合聲包、事件 owner、停止與視覺替代紀錄存在；以下適用情境已接 helper 並有 cue 次數／順序與遊戲狀態斷言。未實作的播放或 UI 事件明列，文件冷讀不代替 runtime 通過。

## 流程

每個畫面先選進場／瀏覽、接受／拒絕、結果、退出短音及可選循環層，切曲沿 [music](music.md)。去重、接受／完成、取消與驗證接線的共同規則見 [audio 入口](../audio.md#場景聲包共同規則)；各節的程式事實以所連的 UI 場景篇為準，以下只寫聲音的時點、owner 與 fixture 預期，不是已存在的 cue API。

### 獎勵與 draft 選牌

聲包為獎勵展示、領取確認、開選牌、選中／略過及返回；寶箱開啟可另用一次性起音。顯示時機、BaseRewardButton／CardRewardButton 與 draft 行為見 [rewards-selection](../ui/screens/rewards-selection.md)。reward_grant_requested 只是資料累積，不是已展示或已取得；展示 owner 以可見的獎勵批次去重，不在 populate 每次播開箱。

確認音明定為接受領取，或等待真實取得且對應本次 reward request，不能把所有 player_money_changed 當獎勵音。draft 的選中與 Skip 都發 card_pick_confirmed，要在各 handler 保留選擇原因／picked_cards 再轉語意 cue。視覺保留已領項目、金錢／牌組與略過結果；中斷時不將取消當獲得稀有牌。

fixture 從 Combat 既有獎勵段延伸並補 chest／draft：只發 grant 不播取得、重繪不重播展示、選中一次與 Skip 零取得音、離場／run_ended 後舊確認不播。

### 地圖檢視與旅行

聲包為開／關地圖、節點瀏覽、接受旅行與到達短音，配樂可延續當前地點；Map 的開圖、can_travel、鄰接驗證與 visit 鏈見 [map](../ui/screens/map.md)。show_map／hide_map 沒有專用全域顯示事件；多處都能開圖時，由這兩個函式的實際狀態轉移提供單一呈現通知，不讓每個呼叫者各播一次。到達音跟隨 map_location_selected，不跟原始 button_up。

「瀏覽不可去節點」是否有拒絕音須明定，不能只看 node 被點；重複 show 同頁不播入場。視覺保留可達／已走節點及位置。按 [地圖 fixture](../ui/screens/map-fixture.md) 建鄰接／不可旅行情境，驗開圖零旅行音、非法節點零到達音、合法旅行一次及返回檢視不重啟地點曲；多節點覆蓋不能由單場 Combat 推論。

### 休息、升級與完成

聲包為休息地點環境、選項確認／不可用、治療或升級結果、完成與退出。接受到 rest_action_ended 的完成鏈見 [rest-services](../ui/screens/rest-services.md)；治療／升級成功音等 rest_action_ended 與真實結果，不在按下時先播，也不靠固定等待。modal 內 cue 與取消選牌見 [selection-cues](selection-cues.md)。

視覺以 HP 差、卡牌結果及排他按鈕禁用佐證；退出到地圖時決定環境延續／停止。fixture 驗一次治療、排他項再選零成功音、升級選擇／取消、連按與離場。

### 選角、新局與收藏瀏覽

聲包為角色切換短句、開始新局確認、無效選項／輸入回饋與返回。選角音已存在且首次開頁會因自動選第一角而出聲（見 [menus-collection](../ui/screens/menus-collection.md#聲音與動畫交接)）；不要再在 _on_character_selected 播同音。只在手動切換時播放的需求，先拆出更新資料與聲音觸發，記初始預選政策。

快速換角停止舊長台詞或採有限尾音政策，選同一角色重繪不重播；run_started 是新局／續玩共用，不能無條件當首次開局提示。角色圖、名稱、屬性與選取框提供無聲替代。收藏／卡牌預覽只提供低頻瀏覽提示，不接戰鬥成功出牌音。fixture 驗初始化、A→B→A、同角重選、開始／返回與續玩。

### 暫停與設定

聲包為暫停進入、恢復、返回標題／放棄確認與音量預覽（後者需明確要求）。以 game_paused／game_unpaused 的已接受狀態為 owner，PauseButton pressed 不保證可暫停；返回標題會先 unpause 再 end_run，需避免恢復音與退出音連播。暫停是否壓低／暫停戰鬥曲與環境在 brief 明定，插件未提供完整 ducking。

設定 slider 不能每個 value_changed 播一次預覽；如要預覽用明確操作或受控節流，且不繞過當前音量／mute。視覺顯示數值、靜音與保存狀態；離頁取消預覽長音，保存／冷啟動另按 mixing。fixture 驗暫停、恢復、放棄、音量 0、快速拖值與重開。

### 結算與返回標題

聲包為勝／敗結果短句、可選結算曲、結果瀏覽及返回標題。結算顯示時機見 [menus-collection](../ui/screens/menus-collection.md#圖鑑歷史與結算)；run_ended 在結束按鈕後才發，不能當首次結算。死亡短句與失敗結算音交戰鬥 owner 排優先，重複 signal 不得再次播結果。

退出結算時停止結算環境／長句，再交 title music owner（空 path 不停止前曲，見 [music](music.md)）。統計、勝敗文字與獎勵提供視覺替代。fixture 分勝利／失敗／主動離開三種，主動 quit 不播勝敗；重開同頁、第二局及返回標題不得洩漏舊聲。既有 Combat 勝敗未覆蓋所有整局結果，需額外專屬情境。

## 交接

聽感、實際輸入及成品載入另列未驗。
