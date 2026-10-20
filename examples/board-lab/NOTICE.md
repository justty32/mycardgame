# Board Lab 來源與授權

[示範包入口](README.md)

此包為 mycardgame 的中性內容示範。它依賴專案內的 Slay-The-Robot 框架與既有素材，不含第三方題材、外部抓取圖像或新音訊。

框架來源：DesirePathGames/Slay-The-Robot，固定上游版本 `4dac5abe0d19382f8ace2cec5ed3fd77e2a0e11d`，加本專案來源鎖記錄的修補。來源鎖見 [tools/upstream.json](../../tools/upstream.json)。

角色圖像參照 `game/external/sprites/characters/character_red/character_red.png` 與同目錄的 `character_red_icon.png`；敵人圖像參照 `game/external/sprites/enemies/enemy_yellow_small.png`。圖像沿用框架內的原檔，包只宣告 AnimationData 路徑與狀態，不重新發行一份來源不明的替代圖。準備可玩副本時保留 `game/LICENSE` 及各 addon 自己的授權檔。

以下保留上游專案 MIT 授權全文；若日後換用素材，應依實際來源另補授權與歸屬記錄。

```text
MIT License

Copyright (c) 2025 DesirePathGames

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
