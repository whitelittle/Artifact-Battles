# 圣遗物大乱斗 · R2.1

Demo 内名称为「提瓦特背包乱斗」。UI 修改请先阅读 [UI_HANDOFF.md](UI_HANDOFF.md)；R2.2.1 界面改版的交接说明见 [HANDOFF.md](HANDOFF.md)，待办见 [BACKLOG.md](BACKLOG.md)。

8名角色、140件物品、34条战后合成配方。选角 → 购买与整理 → 选择天赋／专精 → 同轮次构筑匹配 → 自动战斗 → 结算与合成 → 下一轮。标准模式10胜或5败，10胜后可选生存至18轮；无尽模式在18轮后沿用末轮经济和生命上限继续，仍受5次失败限制。

## 运行与导入

网页入口直接执行相同的 Lua 和模拟器存档。可在商店、背包和储物区直接拖放；绿色表示几何位置合法、红色表示不可放置，松手时完成购买与放置。取消商店拖放不扣钱。也保留点击购买后点击格子放置的方式。旋转、储物、出售、撤销摆放、扩容、商店锁定、刷新和配方图鉴均有按钮。键1旋转、2刷新、3切换战后合成、4出战／下一轮、5取消选择；网页也支持鼠标右键取消。选中物品可追踪相关配方，循环至末条后取消；材料在商店以◆标记，完成后显示已拥有。相邻材料在战后自动合成，空间不足会保留原材料。储物物品不参战。

依次导入 `01-ui.gia`、`02-templates.gia`、`03-script.gia`；在模拟器运行 `backpack/main`。完整存档为 `backpack-r2.qx-save.json`。不要将R1和R2主脚本同时挂载。GIA通过真实模拟器导出并重新导入，验证脚本映射与Lua源完全一致。千星正式客户端尚未实测。

## 开发

保留的模拟器源码：`vendor/miliastra-beyond-simulator`，GPL-3.0-only。依赖版本见 `vendor/deps/package.json`、`package-lock.json`。运行 `npm run setup` 安装锁定依赖并建立源码链接。`node game/build.mjs` 生成GIA、Lua和存档；`node build.mjs` 构建网页。

测试：`node game/tests/engine.mjs`、`node game/tests/optimization.mjs`、`node game/tests/content.mjs`、`node game/tests/balance.mjs`、`node game/tests/core-balance.mjs`、`node game/tests/matching.mjs`、`node game/tests/progression.mjs`、`node game/tests/native.mjs`、`node test-browser-core.mjs`。美术拟合：`python game/scan-portraits.py` 生成当前默认立绘。另保留 `python game/vector-portraits.py` 后 `node game/triangulate.mjs` 的轮廓三角拟合备选管线。需要Pillow/numpy/contourpy；三角剖分使用earcut。默认字体由运行环境提供。

## 匹配与数值

576套合法电脑构筑覆盖18轮、8角色、4档预算；同轮次候选先按本轮购物前的构筑筛选，结合最近3场结果小幅调整目标，再进行两个固定种子的分步预演。保留近似候选中的随机波动与近期重复惩罚。本轮买到强装备、完成整理或选择天赋之后，匹配基准不立即上调，因此保留本轮升级收益。每帧最多推进60个战斗模拟步，避免一帧执行整场预演。近期自己的合法镜像也可入池，最多36条，重开保留。双方遵循相同规则，敌人不接受动态属性修正。预演并非胜率承诺；流派克制、暴击和实际战斗种子仍会改变结果。无联网玩家匹配。

采用固定的原作参考经济、生命和稀有度曲线，而非声称与最新补丁完全一致；本作角色核心、道具战斗效果和配方是改编。耐力限制、治疗触发阈值、有限料理次数、加速／暴击／护盾上限、17秒后的疲劳共同约束成长。平衡报告是有限构筑抽样，不能替代玩家测试。

## 美术与界面

8名角色使用同一套硬边色块动漫方向，保留透明PNG原图；模拟器用64色扫描段合并为矢量矩形拟合，不依赖外链贴图。网页和GIA使用同一拟合数据。保留单图元仿射三角备选方案，默认以矩形拟合保留脸部和服饰细节；角色图元池按需扩充、每帧最多创建60个控件并限制队列操作数；首次仅创建默认角色，对手在开战前准备，战斗计时开始后不新增控件。采用量化源图逐像素一致的矩形覆盖优化；不表示与原始PNG无损一致。拟合有细节损失，细小面部和饰品仍需美术精修。UI、道具图标使用基本矢量图元。

## 来源与改编边界

- 原作介绍：https://store.steampowered.com/app/2427700/Backpack_Battles/
- 固定成长曲线、稀有度与轮次参考：https://wikiwiki.jp/bpb/includex引用リスト
- 背包／商店／合成参考：https://wikiwiki.jp/bpb/ゲームシステム
- 原神物品目录：https://wiki.biligame.com/ys/武器一览 、https://wiki.biligame.com/ys/食物一览 、https://wiki.biligame.com/ys/材料
- 衔珠海皇：https://wiki.biligame.com/ys/衔珠海皇
- 便携营养袋：https://wiki.biligame.com/ys/叁零式·便携营养袋

“应急食品立牌”等梗道具为本作改编，不是原神官方可装备物品；所有数值、相邻效果、配方和角色专精均服务于此Demo。未接入抽卡、付费或原作账户。

## R2.1 补充

结算可打开战斗贡献分析，按物品查看直接／附加攻击伤害、治疗、护盾、触发次数和耐力等待。持续伤害、核心伤害及反伤单独统计，不重复分摊给单件物品；疲劳不记入玩家伤害。提示基于实际记录，不保证给出唯一最优解。耐力预算是自然恢复与静态冷却估算，不计料理、减速和临时增益。修复再生未响应相邻治疗增益的问题，并去除对无效联动的高亮。

继续沿用R2的导出文件名、版本2存档格式和挂载标识，便于替换导入；旧存档缺少新增可选字段时仍可读取，后续轮次会建立新的匹配基准。

## 本地网页试玩

需要 Node.js 22+、npm 和 Python 3。在仓库根目录运行：

```sh
npm run setup
npm run build
python -m http.server 8080 --directory dist
```

打开 http://localhost:8080 。网页通过 HTTP 加载模拟器存档，请使用本地服务器。完整交付包在 `dist/downloads/demo.zip`；修改后执行 `npm run package` 更新交付包（需先构建）。
