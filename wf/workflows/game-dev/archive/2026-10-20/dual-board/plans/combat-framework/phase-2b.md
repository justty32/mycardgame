> 封存 2026-10-20，由 ../../../../../../../../analysis/slay-the-robot/design/dual-board/README.md 取代

# plan：戰鬥框架 Phase 2b 場域格與控制區

[spec](../../specs/combat-framework/README.md)｜[分階段](../../specs/combat-framework/16-movement-phasing.md)

狀態：2026-10-20 使用者已授權恢復，先雙棋盤 A／本體站格，再整合完整 Phase 2b。基準 `ac37a9ad76086e3e68ec0471c873371206eb3e84`；最初開工乾淨，恢復時保留53個未驗實作檔。僅檔案與隔離 headless 檢查，禁止桌面、視窗、螢幕鍵鼠操作；既有程序、存檔與 playtest 保留。

## 範圍與分工

完整採用 phases.json 的 2b 列與 11–16 移動規格，不以八項 Done when 取代其他需求。Phase 3 已完成的 WAIT_UNTIL_FREE／FAIL_SKIP 不重做。Phase 4 AI 決策本體不在本輪，但純 preview 接點必須存在。

FieldController 獨立處理場域生命週期，移動以有序子行動處理格事件及控制區；CombatDirector 僅接線。四位子 agent 分別負責場域、移動與控制區、意圖與位置條件、獨立回歸與文件。整合 owner 管共享 schema／訊號／Director／runner／導航與來源補丁；Godot 由同一 owner 串行啟動。

## 需求映射

場域由 FieldData、FieldInstance、FieldController、三個場域 Action、ValidatorCellHasField 與 UNITS_ON_FIELD 實作；Field suite 驗資料載入、初始場域、stack／filter／owner、建立移除、路徑與生成事件、行動開始、tick 補發及到期、阻擋與純 preview。

移動由 BoardData／BoardController、ActionMoveUnit／ActionDisplaceUnit 及專責 helper 實作；Field suite 驗 Dijkstra 成本、兩種 ZOC、每次行動的借機限制、強制豁免、八向、穿越、撤銷、抗性、多格、碰撞延遲與取消。既有 Board／Ctb／Wave 守住舊契約。

意圖由 IntentResolver／EnemyIntentController／ThreatPreview 實作 FLANK、四種 TELEPORT、path_actions、move_after；位置 helper 與 validators 提供 Adjacent／Flanked 及完整 ComputeBoardValue。Field suite 驗實際行動與預覽、無副作用及固定順序。

BoardView 接場域底色／圖示／剩餘刻、成本高亮與撤銷入口；headless 只驗資料與節點／handler 契約，不驗實際操作或畫面觀感。場域關鍵字／listener 範例放中性測試 fixture。

## 驗證與收尾

先跑隔離 Field，再 All 及受影響內容包 Smoke；runner 合成測試、文件 strict lint、框架／題材 boundary lint 與 diff check。以當次 results.json、原始日誌及來源雜湊記實際證據；未完成前不預填通過。同步分析、code map、機制流程、testing/suites、來源補丁與 metadata。完成後依 STRUCTURE 封存本 plan，交接 Phase 4；GUI 驗收繼續列未驗。

## 暫停交接

以下是實作授權之前的歷史快照，**不描述目前接線狀態**；恢復狀態與最新證據見下方。

使用者改為「敵人一個棋盤、玩家一個棋盤，先規劃看看成本」，並確認通常各守自己的盤，特殊卡可跨盤移動或交換。此時停止 Phase 2b 實作，所有未提交變更原樣保留；沒有回退、清除、commit 或 push。暫停當時未啟動任何 Godot／runtime，也未執行完整 lint。**當時不是可編譯或可執行的完成版本**，不能沿用上一版綠測宣稱此工作樹通過。

整合 owner 已改 schema／資料旗標、Signals／Scripts、BaseAction／ActionHandler 有序子行動入口、CombatDirector／CombatActionPhases 接線、Vulnerable 的無建立者處理、Field runner 選單。Director 的 field_controller getter 仍等 BoardController 提供實例；phase 時點改為行動開始訊號後場域停留、再抽牌，尚無執行證據。

場域 agent 已新增 FieldData、FieldInstance／Controller／EventAction／Preview／ActionCells、三個場域 Action 與 CellHasField Validator；建立者跨排隊動作死亡的重解析，以及同刻刷新後舊事件失效仍需完成。移動 agent 已改 BoardData／BoardCellData／ActionMoveUnit，新增 BoardPathfinding／BoardMovementState／BoardMoveSequence；BoardController 初始場域接線、ActionDisplaceUnit 增補、部分取消與多目標安全仍未做。

意圖 agent 已改 EnemyIntentData／IntentResolver／EnemyIntentController／ThreatPreview／ComputeBoardValue，新增 BoardPositionQueries／IntentTeleportResolver 與 Adjacent／Flanked／OnEdge validators。測試 agent 已建立 field_flow／fixture／cases／action_cases／clock_cases／movement_cases 等未驗草稿；測試入口雖已註冊，不能視為可用套件。實際檔案清單以工作樹差異及各 agent 停工回報為準。

雙棋盤已於同日選 A（跨盤選格、不算盤間距離）並保留 C 演進，首版方向型跨盤效果不支援；顯式跨盤移動／交換仍保留。同盤／跨盤依位置而非陣營判斷。接手先讀 [雙棋盤規劃](../../specs/dual-board/README.md) 與 [分階段計畫](../dual-board/README.md)，當時僅規劃，不恢復程式或 runtime。本 plan 保留未完成狀態，不封存。

## 恢復執行（2026-10-20）

以上暫停段保留當時未驗事實。使用者已明確授權恢復全部工作，依 [雙盤執行計畫](../dual-board/README.md) 分段；初始53個實作檔hash與快照一致，沒有回退。後續實測結果另補，不沿用之前基準通過聲明。
