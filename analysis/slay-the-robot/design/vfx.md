# 戰鬥 VFX：現成能力與機制缺口

[設計分析入口](README.md)｜[VFX 工作流](../../../wf/workflows/game-dev/art-assets/vfx.md)｜[動畫契約](animation.md)

2026-10-19 靜態追讀本機 game：上游 `4dac5abe0d19382f8ace2cec5ed3fd77e2a0e11d` 加來源鎖記錄的本地補丁。未啟動 Godot，未操作桌面／視窗／UI／截圖／焦點、未播放聲音；本文是程式能力核實與後續驗證設計，不是新 runtime、視覺或性能通過證據。

## 現有短效入口

[Scripts.gd](../../../game/autoload/Scripts.gd) 註冊 `ACTION_CREATE_EFFECT_ANIMATION`；[ActionCreateEffectAnimation](../../../game/scripts/actions/combatant_actions/ActionCreateEffectAnimation.gd) 先 `_intercept_action()`，逐一取接受的 target 與 `impact_vfx_animation_id`，呼叫 `target.create_effect_animation()`。target 為 null 時 return；空 ID 不建立。這是 `BaseAction`，`is_instant_action()` 為 true，沒有回傳效果 handle、完成等待或取消 API。

[BaseCombatant](../../../game/scripts/combatants/BaseCombatant.gd) 的 `create_effect_animation(animation_id)` 向 Global 取 AnimationData；null 直接 return；經 [Scenes](../../../game/autoload/Scenes.gd) 的 `COMBAT_EFFECT_ANIMATION` 建立 [AnimatedCombatEffect.tscn](../../../game/scenes/combatants/AnimatedCombatEffect.tscn)，加入 `image_fade_container` 後 init。scene 只有 AnimatedSprite2D 與 script，沒有 shader、particle、Camera 或自訂材質設定。

[AnimatedCombatEffect.gd](../../../game/scripts/combatants/AnimatedCombatEffect.gd) 使用 `animation_default`；offset 是 AnimationData.animation_offset 加兩軸 `randi_range(-random, random)`，不是遊戲 player RNG。`sprite_frames = animation_data.animations` 後 play；animation_finished 直接 queue_free。此 consumer 不讀 next animation，不是一般人物狀態機。

[AnimationData](../../../game/data/readonly/AnimationData.gd) 的 `add_vfx_animations()` 指定 `ANIMATION_VFX`、空 next、預設 30 fps 和 ±10 像素隨機偏移。`add_animation()` 的自比較會將 helper 當下產物設成 loop；`regenerate_animations()` 才以動畫名與 next 比較。不能只呼叫 helper 就假定短效會結束，必須查載入後 SpriteFrames；動畫流程另解釋 duration 與重新生成。Prod／Test generator 的 `add_combat_vfx_animations()`／`add_test_combat_vfx_animations()` 用 14 張 impact_default frames 建立 `animation_vfx_impact_default`，可作接線樣本，不代表全部新效果有相同尺寸或節奏。

缺 `animation_default` 時現碼只記錯、不 queue_free；直接 `init(null)` 的錯誤字串會取 null.object_id，但標準 BaseCombatant 呼叫路徑已先擋 null。未生成 `animations`、空 track、loop 不結束等也不能依正常 finished 回收契約保證處理。這些是靜態可定位風險；本任務沒有修碼或執行紅綠測試。

## 掛點與畫面層級

[Player.tscn](../../../game/scenes/combatants/Player.tscn) 與 [Enemy.tscn](../../../game/scenes/combatants/Enemy.tscn) 的 `ImageFadeContainer` 都在 `Visible/AnimatedSprite2D` 下，沒有自己的非零位置設定；sprite 的局部位置分別 `(64,48)`、`(99,128)`。特效繼承父層 canvas transform／可見性，offset 是 sprite 繪圖偏移，不是全畫面座標。沒有專用 VFX CanvasLayer 或自動對齊世界掛點；擴大畫布可能遮住 sprite 附近的血條、名稱與輸入區域。

文字使用另一個 `Visible/FadeContainer`，Player 局部位置 `(64,-96)`，Enemy `(100,-8)`。根場景已有多種 UI z_index；不能以「over combatants」註解保證特效一定在所有介面上方。新 projectile 應先選戰鬥共同 owner 再轉換兩端座標；新增全畫面層則要明定 viewport、z、遮擋與滑鼠穿透。這些是設計接點，尚無現成可填的 projectile schema。

## 出牌、傷害與效果順序

[ActionAttackGenerator](../../../game/scripts/actions/combatant_actions/ActionAttackGenerator.gd) 從 shadowed values 讀 `impact_vfx_animation_id`、`number_of_attacks`、`time_delay`、`target_override`。每擊先建立 Attack，再依條件追加 sound、人物 animation，最後追加 CreateEffectAnimation。`merge_attacks=true` 先合併傷害並將攻擊次數改成一，因此也改變短效次數。

[ActionHandler](../../../game/autoload/ActionHandler.gd) 預設 `add_actions()` 把每項放為獨立 stack queue，`_perform_actions()` 從尾端 pop。故同擊先建 VFX，再人物動畫／聲音，最後 Attack；多擊群也依後項先處理。instant action 仍 await 一個 process_frame，並非等 animation_finished；非 instant 的 time_delay 在 perform_action 後才等待。既有接口沒有逐格命中事件或「播完才扣血」。

[ActionAttack](../../../game/scripts/actions/combatant_actions/ActionAttack.gd) 另跑攔截、判目標存活，再 `target.damage()`，取得實際 unblocked／capped／overkill 數值。CreateEffectAnimation 與 Attack 是不同 action，前者被接受不代表後者接受，也不代表傷害穿透格擋。因此現成 impact 的語意較接近「攻擊接觸提示」，若要表示確實扣血應接實際結果。

[BaseAction.get_adjusted_action_targets](../../../game/scripts/actions/BaseAction.gd) 對 SELECTED_TARGETS 查 instance／存活，ALL_ENEMIES 查當下敵人群組，PARENT 直接回 parent；不能泛稱所有 target override 都同樣驗證。VFX 與 Attack 各自取目標；RANDOM_ENEMY 各經 player RNG shuffle，可能不同目標且消耗不同 RNG 次數，需專項核對，不能視為已共享一次抽選。想改成共享目標先固定契約並回歸玩法 RNG，不能把它當純換圖。

卡牌可支付與選目標發生於 [Hand](../../../game/scripts/ui/Hand.gd)／[Card](../../../game/scripts/ui/card/Card.gd) 的出牌路徑；預覽使用 `_intercept_action(..., true)` 計算結果而非 perform_action。新 VFX 不應放入 hover／意圖試算或無條件 interceptor 副作用；改動後須從真實出牌入口驗拒絕零次，不只直接呼叫效果函式。

## 格擋、傷害、狀態及其他視覺能力

[Player](../../../game/scripts/combatants/Player.gd) 與 [Enemy](../../../game/scripts/combatants/Enemy.gd) 的 `add_block(amount>0)` 呼叫 create_block_fade，並送 combatant_block_added；目前 BLOCK_TEXTURE 是 icon.svg。`damage()` 中 block 大於 damage 時送 combatant_blocked／顯示 Blocked；block 等於 damage 會走 combatant_block_broken，但 unblocked damage 為 0，不送 combatant_damaged。不能把「完全格擋」和「破盾」互斥地簡化成是否扣血；新效果需包含等值案例。真正扣血分支有 create_damage_text 與 combatant_damaged。

[ImageFade](../../../game/scripts/combatants/fades/ImageFade.gd) 搭 [ImageFade.tscn](../../../game/scenes/combatants/fades/ImageFade.tscn) 用 64×64 TextureRect 的 AnimationPlayer 做 0.5 秒淡化，mouse_filter=IGNORE；[TextFade](../../../game/scripts/combatants/fades/TextFade.gd) 搭 [TextFade.tscn](../../../game/scenes/combatants/fades/TextFade.tscn) 做向上位移及透明度變化。兩者皆於 animation_finished queue_free，沒有中央排隊或重疊避讓器。

[StatusEffect](../../../game/scripts/combatants/StatusEffect.gd) 更新可見性、charges、tooltip 與 texture；BaseCombatant 的狀態建立／移除管理圖示與 interceptor，沒有通用「狀態施加 VFX ID」欄位消費鏈。新短效可在成功狀態變更接線；持續光環需自己的註冊／刷新／移除 owner，不能由圖示存在推論環繞特效已實作。

在本機 `game` 的 `.gd/.tscn/.tres/.gdshader` 搜尋 Shader、shader、Particles、Camera2D、Camera3D、projectile、screen_shake 未見匹配；檔名也未找到 gdshader。現有 Tween 主要出現在 [LayeredHealthBar](../../../game/scripts/combatants/LayeredHealthBar.gd) 的血條與 [Hand](../../../game/scripts/ui/Hand.gd) 排牌，AnimationPlayer 也有 fade／死亡等軌道；這些是局部呈現，不是通用 projectile、粒子池、shader 後製或相機震動系統。Godot 能力不等於專案已接好，新增需另走機制與 UI。

## 取消與回收邊界

ActionHandler.clear_all_actions 清佇列、generation、timer 與 async action；不持有已生成效果，也不遍歷 ImageFadeContainer。正常短效稍後 finished 可自行回收，因此「無顯式清理」不等於已證實 leak。Enemy 在 combat_ended queue_free；Player 在 combat_ended／run_ended 清狀態與 block，未見清這兩個 fade 容器。隱藏畫面、玩家持續存在或同 frame 離場重入時是否留下短暫殘影須 runtime 驗證。

持續 VFX、未結束的 loop、缺 track 或自訂等待效果不能沿用「一定會自然結束」假設。新增時訂 owner 與最大壽命，驗結束、取消、目標離樹、戰鬥／run 結束以及 callback 晚到；若用 BaseAsyncAction 等完成，沿 [資源生命週期分析](../architecture/05_resource_lifecycle.md) 的 begin／finish／force end 契約做 exactly-once，取消後不得再生傷害或後續效果。pool、去重、容量限制目前都沒有現成管理 API。

## 專項測試接點

[tools/test-game.ps1](../../../tools/test-game.ps1) 只有 All、Dictionary、Combat、SaveLoad、Smoke、ResourceLifecycle，沒有 VFX suite。本節為後續實作的測試設計，本次未改 tests／tools、未執行引擎。既有測試只提供骨架與觀測方式，不是下列案例已存在。

在 [framework_smoke.gd](../../../tests/framework_smoke.gd) 的 singleton 就緒後 helper 接新 AnimationData：經正式 FileLoader／註冊路徑取得，斷言非 fallback、track/frame 數、fps、loop=false，並比較 helper 與 regenerate 後結果。對非法 ID、缺 track、空 frames 定義預期拒絕與無殘留，而非允許靜默永存。

以 [combat_fixture.gd](../../../tests/combat_fixture.gd) 配 [combat_flow.gd](../../../tests/combat_flow.gd) 的 `_play()`、`_reject_unaffordable_card()` 與 `_wait()` 延伸真實出牌驗證。以 instance ID／弱參照及容器 child_entered_tree 計數，記錄效果 ID、目標與效果／damage 順序；覆蓋單次、多擊／merge、ALL_ENEMIES、RANDOM_ENEMY、致死後剩餘擊、費用不足、無效目標與 damage interceptor 拒絕。採固定 fixture，避免觀察用程式先額外抽 RNG。

在 [resource_lifecycle_cases.gd](../../../tests/resource_lifecycle_cases.gd) 的 preview／rejected／timer cancel／Root teardown 骨架增加效果觀測；現有 effects 計數是測試 interceptor 的副作用，不是實際 VFX 節點。驗預覽零新增，正常播放在 deadline 前自行回收；先完成觀測再 free fixture，不能測試自己掃掉產品節點。取消案例分「尚未 spawn 零次」與「已 spawn 依約立即移除或限時結束」，另驗同 frame 生成後離戰／run 結束／Root 退出及立即重入。持續效果移除、晚到 callback 與重複取消需各自斷言。

完成上述實作後，依變更執行 `./tools/test-game.ps1 -Suite Smoke`、`-Suite Combat`、`-Suite ResourceLifecycle`，保存完成標記、退出碼與完整日誌。不能將這份未執行清單報作 pass，也不能以 ResourceLifecycle 舊結果宣稱 GPU 記憶體或 VFX 所有權已驗。

視覺驗收另需實際畫面證據：透明邊、峰值與命中對齊、最壞重疊、資訊可辨、無反覆明暗閃爍、停用強光／震動後提示仍完整。性能需記目標裝置／設定與峰值並發量測；靜態紋理估算只是預算，headless 不驗 GPU 過繪。當前操作邊界禁止 UI／截圖／GUI，以上均保留待驗，不用舊選單截圖代替戰鬥效果證據。
