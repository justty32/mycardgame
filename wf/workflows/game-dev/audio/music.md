# music — 音樂、環境音與場景轉移

[聲音子流程](../audio.md)｜[混音與驗證](mixing.md)｜[整局流程](../game-flow.md)

**何時用**：標題／地圖／戰鬥／獎勵／結算的配樂、環境循環、淡入淡出與停止。
**何時不用**：短促介面或命中音走 [sfx](sfx.md)；互動編曲、節拍同步沒有現成產品接線，須先另定需求。

## Done when

交付檔存在轉移契約及素材／循環規格；每次進入、重入、離開與終局的播放／停止紀錄有預期與實際對照。循環、快取、同曲重用、連續切曲及離場回收有對應斷言；未測項明列，不以欄位存在宣稱可用。

## 流程

### 先把「畫面」轉成遊戲狀態

寫來源→目的、目標曲／環境音、同曲是否保留位置、fade 秒數、暫停政策、取消及離場 owner。多筆同質轉移超過 1 KB 用資料檔。先列標題→新局地圖→到訪節點→戰鬥結束／獎勵→地圖→結算→標題，再核對實際 signal；開地圖 overlay 與改變玩家 location 不同。

[TitleScreen](../../../../game/scripts/ui/menus/TitleScreen.gd) 在 ready／run_ended 呼叫 title music，run_started 只隱藏。title 常數空字串會略過，**不停止前曲**；要明確無音樂可透過 NO_MUSIC action。結算顯示與 run_ended 不是同一時間：RunSummaryOverlay 勝敗顯示後，按結束才 Global.end_run。要結算曲或 victory sting，接勝敗狀態的唯一 owner，不能等返回標題才播放。

[Combat](../../../../game/scripts/ui/Combat.gd) 的 `_on_map_location_selected()` 是目前 `generate_location_music_action()` 的遊戲呼叫點，所有到訪節點含非戰鬥都走此函式；它的類別名不代表只處理戰鬥。單純開關地圖、戰後獎勵與結算顯示沒有獨立配樂切換。新增中央狀態 owner 時移交舊觸發責任，不在 Map、Combat、Title 同時再加一份切曲。

ActionGenerator 優先查事件覆蓋，再按節點類型查 ActData／FileLoader 常數。STARTING／TREASURE 用全域 ambient，EVENT 才用 act ambient，SHOP／REST 有自己的常數。目前事件覆蓋分支錯取 `act_data.event_music_file_path`，正確欄位屬 EventData；要使用覆蓋須先修並回歸，不能只填資料。

### 製作循環與載入

按 [audio 入口](../audio.md#來源與製作共同契約) 取得來源，保留母檔與導出檔。區分 intro、loop、outro，記起訖 sample／秒、尾音跨接、長度與拍點；框架只有整曲 loop 旗標，沒有 intro→loop 排程或節拍同步。需要這些能力時另實作控制器，不把三段檔名當可播放機制。

外部 WAV 被 loader 強制不循環；OGG／MP3 可設 audio_loops，但 loop offset 未暴露，且同路徑第一次載入的 loop 設定會留在 cache。需要同曲單次／循環兩種用途時先修 cache key／資源複本策略並測兩種載入順序；不藉重複檔名掩蓋語意衝突。無播放授權可用既有離線工具查時長、接縫波形與頭尾量測，無該工具就記缺口，不能宣稱無縫。

### 播放與停止契約

ActionPlayMusic 的空 path／NO_MUSIC 呼叫 stop_music(duration)；非空 path 目前未傳 audio_crossfade_duration 給 play_music，需修測才會遵守 action 淡入規格。generate_music_action 預設 3 秒，而 plugin play_music 預設 0；不可混稱所有切曲為 3 秒。

plugin music 讓舊曲淡出 2×duration、新曲淡入 duration。同 resource_path busy player 會重用，不重新 play；若需求是從頭開始，須另處理，不依想像。stop(0) 仍最少淡出 0.01 秒；測試等待 fade 完成，不能同 frame 就斷言 busy=0。快切 A→B→A 要驗舊 tween 取消、位置政策及無遺留曲；history／is_playing helper 有已知限制，見核實分析。

環境音用 `play_ambient_sound(stream, fade_in_duration)`，離場用 `stop_ambient_sound(stream, fade_out_duration)` 或 `stop_all_ambient_sounds()`。沒有 JSON 環境音 action。同路徑忙碌時不重播；預設共用 Sounds bus，需按效果音設定驗證。由持有環境狀態的 owner 保存 stream／目前地點；進入戰鬥、退出 run、換場與取消轉移都應停止不再需要的循環。autoload SoundManager 不會因畫面隱藏自然停止。

### 驗證橋接

按 mixing 門檻先證明無實體輸出。用替身觀察上述完整轉移順序，每次記曲 path、loop、fade、播放／停止與 owner；拒絕旅行或只是開地圖不可誤觸切曲。測事件 override、空欄 fallback、NO_MUSIC、同曲重入、兩次 run、勝利／失敗返回標題。替身只證明選曲與參數，不證明 tween／循環／pool。

真實 loader／pool 測試另在已核實的 Dummy driver 背景程序執行：斷言 loop 屬性、當前 stream、fade 後 busy 回收及快速切曲結果。不可把「播放後等待固定秒數」代替狀態斷言與超時。現有 Combat suite 僅戰鬥流程，可延伸 helper；結算與多節點仍需建立情境，沒有 Audio suite 可直接呼叫。

## 交接

交 [mixing](mixing.md) 完成音量、失焦策略與回收驗證，轉移變更同步整局流程及分析。實際長聽、循環接縫、跨曲聽感與成品載入保留未驗。
