# 題材內容包：隔離載入、probe 與邊界

[內容入口](../content.md)｜[驗證](../../testing.md)

**何時用**：某款遊戲的內容（卡牌、角色、敵人、素材、少量覆寫腳本）以獨立 mod 包放在其題材樹 `games/<game>/pack/`，要驗它能被框架載入、並跑實際遊戲流程。

**何時不用**：改框架本體或框架範例內容 → 照一般 game-dev 流程與既有 suite；從零試教學 mod → [第一個 mod](bootstrap.md)。

## Done when

`python3 tools/test_game.py --suite Smoke --pack games/<game>/pack --pack-tests games/<game>/tests` exit 0，輸出含該題材 probe 的 `PASS:` 斷言與 `PACK PROBE DONE:`；不帶 `--pack` 的框架 Smoke 仍 exit 0。

交付可玩流程時，再跑 `--suite PackScenario --content-profile pack --pack DIR --pack-tests DIR`；依 [scenario 契約](../../testing/suites.md#packscenario) 宣告跨程序階段與真實行為斷言，每階段均通過。載入 probe 不代替流程驗收。結果矩陣放在 tests 目錄外，避免填入 PASS 後改變已驗輸入 hash（[案例](../../../../examples/board-lab/README.md)）。

驗 [可玩副本](playable-copy.md) 時，以 `--source-game <prepared>/game` 代替 `--pack` 並指定 pack profile；runner 須通過 prepare manifest 身分、完整輸出／安裝包 hash 與設定核對，再驗複製快照。任意來源不能豁免，來源副本有新增／變動的非排除內容就重新準備。

## 包的形狀

- `games/<game>/pack/mod_info.json`：`mod_folder_to_load_data`／`mod_script_file_paths` 的 key 一律寫 `external/mods/<name>/...`（相對 game 根）。runner 由這個前綴決定安裝名，與來源資料夾名（通常就叫 `pack`）無關；前綴必須只有一個。
- 資料 JSON 的 object_id 帶該題材前綴；刻意 patch 框架 id 時在題材樹登記例外（boundary lint 檢查）。
- 資料夾只載直接列出的 `.json`（不分大小寫），不遞迴；佔位檔與備份略過，真正 JSON 的錯誤仍須失敗。
- probe：`games/<game>/tests/<name>_probe.gd`，`extends RefCounted`，定義 `check_loaded(global_data: Node) -> Dictionary`，回傳 `{斷言標籤: bool}`。標籤以題材前綴開頭，Smoke 逐項印 `PASS:`／`FAIL:`，完成後印 `PACK PROBE DONE: <檔名>`。同目錄其他 `.gd` 只複製、不呼叫，probe 以自身路徑相鄰載入。

## 開新題材樹

`python3 tools/new_pack.py <name> --prefix <pfx>` 從範本樹複製骨架（AGENTS／NOTICE／design／wf 詞表與 boundary.json／含一個自備顏色的 pack／probe），並把名稱與前綴加進新樹的詞表；已存在的目標、範本自身名稱與已被占用的前綴會被拒絕。合成測試 `python3 -I tests/test_new_pack.py`。

## runner 做什麼

- `--pack DIR`（可重複）：在每個 suite 的隔離副本複製到 `external/mods/<name>/`（略過 symlink），改寫**副本**的 `mod_list.json`（enabled、`load_priority` 從 10 起依序），manifest 的 `packs` 記每檔 SHA-256。來源 `game/` 與 `game/external/mod_list.json` 不動；安裝名與既有 mod 資料夾衝突即失敗。
- Smoke 的 `--pack-tests DIR` 可重複且需 `--pack`：複製到 `<run>/Smoke/pack_tests/`，hash 記在 `pack_test_hashes`，每個 `*_probe.gd` 以 `--pack-probe=<path>` 傳入；缺任一 `PACK PROBE DONE:` 即失敗。PackScenario 僅接受一個 tests 目錄。
- 其他 suite 帶 `--pack` 時內容包同樣被載入（疊在框架範例資料上，同 id 即 patch），但只有 Smoke 呼叫 probe。

## 內容側寫（不依賴框架範例內容）

框架預設以 `GlobalTestDataGenerator` 生成範例／測試內容，內容包疊在其上。`--content-profile pack` 支援 Smoke／PackScenario，通常需 `--pack`；已驗證的 [可玩副本](playable-copy.md) 可供 PackScenario 以 `--source-game` 代替。參數傳給 `Global.get_content_profile()` 後跳過生成，只載 external 資料與啟用的 mod；未給參數時讀 `game/content_profile`，預設 `test`，未知值記 ERROR 並退回 `test`。pack 側寫的 Smoke 驗範例內容不存在與 JSON patch，略過 example_mod probe，再跑包內 probe。本地補丁 `content-profile.patch` 也讓 NewRunMenu 容忍空的難度修正清單，見 upstream.json。

```bash
python3 tools/test_game.py --suite Smoke --content-profile pack --pack games/<game>/pack --pack-tests games/<game>/tests
```

pack 側寫通過只代表載入與主選單初始化不靠範例內容；內容包須自備其引用的基礎資料，見下節清單。

## 題材包須自備的基礎資料清單

題材包不依賴框架範例內容（pack 側寫下範例 id 不存在）。包內每個被引用的 id 都要自己提供，並帶題材前綴；mod_info 的 `mod_folder_to_load_data` 要登記對應資料夾與 `class_name`／`table_name`。每個資料夾 key 必須以 `/` 結尾：FileLoader 直接拼接 key 與檔名，少了斜線會把兩者黏成不存在的路徑。啟動前以實際 JSON 檔名逐項檢查拼接結果，不能只驗資料夾存在；首度踩坑與檢查方法見 [bootstrap](bootstrap.md#第一批應寫檔案)。

- 顏色（`ColorData`，`colors/`，表 `_id_to_color_data`）：每張卡的 `card_color_id` 指向的顏色；最小一筆即可，`color` 為 `#rrggbbaa` 字串，圖示路徑可留空。
- 卡牌（`CardData`，`cards/`）：不得引用框架範例的卡、關鍵字或顏色 id。
- 角色與起始牌組（`CharacterData`，`characters/`）：要實際開局時才需要，且起始牌只列包內卡；骨架階段尚未提供。
- 素材（sprites／audio）：路徑留空或指向包內檔案；缺圖的行為未驗。
- 驗證：probe 逐項斷言這些 id 已註冊（比照題材 probe 的「own color registered」類斷言）。

戰鬥規則（`CombatRulesData`，`combat_rules/`，表 `_id_to_combat_rules_data`）選填；缺省由 `Global.get_combat_rules()` 供應預設。提供 `combat_rules_default`（列入 `allowed_unprefixed_ids`）可覆寫欄位：test 側寫 patch，pack 側寫以類別預設新建。消費端已涵蓋抽牌／能量、CTB、棋盤／位移、波次與 ZOC；場域另用 FieldData。欄位支援與驗收依 [戰鬥框架 spec](../../../specs/combat-framework/README.md)，不可將 schema 存在當作實際流程已覆蓋。

## 編輯器載入（本機）

以 symlink／junction 讓本機編輯器載入內容包的工具與限制，見 [編輯器載入與邊界檢查](pack-tools.md#編輯器載入本機)；runner 驗包一律用 `--pack`。

## 邊界檢查

`python3 tools/boundary_lint.py` 與文件 lint 一起跑，`violations=0` 才通過；R1–R4 規則見 [編輯器載入與邊界檢查](pack-tools.md#邊界檢查)。

## 限制

內容包預設疊在框架範例資料之上；載入通過不代表出牌、遭遇、存讀已驗。新增卡的行為仍依卡牌／機制流程補專項斷言。
