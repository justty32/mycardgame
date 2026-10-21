# Board Lab — 中性雙盤示範包

用正常「新遊戲 → 角色 → 起點教學 → 地圖」入口，走完三場固定戰鬥。前兩場勝利後可以選牌並返回地圖，最後一場 Boss 結束本局。內容示範跨盤攻擊、移動、交換、場域與控制區；不依賴測試資料生成器，也不把任何題材寫進框架。

## 準備可玩副本

在專案根目錄執行：

```bash
python tools/prepare_pack.py --pack examples/board-lab/pack
```

工具會印出新建的 `artifacts/playable/<uuid>/game/project.godot` 絕對路徑與後續手動命令。這份副本使用 pack profile，只啟用這個示範包；安裝名是 `board_lab`。命令本身不啟動 Godot、不操作視窗，也不修改原專案的個人 `mod_list.json` 或存檔。使用支援基準與取得方式見 [開發環境](../../wf/workflows/dev-env.md)。

開啟圖形介面與人工遊玩由使用者自行決定；本輪 agent 僅執行檔案操作與 headless 驗證。請在工具列出的副本啟動新遊戲，選擇 **Board Lab Pilot**，閱讀並選取起點的 **開始三場試驗**，再進入地圖上的第一個戰鬥節點。原始 `game/` 的預設測試內容不是此包的啟動入口。

## 啟用前注意

- **全域規則覆寫**：[pack/combat_rules/combat_rules_default.json](pack/combat_rules/combat_rules_default.json) 沿用框架的全域預設 ID，啟用本包後，該 profile 內**所有戰鬥**都改用雙盤（`board_mode=1`）、借機攻擊控制區、10 抽／10 手牌與每行動 2 免費移動，不只示範遭遇。所以只在上述隔離副本的 pack profile 使用，不要加入基礎或其他題材的 `mod_list`。
- **地圖腳本路徑寫死**：[pack/acts/demo_act.json](pack/acts/demo_act.json) 的 `act_action_script_path` 是 `res://external/mods/board_lab/scripts/ActionGenerateBoardLab.gd`。它只在安裝名為 `board_lab`、從專案目錄執行（`res://` 前綴）時有效；匯出版的 external 目錄改在執行檔旁（見 `FileLoader._ready`），或改了安裝名，都會找不到腳本，地圖無法生成。目前尚未提供與安裝位置無關的寫法，匯出未驗證。

## 怎麼玩

角色有 70 HP、每回合 5 能量，起手牌組共十張。兩個 5 × 5 棋盤有獨立座標；跨到另一盤不會改變陣營。「定點打擊」是普通單體攻擊，直接選敵人且沒有射程限制；帶棋盤選項的其他牌依各自射程與形狀判定。「跨步」選空格移動，「換位」與敵人交換站位；「近身推擊」只適用同盤。

先用「伏能格」在空格建立場域，再「跨步」站進場域，最後「換位」把敵人送進去。從敵人相鄰格移動可能遭借機攻擊，即使目的地仍相鄰；本包的強制換位豁免。位移前查看敵人意圖、卡牌範圍與控制區，避免只憑畫面距離推算。第一場認識基本跨盤操作，第二場有兩個敵人，最後的 Warden 有較強攻擊與防禦空窗。這是可玩的功能範例，不是平衡過的遊戲。

戰鬥勝利後在獎勵畫面選牌或繼續，回地圖再進下一場。正常存讀沿用副本自己的 profile；回歸測試另用 runner 的隔離 profile，不把兩者存檔混用。新一輪準備副本會產生新目錄，不會自動搬移上一輪進度。

## 修改與驗證

[最終證據](evidence/README.md)：來源安裝與可玩副本各通過 257 項 headless 流程檢查。

[設計與流程](design.md) 說明固定路線及驗收界線；[pack/mod_info.json](pack/mod_info.json) 是所有資料資料夾的唯一登記入口。[自訂 Act 腳本](pack/scripts/ActionGenerateBoardLab.gd) 經由 ActData 既有接點載入，不覆寫共用世界生成器。調整內容時依 [內容包工作流](../../wf/workflows/game-dev/content/pack.md)；卡牌效果與難度評價分別依 [卡牌設計](../../wf/workflows/game-dev/card-design.md) 和 [卡牌評量](../../wf/workflows/game-dev/card-evaluation.md)。

[驗收映射](verification.json) 保存九項流程的範圍、測試檔、可定位斷言、驗證狀態與證據路徑；目前結果以表內狀態為準。此表放在測試目錄之外，更新驗收結果不會改變 runner 已保存的測試來源 hash。

動畫使用既有素材的單格 idle／attack／death 狀態，沒有新增音訊。素材與框架來源見 [NOTICE](NOTICE.md)。headless 通過只證明被執行的流程與斷言；畫面、音訊、操作感與平衡都未驗。
