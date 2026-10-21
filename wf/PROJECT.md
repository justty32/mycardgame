# mycardgame — 專案背景與來源

[INDEX](INDEX.md)｜[環境](workflows/dev-env.md)｜[後續規劃](workflows/planning.md)

本 repo 根目錄是以 Slay-The-Robot 為框架、題材中立的卡牌遊戲開發基地，可同時承載多款遊戲；各款的題材、原創機制、發行目標與外部參考來源記在各自的題材樹（由根 AGENTS.md 路由），不寫進本檔。使用者偏好與授權見 [user](workflows/common/user.md)。

## 目前範圍

| 目錄 | 內容 |
|---|---|
| game/ | 遊戲原始碼（上游框架加本地修復） |
| tools/、tests/ | 本專案工具與測試 |
| examples/ | 題材中立、獨立啟用的可玩框架範例，不混入各款遊戲的題材或個人 mod 清單 |
| analysis/slay-the-robot/ | 框架的已核實分析與教學，入口見 [分析入口](../analysis/slay-the-robot/README.md)；設計與呈現事實見 [設計分析](../analysis/slay-the-robot/design/README.md) |
| wf/ | 工作流（kernel + dev 非侵入式佈局），遊戲修改從 [game-dev](workflows/game-dev/README.md) 進 |
| games/ | 各款遊戲的題材樹 |

發布為 `justty32/mycardgame` 的外層 snapshot，佈局見 [dev-env](workflows/dev-env.md#環境與來源)。協作採平台原生 sub-agent（[decisions](workflows/decisions.md) 第 1 列）。目前沒有自動平衡模擬器或額外 MCP，只有日後反覆任務與穩定工具介面確實需要時才評估。

## 上游框架

[Slay-The-Robot](https://github.com/DesirePathGames/Slay-The-Robot)（GDScript 卡牌 roguelike 框架、資料驅動擴充，[根 LICENSE](https://github.com/DesirePathGames/Slay-The-Robot/blob/main/LICENSE) 為 MIT）固定於 commit `4dac5abe0d19382f8ace2cec5ed3fd77e2a0e11d`，保留根授權與 addons 授權。本地修復（Dictionary merge、存讀保護等）的補丁、順序與雜湊，以及引擎政策（基準 Godot 4.7.x，4.6 為歷史基準）都以來源鎖 [upstream.json](../tools/upstream.json) 為準；升級流程見 [upstream](workflows/game-dev/upstream.md)。

## workflows 來源

骨架取自本機 `C:/code/mine/workflows`（讀取時 HEAD `794d6d23322a93e0f65e3748375351904fa67066`，模板標記 v0.6），以其 `tools/wf-init.sh --flavor dev --non-invasive wf` 產生，未修改來源 repo；授權副本見 [LICENSE.workflows](LICENSE.workflows)。後續升級依來源 IMPORT.md 的 kernel-owned／project-owned 分類處理，保留已填的專案內容；來源 repo 只在公司 Windows 機，Manjaro 本機無法升級 kernel。

## 歷史摘要

- 2026-10-19 引入 Slay-The-Robot 與 workflows，並把原 PAS 的兩篇 tutorial 與操作日誌完整移入 analysis/（已依固定版本更正；PAS 原件僅作歷史來源，之後不再依賴）。
- 同期修復 Dictionary merge、建立隔離 runner 與流程回歸，引擎基準升到 4.7.x；以不同任務完成 [首次接手演練](../analysis/slay-the-robot/onboarding/README.md)。
- 2026-10-20 起戰鬥框架加入雙盤與可選棋盤模組。
- 細節交給 git log 與 [decisions](workflows/decisions.md)。
