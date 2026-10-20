# 題材內容包：隔離載入、probe 與邊界

[內容子流程](README.md)｜[內容入口](../content.md)｜[驗證](../../testing.md)

**何時用**：某款遊戲的內容（卡牌、角色、敵人、素材、少量覆寫腳本）以獨立 mod 包放在其題材樹 `games/<game>/pack/`，要驗它能被框架載入。**何時不用**：改框架本體或框架範例內容 → 照一般 game-dev 流程與既有 suite；從零試教學 mod → [第一個 mod](bootstrap.md)。

## Done when

`python3 tools/test_game.py --suite Smoke --pack games/<game>/pack --pack-tests games/<game>/tests` exit 0，輸出含該題材 probe 的 `PASS:` 斷言與 `PACK PROBE DONE:`；不帶 `--pack` 的框架 Smoke 仍 exit 0。

## 包的形狀

- `games/<game>/pack/mod_info.json`：`mod_folder_to_load_data`／`mod_script_file_paths` 的 key 一律寫 `external/mods/<name>/...`（相對 game 根）。runner 由這個前綴決定安裝名，與來源資料夾名（通常就叫 `pack`）無關；前綴必須只有一個。
- 資料 JSON 的 object_id 帶該題材前綴；刻意 patch 框架 id 時在題材樹登記例外（boundary lint 檢查）。
- 資料夾只載直接列出的 `.json`（不分大小寫），不遞迴；佔位檔與備份略過，真正 JSON 的錯誤仍須失敗。
- probe：`games/<game>/tests/<name>_probe.gd`，`extends RefCounted`，定義 `check_loaded(global_data: Node) -> Dictionary`，回傳 `{斷言標籤: bool}`。標籤以題材前綴開頭，Smoke 逐項印 `PASS:`／`FAIL:`，完成後印 `PACK PROBE DONE: <檔名>`。同目錄其他 `.gd` 只複製、不呼叫，probe 以自身路徑相鄰載入。

## 開新題材樹

`python3 tools/new_pack.py <name> --prefix <pfx>` 從範本樹複製骨架（AGENTS／NOTICE／design／wf 詞表與 boundary.json／含一個自備顏色的 pack／probe），並把名稱與前綴加進新樹的詞表；已存在的目標、範本自身名稱與已被占用的前綴會被拒絕。合成測試 `python3 -I tests/test_new_pack.py`。

## runner 做什麼

- `--pack DIR`（可重複）：在每個 suite 的隔離副本複製到 `external/mods/<name>/`（略過 symlink），改寫**副本**的 `mod_list.json`（enabled、`load_priority` 從 10 起依序），manifest 的 `packs` 記每檔 SHA-256。來源 `game/` 與 `game/external/mod_list.json` 不動；安裝名與既有 mod 資料夾衝突即失敗。
- `--pack-tests DIR`（可重複，需 `--pack`，suite 須含 Smoke）：複製到 `<run>/Smoke/pack_tests/`，hash 記在 `pack_test_hashes`，每個 `*_probe.gd` 以 `--pack-probe=<path>` 傳給 Smoke；缺任一 `PACK PROBE DONE:` 即判失敗。
- 其他 suite 帶 `--pack` 時內容包同樣被載入（疊在框架範例資料上，同 id 即 patch），但只有 Smoke 呼叫 probe。

## 內容側寫（不依賴框架範例內容）

框架啟動時預設以 `GlobalTestDataGenerator` 生成範例／測試內容（character_red、card_attack_basic…），內容包疊在其上。`--content-profile pack`（僅限 `--suite Smoke` 且至少一個 `--pack`）把 `--content-profile=pack` 傳給引擎，`Global.get_content_profile()` 據此跳過生成，只載 external 資料與啟用的 mod；未給命令列參數時讀專案設定 `game/content_profile`，預設 `test`，未知值記 ERROR 並退回 `test`。pack 側寫的 Smoke 改驗「範例內容不存在」與 JSON patch 契約，略過依賴 character_red 的 example_mod probe，再跑內容包 probe。這是本地補丁 `content-profile.patch`（含 NewRunMenu 容忍空的難度修正清單），見 upstream.json。

```bash
python3 tools/test_game.py --suite Smoke --content-profile pack --pack games/<game>/pack --pack-tests games/<game>/tests
```

pack 側寫通過只代表載入與主選單初始化不靠範例內容；內容包須自備其引用的基礎資料，見下節清單。

## 題材包須自備的基礎資料清單

題材包不依賴框架範例內容（pack 側寫下範例 id 不存在）。包內每個被引用的 id 都要自己提供，並帶題材前綴；mod_info 的 `mod_folder_to_load_data` 要登記對應資料夾與 `class_name`／`table_name`。

- 顏色（`ColorData`，`colors/`，表 `_id_to_color_data`）：每張卡的 `card_color_id` 指向的顏色；最小一筆即可，`color` 為 `#rrggbbaa` 字串，圖示路徑可留空。
- 卡牌（`CardData`，`cards/`）：不得引用框架範例的卡、關鍵字或顏色 id。
- 角色與起始牌組（`CharacterData`，`characters/`）：要實際開局時才需要，且起始牌只列包內卡；骨架階段尚未提供。
- 素材（sprites／audio）：路徑留空或指向包內檔案；缺圖的行為未驗。
- 驗證：probe 逐項斷言這些 id 已註冊（比照題材 probe 的「own color registered」類斷言）。

戰鬥規則（`CombatRulesData`，`combat_rules/`，表 `_id_to_combat_rules_data`）為選填。沒有時 `Global.get_combat_rules()` 退回內建預設，即原行為。要改節奏，就提供框架 id `combat_rules_default`（列入 `allowed_unprefixed_ids`），只寫要改的欄位：test 側寫會 patch 既有物件，pack 側寫以類別預設新建，兩種結果相同。目前只有 `draw_per_action`、`energy_per_action`、`energy_cap` 有消費端，見 [戰鬥框架 spec](../../../specs/combat-framework/README.md)。

## 編輯器載入（本機）

`python3 tools/link_pack.py games/<game>/pack` 建 `game/external/mods/<name>` symlink（POSIX 為相對路徑；Windows 先試 symlink、再退 `mklink /J` junction）。2026-10-20 Windows 11／Python 3.13 已用隔離 fixture 驗真實 junction、空白路徑、unlink 保留 target 與 runner 排除；Python 3.10／3.11 的 junction 辨識以 reparse tag 退路，已在 3.13 模擬缺 API 驗證。該路徑由 .gitignore 的 `/game/external/mods/*`（只放行 example_mod）蓋住。加 `--enable` 會在追蹤中的 `mod_list.json` 插一行，**不得 commit**；`--unlink` 移除 link 並逐位元組還原該行，保留 LF／CRLF／BOM。回歸入口 `python3 tests/test_link_pack.py`。runner 複製時略過 link，並從隔離副本的 mod_list 拿掉被 link 的 mod；要測該包一律用 `--pack`。拒絕取代或刪除真實 mod 資料夾。

## 邊界檢查

`python3 tools/boundary_lint.py`（合成測試 `python3 tests/test_boundary_lint.py`）與文件 lint 一起跑，`violations=0` 才通過：

- R1：框架目錄（game/ tools/ tests/ analysis/ wf/ .claude/）不寫具體題材樹路徑，只用 `games/<game>/` 佔位；連入題材樹的路由只放根目錄檔。
- R2：一棵題材樹不引用另一棵（路徑字樣或相對連結）。
- R3：`games/<game>/wf/forbidden-terms.txt` 的詞只准出現在該題材樹；框架目錄、根目錄檔與其他題材樹都掃，`games/` 頂層索引檔例外。非商業授權參考的名稱也列在該題材的詞表。
- R4：`games/<game>/wf/boundary.json` 宣告 `pack_prefix`；pack 內除 mod_info.json 外每個 object_id 都要帶前綴，刻意 patch 框架 id 列入 `allowed_unprefixed_ids`。有 pack/ 卻沒有 boundary.json 也算違規。

## 限制

內容包預設疊在框架範例資料之上；載入通過不代表出牌、遭遇、存讀已驗。新增卡的行為仍依卡牌／機制流程補專項斷言。
