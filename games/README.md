# games — 題材樹

[專案地圖](../wf/INDEX.md)｜[規劃流程](../wf/workflows/planning.md#遊戲規劃)

框架（game/、tools/、tests/、analysis/、wf/）與題材分層：每款遊戲一個子目錄 `games/<game>/`，內含該遊戲的 `design/`（玩法決定與任務 spec／plan）與 `pack/`（內容包）。框架不知道題材存在；題材間互不連結。

新題材：`python3 tools/new_pack.py <name> --prefix <pfx>` 從 [_template](_template/README.md) 複製出新樹並登記到下表，之後跑 `python3 tools/boundary_lint.py`。

<!-- wf-nav -->
| 遊戲 | 內容 |
|------|------|
| [apocalypse](apocalypse/README.md) | 《天启预报》免費同人（不商業）；pack id 前綴 `apo_` |
