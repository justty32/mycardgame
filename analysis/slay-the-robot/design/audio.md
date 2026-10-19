# 音訊系統：可用接點與設計前提

[框架分析](../README.md)｜[音訊工作流](../../../wf/workflows/game-dev/audio.md)

2026-10-19 靜態核實；Slay-The-Robot `4dac5abe0d19382f8ace2cec5ed3fd77e2a0e11d` 與目前本地檔，Godot 4.6。此文沒有播放音訊、啟動引擎或驗聽感；問題描述是程式路徑證據，不是原生崩潰歸因。本輪只建立分析及工作流，不修音訊功能。

## 載入與資產

[project.godot](../../../game/project.godot) 將 [SoundManager](../../../game/addons/sound_manager/sound_manager.gd) 設為 autoload，並指定 [bus layout](../../../game/sounds/default_bus_layout.tres)。插件自報 2.6.1、Nathan Hoad、[MIT](../../../game/addons/sound_manager/LICENSE)；實際 API 以本地碼為準，不能直接拿新版插件說明代入。

[FileLoader.load_audio](../../../game/autoload/FileLoader.gd) 接 `audio_partial_path, is_absolute=false, audio_loops=false`。非 absolute 路徑加 `_EXTERNAL_FILE_PREFIX`；未設 `exported` feature 時是 `res://`，有該 feature 時是執行檔目錄。原碼要求將 external 資料夾複製到成品旁，本輪未驗 export。

loader 以小寫副檔名選 `AudioStreamWAV/MP3/OggVorbis.load_from_file()`，是 runtime 原檔載入，不是 Godot 匯入後的 ResourceLoader 管線。WAV 強制 `LOOP_DISABLED`；MP3／OGG 設 `loop`，未接 loop offset。cache key 只有完整路徑，後續不同 `audio_loops` 要求會拿到先前物件。缺檔／不支援格式回 `MISSING_AUDIO` 並記 error；因此非 null 不等於成功，也不可依 fallback 的 resource_path 判定真載入。

Godot 4.6 的 [AudioStreamWAV](https://docs.godotengine.org/en/4.6/classes/class_audiostreamwav.html) 本身支援 loop 點及 runtime 載入選項，這些能力沒有全部由本專案 loader 暴露。資源處理規格必須分清引擎能力與框架限制。

現存 external 音檔只有 `external/audio/sounds/slash.wav`：檔頭量測 7412 bytes、mono、16-bit PCM、44100 Hz、3584 frames（約 0.081 秒）。fallback `sounds/missing_audio.wav` 為 100084 bytes、stereo、16-bit PCM、48000 Hz、24996 frames（約 0.521 秒）。以 Python `wave` 讀檔頭，未播放。slash 的 action 範例位於 [GlobalProdDataGenerator](../../../game/autoload/GlobalProdDataGenerator.gd)；目前 [Global](../../../game/autoload/Global.gd) 使用測試資料產生器，不能因 production 範例有音效就說目前全部卡牌有聲音。

## 播放、池與混音

[SoundManager](../../../game/addons/sound_manager/sound_manager.gd) 提供 sound／UI sound／ambient／music 四組池，預建 8／8／1／2 個 AudioStreamPlayer。它們是非空間音訊；沒有接 AudioStreamPlayer2D／3D。實際 layout 只有 Music、Sounds 送 Master，UI 與 ambient 找不到更專用 bus 時同樣使用 Sounds。

一般 sound 為 PAUSABLE，UI／ambient／music 為 ALWAYS。可指定 override_bus；音量 setter 接線性 0–1 再轉 dB，`play_music_at_volume()` 的 volume 則直接寫 player.volume_db，是 dB，不能混用。

[pool](../../../game/addons/sound_manager/abstract_audio_player_pool.gd) 沒有硬性併發上限，空閒池耗盡會補 player。prepare 重設 bus、volume、pitch，播放使用 call_deferred。自然 finished 回池；fade 到 ≤ -79 dB 才 stop 並回池。需新增音訊測試才能證明同 frame 大量觸發、stop 後回池與快速切曲可靠；不能把預建數量解讀成混音上限或回收證據。[AudioStreamPlayer 4.6](https://docs.godotengine.org/en/4.6/classes/class_audiostreamplayer.html) 明示 stop 不發 finished，這是檢驗 pool 生命週期的必要前提。

[music.gd](../../../game/addons/sound_manager/music.gd) 先讓既有曲淡出 `crossfade_duration * 2`，新曲以指定 duration 淡入；同 resource_path 的 busy 曲重用。stop(0) 最少仍淡出 0.01 秒，並非同步停止。ambient 避免重播同 path，需顯式停止循環。這套是音量 tween，不是節拍同步、互動分軌或優先權／ducking 系統。

## Action 與地點音樂

[ActionPlaySound](../../../game/scripts/actions/audio_actions/ActionPlaySound.gd) 讀 audio_path、audio_path_is_absolute，強制不 loop，呼叫 play_ui_sound；即使名字是 sound action，實際採 UI pool。action 為 instant，不等待音檔完成。可用 [ActionGenerator](../../../game/autoload/ActionGenerator.gd) 的 generate_sound_action，或 action dictionary 的 Scripts.ACTION_PLAY_SOUND 接入。

[ActionPlayMusic](../../../game/scripts/actions/audio_actions/ActionPlayMusic.gd) 讀 audio_path、absolute、audio_loops（預設 true）、audio_crossfade_duration（預設 1 秒）。空 path／NO_MUSIC 呼叫 stop_music(duration)；非空 path 卻只呼叫 play_music(audio)，**沒有將 duration 傳入**，因此目前這個 action 的開始播放不遵守指定 crossfade。

generate_music_action 預設傳 3 秒；generate_location_music_action 嘗試事件覆蓋，再按位置用 ActData 或 FileLoader 常數。事件分支檢查 `event_data.event_music_file_path`，實際卻取 `act_data.event_music_file_path`；[ActData](../../../game/data/readonly/ActData.gd) 沒有這個欄位，故事件音樂不能只填 [EventData](../../../game/data/readonly/EventData.gd) 就視為接線完成。

一般 EVENT 用 act ambient；COMBAT／MINIBOSS／BOSS 用 act 對應路徑再 fallback。STARTING／TREASURE 直接走全域 ambient；REST_SITE、SHOP 走各自常數。[TitleScreen](../../../game/scripts/ui/menus/TitleScreen.gd) 在 ready／run_ended 播 title 常數，該值目前為空；其他預設音樂常數是 NO_MUSIC。現有素材與預設並未建立完整配樂。

## 設定與未驗邊界

[UserSettingsData](../../../game/data/mutable/UserSettingsData.gd) 有 master／music／effects volume 及失焦靜音，沒有 audioPrefs 欄位。檔頭「none hooked up」註解已落後實作。[SettingsMenu](../../../game/scripts/ui/menus/SettingsMenu.gd) 的 slider signal 將 music×master、effects×master 送至 bus；沒有直接調 Master bus volume。離開該 menu 時保存至 external/user_settings.json，Global 啟動時先 load_user_settings，但該函式只反序列化，未套音量。populate_menu 可能藉 slider value_changed 間接套用；未進設定頁的冷啟動不應被當作音量已還原。

SoundManager 收到焦點外移且設定啟用時 mute Master；焦點回來無條件解除 Master mute。這是臨時失焦靜音，不是獨立、可持久的 master mute；未來新增手動 mute 須避免焦點回復覆蓋它。當前禁止實際操作焦點，測試只能在授權隔離背景程序內驗 handler，不能聲稱驗過 OS 事件。

另兩個 API 邊界可從本地碼看到：get_currently_playing_music_tracks 呼叫 music.get_current_tracks，但實際方法名為 get_currently_playing_tracks；get_last_played_music_track 直接取 history[0]，未保護空歷史。新接線不要假定這些 wrapper 已可靠。

現有遊戲回歸沒有音訊專項斷言。本次未證明聽感、loop 無接縫、淡入淡出效果、設定冷啟動套用、音效併發或成品載入。後續任務先按 [音訊工作流](../../../wf/workflows/game-dev/audio.md) 將所需能力轉成針對性測試，再決定修哪些缺口；不將靜態發現升格為「已修復」。
