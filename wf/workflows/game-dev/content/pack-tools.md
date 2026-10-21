# 題材內容包：編輯器載入與邊界檢查

[題材內容包](pack.md)｜[內容入口](../content.md)｜[驗證](../../testing.md)

**何時用**：要在本機編輯器實際載入某個內容包，或要確認框架與題材樹的邊界規則（boundary lint）。

**何時不用**：驗包的載入與遊戲流程一律用 runner 的 `--pack`（見 [題材內容包](pack.md)），不靠本機 link。

## 編輯器載入（本機）

`python3 tools/link_pack.py games/<game>/pack` 建 `game/external/mods/<name>` symlink（POSIX 為相對路徑；Windows 先試 symlink、再退 `mklink /J` junction）。2026-10-20 Windows 11／Python 3.13 已用隔離 fixture 驗真實 junction、空白路徑、unlink 保留 target 與 runner 排除；Python 3.10／3.11 的 junction 辨識以 reparse tag 退路，已在 3.13 模擬缺 API 驗證。該路徑由 .gitignore 的 `/game/external/mods/*`（只放行 example_mod）蓋住。加 `--enable` 會在追蹤中的 `mod_list.json` 插一行，**不得 commit**；`--unlink` 移除 link 並逐位元組還原該行，保留 LF／CRLF／BOM。回歸入口 `python3 tests/test_link_pack.py`。runner 複製時略過 link，並從隔離副本的 mod_list 拿掉被 link 的 mod；要測該包一律用 `--pack`。拒絕取代或刪除真實 mod 資料夾。

## 邊界檢查

`python3 tools/boundary_lint.py`（合成測試 `python3 tests/test_boundary_lint.py`）與文件 lint 一起跑，`violations=0` 才通過：

- R1：框架目錄（game/ tools/ tests/ analysis/ wf/ examples/ .claude/）不寫具體題材樹路徑，只用 `games/<game>/` 佔位；連入題材樹的路由只放根目錄檔。
- R2：一棵題材樹不引用另一棵（路徑字樣或相對連結）。
- R3：`games/<game>/wf/forbidden-terms.txt` 的詞只准出現在該題材樹；框架目錄、根目錄檔與其他題材樹都掃，`games/` 頂層索引檔例外。非商業授權參考的名稱也列在該題材的詞表。
- R4：`games/<game>/wf/boundary.json` 宣告 `pack_prefix`；pack 內除 mod_info.json 外每個 object_id 都要帶前綴，刻意 patch 框架 id 列入 `allowed_unprefixed_ids`。有 pack/ 卻沒有 boundary.json 也算違規。

