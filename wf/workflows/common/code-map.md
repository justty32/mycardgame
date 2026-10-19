# code-map — 程式碼導航 index（哪個檔負責什麼）

[common/README](README.md)｜[INDEX](../../INDEX.md)

碰原始碼前先查這張表，只讀相關領域列出的檔；動完再照維護鏈把表更新回去。寫碼慣例本身在 [conventions](conventions.md)。

## 領域表

| 領域 | 檔案 | 職責 | 測試在哪 |
|------|------|------|---------|
| 工作流 | 根 `AGENTS.md`、`wf/workflows/` | 派發、偏好與開發流程 | `wf/tools/wf-lint.sh --strict .`；邊界 `tools/boundary_lint.py`（合成測試 `tests/test_boundary_lint.py`） |
| 工作流工具 | `wf/tools/` | 上游 kernel 的文件檢查與資料工具 | 同上；目前未修改工具實作 |
| 專案來源 | [PROJECT](../../PROJECT.md) | 上游框架、參考專案與內建教學入口 | strict lint 驗本機連結；來源內容需另核對 |
| 題材樹 | `games/<game>/`（AGENTS、design、wf、pack、tests） | 各款遊戲的設計、決策與內容包；框架不引用 | 內容包模式 Smoke（見 testing） |
| 框架知識 | [analysis/slay-the-robot](../../../analysis/slay-the-robot/README.md) | 本專案維護的教學、分析與日誌 | strict lint 驗本機連結；執行範圍見啟動驗證紀錄 |

## 遊戲領域導航

啟動與內容：[project.godot](../../../game/project.godot)、[Global.gd](../../../game/autoload/Global.gd)、[FileLoader.gd](../../../game/autoload/FileLoader.gd)。註冊 schema、生成資料、載入 mods；驗證用 [framework_smoke.gd](../../../tests/framework_smoke.gd)。

戰鬥與 UI：[ActionHandler.gd](../../../game/autoload/ActionHandler.gd)、[HandManager.gd](../../../game/autoload/HandManager.gd)、[Root.tscn](../../../game/scenes/Root.tscn)。資料流見 [架構總覽](../../../analysis/slay-the-robot/architecture/01_overview.md)；[combat_flow.gd](../../../tests/combat_flow.gd) 搭配 [fixture](../../../tests/combat_fixture.gd) 驗單場戰鬥、獎勵與返回地圖。

戰鬥框架（[spec](../../specs/combat-framework/README.md)，Phase 0）：[UnitRegistry.gd](../../../game/scripts/combat/UnitRegistry.gd) 是 autoload，管 unit_uid、陣營查詢與主角；[BaseCombatant.gd](../../../game/scripts/combatants/BaseCombatant.gd) 帶單位身分欄位與 `_on_own_action_*` hook；[CombatRulesData.gd](../../../game/data/readonly/CombatRulesData.gd) 定戰鬥節奏，`Global.get_combat_rules()` 取用。由 Smoke 呼叫 [unit_registry_probe.gd](../../../tests/unit_registry_probe.gd) 驗證。

整局狀態與結算：[NewRunMenu.gd](../../../game/scripts/ui/menus/NewRunMenu.gd)、[RunSummaryOverlay.gd](../../../game/scripts/ui/RunSummaryOverlay.gd)、[ProfileData.gd](../../../game/data/mutable/ProfileData.gd)、[StatsHandler.gd](../../../game/autoload/StatsHandler.gd)。起局、跨幕、終局與持久化邊界由 [整局流程](../game-dev/game-flow.md) 串接；既有單場測試不代表這些轉移全部覆蓋。

非戰鬥節點：[DialogueData.gd](../../../game/data/readonly/DialogueData.gd)、[DialogueOverlay.gd](../../../game/scripts/ui/DialogueOverlay.gd)、[ShopOverlay.gd](../../../game/scripts/ui/ShopOverlay.gd)、[RestOverlay.gd](../../../game/scripts/ui/RestOverlay.gd)。選項效果、設施與寶箱接線沿 [關卡設計](../game-dev/level-design.md) 的子流程查來源與專項驗收。

序列化與擴充：[SerializableData.gd](../../../game/data/SerializableData.gd)、[擴充契約與限制](../../../analysis/slay-the-robot/architecture/02_extension_points.md)。Dictionary merge 已修，公開 API 回歸見 [dictionary_regression.gd](../../../tests/dictionary_regression.gd)；跨程序讀寫、續玩與拒絕無效輸入見 [save_load_flow.gd](../../../tests/save_load_flow.gd)。

本專案工具：[test_game.py](../../../tools/test_game.py) 為跨平台隔離回歸與流程驗證 runner（Python 3.10+），[test-game.ps1](../../../tools/test-game.ps1) 是沿用舊參數的 Windows 薄包裝；[game.ps1](../../../tools/game.ps1) 為 Windows 專用的舊 Run／Import／Smoke 入口；[upstream.json](../../../tools/upstream.json) 固定來源、引擎政策（基準 4.7.x）與本地修復。[link_pack.py](../../../tools/link_pack.py) 把題材內容包 link 進 game/external/mods/ 供編輯器載入，用法見 [題材內容包](../game-dev/content/pack.md)。

程序診斷：[test_game.py](../../../tools/test_game.py) 本身保存退出碼、原生崩潰標記與逐階段結果；[test_runner_diagnostics.py](../../../tests/test_runner_diagnostics.py) 以不開視窗的假引擎程序驗證 runner，不啟動 Godot。事故判讀見 [native-crash](../game-dev/native-crash.md)，執行前遵守 [使用者操作邊界](user.md)。

資源生命週期：[ActionInterceptorProcessor.gd](../../../game/scripts/action_interceptors/ActionInterceptorProcessor.gd)、[BaseAsyncAction.gd](../../../game/scripts/actions/BaseAsyncAction.gd)、[ActionHandler.gd](../../../game/autoload/ActionHandler.gd) 管理攔截器與等待／取消；Root／Map 離樹與選單型別也在清理範圍。專項入口為 [resource_lifecycle.gd](../../../tests/resource_lifecycle.gd)，實測與檔案責任見 [清理報告](../../../analysis/slay-the-robot/architecture/05_resource_lifecycle.md)。

## 設計與素材導航

[設計來源核實](../../../analysis/slay-the-robot/design/README.md) 串接卡牌／升級／卡包、EnemyIntent／EventPool／Map、圖像／UI 與聲音。未來 agent 先選 [領域工作流](../game-dev/README.md)，再沿該篇指向的實作與資料讀取；資料欄位存在不代表已有完整消費端。

靜態美術沿 [素材製作](../game-dev/art-assets.md) 查 FileLoader 與資料消費端；人物動畫及短效分別沿 [動畫](../game-dev/art-assets/animation.md)、[特效](../game-dev/art-assets/vfx.md) 查 AnimationData、BaseCombatant、AnimatedCombatEffect 與 Action 接點。實際尺寸、播放／等待與回收契約保存在各領域分析。

UI 的 [元件／版面與互動入口](../game-dev/ui/README.md) 導向 Root、Card／Hand、HUD、theme 與 CustomUIData；音訊的 [製作與接線入口](../game-dev/audio/README.md) 導向 [SoundManager](../../../game/addons/sound_manager/sound_manager.gd)、FileLoader 與 SettingsMenu。同一出牌事件跨領域時先用 [演出整合](../game-dev/presentation-delivery.md) 明定觸發及停止責任，不能把素材載入當成完整事件驗證。

任務是完整對話、商店、戰鬥等畫面時，從 [完整場景製作](../game-dev/scene-pack.md) 分派到各用途子流程，以同一狀態轉移串接圖像包、UI、聲音和動畫；基礎元件流程不代替完整畫面的資料與操作契約。


## 真相層優先序

各專案可以改自己的優先序，但必須明確。預設：

```text
code/tests > schema/examples/fixtures > code map > docs > generated
```

- 上層與下層衝突時，**以上層為準並修正下層**。
- generated（產生出來的檔、html）永遠不是唯一真相。
- 原始來源與摘要衝突時，以**原始來源**為準。
- code map 是**導航不是規格**；行為以 code/tests 為準。

## 維護鏈：程式碼 > code map > 文檔

**優先級**（衝突或時間不夠時，依序保持一致）：程式碼 > code map > 文檔。
**code map 與程式碼衝突時以程式碼為準，立刻改 code map。**

1. **修改前**：先讀本表找到相關領域，只讀清單裡的檔——不讀無關領域的檔。
2. **修改後**：新增／刪除了原始碼檔案，或某檔職責顯著改變，必須同步更新本表。
3. 原始碼裡**不加**「對應 code map」的註釋（維護成本過高）；反向查找直接 grep 本檔。
4. 迭代期間本表可暫時落後，**commit 前必須對齊**（見 [feature-dev](../feature-dev/README.md)）。
