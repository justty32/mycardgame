# 題材內容包：隔離載入、probe 與邊界

[內容子流程](README.md)｜[內容入口](../content.md)｜[驗證](../../testing.md)

**何時用**：某款遊戲的內容（卡牌、角色、敵人、素材、少量覆寫腳本）以獨立 mod 包放在其題材樹 `games/<game>/pack/`，要驗它能被框架載入。**何時不用**：改框架本體或框架範例內容 → 照一般 game-dev 流程與既有 suite；從零試教學 mod → [第一個 mod](bootstrap.md)。

## Done when

`python3 tools/test_game.py --suite Smoke --pack games/<game>/pack --pack-tests games/<game>/tests` exit 0，輸出含該題材 probe 的 `PASS:` 斷言與 `PACK PROBE DONE:`；不帶 `--pack` 的框架 Smoke 仍 exit 0。

## 包的形狀

- `games/<game>/pack/mod_info.json`：`mod_folder_to_load_data`／`mod_script_file_paths` 的 key 一律寫 `external/mods/<name>/...`（相對 game 根）。runner 由這個前綴決定安裝名，與來源資料夾名（通常就叫 `pack`）無關；前綴必須只有一個。
- 資料 JSON 的 object_id 帶該題材前綴；刻意 patch 框架 id 時在題材樹登記例外（boundary lint 檢查）。
- probe：`games/<game>/tests/<name>_probe.gd`，`extends RefCounted`，定義 `check_loaded(global_data: Node) -> Dictionary`，回傳 `{斷言標籤: bool}`。標籤以題材前綴開頭，Smoke 逐項印 `PASS:`／`FAIL:`，完成後印 `PACK PROBE DONE: <檔名>`。同目錄其他 `.gd` 只複製、不呼叫，probe 以自身路徑相鄰載入。

## runner 做什麼

- `--pack DIR`（可重複）：在每個 suite 的隔離副本複製到 `external/mods/<name>/`（略過 symlink），改寫**副本**的 `mod_list.json`（enabled、`load_priority` 從 10 起依序），manifest 的 `packs` 記每檔 SHA-256。來源 `game/` 與 `game/external/mod_list.json` 不動；安裝名與既有 mod 資料夾衝突即失敗。
- `--pack-tests DIR`（可重複，需 `--pack`，suite 須含 Smoke）：複製到 `<run>/Smoke/pack_tests/`，hash 記在 `pack_test_hashes`，每個 `*_probe.gd` 以 `--pack-probe=<path>` 傳給 Smoke；缺任一 `PACK PROBE DONE:` 即判失敗。
- 其他 suite 帶 `--pack` 時內容包同樣被載入（疊在框架範例資料上，同 id 即 patch），但只有 Smoke 呼叫 probe。

## 編輯器載入（本機）

`python3 tools/link_pack.py games/<game>/pack` 建 `game/external/mods/<name>` 相對 symlink（Windows 先試 symlink、再退 `mklink /J` junction，**Windows 路徑未實測**）；該路徑由 .gitignore 的 `/game/external/mods/*`（只放行 example_mod）蓋住，link 後 `git status` 不變。要在編輯器實際載入再加 `--enable`：在追蹤中的 `mod_list.json` 插一行，`git status` 會顯示已修改，**不得 commit**；`--unlink` 移除 link 並逐位元組還原該行。runner 複製時略過 link，並從隔離副本的 mod_list 拿掉被 link 的 mod，框架 Smoke 不受本機 `--enable` 影響；要測該包一律用 `--pack`。拒絕取代或刪除真實 mod 資料夾。

## 限制

內容包預設疊在框架範例資料之上；載入通過不代表出牌、遭遇、存讀已驗。新增卡的行為仍依卡牌／機制流程補專項斷言。
