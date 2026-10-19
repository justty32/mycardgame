# mycardgame — 專案背景與來源

[INDEX](INDEX.md)｜[環境](workflows/dev-env.md)｜[後續規劃](workflows/planning.md)

使用者於 2026-10-19 指定：製作自己的卡牌遊戲，以 Slay-The-Robot 為框架、spire-codex 做參考；第一步以非侵入式方式引入本機 workflows。遊戲題材、原創機制與發行目標尚未定義。

## 目前範圍

已導入 kernel + dev，工作流與背景收在 wf/，框架分析與教學收在 analysis/slay-the-robot/。遊戲原始碼位於 game/，本專案工具與測試在 tools/、tests/。使用者指定以 `justty32/mycardgame` 外層 snapshot 發布完整程式與本地修復；原本固定 HEAD 的獨立 game checkout 保留於開發機，公開 checkout 的 game/ 為一般追蹤檔案，詳細佈局見 dev-env。現階段用平台原生 sub-agent 協作。

## 框架與參考

### Slay-The-Robot：已引入的遊戲框架

[上游 README](https://github.com/DesirePathGames/Slay-The-Robot) 在 2026-10-19 查核時列 Godot 4.6、GDScript，提供卡牌 roguelike 框架與資料驅動擴充。[根 LICENSE](https://github.com/DesirePathGames/Slay-The-Robot/blob/main/LICENSE) 為 MIT。已 clone 至 game/ 並 detached 到 commit `4dac5abe0d19382f8ace2cec5ed3fd77e2a0e11d`；保留根授權與 addons 授權，另有 Dictionary／存讀保護的本地修復。Godot 4.6 可攜版已核對 SHA-512；版本與補丁紀錄見 [upstream.json](../tools/upstream.json)，啟動方式見 [dev-env](workflows/dev-env.md)。

### spire-codex：設計與資料研究參考

[上游](https://github.com/ptrlrd/spire-codex/tree/main) 是 Slay the Spire 2 資料庫與 API，使用 Python/FastAPI 與 Next.js/TypeScript。角色是研究參考；目前沒有匯入程式碼、資料或素材，也沒有接入 hosted API。[LICENSE.md](https://github.com/ptrlrd/spire-codex/blob/main/LICENSE.md) 在 2026-10-19 查核時為 PolyForm Noncommercial 1.0.0；README 另區分遊戲資料與 hosted API 條件。實際採用任何內容時記錄來源與適用條件。

Slay-The-Robot 已固定版本；spire-codex 仍是未匯入的研究參考。

## 專案內建分析與教學

2026-10-19 依使用者指示，已將 PAS 的相關資料完整納入本專案。後續維護以 [本機分析入口](../analysis/slay-the-robot/README.md) 為準，不再依賴 PAS：

- [新手指南](../analysis/slay-the-robot/tutorial/beginner_guide_zh.md)：Godot、GDScript、JSON、卡牌／敵人／角色與 mods。
- [進階指南](../analysis/slay-the-robot/tutorial/senior_guide.md)：Action、Interceptor、Signals、patch_data 與除錯。
- [操作日誌](../analysis/slay-the-robot/session_log.md)：保留 2026-04-15 遷移紀錄，追加本專案進度。

原始資料只有兩篇 tutorial 與日誌；現在已依固定版本更正 API 與 JSON 範例，新增架構、擴充方式、原版啟動及 [流程回歸](../analysis/slay-the-robot/architecture/04_regression_validation.md)。Dictionary merge 已以紅綠測試修復，已驗單場戰鬥勝敗及跨程序存讀續玩；後續資源清理的實作與最新驗收見 [生命週期報告](../analysis/slay-the-robot/architecture/05_resource_lifecycle.md)。相關文件與導航均在 mycardgame，PAS 原件僅作歷史來源。

## workflows 導入來源

後續由 AI agent 持續改程式；本專案已補齊 [遊戲開發流程](workflows/game-dev/README.md)、[協作與交接](workflows/agent-session.md) 及 [經驗整理](workflows/learning.md)。agent 在授權任務內負責實作、驗收與受影響文件同步，不把可重複經驗只留在對話。

使用者將 wf/ 定位為結構化記憶與操作技能。圖像／聲音／UI、卡牌設計／評量、敵人與關卡工作流都先對照實際框架，再建立輸入、步驟與驗收契約；核實事實集中在 [設計與呈現分析](../analysis/slay-the-robot/design/README.md)。目前沒有自動平衡模擬器或額外 MCP；只有日後反覆任務與穩定工具介面確實需要時，才評估服務化。

後續以不同任務做 [首次接手演練](../analysis/slay-the-robot/onboarding/README.md)，依實際阻礙補第一個 mod、分層關卡、整局與持久化流程。文件復走、候選範例實跑及正式遊戲驗收各自留證據，不能互相代替；具體子流程由遊戲開發入口派發。

來源為本機 `C:/code/mine/workflows`，讀取時 HEAD 為 `794d6d23322a93e0f65e3748375351904fa67066`，模板標記 v0.6。使用其 tools/wf-init.sh，以 `--flavor dev --non-invasive wf` 產生骨架；沒有修改來源 repo。授權副本見 [LICENSE.workflows](LICENSE.workflows)。

環境、驗證、code map 與偏好已更新為目前事實；尚未建立發行版 export 驗證。後續升級依來源 IMPORT.md 的 kernel-owned / project-owned 分類處理，保留已填的專案內容。
