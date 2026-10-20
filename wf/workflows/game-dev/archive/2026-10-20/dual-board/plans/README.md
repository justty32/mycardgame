> 封存 2026-10-20，由 ../../../../../../../analysis/slay-the-robot/design/dual-board/README.md 取代

# 雙棋盤分階段執行計畫

[規劃與已決方向](../../specs/dual-board/README.md)｜[Phase 2b 暫停交接](../combat-framework/phase-2b.md#暫停交接)

狀態：2026-10-20 使用者已授權開始實作：雙棋盤 A → 本體站格 → 完整 Phase 2b。開工核對中斷 manifest 的 53 個 game/tests/tools 檔 hash 全相同；保留未提交改動及原快照，不 reset。僅隔離 headless，不操作桌面／螢幕鍵鼠；本輪完成前不發布未驗版本。

## 分批順序

第一批確定 BoardPosition／Battlefield、盤身份與陣營分離、唯一 CTB；選格及訊號契約帶盤身份。驗同座標在兩盤不互相占格，入侵者不換陣營。

第二批建立版本化的跨盤單入口，第一版僅 A；缺 policy 的雙盤設定採 A，未知值／版本拒絕。舊單盤模式明確保留。驗同盤距離、跨盤目標合法性、局部 shape 與版本負例。

第三批接兩盤部署、波次、召喚及局部尋路；驗普通步行不跨盤、生成不串盤、勝敗跨盤查詢與 CTB 不重複。

第四批做特殊跨盤 move／swap 的預檢與原子佔格提交；驗多格、障礙、禁入、取消、失敗位置不變、成功後場域事件與致死中斷。事件序採提交後帶盤訊號、原盤借機／離格、目標盤進格；每一步重新驗活性與位置，不承諾傷害副作用回滾。

第五批接 Hand／BoardView、卡牌與敵人意圖、ThreatPreview；驗目標盤選取、預覽與實際命中一致、入侵後同盤／跨盤判斷。首版跨盤 LINE／LINE_PIERCE 與依跨盤方向的推拉在付費前拒絕；同盤方向型保留，特卡入侵後依實際盤切換判斷。CONE 不在既有 enum，本輪不新增。

第五批的呈現工作依 [角色本體站盤契約](../../specs/dual-board/presentation.md) 增加 1–2 個驗收子批：實際 sprite 由盤位置／footprint 定位，普通移動、跨盤及交換跟隨；核對 draw order、血條／意圖／hitbox／預覽 owner，以及死亡、波次與轉移後引用／取消。以既有 2D 素材驗功能，不把未定鏡頭或 3D 當需求。實際觀感仍待使用者驗。

第六批整合 All、必要 pack Smoke、存讀重建與退出清理；更新來源補丁、分析及工作流。原估 A 6–8 批，角色本體站盤再加 1–2 批，合計約 7–10 批；原創素材與美術打磨另計，不能按檔數估工。

## Phase 2b 與未來 C

完整 Phase 2b 另約 3–5 批：回收局部場域與尋路草稿、完成 ZOC／位移增補、雙盤時序與生命周期回歸，並核對原 phases.json 全部需求。這是恢復前的成本估算；目前工程接線已落盤，是否交付以最終整合證據為準。

未來 C 另按新增 policy 列增量 spec：schema／版本相容、validator、解析與 preview、intent、AI（該階段已存在時）的完整測試；沿用 A 的位置與轉移，不預先建 plugin 系統。

## 驗收與停止條件

每批先有可觀察測試再整合，最終按 [驗證矩陣](../../specs/dual-board/verification.json) 與 strict 文件 lint／boundary 收尾。A 與第一版不支援跨盤方向型效果均已決，本輪已授權實作與 headless；GUI／鍵鼠驗收仍禁止且未驗。

## 實作分工與接線

Battlefield owner 管位置／盤集合／A policy與schema；movement owner 管盤內尋路、跨盤轉移與位移／ZOC；intent owner 管target/validator/意圖與preview；presentation owner 管實際人物與HUD站格、雙盤BoardView及Hand選格；fields owner 管各盤場域；tests owner 管專項回歸。整合 owner 管Director/UnitSpawner/shared ActionHandler、runner、文件與來源補丁，並唯一串行執行引擎。每個檔案只有一個owner，跨owner API先確認。
