# mycardgame

以 [Slay-The-Robot](https://github.com/DesirePathGames/Slay-The-Robot) 為框架的個人卡牌遊戲專案，採 Godot 4.6。此版本建立可持續開發的程式基準、回歸測試與 agent 工作流；遊戲題材與原創內容仍待設計。

## 開始開發

Agent 先讀 [AGENTS.md](AGENTS.md)，再依 [工作流入口](wf/workflows/game-dev/README.md) 選擇卡牌設計／評量、敵人、關卡、圖像、聲音、UI 或機制。各流程均附實際程式來源與驗收邊界；[框架分析](analysis/slay-the-robot/README.md) 保存核實事實與已知缺口。

`game/` 包含框架程式及本地修復。來源版本、引擎校驗值與重建補丁在 [tools/upstream.json](tools/upstream.json)；詳細安裝及 Git 佈局見 [開發環境](wf/workflows/dev-env.md)。本機引擎、快取與個人存檔不隨程式碼發布。

準備 PowerShell 7 與來源鎖指定的 Godot 4.6 執行檔後，在專案根目錄執行背景驗證：

```powershell
./tools/test-game.ps1 -Suite All -GodotPath 'C:/path/to/Godot_v4.6-stable_win64_console.exe'
```

測試使用隔離遊戲副本與獨立資料目錄，涵蓋 Dictionary、主選單載入、資源生命週期、單場戰鬥勝敗及跨程序存讀。實測版本、結果與限制見 [流程回歸](analysis/slay-the-robot/architecture/04_regression_validation.md) 及 [資源清理](analysis/slay-the-robot/architecture/05_resource_lifecycle.md)。新卡、全幕通關、視覺、音訊聽感與實際輸入需各自驗證。

## 維護與來源

`wf/` 是結構化記憶與可執行的任務流程：程式變動後同步分析、驗證及操作指引。資料驅動擴充優先使用獨立 mod；修框架時保留回歸證據與補丁。多人分工與目前操作授權見 [agent-session](wf/workflows/agent-session.md) 及 [使用者邊界](wf/workflows/common/user.md)。

Slay-The-Robot 的 [MIT 授權](game/LICENSE) 與 addons 原授權保留；工作流來源授權見 [LICENSE.workflows](wf/LICENSE.workflows)。[spire-codex](https://github.com/ptrlrd/spire-codex) 作為研究參考，沒有匯入其程式碼、遊戲資料或素材；詳細來源與使用邊界見 [PROJECT](wf/PROJECT.md)。
