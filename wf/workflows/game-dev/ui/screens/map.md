# 地圖畫面 — 辨認路線、選擇與返回

[場景目錄](README.md)｜[UI 入口](../../ui.md)｜[共用元件](../components-layout.md)｜[互動契約](../interaction-states.md)｜[驗證接線](../verification.md)｜[地圖內容規則](../../level-design/map-act.md)

**何時用**：完整地圖畫面、節點狀態與導航。

**何時不用**：地圖生成／機率／跨幕／資源節奏走 [地圖內容規則](../../level-design/map-act.md)；設施畫面走 [商店](shop-rest.md) 或 [休息服務](rest-services.md)；測試接法見 [地圖 fixture](map-fixture.md)。

## Done when

- 規格／結果檔記錄狀態來源、路線、從輸入到 visit 的鏈，以及拒絕／返回／重進與清理的斷言。
- 素材引用可解析；[地圖 fixture](map-fixture.md) 的 helper 已接到 caller 並有結果，未驗項明列。
- 文件 lint 通過（見 [testing](../../../testing.md)）。

## 流程

### 先定玩家目的與整張素材包

玩家要辨認目前位置、可達節點與後續風險，再決定前往或返回。完整畫面包含幕／樓層標題、節點圖文、連線、圖例、目前／已訪／可達／不可達／隱藏狀態、捲動與 Back；其中標題、連線、圖例及完整的狀態圖層目前都還沒有，需要新增。

素材包含各 LOCATION_TYPES 的圖示、問號、位置／已訪／鎖定／可達／選取標記、路線與背景，並附上顯示框和文字尺寸；狀態不可只靠閃色區分。圖像接 [介面素材](../../art-assets/interface-assets.md)，動態接 [獎勵與地圖動態](../../art-assets/motion/rewards-map.md)，聲音接 [畫面音訊](../../audio/screen-cues.md)；不要填寫不存在的資料欄位。

### 真實 scene、資料與導航契約

[Root.tscn](../../../../../game/scenes/Root.tscn) 的 `RunScreen/Map` 是固定 1200×700、z_index=100 的 Control，內含 Background／Background2、BackButton、ScrollContainer/LocationContainer。ScrollContainer 使用 SmoothScroll、follow_focus=true，允許垂直捲動；它不是會自動排版節點的 Grid。入口 `%MapButton` 只打開預覽，不會因此把 can_travel 設為 true。

[Map.gd](../../../../../game/scripts/ui/Map.gd) 的 show_map→populate_locations 讀 Global.get_all_act_locations／get_next_locations，略過 STARTING，逐個實例化 [MapLocation.tscn](../../../../../game/scenes/ui/MapLocation.tscn)。[LocationData](../../../../../game/data/mutable/LocationData.gd) 提供 location_id、location_position、location_next_location_ids、location_type、location_visited／location_obfuscated。節點位置直接寫入 button.position，container 高度為 max_y+150。連線還沒有 renderer，資料中的鄰接關係不會自動畫成線。

[MapLocation.gd](../../../../../game/scripts/ui/MapLocation.gd) 是 64×64 的 TextureButton，目前用 res://icon.svg 而不是各類型圖示，子節點 MapLabel 顯示 enum 名稱；只有隱藏且未訪問時才顯示「???」。修改分類圖示應沿這個 consumer 加映射與 fallback，並保留遮蔽規則，不能讓圖片或 tooltip 提前洩漏隱藏的種類。UI 預覽只讀資料，不要呼叫 get_location_event_object_id()，以免抽事件池、消耗 RNG。

### 進場、可達與選取

正常進場會重建所有節點；can_travel=true 時，下一個可達節點播放 flash_location。定位到目前位置的分支被註解掉了，因此沒有專用的「目前／已訪」樣式。已訪節點只影響是否揭露類型，不能假定有灰色的完成標記。can_travel=false 是查看模式：仍會建出可點的按鈕，由父層拒絕旅程；要顯示禁用原因或鎖定圖示需要新增。

點擊即確認前往，沒有保留選取、Confirm 或撤銷。Map 的 handler 先驗 can_travel 和 Global.get_next_locations().has(location_data)，才呼叫既有拼字的 `ActionGenerator.generate_visition_location(location_id)`。[ActionVisitLocation](../../../../../game/scripts/actions/world_interaction_actions/ActionVisitLocation.gd) 本身不驗鄰接：它改 player_location_id、清 shop、autosave、發 map_location_selected，Map 收到後才關閉並禁止 travel。因此直接執行 action 成功不證明路線可達。

若需求改成「點選預覽→確認前往」，需新增 transient 的 selected_id、選取外觀與 Confirm handler；送出前重新驗證位置、can_travel、鄰接，並保證只送出一次。取消只清掉 transient 選取，不改 location_visited，也不存檔；確認後才做 visit。跨幕／終局判斷仍交內容規則，不由節點動畫推導。

### 空值、拒絕與返回的既有缺口

空的 locations 目前只產生空容器與 Back，沒有「空地圖」或「無路可走」的提示；沒有下一個位置可能只是幕尾，要先依內容規則判斷，不能一律當成錯誤。fixture 還應涵蓋壞邊、無效 ID、位置超界與重疊；null LocationData 沒有通用防護，資料驗證與 fallback 要先接上，才能宣稱可恢復。

重要的既有問題：MapLocation._on_button_up 在發訊號**之前**就把 location_visited 設為 true，父層之後才驗 can_travel／鄰接。因此點擊不可達節點、在查看模式點擊或其他被拒絕的目標，仍可能把 visited 改掉，重開地圖後揭露隱藏名稱。這是靜態確認的副作用，應先寫拒絕路徑的失敗測例，再把標記移到合法提交路徑或建立同等保護。

Back 只呼叫 hide_map，底層既有畫面仍在，不會反向 visit 或自動消耗節點。再次按 MapButton 會重建。travel 的開關分散在各畫面：shop_opened／chest_opened／combat_ended 開啟，戰鬥開始關閉；dialogue_ended 且玩家存活時開啟並展開地圖，玩家死亡則隱藏；休息的 Continue 也另外設定 travel。狀態責任跨畫面，不能為了讓按鈕亮起而在 show_map 裡無條件開 travel。

### 演出、焦點與離場

AnimationPlayer 已有 `flash_map_location`：2 秒循環，self_modulate 白→藍→白，用來提示可達。節點 hover、拒絕、旅程音效與移動動畫都尚未接線。新增的成功 cue 要跟隨已被接受的 visit，不能跟原始 button_up；動畫不得延後必要的提交，隱藏或重建時要停掉自建的循環、tween 與音訊。

本地補丁把 layout 後的捲動做成一次 process_frame callback，以 WeakRef 指向最後一個可達節點；它會 grab_focus，沒有節點時才直接設定 scroll_vertical。這不等於聚焦目前位置，也不保證鍵盤順序沿著路線。clear_locations 與 _exit_tree 會取消 pending callback。背景 fixture 不得操作真實焦點：排程前須以測試 adapter 截斷焦點分支，或把該檢查保留待驗；不能直接跑 show_map 後任它 grab_focus。

要支援鍵盤／手把，依 [互動契約](../interaction-states.md#新-modal-與鍵盤手把) 定義可達節點順序、圖上方向、捲動與 Back／Confirm，補上可見的焦點樣式及返回原 opener 的行為；不能依賴 child 順序和 follow_focus 就假定已可用。實際導航與命中另列未驗。

## 交接

交付圖的不變條件、ID／邊、圖示／狀態／連線素材，以及 [地圖 fixture](map-fixture.md) 的 caller。依 2026-10-19 固定上游加本地補丁靜態查核；runtime／視覺／實際輸入／聽感未驗。
