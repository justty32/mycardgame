# headless-geometry — 版面與動畫定位驗證

[UI 專項驗證](verification.md)｜[雙盤呈現](../../../specs/dual-board/presentation.md)

**何時用**：修改人物站位、格面、HUD、動畫與 viewport 幾何。

**何時不用**：只驗數值規則不需要畫面節點；視覺觀感或硬體操作不能由本流程替代。

## 流程

先讀 project.godot 的 viewport 設定，再記錄測試 SceneTree root 的實際尺寸。公司 headless `-s` 執行時曾取得 64×64，而正式專案是 1200×700；測試應把隔離虛擬 root.size 設為專案設定後再載入場景，不改實體視窗或焦點。保留 viewport／祖先裁切斷言，不因尺寸錯誤刪除測試。

固定文案（長名、繁中、空值、多段數字、BBCode icon），等 layout／字級穩定後驗必要 rect、minimum size、間距、可見性、theme font 與最低字級。tooltip 的 window size 可能和虛擬 viewport 不同，須提供可驗幾何輸入或明列尚未驗，不假造相同。

人物語意位置與動畫位置分離。腳點取站立基準位置及 idle 素材尺寸：在共用單位 `_ready` 最先保存原始 sprite position 與 offset，早於註冊與 run 動畫。巢狀／繼承場景的 SceneState 不保證直接列出該 property，不能失敗後把 run_start／攻擊／死亡動畫的瞬時偏移快取成永久 anchor。二進位 AnimationLibrary 可由同一 headless 專項唯讀列出相關 track/key；現有 run_start 與 attack 都動畫化 sprite.offset，站立斷言等動畫完成後以實際 sprite 腳底驗算。至少驗普通移動、跨盤、交換拒絕、致死後位置、原動畫完成以及同一 Root 再開 run。資料格先提交，tween 只影響呈現；UID、父節點、timeline membership 與控制者不因呈現而更換。

## Done when

對應專項有實際 assertion／來源 hash 與通過日誌；保留 clip、footpoint、viewport、資料／動畫分離與退出重開證據。背景字型 cmap 只驗字元存在，節點 rect 只驗幾何；字形可讀、遮擋、alpha／對比、DPI、GPU、鍵鼠與手把依 [證據層級](verification.md#證據層級與判讀) 另列未驗。

## 交接

由 [UI 專項驗證](verification.md) 選 suite；新 helper 須實際接到 runner 入口。明列尺寸設定來源、原失敗座標與修後對照，以及未驗的人工作業。
