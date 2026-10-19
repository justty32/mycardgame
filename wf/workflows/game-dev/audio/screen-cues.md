# screen-cues — 獎勵、地圖、休息與選單聲包

[聲音場景入口](README.md)｜[完整場景交付](../scene-pack.md)｜[UI 場景入口](../ui/screens/README.md)

**何時用**：為非戰鬥畫面交付完整進入、互動、結果與離開聲音流程。
**何時不用**：對話與商店各走 [dialogue-cues](dialogue-cues.md)、[shop-cues](shop-cues.md)；單一短音加工走 sfx。

## Done when

本次畫面的組合聲包、事件 owner、停止與視覺替代紀錄存在；以下適用情境已接 helper 並有 cue 次數／順序與遊戲狀態斷言。未實作的播放或 UI 事件明列，文件冷讀不代替 runtime 通過。

## 流程

### 共同交付方式

每個畫面先選進場／瀏覽、接受／拒絕、結果、退出短音及可選循環層；可以明定靜音。每項記長度／延遲／尾音、一次或 loop、變體、冷卻、併發與中斷政策，沿 README 的來源／格式，沿 music 的切曲 owner。以下是實際場景組合與接點，不是已存在的 cue API。

頁面 generation＋業務 request 是去重與取消的範圍；初始化、populate、重繪不等於使用者新操作。選單短音可用 UI pool，但該池 ALWAYS，隱藏頁面不會自動停止。離場、run 切換、死亡及離樹撤銷 pending cue，循環／長台詞另持有 handle 停止，詳 mixing。

### 獎勵與 draft 選牌

聲包組合為獎勵展示、領取確認、開選牌、選中／略過及返回；寶箱開啟可另用一次性起音。UI 接 [RewardOverlay](../../../../game/scripts/ui/RewardOverlay.gd)：reward_grant_requested 是資料累積，不是已展示或已取得；戰後會等 actions_ended 且玩家活著、非終局才顯示，chest_opened 另觸發展示。展示 owner 以可見的獎勵批次去重，不在 populate 每次播開箱。

BaseRewardButton 點下排 action 後 queue_free，不代表結果已套用。確認音應明定為接受領取，或等待真實取得且對應本次 reward request；不能把所有 player_money_changed 當獎勵音。CardDraftSelectionOverlay 的選中與 skip 都發 card_pick_confirmed，故只聽該 signal 不能分辨二者；在各 handler 保留選擇原因／picked_cards 再轉語意 cue。視覺保留已領項目、金錢／牌組與略過結果；中斷時取消舊 draft 音且停止環境層，不將取消當獲得稀有牌。

測試從 Combat 既有獎勵段延伸，另補 chest／draft fixture：只發 grant 不播取得、重繪不重播展示、選中一次與 skip 零取得音、離場／run_ended 後舊確認不播。UI 流程見 [rewards-selection](../ui/screens/rewards-selection.md)。

非 draft 的 CardSelectionOverlay VIEW／SELECT、暫選／反選、Confirm／Back、quick_pick、空候選及返回休息／牌堆 opener，接 [選牌聲包](selection-cues.md)；不能沿用 draft 立即完成的聲音契約。

### 地圖檢視與旅行

聲包包含開／關地圖、節點瀏覽、接受旅行與到達短音，配樂可延續當前地點。Map.show_map/hide_map 沒有專用全域顯示事件；若多處都能開圖，應由這兩個函式的實際狀態轉移提供單一呈現通知，不能每個呼叫者再播一次。Map._on_map_location_button_up 只有 can_travel 且鄰接合法才 generate_visition_location；map_location_selected 是接受地點變更，還會觸發共用 music。

「瀏覽不可去節點」是否有拒絕音須明定，不能只看 node 被點。到新節點取消地圖瀏覽音／舊環境，重複 show 同頁不播入場。視覺保留可達／已走節點及位置。按 [map](../ui/screens/map.md) 建鄰接／不可旅行 fixture，驗開圖零旅行音、非法節點零到達音、合法旅行一次及返回檢視不重啟地點曲；多節點覆蓋不能由單場 Combat 推論。

### 休息、升級與完成

聲包是休息地點環境、選項確認／不可用、治療或升級結果、完成與退出。RestOverlay 到 REST_SITE 時建立按鈕，_on_rest_action_button_up 在 actions 執行時 return；自動結束的項目加入 ActionRestActionEnd，`rest_action_ended(id)` 才進完成處理並重驗排他按鈕。選項接受與完成各有語意，治療／升級成功不能在按下時先播。

非 auto_end 項目必須由其 action 完成路徑明確結束，不能靠固定等待播完成；玩家取消選牌不等於升級；完整 modal cue 與返回服務 owner 見 [selection-cues](selection-cues.md)。視覺以 HP 差、卡牌結果及排他按鈕禁用佐證。退出到地圖時決定環境延續／停止，換節點及 run_end 必須撤銷舊 callback。fixture 驗一次治療、排他項再選零成功音、升級選擇／取消、連按與離場；參考 [shop-rest](../ui/screens/shop-rest.md)。

### 選角、新局與收藏瀏覽

聲包包含角色切換短句、開始新局確認、無效選項／輸入回饋與返回。NewRunMenu.populate_character_info 已播放 character_selection_audio_path；populate_character_buttons 還會自動 emit 第一個 button_up，首次開頁也可能出聲。不要再在 _on_character_selected 播同音；若需求只手動切換播放，先拆出更新資料與聲音觸發，記初始預選政策。

快速換角停止舊長台詞或採有限尾音政策，選同一角色重繪不重播；run_started 是新局／續玩共用，不能無條件當首次開局獎勵。角色圖、名稱、屬性與選取框提供無聲替代。收藏／卡牌預覽只提供低頻瀏覽提示，不接戰鬥成功出牌音。fixture 驗初始化、A→B→A、同角重選、開始／返回與續玩；沿 [menus-collection](../ui/screens/menus-collection.md) 接真實 menu 路徑。

### 暫停與設定

聲包包含暫停進入、恢復、返回標題／放棄確認與音量預覽（後者需明確要求）。以 game_paused/game_unpaused 的已接受狀態為 owner；PauseButton pressed 不保證可暫停，PauseOverlay 返回會先 unpause 再 end_run，需避免恢復音與退出音連播。暫停是否壓低／暫停戰鬥曲與環境在 brief 明定，插件未提供完整 ducking。

設定頁修改 slider 已直接套 bus，不能每個 value_changed 播一次預覽；如要預覽用明確操作或受控節流且不繞過當前音量／mute。視覺顯示數值、靜音與保存狀態；離頁取消預覽長音，保存／冷啟動另按 mixing。fixture 驗暫停、恢復、放棄、音量 0、快速拖值與重開；當前不得操作真實視窗焦點。

### 結算與返回標題

聲包是勝／敗結果短句、可選結算曲、結果瀏覽及返回標題。RunSummaryOverlay 對 run_victory 或 player_death_animation_finished 顯示結果；run_ended 在結束按鈕後才發，不能以它當首次結算。死亡短句與失敗結算音交戰鬥 owner 排優先，重複 signal 不得再次播結果。

退出結算時停止結算環境／長句，再交 title music owner；title 空 path 略過而非停止，按 music 明確處理。統計、勝敗文字與獎勵提供視覺替代。fixture 分勝利／失敗／主動離開三種，主動 quit 不播勝敗；重開同頁、第二局及返回標題不得洩漏舊聲。既有 Combat 勝敗未覆蓋所有整局結果，需額外專屬情境。

## 交接

各 fixture 依 [mixing](mixing.md) 先核實無聲策略，接既有 Smoke／Combat 的 `_check()`、等待與結果日誌；沒有 Screen／Audio suite，新增 helper 也不會自動執行。素材及 [UI 動畫](../art-assets/ui-motion.md) 共用場景 generation 與接受／完成／取消語意，聽感、實際輸入及成品載入另列未驗。
