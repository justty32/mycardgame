# game-dev — AI agent 遊戲開發入口

[WORKFLOWS](../../WORKFLOWS.md)｜[專案地圖](../../INDEX.md)｜[agent 接手與協作](../agent-session.md)

將使用者需求轉成可驗證的遊戲變更。共同執行流程用 [feature-dev](../feature-dev/README.md)，此處依遊戲領域補齊必要的原始碼與驗收。

**何時用**：設計與評量卡牌、敵人或關卡，製作圖像／聲音／UI，新增內容、修改規則／數值、修遊戲 bug 或更新框架。

**何時不用**：只查一個問題 → [investigation](../investigation.md)；單純改文件 → 修改後跑文件 lint；沒有需求的玩法構想 → [planning](../planning.md)。

## 先選修改類型

<!-- wf-nav -->
| 使用者需求 | 操作指引 |
|---|---|
| 卡牌定位、費用、效果、升級與取得入口 | [卡牌設計](card-design.md) |
| 單卡、牌組、協同與遭遇中的強度評量 | [卡牌評量](card-evaluation.md) |
| 敵人角色、意圖、行動節奏與反制 | [敵人設計](enemy-design.md) |
| 遭遇、事件池、地圖、幕與獎勵節奏 | [關卡設計](level-design.md) |
| 卡圖、角色圖、圖示、背景與動畫素材 | [圖像素材](art-assets.md) |
| 音效、音樂、匯入、播放與音量設定 | [聲音製作與接線](audio.md) |
| 場景、介面、文字、輸入與畫面呈現 | [UI 與呈現](ui.md) |
| 設計完成後的 schema、mod、角色、遺物與內容接線 | [內容開發](content.md) |
| Action、戰鬥、攔截、隨機、序列化與存檔 | [機制修改](mechanics.md) |
| ownership、快取、非同步取消與退出資源保留 | [資源生命週期](resource-lifecycle.md) |
| Slay-The-Robot 或 Godot 版本更新 | [上游升級](upstream.md) |
| 改動應驗到哪、既有測試涵蓋什麼 | [驗證選擇](validation.md) |

先通讀 [agent-session](../agent-session.md) 指定的核心規矩，領域流程按任務取用。例如新卡先設計與評量，再由內容流程接線；需要新 Action 才加機制；需要卡圖或音效則交對應素材流程，最後由 UI／內容完成引用與驗證。

## 流程

先依 [code-map](../common/code-map.md) 找實作，讀 [來源紀錄](../../../tools/upstream.json) 與現有測試。將需求寫成可觀察結果，例如卡牌在哪出現、付出多少能量、影響誰、在哪個時點生效；不自行填入未決定的核心玩法。

小改直接執行；涉及數個系統、存檔相容或多 agent 寫入時，先在同一任務落下簡短方案與分工，再動工。這是 agent 自行維護的工程記錄，不增加例行確認回合。需求缺少且會改變核心玩法的資訊才向使用者釐清，其餘工作繼續。

沿現有資料與 API 實作最小變更。修改前記下與本次有關的既有問題；完成後依 validation 的變更類別選檢查，不只跑固定 smoke。命令與日誌入口在 [testing](../testing.md)。

## 文件與經驗同步

行為真相是 game 原始碼及測試。改路徑／職責同步 code-map；改操作同步本資料夾對應流程；改 API／schema 同步 analysis 的相關架構與教學；改命令／版本同步 dev-env、testing 與來源紀錄。只改受影響的文件，不為湊數改整套。

已驗證且可重複使用的經驗，依 [learning](../learning.md) 提煉進現有流程。完整日誌留 artifacts/，持久文件只留條件、做法、結果與證據位置。

## Done when

- 任務記錄列出需求對應的改動檔與實際驗收結果。
- validation 選出的命令回傳符合預期，新增行為有針對性證據；未驗部分明列。
- 受影響的 code-map／教學／工作流已同步，strict lint 回傳 0。
- 已完成的 SESSION-LOG 條目移除；真正待使用者操作者才留 WAIT_USER。

## 交接

尚未完成的工程工作交 [agent-session](../agent-session.md)；需求取捨交 [planning](../planning.md)。設計評估與素材審查的證據不能互相替代，未實作的自動化工具明列為缺口。Dictionary／存讀歷史見 [流程驗證](../../../analysis/slay-the-robot/architecture/04_regression_validation.md)，資源生命週期的當前結果見 [清理驗證](../../../analysis/slay-the-robot/architecture/05_resource_lifecycle.md)。
