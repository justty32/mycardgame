# 每場明確 0／N 盤與開始提交：遷移 C

[分析入口](../README.md)｜[資料格式](../../../wf/specs/board-module/encounter-format.md)

2026-10-21，基於 snapshot `b510dff`。本輪把 B 的內部盤集合接到正式遭遇資料與原有戰鬥流程；部署與排版仍是明確資料，不決定陣營 home、敵我盤數或最終 N 盤自動排法。實際可觀察範圍與未驗項由下列逐項審核及最終證據界定。

## 資料與模組能力

EncounterData 局部序列化原始 `encounter_board_setup`，保留省略／空物件、版本化空盤集合與非法 scalar／null。正常 schema 匯出仍帶舊欄位預設，衝突判斷只拒非預設舊棋盤覆寫。PreparedEncounter 先驗核心 envelope 與波次，再按路徑呼叫可選模組的正規化器；核心沒有棋盤類別型別依賴。

合法 0 不建 BoardCombatModule。明確正盤缺能力回 unavailable，舊格式缺檔／關旗標仍保留普通戰鬥相容。命名 Encounter 找不到不再合成別場。正盤設定與錯誤彼此分開，錯誤不能轉成空集合。

模組的 BoardSetup 仍以集合決定盤數；`explicit_positions` 部署政策自行要求主角起點，生成位置由明確 wave entry 或明確 spawn 缺省提供。幾何不強制主角、敵我預設或首末盤；政策標記允許未來替換，沒有建立通用插件系統。矩形獨立逐 ID 輸入，新格式不套舊雙槽。已驗設定的 getter 回 detached copy，不暴露 Prepared 的可變別名，也不再次解析來源。

## 一個開始入口與成功通知

原 `ActionStartCombat` 先發布 `combat_started`，但 StatsHandler、HandManager、Player、RewardOverlay 會立即改 stats、牌堆、狀態與獎勵；UI 訂閱者也改互動。部分訂閱早於 Combat 的準備，無法靠失敗後補一個 `combat_ended` 回滾。全域搜尋沒有必須在準備前執行的該訊號訂閱者。

新流程由 Scene 的 request 入口停止上一場、準備資料並暫存模組 setup；成功才發布原 `combat_started` 讓訂閱者初始化一次，接原 Director 的首波與 CTB。直接 Director 開始亦轉送同一入口。普通卡費用、牌堆與結算仍屬原 owner，沒有第二套戰鬥 loop。明確 Event 的獎勵資料讀取當場快照，避免回頭混用地圖另一事件。

旅行位置、抽取並綁定遭遇及進站存檔屬較早的流程，不承諾整次旅行回滾。只將戰鬥節點的提前 visited 標記延至成功開始，非戰鬥點擊語意保留；失敗仍可重試已抵達的戰鬥節點，不假造勝敗或獎勵結束。

## 場域、部署與取消

BoardController 暫存幾何與初始場域，只做主角 footprint 可放性查詢，不先改角色位置或發布事件。成功提交時按原 create 操作順序建立正式場域，保留 STACK、REPLACE、零時長事件當時可見的狀態。只緩存訊號而共享已變動 instance 會破壞這些語意，因此未採用。

失敗清除未公開的 trial resources，不發布初始 field_created／field_removed。成功通知或場域 callback 可重入 clear／換場。Director 在 stage 時、通知之前保存模組 instance 與 generation，開始時核對同一 token；每個可重入 field emit 後再次核對，取消便停止後續場域、首波及 CTB。不能在通知後才取得新 generation 冒充原請求仍有效。場景失敗狀態關閉 HUD／輸入，保留原費用與獎勵所有權。Director 統一 stop 邊界禁用手牌選取，下一次成功 party action 沿原流程解鎖，防止失敗後隱藏 HUD 但普通選牌仍可扣費。

## 驗證與交付

獨立審核 [25 項完成條件](10_multi_board_encounters-audit.json) 分別記錄產品檔、測例、實際證據與限制。資料列包含 id／condition、product_files／test_files、evidence／status 及 remaining_or_limit；runtime 與 source 核對分開，不以套件通過取代需求審核。C／D 適用工程驗收完成；原方案／遷移計畫封存，現行格式、責任與生命週期保留在棋盤模組契約。

1／2／3／7 盤的 parser、world 與任意 ID 順序已有專項；正式同場景 0→DUAL→0→三盤驗普通付費卡、晚波、超過畫面槽數的敵人生成及跨盤目標行動。七盤完整遊玩、大 N 效能、全部內容包、多幕通關未驗；GUI、音訊、物理點擊與人工畫面可讀性受本輪禁止桌面操作邊界限制，headless 的場景／訊號斷言不能取代它們。

早期失敗保留在本機 artifacts/verification：205755-acefee29 找到主角合法起格被 nearest 搜尋改寫與 freed module cast，已修 exact-first 及 instance 防護；210014-bfd5f677／210127-42a06e2d 的空貼圖／icon 及未定型獎勵 fixture 使 engine error，即使 assertion 全綠仍判 FAIL，已修有效資產與型別。之後 review 補出通知前 stage token 與 stop 禁手牌的必要生命周期邊界，最終驗證不冒用之前不同 source 的 pass。

[最終驗證表](10_multi_board_encounters-verification.json) 有 12 列，共 2166 checks／0 failures、18 測試階段與 42 程序階段；Godot 為 `4.7.2.stable.mono.arch_linux.ed1daf0bf`。欄位保存 suite／run、assertions／phases、verdict／markers、原始 results SHA256、source／test 差異與重用理由。所有程序正常退出，沒有 unexpected engine error、native crash、ObjectDB leak 或新增 shutdown resource。

最後停止輸入修正後重驗 Smoke、DualBoard、BoardRemoved、ResourceLifecycle、SaveLoad、CombatVictory、CombatDefeat，七套 source／test hash 全符。Board、Boardless、Wave、Field、Ctb 沿用上一凍結版本：差異僅 Director 的停止委派與 Scene 的自身 UI 清理 helper，不改其規則／幾何／生成／時序；新停止路徑由上述七套覆蓋。runner 記錄的完整測例清單另包含只由 DualBoard 呼叫的 `multi_board_start_cases`，新增斷言由最終 Dual 464 驗證。五套的原／現 SHA 與理由逐列保存，不把它們當成 final hash 重跑結果。共同 serializer 未改，故未另跑 Dictionary。

來源交付使用相對 `b510dff` 的 [增量補丁](../../../tools/patches/per-encounter-board-sets.patch)，按 upstream 鎖接在 B 後；SHA256 為 `6d5ccae9de6ca648eba6434e5b02409dfa4c3181545acf84f2b2094598c7c42b`。隔離 archive 基準後 apply、逐檔比較 17 個產品檔完全一致；全 16 個 patch 鎖雜湊均相符。原本機重建紀錄 `artifacts/phase-c-patch-tsrn1pet/verification.json` 保留，版本控制交付本摘要與補丁本體。完成封存後 `bash wf/tools/wf-lint.sh --strict .` 通過，broken／residue／oversize／biglist／querycmd 全 0；`python3 tools/boundary_lint.py` 通過、violations=0。
