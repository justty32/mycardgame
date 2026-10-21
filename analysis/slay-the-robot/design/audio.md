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

SoundManager 收到焦點外移且設定啟用時 mute Master；焦點回來無條件解除 Master mute。這是臨時失焦靜音，不是獨立、可持久的 master mute；未來新增手動 mute 須避免焦點回復覆蓋它。依[操作邊界](../../../wf/workflows/common/user.md#桌面與程序邊界)不實際操作焦點，測試只能在授權隔離背景程序內驗 handler，不能聲稱驗過 OS 事件。

另兩個 API 邊界可從本地碼看到：get_currently_playing_music_tracks 呼叫 music.get_current_tracks，但實際方法名為 get_currently_playing_tracks；get_last_played_music_track 直接取 history[0]，未保護空歷史。新接線不要假定這些 wrapper 已可靠。

現有遊戲回歸沒有音訊專項斷言。本次未證明聽感、loop 無接縫、淡入淡出效果、設定冷啟動套用、音效併發或成品載入。後續任務先按 [音訊工作流](../../../wf/workflows/game-dev/audio.md) 將所需能力轉成針對性測試，再決定修哪些缺口；不將靜態發現升格為「已修復」。

2026-10-19 冷接手補查當時的 PowerShell runner（現由 [test_game.py](../../../tools/test_game.py) 取代，以下兩點仍成立）：suite 名稱與測試腳本映射固定，沒有 Audio suite；runner 會複製 tests/*.gd，但新增 helper 仍須由既有測試呼叫。程序參數明列 `--headless`，未顯式指定音訊驅動；本輪未啟動引擎，因此沒有「新音訊專項不輸出至實體裝置」的實測證據。新增播放檢查前須先核實 Dummy／替身策略，不能由舊 suite 通過推論音訊輸出邊界。loader helper 接入方式見 [內容 bootstrap](../../../wf/workflows/game-dev/content/bootstrap.md)，播放、bus／pool 與聽感仍各自需要相應證據。

## 事件語意與畫面轉移補查

2026-10-19 子流程冷讀後核實完整函式，而非僅依搜尋命中判斷。聲音工作流已拆為 [子流程入口](../../../wf/workflows/game-dev/audio.md)，本節是靜態證據，沒有音訊修復或 runtime 通過宣稱。

[HandManager._play_card](../../../game/autoload/HandManager.gd) 在卡移入 limbo 後發 card_play_started；[ActionCardPlayEnd](../../../game/scripts/actions/card_actions/card_play_actions/ActionCardPlayEnd.gd) 才發 card_played。前者是出牌開始，後者是該次 action 鏈的完成通知，兩者不是兩個成功音。HandManager 另有不足能量拒絕及死亡目標退款；[Hand](../../../game/scripts/ui/Hand.gd) 的 _on_card_selected 在禁用、不可出及已排隊時 return，沒有統一拒絕 signal。預覽／查詢能否出牌不能當手動拒絕事件。

[ActionAttackGenerator](../../../game/scripts/actions/combatant_actions/ActionAttackGenerator.gd) 既向 ACTION_ATTACK 傳 audio_path，又在每段 action_data 追加 ACTION_PLAY_SOUND；[ActionAttack](../../../game/scripts/actions/combatant_actions/ActionAttack.gd) 對每個有效活目標又立即 generate_sound_action，且在 target.damage 之前。非空 path 因此有雙播來源，多目標可增加呼叫數；這是程式路徑證據，尚未量測實際聲音次數。音效是攻擊嘗試而非扣血確認，需先決定每卡／每段／每目標契約與唯一播放 owner。

[Player.damage](../../../game/scripts/combatants/Player.gd) 與 [Enemy.damage](../../../game/scripts/combatants/Enemy.gd) 的 block > damage 發 combatant_blocked；block == damage 發 combatant_block_broken，再返回 [0,0,0]。實際正扣血發 combatant_damaged。因此「所有完全吸收傷害都有 blocked」不成立；零扣血格擋、破盾與真正命中應依產品語意另做互斥路由。Signals 本身不包含通用聲音仲裁。

[Combat._on_map_location_selected](../../../game/scripts/ui/Combat.gd) 是 generate_location_music_action 的遊戲呼叫點，所有到訪戰鬥與非戰鬥節點都經過此處。單純開關地圖、戰後獎勵與結算顯示沒有獨立切曲呼叫。不能從類別名 Combat 推論非戰鬥未接音樂。

[RunSummaryOverlay](../../../game/scripts/ui/RunSummaryOverlay.gd) 勝敗時先顯示結算，結束按鈕才 Global.end_run；title 在 run_ended 回來。TitleScreen 的 title path 空字串會略過 generate_music_action，不會停止仍在播的曲；NO_MUSIC 才經 action 停止。run_started 只隱藏標題，不自行停曲。尚未實作專用結算曲／地圖 overlay 音樂政策。

EnemyIntent 的音效在 Combat 中只有 intent_number_of_attacks == 0 時直接播放；攻擊音路由另沿 AttackGenerator。NewRunMenu 的角色選擇音是另一個已存在接點，不能推論所有介面控件都自動播音。

## 池的額外生命週期風險

[sound_effects.stop](../../../game/addons/sound_manager/sound_effects.gd) 僅對相同 stream 的 busy player 延後 stop，沒有立即 mark_player_as_available。pool 的 increase_pool 在耗盡時才嘗試收回 not playing 的 busy player；而 play 本身也 deferred，同 frame 尚未開始者可能被當作可回收。此處需要同 frame 超過預建數、手動停止及重用的專項測試，不是已證實丟音或已修復。

prepare 重設 bus／volume／pitch，但未明確重設 stream_paused；music 暫停後的重用需另驗。AudioStreamRandomizer 有特殊 player 查找路徑，沒有 JSON 變體策略；變體、冷卻、優先權與硬性併發上限皆須另實作。素材換檔或補檔後，cached fallback／loop 狀態也可能繼續存活，不能只改磁碟就假設目前程序會重載。

最小 loader probe 與既有 Smoke 的實際接入位置收在 [mixing](../../../wf/workflows/game-dev/audio/mixing.md)；範本尚未執行。播放替身／Dummy 能力仍待確認，現有 runner 與 suite 沒有因文件新增就取得音訊覆蓋。

## 完整場景的音訊接點補查

2026-10-19 依場景用途需求補查，操作分流見 [聲音子流程](../../../wf/workflows/game-dev/audio.md)；沒有新增音效資產或遊戲功能。

[DialogueOverlay](../../../game/scripts/ui/DialogueOverlay.gd) 在 start_dialogue 解析成功、populate 初始 state 後發 dialogue_started；prompt 直接 parse_bbcode，沒有逐字或配音 API。[DialogueOption](../../../game/scripts/ui/general/DialogueOption.gd) 只有 option_enabled 且 left_click 才發選項 signal，不能靠這個 signal 接禁用拒絕音。Overlay 將選項 actions 加佇列，等待 actions_ended 後檢查玩家生死並換 state；reset 也在死亡／run／非 EVENT 節點呼叫，不等於正常完成。語音、文字音與分支取消 token 均是新能力。

[BaseShopButton](../../../game/scripts/ui/shop/BaseShopButton.gd) 按下只排 action；[ActionShopPurchaseItems](../../../game/scripts/actions/shop_actions/ActionShopPurchaseItems.gd) 按即時價格與錢判斷，消耗品另查槽位，成功後排扣錢／取得 actions、移除商品並發 purchased。這是交易接受接點，後續 action 完成仍需另觀察；[ShopOverlay](../../../game/scripts/ui/ShopOverlay.gd) 收訊後等 actions_ended 才重建。沒有通用 purchase_failed／sold_out 音訊事件；刷新清除控件不應重播開店或成交。continue 可只 show_map，不能只用 overlay.visible 判斷當前可互動場景。

[RewardOverlay](../../../game/scripts/ui/RewardOverlay.gd) 的 reward_grant_requested 僅累積資料，戰後另等 action 完成且檢查存活／非終局才顯示，寶箱有另一展示入口。BaseRewardButton 排 action 後 queue_free，不代表已領取完成。[CardDraftSelectionOverlay](../../../game/scripts/ui/CardDraftSelectionOverlay.gd) 選中與 skip 都發 card_pick_confirmed，聲音如需區分接受／略過須保留原因，不能只聽 signal 名稱。

[Map](../../../game/scripts/ui/Map.gd) 的 show_map／hide_map 沒有獨立全域顯示 signal；旅行須 can_travel 且相鄰，合法才 generate_visition_location。[RestOverlay](../../../game/scripts/ui/RestOverlay.gd) 的按鈕接受與 rest_action_ended 分開；auto_end 決定是否加入完成 action，不能一律以按下判治療／升級完成。這些資料／結果更新不是已整合的聲音 cue。

[NewRunMenu](../../../game/scripts/ui/menus/NewRunMenu.gd) 建角色按鈕後自動觸發第一個 button_up，populate_character_info 播角色音，因此初始化也可能播放；純手動切換需求需調整責任。[PauseOverlay](../../../game/scripts/ui/PauseOverlay.gd) 的返回標題先 unpause 再 end_run，無差別監聽可能疊加恢復與退出音。game_paused／game_unpaused 與實際暫停、UI pool ALWAYS 的差異需按聲包政策驗證，未取得播放結果。

每場景工作流已列聲音包、唯一 owner、視覺替代、中斷及 Smoke／Combat helper 橋接；這些是後續實作／驗收契約。新增文件不表示現有 suite 已覆蓋對話、交易、地圖、休息、語音或整局結算音訊。

## 非 draft 選牌與結束原因補查

2026-10-19 依獨立用途復查 E-G1 補查 [CardSelectionOverlay](../../../game/scripts/ui/CardSelectionOverlay.gd)。VIEW 點牌為 pass，四個牌堆入口由 Combat 呼叫；SELECT 點牌是 picked_cards 暫選／反選與 glow，不是出牌或取得。Confirm 直接 confirmed，Back 清空後也 confirmed；quick_pick 達 max 後自動進同一 Confirm。confirmed listener 會清 current action，因此新聲音 adapter 應在 emit 前保存 action／opener／原因與選取快照，而非事後猜測。handler 沒有重新驗足額／can_back_out／防重，UI 隱藏控制項不代表直接呼叫安全。

[ActionBasePickCards](../../../game/scripts/actions/card_actions/pick_card_actions/ActionBasePickCards.gd) 候選小於 min 且 required 時不開 UI 直接 finish，剛好 min 自動選取；不足但非 required 亦可自動執行。force_action_end 設 async_cancelled、清 picked，必要時以 confirmed 解除 await，不是正常確認。ActionPickCards 的 async finish 在產生 child 後，仍不保證 child 效果完成。Back 只有在 min／required 等條件阻止空 child 時才是零效果；不能把所有 confirmed 當成功或把所有 Back 當 rollback。專屬聲包及計數契約見 [selection-cues](../../../wf/workflows/game-dev/audio/selection-cues.md)。

DialogueOverlay 的選項 effects 致死後，await 回來仍會 end_dialogue→dialogue_ended。因此 dialogue_ended 不能無條件當正常收尾；聲音 owner 須驗存活、generation 與結束原因，現無 cause payload。此為靜態核實與流程修補，沒有修改遊戲或新增測試通過證據。
