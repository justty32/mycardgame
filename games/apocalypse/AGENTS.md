# apocalypse — agent 入口（題材樹）

[README](README.md)｜[NOTICE](NOTICE.md)｜[框架入口](../../AGENTS.md)

本目錄是《天启预报》免費同人卡牌遊戲的題材樹，建在 repo 根目錄的題材中立框架上。框架規矩（鐵律、派發、驗證）以根 [AGENTS.md](../../AGENTS.md) 為準，本檔只補題材專屬的入口與邊界。

## 開場

- 先讀根 AGENTS.md 的必讀項，再讀本檔、[NOTICE](NOTICE.md) 與 [wf/](wf/README.md)（題材背景、決策、roadmap、詞表）。
- 玩法決定與任務 spec／plan → [design/](design/README.md)；內容包 → `pack/`（Slay-The-Robot mod，id 前綴 `apo_`）；題材 probe → `tests/`。

## 邊界

- 題材名詞、spire-codex 參考與本遊戲的 spec 只留在本目錄；不寫進框架目錄（game/、tools/、tests/、analysis/、wf/）或其他題材樹。詞表在 [forbidden-terms.txt](wf/forbidden-terms.txt)，由 boundary lint 機械檢查。
- 戰鬥結構等需求寫在 design/；通用機制的實作在框架，用通用命名與框架測試資料，不放 `apo_` id。
- pack 內 object_id 一律帶 `apo_` 前綴（mod_info.json 的 `mod_data_apocalypse` 除外）。

## 驗證

框架驗證照根 AGENTS.md；本題材另跑內容包模式 Smoke，輸出須含 `PASS: APO:`：

```bash
python3 tools/test_game.py --suite Smoke --pack games/apocalypse/pack --pack-tests games/apocalypse/tests
```
