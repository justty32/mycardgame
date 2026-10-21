# presentation-delivery — 一次出牌的跨領域交付

[遊戲開發](README.md)｜[完整畫面交付](scene-pack.md)｜[美術](art-assets/README.md)｜[聲音](audio/README.md)｜[UI](ui/README.md)｜[驗收](validation.md)

**何時用**：同一張卡或戰鬥事件同時涉及人物動畫、VFX、音效與 UI，需要交接事件、素材和清理責任。
**何時不用**：只替換單張圖或單段音檔走對應子流程；改傷害、等待、攔截或取消語意走 [mechanics](mechanics.md)。

## Done when

任務交付記錄存在，填明每個事件的唯一觸發 owner、素材版本、消費欄位、數量、回退、離場清理與已測／待測結果。來源查核和適用的專項命令有結果；文件 strict lint 回傳 0。沒有執行證據的項目明列未驗，不能用動畫完成、靜態路由或 Smoke 成功代替命中／聲音／輸入驗收。

## 流程

### 先鎖定語意和所有權

從 [Hand](../../../game/scripts/ui/Hand.gd)、[HandManager](../../../game/autoload/HandManager.gd) 到 [ActionHandler](../../../game/autoload/ActionHandler.gd) 追同一 CardPlayRequest。內容 owner 管 card／animation ID、actions 與資料引用；動畫 owner 管人物 frame／狀態；VFX owner 管短效建立／消失；音訊 owner 管事件播放及停止；UI owner 管選取、回饋與資料刷新。指定一位整合 owner 保管這條事件契約；不是各領域各接一份成功 listener。

先決定「成功」指開始或完成，「命中」指攻擊嘗試或實際扣 HP；每卡、每擊、每目標是不同計數。定義失敗回饋要覆蓋哪些 return、取消是否只撤回尚未送出的選取。這些是待填產品需求，現成信號不能替使用者決定。

### 成功出牌與完成

Hand 通過 disabled、right-click、can_play_card 與重複佇列檢查後，直接送出或選目標；HandManager 再核能量並先扣／保留能量、更新 HUD。排入佇列不等於開始執行，失效目標會退款。

選目標、驗證與執行資料由場景提供的 [CardPlayAdapter](../../../game/scripts/combat/CardPlayAdapter.gd) 決定：未掛棋盤時是基底 adapter（點敵人選目標）；掛棋盤時是 [BoardCardAdapter](../../../game/scripts/combat/board/BoardCardAdapter.gd)（選格、跨盤、盤面專屬效果在費用前拒絕）。adapter 不扣費也不入列，演出事件要在兩種模式下都有觸發點，不能只掛在 BoardView 或格子節點上。

`_play_card()` 移卡到 limbo 後發 `Signals.card_play_started`；完成 action 為 [ActionCardPlayEnd](../../../game/scripts/actions/card_actions/card_play_actions/ActionCardPlayEnd.gd) 的 `card_played`。後者仍在 action 處理中，目的牌堆移動在 HandManager 等待 actions_ended 之後；不要把 card_played 說成卡已入棄牌堆。若成功音選開始／完成信號，便不再從 CardButton 及 card_play_actions 重複播放。

`add_actions()` 預設每項推 stack、後項先執行；enqueue 的 current queue 才是 FIFO。HandManager 將完成 action 放在陣列前端，因而最後執行。新增 presentation action 要寫實際執行序，不能只按 JSON 由上往下閱讀。

### 攻擊、畫面命中與實際扣血

[ActionAttackGenerator](../../../game/scripts/actions/combatant_actions/ActionAttackGenerator.gd) 先要求人物 attack，產生每擊 actions；全數啟用時，每擊陣列為 attack、sound、per-attack animation、VFX，預設 stack 反序執行。VFX 先於 [ActionAttack](../../../game/scripts/actions/combatant_actions/ActionAttack.gd) 的 `target.damage()`，不表示已扣血；多擊／多目標要沿 interceptor 展開數量重新核算。

VFX 與 Attack 各自攔截／選目標，隨機選擇可能各抽一次；傷害被阻止不保證 VFX 零次。ActionPlayAnimation／ActionCreateEffectAnimation／ActionPlaySound 都是 instant BaseAction，不等待媒體完結；ActionHandler 執行後仍讓出 frame，非 instant 的 time_delay 也是執行後等待。調 fps 或效果長度不會把 damage 對齊命中幀。若需等待投射物／命中幀，交 mechanics 設計可取消 action，不能順帶改 delay 或扣血位置。

目前 AttackGenerator 同時加入聲音 action 並傳 audio_path 給 Attack；Attack 又立即呼叫 generate_sound_action，因此非空值存在重複播放來源。這是待修接線，不是「每擊一次」保證。實際扣血依 Player／Enemy.damage 的 `combatant_damaged`；格擋大於傷害才發 `combatant_blocked`，剛好相等會發 `combatant_block_broken` 並回傳零傷害。需要零 HP 損失提示須覆蓋兩者，不可只聽 blocked。來源與詳細驗法交 [音效](audio/sfx.md)。

### 拒絕、取消與離場

Hand／HandManager 的拒絕 return 沒有統一拒絕信號。UI 回饋如需新增，指定一個能辨識實際拒絕原因的 owner；預覽／hover 不得播放成功或命中媒體，也不得改 energy、牌堆或戰鬥 RNG。這是驗收要求，並非現有只讀保證：KeywordContainer 直接取 card_keyword_object_ids 再 append；先記刷新前後差異，若任務修此副作用，再斷言陣列不變。

背景 button 取消目前只清 `current_selected_card` 和目標提示；右鍵先撤目標，但還可能執行 `card_right_click_actions`，不能把右鍵一概當無副作用取消。排隊退款與已執行傷害的回滾不是同一功能，沒有既定需求時不得新增。

[Root._exit_tree](../../../game/scripts/Root.gd) 清 action／interceptor；ActionHandler 以 generation 失效舊 continuation，取消 async action 並清 queue。這不會自動停止 SoundManager 已接手的聲音，也不會遍歷刪除已生成 VFX。VFX 掛在 combatant 的 ImageFadeContainer，正常靠非循環 animation_finished 釋放，父節點離樹才隨之釋放。新 listener、持續效果、音樂或環境音需另定註銷／停止 owner；參照 [VFX](art-assets/vfx.md)、[音樂](audio/music.md) 與 [生命週期](resource-lifecycle.md)。

### 素材契約與回退

把母稿／輸出版本接到穩定內容 ID 和消費欄位：卡圖是 card_texture_path，人物是 character_animation_id／enemy_animation_id，命中特效是 impact_vfx_animation_id，聲音是 audio_path。動畫交尺寸、原點、frame 順序、duration／fps、loop／next；UI 交顯示框與文字／數值安全區，音訊交格式、bus、loop、停止及無聲替代。批次同質記錄超過 1 KB 依 [資料契約](../common/data-files.md) 落資料檔，不複製到各領域文件。

外部素材交完整專案相對路徑，不能假設相對 JSON；FileLoader 的路徑快取要求在新隔離驗證程序檢查替換結果，不控制既有程序。缺圖／音訊的 MISSING fallback 只保底，不是採用成功；音訊 fallback 也不代表靜音。查實際解碼、尺寸／frame 與非 fallback 身份，勿單靠 resource_path。缺 AnimationData 時效果略過，缺軌／錯 loop 可能無法完成清理。回退應明列沿用哪個已驗資產或停用哪個純呈現接點，不能改規則值補救。

### 最小驗收與交接

交付同一可取得卡牌與 fixture，記錄正常一次、全格擋、等額破盾、多擊／多目標、不可出牌、選目標取消、預覽及離場的預期事件數和資料狀態。先以引用／檔頭／JSON／source 核對；實作時再由 runtime owner 依 [validation](validation.md) 接入專項 helper，不能直接執行聲音 action 就宣稱成功出牌鏈已驗。

只改文件時不啟動 Godot。本輪禁止 GUI、桌面／視窗／截圖／焦點／音訊與既有程序控制；未來背景音訊驗證仍先證明 Dummy 或替身無實體輸出。背景斷言只能證明事件、狀態與清理；動畫連貫、同步感、文字遮擋、聽感和真實輸入保留待授權驗收。

## 交接

整合 owner 將素材／事件契約和未驗項交給對應領域；規則或等待需求接 mechanics，獨立冷接手復走接 [agent-session](../agent-session.md)。本流程依 2026-10-19 固定上游加現有 lifecycle 修復查碼，詳細來源沿各領域分析追蹤；更換版本後重查事件序，不以本輪文件修補宣稱遊戲已修復。
