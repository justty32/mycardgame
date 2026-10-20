# 雙棋盤 A：已核實契約與擴充接點

[設計分析](../README.md)｜[呈現](presentation.md)｜[驗證映射](verification.json)｜[場域與控制區](../../architecture/07_fields_zoc.md)

2026-10-20：本輪雙棋盤 A、本體站格與完整 Phase 2b 已通過隔離 All；來源與各 suite 原始日誌的可攜副本見 [執行證據](../../evidence/2026-10-20/dual-board/README.md)。本頁記實作契約，操作流程留在 [fields-zoc](../../../../wf/workflows/game-dev/fields-zoc.md)。headless 不代表 GUI、鍵鼠、GPU 或最終美術驗收。

## 位置、陣營與戰鬥

`BoardPosition(board_id, cell)` 是位置，`CombatBattlefield` 持有兩個獨立 BoardData。正常新局的 CombatRulesData 預設 DUAL，舊單盤回歸明確指定 SINGLE；Encounter 可覆寫模式，各盤各有 size、blocked/deploy/spawn cells 與 initial_fields。party／enemy 是初始配置盤名，不限制陣營。單位跨盤不換 UID、陣營、控制者、registry 或 CTB 身分；仍是一場戰鬥、同一時間軸。

局部格、佔格、footprint、尋路、場域與相鄰由各盤管理；Director 的生成與行動開始查實際所在盤，tick 排程覆蓋兩盤。勝敗、波次與全戰場目標跨盤查活單位；敵人盤滿時不能使用玩家盤空格冒充生成成功。存檔不保存戰鬥中棋盤，讀檔後從 Encounter 重建雙盤。

## 跨盤 A 與選格

`CrossBoardPolicy.resolve` 統一位置、shape、range、footprint 與 movement 的幾何結果。第一版只有 `cross_board_policy_version = 1`、`cross_board_policy = SELECT_TARGET_CELL`；雙盤缺欄位採 v1/A，未知版本或值拒絕並給診斷。跨盤直接選格，不定義盤間距離；陣營、盤、佔格、障礙、可選性仍須合法。

跨盤 SINGLE、ROW、COLUMN、CROSS、SQUARE_3 在目標盤展開並裁切邊界；SELF_AREA 留在施法者實際盤，ALL 只含選定盤，NONE 沒有格子。ALL_OPPONENTS 的全戰場 override 與 ALL shape 分開。沒有新增 CONE 或 CIRCLE。

LINE／LINE_PIERCE 與依跨盤方向的 PUSH／PULL／PULL_ADJACENT 在費用、RNG 或位置副作用之前拒絕。遞迴 ActionValidator／generator 分支、custom aliases 與 request values 也做 preflight；不能藏入包裝 action 繞過。跨盤 ComputeBoardValue 因距離未定義拒絕。同盤入侵者恢復正常 range、LINE 與推拉；判斷依實際 board_id，不能按 faction。

Hand 將目標盤寫入 CardPlayRequest.selected_board_id，出隊前再驗；預覽、驗證與實際解析共用規則。敵人意圖在反應可能轉盤後重新取得實際盤，move_after 也重新取得攻擊後位置。同盤距離可比較者優先，沒有同盤候選時跨盤 NEAREST/FARTHEST 以穩定 UID 排序，不假造距離零。

## 原子移動與反應

普通步行不跨盤。MoveUnit 跨盤需明確 TELEPORT 或 use_path=false 與 target_board_id（可為 SELECTED）；DisplaceUnit.TO_CELL 可作跨盤強制位移，SWAP 可交換兩盤單位。

Battlefield 預檢兩端盤、邊界、footprint、障礙、禁傳送及佔格，成功才一次提交。預檢或第二端提交失敗，兩端位置均維持；提交成功後發帶盤移動訊號，再處理來源借機、leave 與目的 enter。反應傷害不回滾幾何，致死、scope clear 或再次轉移須停掉失效 continuation，不可重建死者或留下半個交換。

普通 transfer 累計一次移動，強制 swap 累計一次位移，不捏造盤間距離。局部 ZOC 按敵對陣營判斷，強制位移預設豁免，可由規則明確開啟；來源控制者的 owner 與 target override 不因場域建立者而錯綁。場域的動態時鐘、生命週期與預覽邊界見 [專項分析](../../architecture/07_fields_zoc.md)。

## 擴充邊界與證據

保留 C 只代表未來可在單一 policy 入口新增經確認的規則；目前沒有多 policy、plugin 或 DSL。新增規則需另定 schema／版本／舊資料相容、拒絕情境、preview／實際結果、意圖與後續 AI 候選格測試，保持既有 A 意義。Phase 4 AI 與原創內容不在本輪。

[驗證映射](verification.json) 對應實際測試檔、assertions 與本輪證據；Field、DualBoard 與 SaveLoad 覆蓋局部場域、兩盤時序、失敗原子性、反應取消、正常新局、本體節點、雙盤波次／勝利及跨程序重建。人工觀感與鍵鼠操作仍待使用者驗證。
