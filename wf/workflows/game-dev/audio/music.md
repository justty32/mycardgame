# music — 音樂、環境音與場景轉移

[聲音子流程](../audio.md)｜[混音與驗證](mixing.md)｜[整局流程](../game-flow.md)｜[核實分析](../../../../analysis/slay-the-robot/design/audio.md)

**何時用**：標題／地圖／戰鬥／獎勵／結算的配樂、環境循環、淡入淡出與停止。
**何時不用**：短促介面或命中音走 [sfx](sfx.md)；互動編曲、節拍同步沒有現成產品接線，須先另定需求。

## Done when

交付檔存在轉移契約及素材／循環規格；每次進入、重入、離開與終局的播放／停止紀錄有預期與實際對照。循環、快取、同曲重用、連續切曲及離場回收有對應斷言；未測項明列，不以欄位存在宣稱可用。

## 流程

### 先把「畫面」轉成遊戲狀態

寫來源→目的、目標曲／環境音、同曲是否保留位置、fade 秒數、暫停政策、取消及離場 owner。先列標題→新局地圖→到訪節點→戰鬥結束／獎勵→地圖→結算→標題，再核對實際 signal；開地圖 overlay 與改變玩家 location 不同。

現有切曲接點（title 空字串略過而**不停止前曲**；Combat._on_map_location_selected 是所有到訪節點的切曲點；開關地圖、獎勵與結算沒有獨立切曲；節點類型到常數的對應）見 [核實分析](../../../../analysis/slay-the-robot/design/audio.md#action-與地點音樂)。據此：

- 要明確無音樂用 NO_MUSIC action，不靠空 path。
- 結算曲或 victory sting 接勝敗狀態的唯一 owner；結算顯示早於 run_ended，不能等返回標題才播。
- 新增中央狀態 owner 時移交舊觸發責任，不在 Map、Combat、Title 同時再加一份切曲；Combat 的類別名不代表只處理戰鬥。
- 事件音樂覆蓋分支目前錯取 ActData 欄位，要用 EventData 覆蓋須先修並回歸，不能只填資料。

### 製作循環與載入

區分 intro、loop、outro，記起訖 sample／秒、尾音跨接、長度與拍點；框架只有整曲 loop 旗標，沒有 intro→loop 排程或節拍同步。需要這些能力時另實作控制器，不把三段檔名當可播放機制。

載入的 loop 與 cache 限制見 [共同載入邊界](../audio.md#共同載入邊界)；loop offset 也未暴露。需要同曲單次／循環兩種用途時先修 cache key／資源複本策略並測兩種載入順序；不藉重複檔名掩蓋語意衝突。無播放授權時可用既有離線工具查時長、接縫波形與頭尾量測，無該工具就記缺口，不能宣稱無縫。

### 播放與停止契約

crossfade 與重用的現況見 [核實分析](../../../../analysis/slay-the-robot/design/audio.md#播放池與混音)。generate_music_action 預設 3 秒、plugin play_music 預設 0，不可混稱所有切曲為 3 秒；ActionPlayMusic 的淡入規格要修測才會遵守；同曲 busy 會重用，需求是「從頭開始」時須另處理；stop(0) 也有最短淡出，測試等待 fade 完成，不能同 frame 就斷言 busy=0。快切 A→B→A 要驗舊 tween 取消、位置政策及無遺留曲；history／is_playing helper 有已知限制。

環境音用 `play_ambient_sound(stream, fade_in_duration)`，離場用 `stop_ambient_sound(stream, fade_out_duration)` 或 `stop_all_ambient_sounds()`。沒有 JSON 環境音 action。同路徑忙碌時不重播；預設共用 Sounds bus，需按效果音設定驗證。由持有環境狀態的 owner 保存 stream／目前地點；進入戰鬥、退出 run、換場與取消轉移都應停止不再需要的循環。autoload SoundManager 不會因畫面隱藏自然停止。

### 驗證橋接

按 mixing 門檻先證明無實體輸出。用替身觀察上述完整轉移順序，每次記曲 path、loop、fade、播放／停止與 owner；拒絕旅行或只是開地圖不可誤觸切曲。測事件 override、空欄 fallback、NO_MUSIC、同曲重入、兩次 run、勝利／失敗返回標題。替身只證明選曲與參數，不證明 tween／循環／pool。

真實 loader／pool 測試另在已核實的 Dummy driver 背景程序執行：斷言 loop 屬性、當前 stream、fade 後 busy 回收及快速切曲結果，不以「播放後等待固定秒數」代替狀態斷言與超時。現有 Combat suite 僅戰鬥流程；結算與多節點需另建情境。

## 交接

交 [mixing](mixing.md) 完成音量、失焦策略與回收驗證，轉移變更同步整局流程及分析。實際長聽、循環接縫、跨曲聽感與成品載入保留未驗。
