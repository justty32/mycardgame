# 動畫：人物逐格、UI 動態與場景演出

[設計入口](README.md)｜[人物動畫](../../../wf/workflows/game-dev/art-assets/animation.md)｜[UI 動態與場景編排](../../../wf/workflows/game-dev/art-assets/motion/README.md)｜[呈現](presentation.md)｜[VFX](vfx.md)

2026-10-19 靜態核實：上游及本機 game HEAD 為 `4dac5abe0d19382f8ace2cec5ed3fd77e2a0e11d`，ActionHandler 等已有本地修復，依 [來源鎖](../../../tools/upstream.json)。這輪沒有啟動 Godot、修改遊戲、生成素材或做視覺驗收。

## 已有資料路徑

[Global](../../../game/autoload/Global.gd) SCHEMA 將 AnimationData 映射到 `_id_to_animation_data`，基礎資料夾為 animations/。啟動先 generate_test_data，再 FileLoader.load_read_only_data 載 mods，最後 generate_all_animations。原生範例主要由 [GlobalTestDataGenerator](../../../game/autoload/GlobalTestDataGenerator.gd) 產生；不能因 external/data 沒有對應動畫 JSON 就斷言不存在。

[AnimationData](../../../game/data/readonly/AnimationData.gd) 實作是 SpriteFrames，檔首 AnimatedTexture 註解已過時。`regenerate_animations()` 對 `_animation_data` 每個狀態讀 frame 路徑、duration、fps、next，經 [FileLoader.load_texture](../../../game/autoload/FileLoader.gd) 逐張載入。它沒有 sheet 的 region／columns，也沒有骨骼資料解析。場景的 AtlasTexture 僅是 missing_texture 預設片段，不能證明資料 loader 支援 sheet 切格。

人物以 [Player](../../../game/scripts/combatants/Player.gd).get_animation_data → CharacterData.character_animation_id、[Enemy](../../../game/scripts/combatants/Enemy.gd).get_animation_data → EnemyData.enemy_animation_id 取得資料。reset_player／Enemy.init 將生成的 SpriteFrames 賦給 AnimatedSprite2D 並播 animation_idle。[EnemyData](../../../game/data/prototype/EnemyData.gd).add_standard_animations 用 `animation_` 加 object_id 產生 ID，因此 enemy_1 對應 animation_enemy_1；character_red 對應 animation_character_red。

BaseCombatant.play_animation 直接呼叫 sprite.play；play_next_animation 在 finished 查目前狀態的 next。只有 idle、attack、death 標準常數；`animation_hit` 並無內建自動觸發。Player／Enemy.damage 發 combatant_damaged、傷害文字與血條更新，但不播放 hit。AnimationData.animation_offset 不是人物位置契約；它由 AnimatedCombatEffect 使用，詳 VFX。

## 資產與引擎語意

單格 duration 是相對權重，非秒；正常播放速度 1 時，總秒數為 sum(duration)/fps。缺 duration 補 1.0，缺 fps 為 5；next 缺省為自身，空字串不接續，相同名稱設 loop，其他名稱在 finished 後切換。生成器沒有驗空 frames／非法速度／不存在 next，也不讀註解裡的 animation_speed_scale。依 [Godot 4.6 SpriteFrames](https://docs.godotengine.org/en/4.6/classes/class_spriteframes.html)，add_frame 的 duration 是相對值。

依 [Godot 4.6 AnimatedSprite2D](https://docs.godotengine.org/en/4.6/classes/class_animatedsprite2d.html)，loop 不發 animation_finished；同名 play 可恢復暫停，沒有保證每次重頭。切換 animation 名稱會重設 frame／progress，stop 則重設播放位置。現有 wrapper 不額外管理重播、優先序或取消，因此「每擊重新播放」需要明確實作及驗收。

`add_animation()` 的 loop 條件是參數和自身比較，當下永遠設 true；`regenerate_animations()` 比較當前名稱與 next，會重建正確 loop。前者是靜態缺陷線索，這輪未執行重現／修復。helper 產物與啟動後最終資源不可混為一談。

## 最小 JSON 接線範例

下例使用已存在的紅角色圖示範四個狀態的載入結構，**只有單格佔位圖，不是完成的四套動畫，也未在本輪實跑**。候選檔為 `game/external/mods/media_probe/animations/animation_media_probe.json`；新 ID 為本例示意 ID。正式素材換成完整的 frame 陣列，等長 duration 陣列與實際 fps。

```json
{
  "patch_data": {},
  "properties": {
    "object_id": "animation_media_probe",
    "_animation_data": {
      "animation_idle": {
        "animation_texture_file_paths": ["external/sprites/characters/character_red/character_red.png"],
        "animation_frame_durations": [1.0],
        "animation_fps": 5.0,
        "animation_next_animation_name": "animation_idle"
      },
      "animation_attack": {
        "animation_texture_file_paths": ["external/sprites/characters/character_red/character_red.png"],
        "animation_frame_durations": [1.0],
        "animation_fps": 10.0,
        "animation_next_animation_name": "animation_idle"
      },
      "animation_hit": {
        "animation_texture_file_paths": ["external/sprites/characters/character_red/character_red.png"],
        "animation_frame_durations": [1.0],
        "animation_fps": 10.0,
        "animation_next_animation_name": "animation_idle"
      },
      "animation_death": {
        "animation_texture_file_paths": ["external/sprites/characters/character_red/character_red.png"],
        "animation_frame_durations": [1.0],
        "animation_fps": 5.0,
        "animation_next_animation_name": ""
      }
    }
  }
}
```

mod_info.properties.mod_folder_to_load_data 新增 `"external/mods/media_probe/animations/": {"class_name":"AnimationData","table_name":"_id_to_animation_data"}`。同一 mod 的 characters/ 映射 CharacterData／_id_to_character_data；其 character_red.json 可使用以下補丁。這是部分 mod_info 配置，完整 mod、mod_list 登記與候選隔離依 [bootstrap](../../../wf/workflows/game-dev/content/bootstrap.md)，不要只放 animations 檔。

```json
{"patch_data":{},"properties":{"object_id":"character_red","character_animation_id":"animation_media_probe"}}
```

敵人改為 enemies/ → EnemyData／_id_to_enemy_data，補丁 object_id=enemy_1、enemy_animation_id=animation_media_probe；實際美術應使用敵人的 frames。enemy_texture_path 供圖鑑使用，與戰鬥 sprite 分開。來源例的三個標準狀態共用同一張 PNG，並不能證明多格對齊、hit 或死亡節奏已驗。

## Action 不以逐格結束為命中時點

[ActionPlayAnimation](../../../game/scripts/actions/combatant_actions/ActionPlayAnimation.gd) 繼承 BaseAction 且 is_instant_action=true，只播放、不等待完成。[ActionAttackGenerator](../../../game/scripts/actions/combatant_actions/ActionAttackGenerator.gd) 先播 attack_animation_name（預設 animation_attack），再產生多個 ActionAttack。per_attack_animation_name 預設空；指定時額外產生對 parent 的播放 action，與單次 attack 應擇一。

[ActionHandler](../../../game/autoload/ActionHandler.gd) 預設把 action 陣列逐項推到 stack，再 pop_back；因此生成組合的實際次序要反向讀。每擊若都有資料，先 impact VFX，再 per-attack 播放，再聲音，再傷害；instant action 仍讓出 process_frame，並非所有事件同一個引擎 frame。ActionAttack.perform_action 中 target.damage 才扣血；time_delay 在 action 之後才等。調 fps 不會同步移動扣血到指定接觸格。

ActionAttackGenerator 還填了 attack_anim_name 到 ActionAttack values，但後者不消費此鍵；不要把它當另一個動畫接點。新增接觸格事件或等待 action 必須另做機制變更，驗取消後不扣血、preview 不產生副作用、重播不重複命中。

## 死亡、取消與離樹

Player.play_death_animation 只有在共用 animation_player 沒在播時才啟動 animation_death、Player/death 並發 player_killed；此 guard 可能受其他 AnimationPlayer 動畫影響，具體情境未實跑。Enemy.damage 則在 HP 仍為 0 時，啟動 animation_death 和獨立 Enemy/death，移除 enemies group，再發 enemy_killed。普通 play_animation 不阻止後續 hit／attack 覆寫死亡 sprite。

兩者的 `_on_death_animtation_finished()` 發死亡完成 signal，註解標明由 animation player 呼叫；BaseCombatant 的逐格 finished 只做 next，沒有發這些死亡 signal。[Player.tscn](../../../game/scenes/combatants/Player.tscn)／[Enemy.tscn](../../../game/scenes/combatants/Enemy.tscn) 引用的 [Player.res](../../../game/animations/Player.res)／[Enemy.res](../../../game/animations/Enemy.res) 是壓縮二進位，本輪沒有解碼 method track 與時間。不能據註解宣稱已驗 track、時長或回呼次數；後續應在隔離背景資源檢查列出 animation names、length、method keys，再驗實際 signal 次數。

[Combat](../../../game/scripts/ui/Combat.gd) 收 enemy_death_animation_finished 後判斷非 minion 是否耗盡，必要時等 actions_ended 再 end_combat；Enemy 在 combat_ended queue_free。[RunSummaryOverlay](../../../game/scripts/ui/RunSummaryOverlay.gd) 收 player_death_animation_finished 顯示敗北。因此死亡逐格長度與結算不能假定自動一致。

[BaseAsyncAction](../../../game/scripts/actions/BaseAsyncAction.gd) 具有 begin／finish／force_action_end 與 idempotent 完成；ActionHandler 對 player_killed／run_ended 清行動，Root._exit_tree 也清行動與攔截器，combat_ended 只依短路政策清當前 async。這保護行動等待，不是動畫狀態機；自訂等待動畫若不處理被替換、loop 或目標離樹，仍可懸掛。現有 AnimationPlayer／血條 Tween 的使用不能推導出 JSON 通用補間或骨骼整合。

## 完整用途的 UI 與場景演出

2026-10-19 追加作者靜態盤點，非 fresh agent 盲測。[Hand](../../../game/scripts/ui/Hand.gd).tween_hand 對各 Card.Pivot position／rotation 各建 0.2 秒 Tween，hover 則直接設 Card.position.y 和 z_index；沒有保存 tween 引用供重排取消。[Card.tscn](../../../game/scenes/ui/card/Card.tscn) 有 card_hover／card_unhover 資源，但 [Card.gd](../../../game/scripts/ui/card/Card.gd) 未呼叫其 AnimationPlayer.play。抽牌由 HandManager 建UI後排手，出牌／棄牌／消耗用 CardTrail 後 queue_free 原 Card，升級只刷新顯示，不能稱已有卡背飛行／翻面／升級演出。

[CardTrail](../../../game/scripts/ui/card/CardTrail.gd) 是每 frame 推進的 Line2D；init 中同名參數的自指賦值、combat_ended handler 未在 _ready 接線為靜態疑點，未 runtime 重現或修復。新演出需明確持有唯讀視覺副本，不能等已被釋放的原Card完成。

[Root.tscn](../../../game/scenes/Root.tscn) 的 CombatAnimation 與人物逐格不同：start_turn 的 method key 在1秒呼叫開始回合，end_turn 在0.5秒發回合結束；它還管 TurnOverlay 與 EndTurnButton.disabled。改速度／跳過／減少動態需保住這些玩法責任，不能套用「動畫純視覺」假設。（2026-10-19 Phase 1 本地改動後：兩段動畫的流程 callback 與 EndTurnButton 解鎖軌已移除，改由 [CombatDirector](../../../game/scripts/combat/CombatDirector.gd) 播放並 await animation_finished；時長仍直接決定主角行動節奏，以上為上游原貌。）

[DialogueOverlay](../../../game/scripts/ui/DialogueOverlay.gd)、[ShopOverlay](../../../game/scripts/ui/ShopOverlay.gd)、[RewardOverlay](../../../game/scripts/ui/RewardOverlay.gd) 目前沒有各自 Tween／AnimationPlayer 序列，以立即填資料／顯示／清子項為主。對話名稱屬整體Dialogue，提示圖不是speaker頭像欄位，沒有逐字；商店purchased在庫存移除與後續取得／扣款actions排入後發出，UI等actions_ended重建；獎勵草稿則需選牌完成，不能用獎勵按鈕點擊當取得結果。新增演出應以用途控制器銜接這些不同階段。

[MapLocation.tscn](../../../game/scenes/ui/MapLocation.tscn) 可讀到2秒loop的self_modulate白→藍→白，Map確實對可走節點呼叫flash_location；沒有路徑旅行marker。MapLocation按鈕先設visited，再由Map驗can_travel與鄰接；這個欄位不能單獨作旅行成功cue。Map的weakref／一次frame捲動取消不包含未來新增Tween。

[BaseMenu](../../../game/scripts/ui/menus/BaseMenu.gd) intro/outro hooks預設null，其他menu腳本未覆寫；導航先clear_menu再outro，不能只補fade就假定離場內容仍可見。NewRunMenu與RunSummaryOverlay是立即更新資料／顯示，沒有選角立繪淡化或統計遞增。[UserSettingsData](../../../game/data/mutable/UserSettingsData.gd) 沒有減少動態欄位。以上新用途的輸入鎖、代次取消、還原與專項契約已分至UI動態／場景編排，均未在本輪實作或執行。

新增Tween契約依 [Godot 4.6官方文件](https://docs.godotengine.org/en/4.6/classes/class_tween.html)：一個屬性避免多Tween競爭、保存引用可kill中斷、重播建立新Tween。這只確認引擎API，不證明現有控制器已具這些保護。

## 休息服務與非 Draft 牌庫選牌

首次獨立復走在 D2／E3 判交接 HOLD 後追加靜態核實；修補操作見 [休息與牌庫選牌](../../../wf/workflows/game-dev/art-assets/motion/rest-selection.md)。這是文件補齊，以下保護未在 runtime 實作。[RestOverlay](../../../game/scripts/ui/RestOverlay.gd) 的三欄服務 Grid 只建文字 RestActionButton；後者未讀 rest_action_texture_path，沒有圖示／說明消費端及 Tween／AnimationPlayer。進 REST_SITE 重建、validate；服務 handler 只擋 actions_being_performed，未重驗 disabled／validator。

rest_action_rest 是 EXCLUSIVE、auto_end 預設 true，治療後執行 RestActionEnd。rest_action_upgrade_card 是 INCLUSIVE_REPEATABLE、rest_action_remove_cards 是 INCLUSIVE，兩者 auto_end=false；required 選牌成功後 child 先升級／移除再結束，Back 清空則不生成 child。rest_action_ended 使 INCLUSIVE 排除自身、EXCLUSIVE 排除所有同類並重驗按鈕；excluded 只在實例，重建會清掉，不能宣稱跨重進保存已用狀態。Continue 沒等待鎖，換點先 clear dictionary，舊 ended handler 卻直接索引；新增演出須核對 location、generation、鍵與節點，且處理本地尚無的 run_end／死亡收尾。

[CardSelectionOverlay](../../../game/scripts/ui/CardSelectionOverlay.gd) 與 Draft 不同：五欄 Grid 的 Card 以 init(data,0,false,true) 接 UI，不接戰鬥刷新，hover handlers 為 pass。SELECT 暫選／反選寫 picked_cards 與 CardGlow，Confirm 可見性依足額；Confirm handler 未重驗，quick_pick 在點牌 handler 尾端直接提交，不能推論每次都是合法新增。Back 清空再發同一 card_pick_confirmed，是否可 Back 只控制可見；一般非 required 或 min=0 不保證取消後無 child，休息範例 min≥1、required=true 才有此保證。

ActionBasePickCards 的不足 required、恰 min、部分非 required／random 分支可不開 UI 就完成；force_action_end 也會以 confirmed 解除等待，故該 signal 不是成功事件。ActionPickCards 生成 child 即 finish_async，opener 應等 actions_ended 並核對效果，不能先播升級成功。VIEW 的四個牌堆只供展示，抽牌為洗亂副本；正常 Back 只 hide，不發選牌提交。現況沒有 opener 返回管理；run_end 只 hide／清 current_action、不清卡，須另做 wrapper、timer、提示與子項清理。Grid 擁有布局、UI 擁有 glow，新增演出只寫內層 alpha／scale。

另核實 DialogueOverlay 在致死 action 的 await 返回後仍會 end_dialogue／dialogue_ended；正常閉幕需生存、generation 與原因判斷，不可單聽 signal 當成功。以上 fixture、cue、取消與減少動態契約已補葉篇；原首次審查不覆寫，修補結果另記，仍待 reviewer 復走及後續實作驗證。

## 驗證界線

本輪證據是實碼與官方 4.6 API；JSON 範例可做語法與已存在路徑靜態檢查，未證實它已由 mod loader 載入。素材真實外觀、多格播放、連擊重播、hit 自動接線、死亡 library tracks、取消／離樹的新專項與匯出全屬未驗。既有 Combat／ResourceLifecycle 通過不能替代這些目標斷言；可操作接入方式與交接要求見動畫工作流。
