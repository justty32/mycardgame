# __NAME__ — agent 入口（題材樹）

[README](README.md)｜[NOTICE](NOTICE.md)｜[框架入口](../../AGENTS.md)

本目錄是 __NAME__ 的題材樹，建在 repo 根目錄的題材中立框架上。框架規矩（鐵律、派發、驗證）以根 [AGENTS.md](../../AGENTS.md) 為準，本檔只補題材專屬的入口與邊界。

## 開場

- 先讀根 AGENTS.md 的必讀項，再讀本檔、[NOTICE](NOTICE.md) 與 [wf/](wf/README.md)。
- 玩法決定與任務 spec／plan → [design/](design/README.md)；內容包 → `pack/`（id 前綴 `__PREFIX__`）；題材 probe → `tests/`。

## 邊界

- 題材名詞與參考來源只寫在本題材樹；詞表在 [forbidden-terms.txt](wf/forbidden-terms.txt)，由 boundary lint 機械檢查。
- 通用機制的實作在框架，不放 `__PREFIX__` id。
- pack 內 object_id 一律帶 `__PREFIX__` 前綴（mod_info.json 除外）；自備基礎資料清單見框架 [pack](../../wf/workflows/game-dev/content/pack.md#題材包須自備的基礎資料清單)。

## 驗證

```bash
python3 tools/boundary_lint.py
python3 tools/test_game.py --suite Smoke --content-profile pack --pack games/__NAME__/pack --pack-tests games/__NAME__/tests
```
