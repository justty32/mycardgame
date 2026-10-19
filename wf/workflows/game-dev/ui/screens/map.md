# 地圖畫面 — 辨認路線、選擇與返回

[UI 入口](../README.md)｜[共用元件](../components-layout.md)｜[互動契約](../interaction-states.md)｜[驗證接線](../verification.md)｜[地圖內容規則](../../level-design/map-act.md)

**何時用**：完整地圖、節點狀態與導航。**何時不用**：生成／機率／跨幕／資源節奏走內容規則；設施走 [商店與休息](shop-rest.md)。

## Done when

規格／結果檔記錄狀態來源、路線、輸入到 visit、拒絕／返回／重進及清理斷言；素材引用可解析，helper 接到 caller 並有結果，未驗項明列，文件檢查通過。

## 流程

### 先定玩家目的與整張素材包

玩家辨認目前位置、可達節點與後續風險，決定前往或返回。畫面包含幕／樓層標題、節點圖文、連線、圖例、目前／已訪／可達／不可達／隱藏狀態、捲動與 Back；標題／連線／圖例及完整狀態圖層尚需新增。

素材包含各 LOCATION_TYPES 圖示、問號、位置／已訪／鎖定／可達／選取標記、路線與背景，附顯示框和文字尺寸；不可只靠閃色。接 [介面素材](../../art-assets/interface-assets.md)、[UI 動畫](../../art-assets/ui-motion.md)、[場景演出](../../art-assets/scene-choreography.md) 與 [畫面音訊](../../audio/screen-cues.md)，勿填不存在的資料欄位。

### 真實 scene、資料與導航契約

[Root.tscn](../../../../../game/scenes/Root.tscn) 的 `RunScreen/Map` 是固定 1200×700、z_index=100 的 Control，內含 Background／Background2、BackButton、ScrollContainer/LocationContainer。ScrollContainer 使用 SmoothScroll、follow_focus=true，允許垂直捲動；不是自動排版的節點 Grid。入口 `%MapButton` 打開預覽，不會因此把 can_travel 設 true。

[Map.gd](../../../../../game/scripts/ui/Map.gd) 的 show_map→populate_locations 讀 Global.get_all_act_locations／get_next_locations，略過 STARTING，逐個實例化 [MapLocation.tscn](../../../../../game/scenes/ui/MapLocation.tscn)。[LocationData](../../../../../game/data/mutable/LocationData.gd) 提供 location_id、location_position、location_next_location_ids、location_type、location_visited／location_obfuscated。位置直接寫入 button.position；container 高度為 max_y+150。連線尚無 renderer，資料中的鄰接不會自動畫成線。

[MapLocation.gd](../../../../../game/scripts/ui/MapLocation.gd) 是 TextureButton，64×64，現用 res://icon.svg 而非各類型圖示，子節點 MapLabel 顯示 enum 名稱；隱藏且未訪問才顯示「???」。修改分類圖示應沿此 consumer 加映射與 fallback，保留遮蔽規則，不能讓圖片／tooltip 提前洩漏隱藏種類。UI 預覽只讀資料，勿呼叫 get_location_event_object_id() 抽池／消耗 RNG。

### 進場、可達與選取

正常進場重建所有節點，can_travel=true 時，下一個可達節點播放 flash_location；目前位置的定位分支被註解，沒有專用目前／已訪樣式。已訪節點只影響是否揭露類型，不能假定有灰色完成標記。can_travel=false 是查看模式，仍會建出可點按鈕，父層拒絕旅程；要顯示禁用原因／鎖定圖示需新增。

點擊即確認前往，沒有保留選取、Confirm 或撤銷。Map handler 驗 can_travel 和 Global.get_next_locations().has(location_data)，才呼叫既有拼字的 `ActionGenerator.generate_visition_location(location_id)`。[ActionVisitLocation](../../../../../game/scripts/actions/world_interaction_actions/ActionVisitLocation.gd) 不驗鄰接：改 player_location_id、清 shop、autosave、發 map_location_selected，Map 才關閉並禁止 travel。直接 action 成功不證明路線可達。

若需求改成「點選預覽→確認前往」，需新增 transient selected_id、選取外觀與 Confirm handler；送出前重新驗位置、can_travel、鄰接及一次送出。取消只清 transient 選取，不改 location_visited 或保存；確認後才做 visit。跨幕／終局判斷仍交內容規則，不由節點動畫推導。

### 空值、拒絕與返回的既有缺口

空 locations 目前產生空容器與 Back，沒有空地圖／無路可走提示；無下一位置可能是幕尾，先依內容規則判斷，不能一律當錯誤。fixture 還應涵蓋壞邊、無效 ID、位置超界與重疊；null LocationData 未有通用防護，資料驗證與 fallback 須先接上再宣稱可恢復。

重要既有問題：MapLocation._on_button_up 在發訊號前就把 location_visited 設 true；父層之後才驗 can_travel／鄰接。因此點不可達、查看模式或其他拒絕目標仍可能改 visited，重開後揭露隱藏名稱。這是靜態確認的副作用，應先寫拒絕路徑失敗測例，再把標記移到合法提交路徑或建立同等保護；本文件不修改程式。

Back 只 hide_map，既有底層畫面仍在，沒有反向 visit 或自動消耗節點。再次 MapButton 會重建；shop_opened／chest_opened／combat_ended 開 travel，戰鬥開始關 travel；dialogue_ended 且玩家存活會開 travel 並展開地圖，死亡隱藏。Rest Continue 也另設 travel。狀態責任跨畫面，不能為了讓按鈕亮起在 show_map 無條件開 travel。

### 演出、焦點與離場

AnimationPlayer 已有 `flash_map_location`：2 秒循環、self_modulate 白→藍→白，提示可達。節點 hover／拒絕／旅程音效與移動動畫尚未接線。新增成功 cue 跟已接受的 visit，不能跟原始 button_up；動畫不延後必要提交，隱藏／重建須停自建循環、tween 與音訊。

本地補丁將 layout 後捲動做成一次 process_frame callback，WeakRef 指向最後一個可達節點；它會 grab_focus，無節點才直接設定 scroll_vertical。這不等於聚焦目前位置，也不保證鍵盤順序按路線。clear_locations 與 _exit_tree 取消 pending callback。現行禁止焦點操作；背景 fixture 在排程前須以測試 adapter 截斷焦點分支，或將該檢查保留待驗，不能直接跑 show_map 後任其 grab_focus。

要支援鍵盤／手把，按互動契約定義可達節點順序、圖上方向、捲動與 Back／Confirm，補可見焦點樣式及返回原 opener；不依賴 child 順序和 follow_focus 假定已可用。實際導航與命中仍需有效授權後另驗。

### 最小 fixture 與具體接入

依 verification，建議新增 tests/ui_map_probe.gd（尚未建立），由 Smoke `_run()` 在 Root ready 後 runtime load 做節點路徑／scene／animation／素材與尺寸檢查。若需 populate/show_map，先提供上述無焦點 adapter。純讀靜態 scene 可先做，不能拿它替代導航結果。

旅程情境沿 tests/combat_flow.gd `_scenario()` 起局與 run-start option，在首次 map ready、戰鬥選取前插獨立 probe，或交 runner owner 建專項。固定 seed，配置 STARTING、兩個可達分支、不可達／隱藏節點及終點，驗 ID／邊／event 有效。資料設定與玩家操作分開；勿直接 emit map_location_selected 假造走訪。

查每個節點的 position／label／flash animation、STARTING 不顯示、container 高度與空圖出口。讀取與重建前後記 RNG／事件池，證明預覽未抽事件。查看模式與不可達點擊經真實 MapLocation.button_up，應不改 player_location_id、shop、存檔與 visited；目前 visited 問題明列預期失敗，不能默默放寬斷言。

合法點擊後有界等待 action idle，驗 location_id、visited、shop 清除、訊號恰一次及 Map 關閉；連點、Back／重開與幕尾另列。測 populate 後同 frame 重建／釋放，確認舊節點 queue_free、pending callback 取消且不指向新 scene。若改 travel 時序，補 combat／dialogue／shop／rest 返回情境。新增 suite 要同步 runner 的 ValidateSet、分支、mapping、PASS marker／manifest；現有 Combat 單條路徑不是全圖驗收。

## 交接

交付圖不變條件、ID／邊、圖示／狀態／連線素材及 fixture caller。依 2026-10-19 固定上游加本地補丁靜態查核；runtime／視覺／實際輸入／聽感未驗。
