# 完整用途的呈現交付演練

[演練入口](README.md)｜[完整場景流程](../../../wf/workflows/game-dev/scene-pack.md)｜[原技術領域輪次](media.md)｜[證據副本](media-purpose-evidence/README.md)

2026-10-19，使用者追加要求：圖像、UI、聲音與動畫應按完整用途組合，包含卡框＋卡圖、敵人，以及頭像／文字／選項的對話和商店等完整畫面。原技術域 8 情境的 pass 只證明各領域可開始工作，不能證明本需求已覆蓋；本輪獨立保留任務與證據。

新情境保存在 [media-purpose-scenarios.json](media-purpose-scenarios.json)（6 列，最新 6/6 pass；首次 4 pass、2 hold 永久保留）。任務是完整交付包，部分包含多個必要子畫面；`required_coverage` 明列各子畫面及七項契約。第六案是選角起局→地圖選點→勝敗結算返回的旅程，三畫面都須提出可開工計畫；商店／休息及獎勵／draft／牌庫選牌亦須逐項覆蓋，不能只檢查其中一個便判整案通過。

## 初始證據的性質

四份初始報告是原美術、UI、音訊與動畫作者在追加範圍後，對已有技術流程做的缺口盤點，**不是新的無歷史盲測**。報告保留原入口能做什麼、尚不能組成哪些用途，以及實碼初查；它們與原技術域 initial／fresh 報告分開保存。原件與逐 byte 副本雜湊見本輪 manifest。

`id`／`task` 識別具體完整任務。

`required_coverage` 列不得省略的子畫面和七項契約。

`initial_kind`／`initial_route`／`initial_gap` 記初始方法、入口與阻礙。

`initial_evidence` 連四份作者盤點，副本與雜湊可核對。

`repair_entry`／`repair_summary` 連完整場景統籌及用途子流程，不複製實作規格。

`initial_review_status`／`initial_review_reviewer`／`initial_review_evidence`／`initial_review_findings` 永久保存首次獨立判定與缺口。

`retest_status`／`retest_reviewer`／`retest_evidence` 表示最新獨立結果；`followup_evidence`／`followup_summary`／`followup_repair_entry` 記後續復查及修補路由，不覆蓋首次記錄；`limits` 限定證據能證明什麼。

## 首次獨立結果

完整 [D／E／F 首報](media-purpose-evidence/fresh-purpose-screens.md.txt) 已凍結。D 的商店可開工，但休息缺專屬動畫、選牌中父畫面／Continue 時序及晚到完成回呼的退出責任；E 的獎勵與 draft 可開工，但牌庫 VIEW／SELECT 缺專屬 cue、Grid／glow 動畫和返回 opener 鏈，故兩案都 hold。F 的選角、地圖、勝敗結算逐一具備七項契約，僅判可開工 pass。

D／E 交原作者修補後，經同一獨立 reviewer 復查才更新最新狀態；首次判定與報告雜湊永久保留。[A／B／C 首報](media-purpose-evidence/fresh-purpose-combat-dialogue.md.txt) 確認卡牌與 HUD、一般敵與頭目／圖鑑、兩 state 對話及中斷各自可提出開工計畫，三案首次 pass。

## 修補後獨立復查

[D／E followup 完整報告](media-purpose-evidence/fresh-purpose-screens-followup.md.txt) 確認兩條缺鏈已補齊，僅判可開工 pass。休息新增 [服務專篇](../../../wf/workflows/game-dev/ui/screens/rest-services.md)，明定接受、SELECT 父畫面鎖定、Back、完成／互斥刷新和晚到回呼的身分／generation 責任。非 Draft 選牌新增 [牌庫選牌專篇](../../../wf/workflows/game-dev/ui/screens/card-selection.md)、[選牌聲音](../../../wf/workflows/game-dev/audio/selection-cues.md) 與[休息／選牌動畫](../../../wf/workflows/game-dev/art-assets/motion/rest-selection.md)，將 VIEW／SELECT、暫選、提交、旁路、返回 opener 和清理串完整。

followup 沿用首報中未受影響的商店、獎勵列、draft 與完整旅程證據，沒有將兩次 hold 改寫成首次順利。最新 6/6 只表示六種完整用途都能提出具體實作計畫；控制器、guard、consumer、素材、helper、runtime、視覺、聽感與實際輸入仍待真正開發／驗收。原技術域 8 案及更早 9 案／52 checks 證據不變。

## 獨立復走的判定

用途子篇 freeze 後，由主 agent 派未參與修補的 reviewer 從 wf 入口接具體任務；不得借本表或作者報告補答案。對每個必要子畫面交出 UI 組成、圖像包、聲音 cue、動畫時序、資料來源、退出責任與驗收，均需可定位的 consumer／owner、第一步與測試接入位置。新增機制或未定產品規則可以明列，但不能把未知寫成現成能力。

完整報告存在且必要子畫面都覆蓋後才更新結果；未復走記 pending，已查出子畫面或關鍵責任缺口記 hold 並列理由。首次結果和修補後復查分開保存，不倒寫成一次通過。狀態 pass 僅表示能開始實作，不代表素材、玩法或整套畫面已完成。

本輪只文件與背景靜態查核，不啟動 Godot、不生成素材、不播放音訊、不操作 UI／桌面／視窗／截圖／焦點或既有程序。後續資料／事件／清理的 runtime、視覺、聽感、實際輸入及性能仍各需證據。原 9 情境／52 checks 與技術域 8 情境的報告保持原範圍。
