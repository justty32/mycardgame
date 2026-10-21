# 動畫 — 逐格製作、人物接線與時序驗收

[美術入口](../art-assets.md)｜[核實分析與 JSON 範例](../../../../analysis/slay-the-robot/design/animation.md)｜[特效](vfx.md)｜[UI 動態與場景演出](motion/README.md)

**何時用**：製作或替換角色／敵人的 idle、attack、hit、death，調整逐格節奏，或判斷 sheet／骨骼能否接入。

**何時不用**：命中特效走特效；靜態圖走素材入口；改命中、等待或優先序走 [機制](../mechanics.md)。

程式事實（資料路徑、引擎語意、死亡雙播放器、helper 自比疑點）以頁首分析為準；來源、hash 與檔案層檢查依 [static-assets](static-assets.md)。本篇寫操作契約。

## Done when

素材與 AnimationData／人物引用檔存在，交接記錄填有尺寸、基準點、frame 順序、fps、相對 duration、next、觸發與中斷規則。所選背景檢查有目標 ID 的斷言、退出碼及日誌；文件 lint 通過（見 [testing](../../testing.md)）。未接的 hit／重播／死亡時點及未做的視覺驗收明列，不用既有 Smoke PASS 代替新動畫證據。

## 流程

### 先選真正支援的製作路徑

原生路徑只有逐張外部圖 → SpriteFrames；靜態圖可作一格動畫。sheet 先按明確格寬高、行列、padding、讀取順序與空格政策離線切成 frames 再填路徑。骨骼原檔可由授權工具離線烘成 frames，或另立機制改造載入、播放與生命週期（目前無現成契約）。現有 AnimationPlayer／Tween 是局部用法，不是通用補間入口。

### 固定畫面規格再批次製作

先寫內容 ID、朝向、顯示尺寸、共同畫布、透明背景、腳底／重心座標與留白；所有狀態同畫布、同原點，不逐格緊裁。命名如 `enemy_id_attack_000.png`，播放依陣列順序，loader 不排序；另記切片參數。

核對 Player／Enemy.tscn 的 sprite 位置、SelectionButton 與血條父子關係；圖片放大不會放大選取區。人物不消費 animation_offset，腳底優先統一畫布，節點位置交 [UI](../ui.md)。

### 狀態與時長要寫成資料契約

idle 的 next 指自己；attack 指 idle；death 指空字串。frame 清單不可空，fps／duration 採正值，每個非空 next 必須存在——生成器不驗，交付端自己守。duration 是相對權重（fps=10、[1,2,1] 共 0.4 秒），缺省值見分析。

hit 可新增為自訂 `animation_hit`，next=idle，但沒有自動觸發。若只驗素材，可顯式呼叫 play_animation；要在真實受傷時播放，先定義未格擋傷害、完全格擋、致死與多擊政策，再交機制補消費端。死亡優先於 hit／attack 是待實作政策，現有 play_animation 沒有死亡鎖或優先佇列。

### 建立最小可載入的接線

依 [第一個 mod](../content/bootstrap.md) 建候選、mod 登記與 `mod_folder_to_load_data` 映射，採分析中的完整四狀態 JSON 與角色／敵人補丁；新 animation JSON 放 `external/mods/<mod_id>/animations/`。角色用 `character_animation_id`，敵人用 `enemy_animation_id` 引用新的 object_id；`enemy_texture_path` 是圖鑑，不能替代戰鬥接線。

驗證以 mods 載完後 regenerate 的資料為準，不以 helper 的即時 SpriteFrames 為最終結果；既有 sprite 持有舊 SpriteFrames 引用，換檔驗證用新的隔離程序。

### 將攻擊畫面與傷害事件分開

`attack_animation_name`（預設 animation_attack）與 `per_attack_animation_name`（預設空，可逐擊播放）擇一，使用後者時將前者設空以免重疊。執行序、ActionPlayAnimation 為 instant、`time_delay` 是執行後等待，見 [攻擊畫面與扣血](../presentation-delivery.md#攻擊畫面命中與實際扣血)；因此 time_delay 不能延後第一擊到揮刀中點，逐格末幀也不會自動觸發傷害。

若要「預備 → 接觸格命中 → 收招」，交機制定義顯式命中事件或可取消的等待 action，且只讓規則管傷害，避免動畫重播重複扣血。命中特效接 [VFX](vfx.md)。不要為了調畫面快慢順手改 damage 或 time_delay；交接要分列畫面總長與玩法事件時間。

### 重播、切換、死亡與取消

迴圈不發 finished，同名 play 不保證重頭（見分析）。需求是每擊從頭時，在實作中明確重設並驗兩次播放，不能只追加相同 ActionPlayAnimation；連擊短於動畫長時尤其要驗。

死亡由逐格與另一個 AnimationPlayer 並行，完成 signal 來自後者（見 [分析](../../../../analysis/slay-the-robot/design/animation.md#死亡取消與離樹)）。其 .res track 未解碼；改 death 長度前需背景載入檢查它與結算的關係，不能保證長逐格播完才離場。

當前 animation action 沒有可取消等待。若新增 BaseAsyncAction，必須讓完成、取消、死亡、目標離樹與 Root 切換都能恰好一次結束；force_action_end 斷開自建 signal／timer 並禁止延遲傷害，沿 [生命週期](../resource-lifecycle.md) 的既有契約。不要只 await animation_finished：loop、被替換或目標釋放可能永遠等不到。clear_all_actions 清行動，不等於把所有 sprite 停播。

### 背景可驗與視覺未驗

先靜態驗 JSON 與序號無缺漏。接著依 bootstrap 把專屬 helper 接到既有 Smoke（[helper 接線](../ui/verification.md#把新增-helper-真正接上)），驗 Global 查得到 ID、人物持有同一 SpriteFrames、各狀態的 frame 數／fps／duration／loop／next、texture 有尺寸且非 fallback。

時序需求另加有限 timeout 的專項：attack 回 idle、連續同名播放、中途 hit／death、致死完成 signal 一次、combat 結束與離樹後無殘留等待；加入真實攻擊的 HP／格擋斷言，證明調動畫未改規則。接線後才跑 `python3 tools/test_game.py --suite Smoke`；戰鬥／取消有改動再選 Combat／ResourceLifecycle，套件入口與通過標記依 [testing](../../testing.md)。現有套件未自動覆蓋這批素材。節奏觀感、接觸格、視覺跳動與透明邊的判讀見 [證據層級](../ui/verification.md#證據層級與判讀)。

## 交接

交下一 agent：路徑、內容 ID → animation ID → 狀態、規格／時長、命中事件責任、中斷政策、命令／日誌與未驗項。下一步按 bootstrap 建候選，以交付 frames 替換分析範例，再接目標 helper；hit／命中同步未實作時不能回報四狀態接完。
