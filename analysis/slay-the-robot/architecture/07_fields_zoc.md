# 場域、控制區與雙棋盤接線

[分析入口](../README.md)｜[操作流程](../../../wf/workflows/game-dev/fields-zoc.md)

2026-10-20：本頁記錄本地實作的 API 與驗證入口。完整 All 已通過；可攜結果、主日誌與來源重建證據見 [本輪證據](../evidence/2026-10-20/dual-board/README.md)。

## 場域資料與生命週期

[FieldData](../../../game/data/readonly/FieldData.gd) 經 Global 的 `fields/` schema 載入；每格的 [FieldInstance](../../../game/scripts/combat/board/FieldInstance.gd) 帶 `board_id`、owner UID、建立／到期刻與 revision。owner 使用 UID 重新查詢，不以強參照延長角色生命；死亡或釋放後 parent 為 null，targets 仍是觸發單位。相對陣營 filter 保留建立時 owner 陣營。

[FieldController](../../../game/scripts/combat/board/FieldController.gd) 每盤一個，BoardData 只持弱參照。REPLACE 換實例；STACK 增層並刷新期限，保留原 owner；IGNORE 保留原實例且不刷新。零時長立即建立／移除。到期刻不再觸發 interval：300 刻壽命、100 刻間隔只在 100、200 觸發。跨大段 tick 逐邊界補發，Director 將兩盤邊界合併排序；revision 使同刻刷新之前已排程的舊到期工作失效。

移動的 leave／enter 經 [FieldEventAction](../../../game/scripts/combat/board/FieldEventAction.gd) 與實際 occupancy 檢查執行。公開 cell 訊號帶 unit、board_id、cell；事件不是從 `unit_moved` 反推。中途格預設不觸發，`field_triggers_on_pass_through` 可啟用；生成預設不觸發，`field_triggers_on_spawn` 可啟用。每個 footprint 格的獨立 instance 各自觸發；`UNITS_ON_FIELD` 作目標集合時則對單位去重。stay 在自己的 `unit_action_started` 之後、抽牌之前。

`ActionHandler.add_ordered_actions()` 保證反應子行動先完成，再續下一移動／場域步驟；舊 `add_actions()` 的 stack 次序仍保留。有序 ancestry 僅在同步執行 scope 或明確 parent context 中傳遞；外部在 await 期間獨立 enqueue 的行動不會被收編為該場域子樹。場域 payload 的 owner 與 controller generation 每次執行重查。場域清除、角色死亡、反應造成轉移／推走或戰鬥退出後，舊 continuation 不可再套入舊位置。

## 局部棋盤與跨盤

tick 使用動態邊界排程：每個邊界的子行動完成後重新找下一邊界，payload 建立／刷新的場域使用該事件有效刻。一次推進至 350 時，100 刻新建、間隔 100 的場域會在 200、300 觸發，與逐段推進等價；不能以最終端點當建立刻而漏掉區間效果。這個等價契約涵蓋場域事件及沿 parent action／`inherit_execution_context` 傳遞有效刻的子樹；任意 signal listener 另造、未接祖先 context 的獨立行動，不會自動取得事件有效刻。

每個 BoardData 自己保存 fields、佔格與路徑；相同 local cell 在另一盤是不同位置。建立／移除／設障礙 action 的盤選擇依明確 `board_id`、request.selected_board_id、parent 實際所在盤解析。未知盤不應落回任一盤。Encounter 可用各盤的 `initial_fields`；FieldData 本身沒有把陣營與盤綁定。

[CombatBattlefield](../../../game/scripts/combat/board/CombatBattlefield.gd) 處理跨盤原子位置提交；一般步行仍在一盤。特殊 transfer／swap 完成兩端幾何提交後才派發原盤 leave、新盤 enter，事件有副作用就不承諾回滾傷害。原盤與目的盤均須驗完整 footprint、佔格及傳送禁入。單位跨盤保留 UID、陣營與 CTB 身分。

## 移動成本與控制區

[BoardPathfinding](../../../game/scripts/combat/board/BoardPathfinding.gd) 分開成本預算與實際格數。[BoardData](../../../game/scripts/combat/board/BoardData.gd) 的 `reachable_cells()` 委派 BoardPathfinding `reachable()` 做 Dijkstra 成本；卡牌距離限制用 `reachable_steps()`，主動移動用 `reachable_active()` 同時算免費點與付費格額度（BoardData 同名方法皆轉呼叫 BoardPathfinding）。八向不改卡牌距離使用的 distance metric。穿越友軍／敵軍與飛行只允許經過，終點仍須可站。

[BoardMovementState](../../../game/scripts/combat/board/BoardMovementState.gd) 管同盤 ZOC、借機節流與撤銷。EXTRA_MOVE_COST 在離開敵對相鄰格時加點數成本；OPPORTUNITY_ATTACK 每攻擊者／移動者配對每行動一次。強制位移預設不觸發 ZOC；可明確啟用。卡牌移動預設觸發，也可 `ignore_zoc`。撤銷只限未出牌、未觸發效果且起點仍合法；跨盤轉移使原盤快照失效。

位移抗性、面積上限與不可位移先驗，再逐步驗完整 footprint。碰撞剩餘格傷害、阻擋者傷害走 action；`delay_on_collision` 直接加被位移者 tick。普通／卡牌移動與強制位移分別累計 `cells_moved_this_action`／`cells_displaced_this_action`。

## 預覽的實際邊界

[FieldPreview](../../../game/scripts/combat/board/FieldPreview.gd) 支援 DirectDamage、Attack、AttackGenerator、Block、AddHealth、HealPercent。AttackGenerator 與 Attack 各自經 preview 攔截鏈；未知 action 沒有一般模擬器，估值為零。隨機目標不抽 RNG，也不估命中；隨機傷害用平均估值。

`preview_hazard(cell, unit)` 加總 footprint 各格有效 enter＋stay，傷害正、治療／格擋負，不扣既有 block；它是局部危險估值，不能當整條路徑的實際損血。借機預覽另有共用 block pool，依真正 target override 判斷是否傷到 mover，並扣除本行動已用配對。

## 回歸入口與目前限制

[Field](../../../tests/field_flow.gd) 用真實 Root／New Run／Map 啟動，資料 fixture 明確選 SINGLE，保留局部 Phase 2b 規則的可觀察案例；其 actions 走公開 handler，只有安排起點使用直接 BoardData 放置。[DualBoard](../../../tests/dual_board_flow.gd) 不覆寫 production DUAL 預設，驗雙盤位置、A 的費用前拒絕、實際 sprite 節點定位、轉移／交換與場域交錯時序。測試專用故障注入只放在 tests，沒有改生產預設讓測試通過。

Field／DualBoard、SaveLoad 與其餘 All 套件已通過；精確來源與日誌見 [本輪證據](../evidence/2026-10-20/dual-board/README.md)，測試映射見 [雙盤分析](../../../wf/specs/dual-board/verification.json)。headless 仍不驗 GUI 觀感、硬體輸入、音訊或 GPU。
