# 多棋盤可行性調查：語意模型與推薦方案

> 2026-10-21 使用者已決定：盤數每場決定，含 0 盤。
>
> 狀態：2026-10-21 唯讀調查，未實作。使用者後續要求先規劃乾淨解耦結構，不先定死部署玩法；目前接 [架構草案](../../specs/multi-board/README.md)。以下 M1–M4 與問題保留為候選分析，不是開工前必須逐項問使用者的清單。前篇：[feasibility](2026-10-21-multi-board-feasibility.md)。

## 可行語意模型

模型｜內容｜要改的層｜工作量｜風險｜與既有決策相容性

**M1 多陣營盤（1 我方 + K 敵方，或一般化「每盤標一個主場陣營」）**｜遭遇資料列出盤清單與順序，每盤標 `home`（party／enemy／none）；跨盤一律規則 A｜EncounterData（盤清單、驗證、預設波次盤）、CombatRulesData（新模式或盤數上限）、CombatBattlefield.default_board_id 改查資料、BoardController 預設部署／生成盤、Presentation N 槽排版、新測試 fixture｜**中**（核心邏輯少，主要在資料／驗證／版面）｜版面可讀性（槽變窄）；AI「最近」多數走 fallback；作者寫錯 home 的驗證｜**高**：規則 A 原樣適用任兩盤；卡牌機制不動；仍是模組內部；DUAL＝M1 的特例

**M2 中立／共享區盤**｜在雙盤之外加一或多個 `home: none` 的盤（中場、獎勵區、陷阱區），無陣營主場、可有場域與障礙｜同 M1（M2 是 M1 的子集），另需決定 NEUTRAL 陣營預設盤（H5 現在把 NEUTRAL 丟到 enemy）｜**小～中**（若 M1 已做，近乎純內容）｜進出中立盤只能靠特殊卡，玩法可能卡住｜高；同 M1

**M3 每單位一盤（決鬥格／分割戰場）**｜每個單位或每組單位一盤，盤數＝參戰單位數，動態增減｜生成時動態建盤（目前盤只在 setup 建、Presentation 只在 keys 變化時整批重建 view 並 `actor_presentation.clear()`）、波次／召喚建盤、死亡回收盤、存讀檔、UI 動態排版、所有「同盤距離」規則幾乎全失效（全部變跨盤 A）｜**大**｜範圍／LINE／推拉／ZOC／FLANK 等同盤機制大量失效；動態盤生命週期與 generation、場域清理的新失敗模式；版面不可控｜低～中：規則 A 能跑但大部分棋盤玩法退化；違背「棋盤是可選模組、維持既有契約」的精神不多，但改動面接近重寫

**M4 有拓撲的多盤（盤間距離／鄰接圖／戰線）**｜盤之間定義鄰接或距離，跨盤射程、方向型效果依拓撲計算｜CrossBoardPolicy 新 policy／版本（spec 明說「保留 C」須另定 schema、拒絕情境、preview、AI 測試）、BoardActionGeometry、IntentResolver 距離、ThreatPreview、ComputeBoardValue｜**大**｜改變規則 A 語意；需使用者確認方向／距離語義｜與「雙盤先採 A、不支援跨盤方向型」決策衝突，需使用者重新決策（decisions.json 2026-10-20 兩列的 premise 已預留此觸發條件）

## 結論與推薦：最小可行方案（M1，含 M2）

以下是多盤語意的**工程提案，尚非定案 schema**。每場 0 盤已獲使用者確認；本節原先的 2..上限與 NONE 不讀新欄位只描述舊推薦，不能覆蓋新決策。必須先補 [H0 裝配缺口](2026-10-21-multi-board-feasibility.md#2-寫死兩盤或-singledual-二選一的地方)：解析同一份 Encounter 後，0 盤走真正未掛模組；正盤才交模組驗盤資料。舊內容省略欄位仍須保留 SINGLE／DUAL 相容行為，明確 0 盤不能等同省略。場景／規則旗標與模組檔案缺失的既有能力邊界亦須回歸。

**可行，且不需動規則 A、卡牌或 AI 核心。** 推薦以「盤清單資料化」實作 M1，DUAL／SINGLE 保持原義作為內建預設：

(1) **資料（EncounterData）**：新增模式（例：`BOARD_MODES.MULTI`）或「`encounter_board_list` 非空即多盤」；清單元素 `{id, home: "party"|"enemy"|"none", size?, deploy_cells?, ...}`，順序＝畫面順序。`get_board_ids` 回清單 id（H2）；驗證：id 唯一、恰一個 party 主場盤（主角部署）、至少一個 enemy 主場盤或所有波次單位明寫 board_id、盤數 2..`board_max_count`（H3）。`default_wave_board` 改為「第一個 enemy 主場盤」，與模組共用同一函式（H4/H7）。

(2) **規則（CombatRulesData）**：`validate_configuration` 接受新模式；新增 `board_max_count`（建議預設 3、硬上限 4），理由同 board-size 上限＝呈現可讀性（H1）。

(3) **Battlefield／Controller**：`default_board_id(faction)` 改查「第一個 home＝該陣營的盤」，NEUTRAL 找 none 盤再退 enemy；DUAL／SINGLE 行為逐字不變（H5/H6）。舊 `board` getter 維持＝party 主場盤。

(4) **呈現**：`view_position(index, count, size)` 依 count 產生 N 個槽（3 盤：三等分寬或 2+1；4 盤：2×2），槽尺寸由 count 決定並傳入 `compute_layout`；`actor_scale_for` 已按格寬算，可沿用（H8/H9）。這會觸發 decisions.json「棋盤大小」列的 premise（槽尺寸改變→重看上下限），需在 board-size.md 補「多盤時的有效上限」或按盤數收窄驗證。

(5) **不改**：CrossBoardPolicy、BoardTargeting、IntentResolver、ThreatPreview、Field/ZOC、Hand／HandManager／CardPlayAdapter、普通卡。NONE 不建立盤面資源、不解析盤面幾何；但場景裝配必須讀遭遇的盤數選擇，才能決定這一場走 NONE。

(6) **測試**：新增 `multi_board_cases`＋3 盤 fixture（1 party＋2 enemy＋可選 1 none）：建盤數與 home 解析、波次預設盤、敵方盤間 TELEPORT／SWAP 原子性、ALL 只含選定盤、AI 無同盤目標時 uid fallback、場域時鐘跨 3 盤排序、view 位置互不重疊且在畫面內、驗證錯誤碼；既有 DUAL／Boardless／BoardRemoved 回歸不改斷言即應全綠。

(7) **工作量估計**：中。核心程式改動約 5 檔（EncounterData、CombatRulesData、CombatBattlefield、BoardController/BoardCombatModule 小改、BoardCombatPresentation），加 1 個測試檔與 spec（board-module 新增 multi-board 節、decisions 一列）。

零盤先行驗收以既有 DUAL 為正盤對照：同一場景依遭遇資料走 0→DUAL→0，確認普通卡牌／敵人／波次仍運作，0 盤沒有模組、盤面 UI 或殘留格位，舊請求不能越過模組 generation，之後再回正盤能重建。既有 Boardless 的全域／場景關閉回歸不等於這組新測例已完成；真正 N 盤另需上述多盤測試。

**需使用者決定（未驗證、不自行補完）**：
多盤要服務的玩法是哪種（M1 多敵方盤？M2 中立區？）——決定 `home` 的種類與驗證規則。

盤數上限與排版（三並列 vs 2+1 vs 2×2）；實際觀感與點擊只能人工 GUI 驗收（headless 只驗數值）。

主角以外的我方單位是否會入盤（目前只有主角部署）。

若要盤間距離或跨盤方向型（M4），屬推翻規則 A 的新決策。

## 來源

game/scripts/combat/board/CombatBattlefield.gd:7-9, 11, 33-38, 45-146（含 63-66）

game/data/readonly/EncounterData.gd:11-14, 44-52, 83-133（含 116）

game/data/readonly/CombatRulesData.gd:20, 50, 101-102

game/scripts/combat/board/BoardController.gd:9-16, 27-59, 72-93, 115-136

game/scripts/combat/board/BoardCombatModule.gd:186-216, 235-240

game/scripts/combat/board/CrossBoardPolicy.gd:9-34

game/scripts/combat/board/BoardTargeting.gd:184, 207-225；BoardActionGeometry.gd:55-80；BoardActionTargets.gd:42-63；FieldActionCells.gd:7-23

game/scripts/combat/board/IntentResolver.gd:11-51, 126-129；ThreatPreview.gd:17-77；BoardMovementState.gd:52；BoardCardInput.gd:41-68

game/scripts/ui/BoardCombatPresentation.gd:9-22, 47-76；BoardView.gd:6-8, 24

game/autoload/Signals.gd:174；game/scripts/combat/UnitSpawner.gd:63-81, 107, 148, 167, 248-257

tests/dual_board_fixture.gd:10-21；tests/combat_flow.gd:134；tests/save_load_flow.gd:176；tests/dual_board_cases.gd:10-18；tests/dual_board_presentation_cases.gd:220；`rg -c '"party"|"enemy"' tests`

examples/board-lab/pack/encounters/demo_encounter_{entry,field,final}.json、cards/demo_cross_step.json

wf/specs/dual-board/README.md、presentation.md；wf/specs/board-module/README.md、board-size.md、intents.md；wf/workflows/decisions.json（2026-10-20 雙盤 A／方向型／可選模組；2026-10-21 不做 per-encounter 開關／每場大小）

