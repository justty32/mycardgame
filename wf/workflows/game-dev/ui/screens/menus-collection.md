# 選單與收藏畫面 — 選角、設定、圖鑑及結算

[場景目錄](README.md)｜[文字／字型／尺寸](../menus-localization.md)｜[整局契約](../../game-flow.md)｜[專項驗證](../verification.md)

**何時用**：把主選單、選角／起局、暫停設定、圖鑑／歷史或結算做成一套可進出畫面。**何時不用**：run 的存讀／勝敗規則交整局；只改單一文字沿文字流程。

## Done when

各畫面的玩家目的、入口／返回、資料與空值狀態、整套素材及 cue 紀錄存在；有效／空 profile、起局和結算 fixture 核對狀態及返回結果，文件 lint 通過（見 [testing](../../../testing.md)）。真實焦點／控制器、視覺和聲音未驗者明列。

## 流程

### 畫面族與素材包

[Root](../../../../../game/scenes/Root.tscn) 內 TitleScreen 持有 MainMenu、NewRunMenu、SettingsMenu、CodexMenu、RunHistoryMenu 與 ProfileStatsMenu；RunScreen 持有 PauseOverlay／RunSummaryOverlay。它們共享部分 theme 與導航，並非都繼承同一 modal。先列本次玩家旅程，例如「主選單→選角色→起局」或「結算→歷史→回主選單」，不要只列按鈕集合。

素材包需有標題／背景、選單 panel、角色 icon 與選中狀態、角色資訊／遺物圖、卡牌／敵人／遺物／耗材圖鑑圖、空歷史提示、勝敗標題和統計框，以及所有返回／不可用／focus 樣式。角色選角 icon 不等於戰鬥 sprite；enemy_texture_path 是圖鑑圖，不能取代戰鬥 animation_id。圖片接 [介面素材](../../art-assets/interface-assets.md)，角色視圖接 [角色素材](../../art-assets/combatants.md)，字型／文字由既有子流程維護。

### 主選單與角色選擇

[BaseMenu.gd](../../../../../game/scripts/ui/menus/BaseMenu.gd) 由匯出 navigation_button_to_menu／sub_menu 字典在 button_up 導航；populate_menu／clear_menu 控可見性與子項，intro／outro tween hook 預設 null。改階層須同步字典及 NodePath；新返回按鈕要指實際目的地，不能只寫 Back。

[MainMenu.gd](../../../../../game/scripts/ui/menus/MainMenu.gd) 依 FileLoader.has_save_file 讓 Continue／Forfeit 或 NewRun 可見；Continue 走 autoload，Forfeit 走 Global，Exit 直接 quit。有效 save、不存在及無效 save 的內容判定走存讀流程；不要在 UI 用「檔案存在」宣稱可續玩，也不要為驗 Exit 結束使用者既有程序。

[NewRunMenu.gd](../../../../../game/scripts/ui/menus/NewRunMenu.gd) 動態生成 CharacterSelectionButton 並自動選第一個，顯示名稱／描述／HP／Money 和第一個起始遺物；多遺物未完整呈現，無角色時沒有現成完整空態。角色沒有遺物時需核對是否沿用先前資訊，不假設切角色會清全部欄位。character_background_texture_path 尚無已核實消費端，想用選角大圖須另接。

難度、seed 和 modifier 是起局的一部分；StartRunButton.pressed 直接 Global.start_run(selected_character_object_id, seed, difficulty, modifiers)，目前無額外確認。取消選角只是導航離開，不應先建立 run；若產品要角色鎖定／未解鎖／無可用角色，需定資料與 disabled 原因，不靠暗圖推定。起局後 RunStartOptions 又使用 DialogueOption，需保留選初始獎勵這個中間畫面與結果。

### 暫停與設定是兩種契約

PauseOverlay 的 Resume／ReturnToTitle／Forfeit 分別呼叫 unpause、unpause+end_run(QUIT)、unpause+end_run(LOSS)；是實際遊戲狀態變更，不能當普通關閉 panel。新「確認放棄」需先延後 end_run 並保留取消回暫停，不能先結算再問。鍵盤取消優先序與 focus 還原依共同互動；現有 UI 不構成完整手把支援。

[SettingsMenu.gd](../../../../../game/scripts/ui/menus/SettingsMenu.gd) 將三個音量值與背景靜音整合成設定頁：調 slider 即改 SoundManager 音量，離開 `_navigate_to_next_menu()` 前儲存 user_settings。它沒有 Apply／Discard／恢復預設的完整流程；若新增取消還原，需保存進場值並恢復播放值和資料，不能只改返回文案。只驗背景 property 不得操作真實焦點或播放測試。

### 圖鑑、歷史與結算

CodexMenu 管子頁，CodexCardsMenu 讀全卡／卡包 filter，排序後交 ResizingGridScrollContainer 生成 Card；它是檢視，不應發出牌 Action。CodexEnemiesMenu 顯示敵人圖片／名稱／意圖可見性，其他收藏型別各有 consumer。篩選零筆、長文字、tooltip、切頁後清舊元件是完整畫面要求；不存在的搜尋／解鎖 API 不因視覺有搜尋框就算完成。

[RunHistoryMenu.gd](../../../../../game/scripts/ui/menus/RunHistoryMenu.gd) 用 profile_run_history，空時顯示 NoRunsLabel；有資料時預設最新、前後按鈕受邊界限制，顯示角色／seed／結果／牌組／遺物／耗材。ProfileStatsMenu 組合勝敗、時間與角色統計；顯示應唯讀，不由打開頁面再次計分。清頁 queue_free 後要等 frame，重入不重複疊卡。

RunSummaryOverlay 收 run_victory 或 player_death_animation_finished，更新勝敗文案與 current_run_stats 三欄統計；EndRunButton 呼叫 Global.end_run。按鈕雖寫 Back To Main Menu，現有敗北測試實際返回 NewRunMenu。沒有 stats 的路徑含 breakpoint，fixture 不可空發勝利訊號。完整通關與一般戰鬥獎勵分開驗；翻譯 Damage Taken 須同步現有文案耦合斷言，詳文字流程。

### 聲音與動畫交接

TitleScreen 在 ready／run ended 播 title music；NewRunMenu.populate_character_info 可播 character_selection_audio_path，且自動選第一角也會進此路徑，不能再無條件加一次選角音。設定調整是音量控制，預覽音需另定；暫停音樂是否停止不得靠畫面 hidden 猜測。

聲音的導航／選角／拒絕／設定／勝敗 cue 接 [畫面音訊](../../audio/screen-cues.md)。BaseMenu tween hook 可承載進退場，但 clear_menu 先隱藏再取得 outro，新動畫要確認可見性、輸入鎖和等待有效性；現成 hook 不等於所有選單已有動態。整體節奏接 [畫面轉場](../../art-assets/motion/menus.md)。取消／快速切頁時停舊 cue，晚到完成不再導航；字串刷新不重播勝利音。

### Fixture 與驗收

以 Smoke Root ready 後 helper 驗 navigation 引用、空／有效 profile、角色切換與無遺物清空、收藏篩選零筆、歷史邊界和多次進退不累積子項。可能啟動音訊的 handler 先做靜態查核，播放驗證遵循音訊的隔離契約。設定專項只能用隔離 user_settings，不能寫個人設定。

Combat 既有敗北分支可保留結算／返回回歸；新勝利結算需有效 RunStatsData／EventData 的專項情境，核對結果只記一次及返回目標。GUI、focus、字形、實際控制器和聲音目前均未驗，不能由 button_up.emit 的成功推廣。fixture 實際接線依 verification，沒有自動新畫面 suite。

## 交接

交玩家旅程、每頁返回與保存／放棄語意、動態資料／空態、整套素材 cue、測試 fixture 和未驗層級；存讀及勝敗真相仍由整局工作流維護。
