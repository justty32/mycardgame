# 動畫 — 逐格製作、人物接線與時序驗收

[美術入口](../art-assets.md)｜[分析與 JSON](../../../../analysis/slay-the-robot/design/animation.md)｜[特效](vfx.md)｜[UI 動態與場景演出](motion/README.md)

**何時用**：製作或替換角色／敵人的 idle、attack、hit、death，調整逐格節奏，或判斷 sheet／骨骼能否接入。

**何時不用**：命中特效走特效；靜態圖走素材入口；改命中、等待或優先序走 [機制](../mechanics.md)。

## Done when

素材與 AnimationData／人物引用檔存在，交接記錄填有尺寸、基準點、frame 順序、fps、相對 duration、next、觸發與中斷規則。所選背景檢查有目標 ID 的斷言、退出碼及日誌；文件 lint 通過（見 [testing](../../testing.md)）。未接的 hit／重播／死亡時點及未做的視覺驗收明列，不用既有 Smoke PASS 代替新動畫證據。

## 流程

### 先選真正支援的製作路徑

先核對 [來源鎖](../../../../tools/upstream.json) 與分析所列實碼；基準為 2026-10-19、4dac5abe 加本地修復。原生路徑是逐張外部圖 → FileLoader → SpriteFrames → AnimatedSprite2D；靜態圖可作一格動畫。

sheet 必須先按明確格寬高、行列、padding、讀取順序與空格政策離線切成 frames，再填逐張路徑。現有場景的 missing_texture 使用 AtlasTexture，不代表 AnimationData 有自動切片欄位。骨骼原檔不能直接填 frame 路徑；可由授權工具離線烘成 frames，或另立機制改造接載入、播放與生命週期，後者目前沒有現成契約。

AnimationPlayer 已用在人物 run_start／death，與逐格並行，不由 AnimationData 定義 tracks。Tween 已用於血條，沒有通用「動畫 ID 補間人物」入口。Godot 能力不等於框架已接。

### 固定畫面規格再批次製作

先寫內容 ID、朝向、顯示尺寸、共同畫布、透明背景、腳底／重心座標與留白；所有狀態同畫布、同原點，不逐格緊裁。命名如 `enemy_id_attack_000.png`，播放依陣列順序，loader 不排序。原始素材、切片參數、授權與輸出沿素材入口記錄。

核對 Player／Enemy.tscn 的 AnimatedSprite2D 位置、SelectionButton 與血條父子關係；圖片放大不會放大選取區。人物不消費 AnimationData.animation_offset；腳底優先統一畫布，節點位置交 [UI](../ui.md)，不照搬 VFX offset。腳底、輪廓與文字遮擋需要視覺驗收，需要 GUI 而未執行時列待驗。

### 狀態與時長要寫成資料契約

idle 的 next 指自己；attack 指 idle；death 指空字串。缺省 next 是自己，會循環；空字串停最後一格。frame 清單不可空，fps／duration 採正值，每個非空 next 必須存在。`animation_frame_durations` 是相對權重：速度 1 時單格秒數為 duration / fps，缺項補 1.0；例如 fps=10、[1,2,1] 共 0.4 秒。`animation_speed_scale` 只出現在註解，生成器不讀它。API 依據見核實分析。

hit 可新增為自訂 `animation_hit`，next=idle，但標準常數與 damage() 沒有自動觸發。若只驗素材，可顯式呼叫 play_animation；要在真實受傷時播放，先定義未格擋傷害、完全格擋、致死與多擊政策，再交機制補消費端。死亡優先於 hit／attack 是待實作政策，現有 play_animation 沒有死亡鎖或優先佇列。

### 建立最小可載入的接線

依 [第一個 mod](../content/bootstrap.md) 建候選與 mod 登記，採分析中的完整四狀態 JSON。將新 animation JSON 放 `external/mods/<mod_id>/animations/`；mod_info 的 `mod_folder_to_load_data` 明列該完整路徑 → `AnimationData`／`_id_to_animation_data`。角色補丁資料夾映射 `CharacterData`／`_id_to_character_data`；敵人則 `EnemyData`／`_id_to_enemy_data`。路徑相對 game 根，保留 properties／patch_data 包裝。

角色用 `character_animation_id`，敵人用 `enemy_animation_id` 引用新的 object_id；`enemy_texture_path` 是圖鑑，不能替代戰鬥接線。既有來源例是 character_red → animation_character_red，以及 enemy_1 → animation_enemy_1；新增 mod 必須列入 mod_list enabled，單放檔案不會啟用。

FileLoader 在 mods 載完後 regenerate 全部動畫。`add_animation()` helper 當下 loop 比較有自比疑點，不能把它的即時 SpriteFrames 當最終結果；應驗經 regenerate 的資料。重新生成會換 SpriteFrames 物件，既有 sprite 持有的舊引用不會因換檔自動替換；圖片也有完整路徑快取。用新建隔離程序驗載入，不重載既有使用者程序。

### 將攻擊畫面與傷害事件分開

ActionAttackGenerator 的 `attack_animation_name` 預設 animation_attack，播放一次後產生傷害 actions；`per_attack_animation_name` 預設空，可逐擊播放，使用時將前者設空以免重疊。ActionPlayAnimation 是 instant BaseAction，沒有 await。ActionHandler 的 `time_delay` 是執行 action **之後**的間隔，不能拿來延後第一擊到揮刀中點；逐格末幀也不會自動觸發傷害。

若要「預備 → 接觸格命中 → 收招」，交機制定義顯式命中事件或可取消的等待 action，且只讓規則管傷害，避免動畫重播重複扣血。命中特效接 [VFX](vfx.md)。不要為了調畫面快慢順手改 damage 或 time_delay；交接要分列畫面總長與玩法事件時間。

### 重播、切換、死亡與取消

BaseCombatant 在 animation_finished 查當前狀態的 next 並播放；迴圈不發 finished。同名 play 不是可靠的重頭契約，既有 wrapper 不重設 frame／progress；連擊短於動畫長時尤其要驗。若需求是每擊從頭，需在實作中明確重設並驗兩次播放，不能只追加相同 ActionPlayAnimation。中途切到別名會換狀態，不保證舊動畫走到 finished。

死亡同時啟動逐格 animation_death 與另一個 AnimationPlayer。Player 有「animation_player 沒在播」的 guard；Enemy 用獨立 death_animation_player。死亡完成 signal 由 `_on_death_animtation_finished()` 回呼發出，不是 BaseCombatant 的逐格 finished。二進位 .res 的實際 method track／時點尚未解碼；改 death 長度前需背景載入檢查它與結算的關係，不能保證長逐格播完才離場。

當前 animation action 沒有可取消等待。若新增 BaseAsyncAction，必須讓完成、取消、死亡、目標離樹與 Root 切換都能恰好一次結束；force_action_end 斷開自建 signal／timer 並禁止延遲傷害，沿 [生命週期](../resource-lifecycle.md) 的既有契約。不要只 await animation_finished：loop、被替換或目標釋放可能永遠等不到。clear_all_actions 清行動，不等於把所有 sprite 停播。

### 背景可驗與視覺未驗

先靜態驗 JSON、路徑與大小寫、圖片可解碼、尺寸／alpha、序號無缺漏。接著依 bootstrap 把專屬 helper 接到既有 Smoke，驗 Global 查得到 ID、人物持有同一 SpriteFrames、各狀態的 frame 數／fps／duration／loop／next、texture 有尺寸且非 fallback。僅新增 helper 而沒有入口呼叫不算測試。

時序需求另加有限 timeout 的專項：attack 回 idle、連續同名播放、中途 hit／death、致死完成 signal 一次、combat 結束與離樹後無殘留等待；加入真實攻擊的 HP／格擋斷言，證明調動畫未改規則。接線後才跑 `python3 tools/test_game.py --suite Smoke`；戰鬥／取消有改動再選 Combat／ResourceLifecycle，套件入口與通過標記依 [testing](../../testing.md)。現有套件未自動覆蓋這批素材。

背景不驗節奏觀感、接觸格、視覺跳動、透明邊或 viewport；這些視覺項需要 GUI，未執行時保留未驗。

## 交接

交下一 agent：路徑／hash、內容 ID → animation ID → 狀態、規格／時長、命中事件責任、中斷政策、命令／日誌與未驗項。下一步按 bootstrap 建候選，以交付 frames 替換分析範例，再接目標 helper；hit／命中同步未實作時不能回報四狀態接完。
