# 啟動與擴充驗證紀錄

> 本篇保留原版初次驗證事實。後續本地修復、戰鬥與存讀結果見 [回歸與流程驗證](04_regression_validation.md)。

[分析入口](../README.md)｜[架構](01_overview.md)｜[擴充方式](02_extension_points.md)｜[測試指令](../../../wf/workflows/testing.md)

2026-10-19，Windows、Godot `4.6.stable.official.89cea1439`，Slay-The-Robot commit `4dac5abe0d19382f8ace2cec5ed3fd77e2a0e11d`。來源與引擎下載 checksum 見 [upstream.json](../../../tools/upstream.json)。上游 checkout 未修改，example_mod 的磁碟清單維持 disabled。

## 啟動結果

Godot editor import 完成，332 個 global script class 掃描／註冊及資源匯入完成。一般 headless 主場景執行 180 frames 後 exit 0；圖形模式成功建立 OpenGL 3.3 Compatibility 視窗，使用 Intel Arc 140V。

[framework_smoke.gd](../../../tests/framework_smoke.gd) 載入真正的 project.godot 主場景，確認主選單 visible、New Run 節點 ready、角色存在與起始牌組全部可解析。正常執行為 **39 checks、0 failures、exit 0**；透過 [game.ps1](../../../tools/game.ps1) 的 Smoke 模式也得到相同結果。

非 headless 的 `--capture` 模式額外等待 frame_post_draw，將遊戲自己的 viewport 輸出成 `artifacts/startup/main-menu.png`，結果 **40 checks、0 failures、exit 0**。已目視確認 1200×700 主選單正常渲染。擷取時存在本機存檔，畫面顯示 Continue／Forfeit Run，不能據此宣稱已驗新遊戲點擊或戰鬥。

原生視窗檢查曾因 app approval timeout 未能完成；上述圖片是測試程式產生的遊戲渲染結果，非原生視窗點擊驗收。沒有把啟動通過等同完整遊戲流程通過。

## 擴充的執行證據

角色起始牌組透過 SerializableData 的 JSON `append`，實際保留原項目並追加新項目。

測試只覆寫 FileLoader 的 mod 清單讀取函式，讓記憶體內的清單啟用官方 example_mod，其餘使用真正 `load_read_only_data()`。已驗證新增卡 `card_modded_card` 註冊、角色起手卡保序追加、腳本 `take_over_path()` 生效、ActionGenerator 建立替換後的 action；磁碟 mod_list.json 前後相同。未執行這張卡的出牌或傷害效果。

Dictionary patch 的初始資料為 `existing=3, shared=1`，輸入為 `added=5, shared=9`。`merge_keep` 與 `merge_overwrite` 的實際結果都只剩 `added=5, shared=9`，原有 existing 消失。這重現 [SerializableData.gd](../../../game/data/SerializableData.gd) `set_serializable_properties()` 普通字典分支寫回 temp_value、未採用 patched_dictionary 的問題。該項列為 KNOWN ISSUE 診斷，**沒有修正，也不列入啟動 PASS 的斷言**；依賴合併功能前需另修並建立回歸測試。

## 失敗出口與副作用

`--force-failure` 控制組得到 **40 checks、1 failure、exit 1**，確認外層可以辨識失敗。測試有 45 秒事件迴圈 timeout，子測試也有完成旗標以避免 GDScript 錯誤後誤報成功；若發生同步卡死仍需外層終止程序。

測試本身不開始 run；profile/settings 在主場景建立前轉向 artifacts/test-runtime/，但 autoload 的首次 ready 已先讀取或建立 game/external 的原始檔案。現有存檔保留，測試不執行刪除或覆寫存檔操作。

## 上游基準問題

舊 `icon.svg` UID 會 fallback 到文字路徑；FileLoader 的 missing_texture 外部 image 載入產生 export 警告；結束時有 ObjectDB instances leaked 與 `1 resources still in use`。Import、普通 headless 與 smoke 均可看到關閉訊息，未出現最終 smoke 的 SCRIPT ERROR。Exit 0 不表示零警告或沒有資源洩漏。

首輪沙箱執行曾無法讀 root certificate store、寫 user:// 與 editor settings，核准後重新匯入已排除這些環境訊息。冷啟動的 SoundManager UID 在資源 cache 建立後可解析；不需為此改上游程式。

## 本機證據與驗收邊界

日誌位於 artifacts/startup/：import-verified.log、headless.log、gui-interactive.log、framework-smoke.log、framework-smoke-failure.log、framework-smoke-capture.log、smoke.log。artifacts/ 為可重建輸出，不當作程式碼依賴。

尚未涵蓋完整戰鬥、敵人與卡牌所有效果、存讀往返、發行版匯出，以及更正後教學的所有自訂內容。這些應隨後續遊戲功能逐項驗收。
