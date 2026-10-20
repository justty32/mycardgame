# 雙棋盤呈現：角色本體站在格上

[雙棋盤分析](README.md)｜[UI 流程](../../../../wf/workflows/game-dev/ui.md)

## 已確認需求

使用者於 2026-10-20 確認：「角色和敵人直接站在棋盤上，日式 RPG 回合式對戰那種感覺」。雙方對峙，實際 sprite、血條、狀態與意圖隨 `board_id + cell + footprint` 站位；一般移動、特殊卡跨盤移動與交換後，本體跟隨。只畫格內代號、人物仍留固定位置不符合需求。

使用者已授權實作與 headless 驗功能。側視／斜視、格線常顯或操作時顯示、透視、場景風格及 3D 尚未決定；以下兩盤並列的既有 2D sprites 是工程基線，不代表最終美術決定。agent 仍不得操作螢幕、鍵盤、滑鼠、視窗或 GUI。

## 歷史起點與目前接線

改動前的 BoardView 是自繪格子與文字 token，人物保留舊畫面位置。[BaseCombatant](../../../../game/scripts/combatants/BaseCombatant.gd) 是 Control，持有 AnimatedSprite2D、血條、狀態與選取元件；`tree_exiting` 會註銷單位，不能用跨盤 reparent 當作移動。

目前 [Combat](../../../../game/scripts/ui/Combat.gd) 是場景裝配入口：只有 `board_module_enabled` 與規則 `board_enabled` 同時為 true，才建立 [BoardCombatModule](../../../../game/scripts/combat/board/BoardCombatModule.gd) 子節點。模組每場建立 [BoardCombatPresentation](../../../../game/scripts/ui/BoardCombatPresentation.gd)，由它依 Battlefield 建立 `board_views`，各 [BoardView](../../../../game/scripts/ui/BoardView.gd) 帶自己的 `board_id`。真正 NONE 沒有模組與 board controller／field controller／threat preview，也沒有 BoardView、actor helper 或 Undo 按鈕；不是把棋盤藏起來仍跑其規則。Combat 的舊 `board_view`／`board_views`／`actor_presentation`／`undo_move_button` 僅為相容查詢，無呈現時回 null／空集合。[BoardActorPresentation](../../../../game/scripts/ui/BoardActorPresentation.gd) 統一管理實際 combatant 根節點的畫面位置、縮放、深度、點擊橋接與回收；[EnemyContainer](../../../../game/scripts/ui/EnemyContainer.gd) 讓棋盤敵人從生成起就位於自由定位的 Control 子層，避免 HBox 每次排版覆寫位置。玩家與敵人在普通移動、跨盤或交換時都不換父節點，保留 unit uid、控制者、血條／意圖／hitbox 子樹及動畫相對 NodePath。

## 站位、動畫與事件

每盤以自己的畫面座標轉換將 anchor／footprint 映射到占格底部中心；圖片尺寸只決定 sprite 的落腳偏移與呈現比例，不反推占格。BaseCombatant 首次 ready、註冊與播放動畫前保存 sprite 的 position 與 offset 站立值；呈現接管時搭配 idle frame 保存腳點，不把正在播放的 run-start 位移凍結成基準，攻擊／死亡改子層姿勢時不重新解讀為移動。兩盤採固定並列布局、格尺寸上限 64；角色以格尺度縮放。此配置服務功能驗證，不承諾最終視角、像素密度或可讀性。

資料位置是玩法真相。`unit_board_moved` 在成功幾何提交後、場域 leave／enter 等反應前發送；原子交換雙方已提交才送。呈現立即記下兩人的目標位置，tween 只改畫面 `global_position`，不寫 board anchor、不重播傷害。同步致死時將本體落到已提交目的地再保留死亡演出，失敗轉移不先移動畫面。跨盤畫面遠近不參與 A 的射程計算。

角色深度在格子上方、既有 modal 下方，按占格底部排序。Control 的輸入優先序不能由 `z_index` 推論；格面在場景樹中排到角色之前，使角色 hitbox 可先處理點擊。原人物按鈕 handler 在接管期間替換成單一帶盤選格事件，避免同一點擊同時走 enemy click 與 board click；退出還原原連線。

## 選格與場域操作

[Hand](../../../../game/scripts/ui/Hand.gd) 經場景提供的 [BoardCardAdapter](../../../../game/scripts/combat/board/BoardCardAdapter.gd) 把確切目標盤寫入 `CardPlayRequest.selected_board_id`，交共同 BoardTargeting policy 驗合法性。adapter 在 NONE 仍提供被動的空間效果拒絕檢查；只有模組 presentation.setup 才 bind_hand 接選格輸入，停止即 unbind，通用 Hand 不自行裝配棋盤功能。普通步行只接受當前單位所在盤，兩盤同座標不混用。卡牌預覽與敵方命中格按實際效果盤畫；SELF_AREA 留在施法者盤。時間軸條目的 hover 送入同一敵人預覽；TELEPORT 即使沒有路徑也在來源盤標示目的格，原意圖列附移動模式文字 fallback。移動高亮採 `reachable_active`，費用提示依路徑逐步計算 paid 實體步數，不能把高成本地形直接當成更多付費格。

場域格底色與角落圖示使用 FieldData 的 color／icon 引用；缺 icon 時用短名稱。hover 列出各場域名稱、堆疊與剩餘 tick，永久場域另標記；人物 hitbox 也能取得腳下場域 tooltip。新增、移除、堆疊刷新及時序變化更新顯示。`UndoMoveButton` 只在規則允許時顯示，由 Director 的共同 gate 決定可用性；按下呼叫正式撤銷入口，不由 UI 直接改位置或退還資源。

## 生命週期與驗收

新生成／波次單位依盤位置加入呈現。模組 runtime 與呈現結束分開：英雄死亡會先停止 runtime；`presentation.stop()` 停用輸入與 process，將死者 snap 到已提交的目的地，再把 actor 保存為 retired，維持死亡演出落點。因 Director 的死亡回呼早於 actor helper，這個 snap 必須在 stop 內完成，不能等待稍後的信號。

真正 combat／run 結束或場景離樹才 `clear()` 還原存活或 retired 根變換，特別是跨 run 重用的 Player，再釋放 view、Undo 與 actor helper。下一場 setup 強制清掉舊 presentation 再建立新實例；runtime 的 occupancy 清理不反推畫面位置。清理取消 tween、斷開自建訊號並解除 hand 綁定，舊回呼不能修改下一場。

[呈現回歸](../../../../tests/dual_board_presentation_cases.gd) 已接至 DualBoard 的真實 Root 起局路徑：驗 sprite 與 HP 可見狀態、落腳／viewport／祖先裁切、HUD／意圖／hitbox owner、UID 與 CTB、兩盤選格、正常／失敗轉移、交換、移動 tween 與資料分離、既有 attack 動畫、撤銷按鈕與 tooltip；獨立末組驗致死轉移／死亡動畫／退出清理及同 Root 下一 run。2026-10-20 本輪最終 All（run 尾碼 `4ebd60e5`）中的 DualBoard 已通過 394 checks／0 failures，涵蓋可選模組裝配與 stop／clear 拆分後的呈現回歸。當前範圍與證據入口見 [模組驗收矩陣](../board-module-verification.json)；既有斷言與歷史主日誌見 [驗證映射](verification.json) 與 [可攜證據](../../evidence/2026-10-20/dual-board/README.md)。

headless 的節點、座標與 handler 斷言不證明實際遮擋、動作感、字級可讀性、GPU 呈現或鍵鼠命中。這些仍待使用者人工驗；未執行 GUI 驗收，不宣稱美術完成。規劃階段估計的額外 1–2 個呈現批次屬歷史成本，原創素材、視角改造及美術打磨另計。
