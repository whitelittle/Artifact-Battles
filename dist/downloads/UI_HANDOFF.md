# UI 修改交接 · R2.1

当前交付包含可运行原生 Lua、真实模拟器、3 个 GIA、网页入口和 8 名角色原图。玩法版本为 R2.1：8 角色、140 道具、34 配方、576 套合法电脑构筑。请从本文件定位 UI，再阅读 README 的运行步骤。

## 修改入口

| 文件 | 职责与建议 |
| --- | --- |
| `game/src/ui.lua` | 原生界面主入口；颜色、面板、按钮、矢量图标、角色显示、商店、背包、详情、结算和交互布局都在这里 |
| `dist/index.html` | 网页外壳和模拟器外部按钮；并非实际游戏面板 |
| `src/main.js` | Pixi 渲染、画布输入、快捷键、存档桥接；触摸和右键取消从这里接入 |
| `dist/portraits/*.png` | 8 名角色透明 PNG 原图，可作为统一美术方向参考 |
| `game/art/portraits.json` | 原生角色矢量矩形拟合数据；由生成脚本产出 |
| `game/scan-portraits.py` | 当前 64 色、192 像素宽扫描拟合管线，改图后重建需 Pillow/numpy |
| `game/src/engine.lua` | 纯 Lua 规则、存档、匹配、战斗；纯视觉修改通常无需改动 |
| `game/data/catalog.json` | 道具、角色、配方和数值；图标类型映射在 UI 的 `iconData` |
| `game/build.mjs` | 将规则、数据、拟合和 UI 打包成 Lua、存档与 GIA，含重新导入校验 |

`game/legacy/`、`vendor/browser-adapter/` 和 `dist/archive-r1/` 是历史备份，含旧环境路径，不作为当前开发入口。以仓库根目录的 npm 命令为准。

## 布局、风格与交互约束

UI 使用 1600×900 逻辑画布，左下角为原点；根节点按画布等比缩放并居中。`ui.lua` 顶部的 `colors` 是调色板，`panel`、`button`、`shape`、`text` 是基础组件；`iconData` 绘制道具图标；`render` 更新当前视图。可以先替换组件皮肤和颜色，再逐面板调整布局。

背包当前原点为 (56,325)，格宽 84、格高 56，输入映射与绘制位置必须一起更新。拖放保留抓取格偏移；商店拖放先预览，合法落地才扣钱。改布局时检查旋转后的形状、碰撞回退、取消无扣款、储物区及撤销。详情、配方追踪、联动高亮、耐力预算、战斗贡献分析都有玩法用途，改皮肤时保留可达入口。

原生 UI 由图元模板创建，模板 ID 1073742701～1073742704 与导出脚本对应。不要随意更换模板或脚本挂载 ID。只依赖模拟器支持的 Lua UI API；网页 CSS、SVG、外链贴图不能直接代替 GIA 中的原生图元。若希望网页与 GIA 一致，主体 UI 应在 Lua 内修改。

角色使用可复用图元池，按需扩充，每帧最多创建 60 个控件、最多执行 1200 个队列操作；匹配与立绘准备完成才开始战斗。保留延迟创建、`ready` 门控和图元复用，避免每帧重建角色。初始约 9418 个控件，全部角色与对手展开后会增加。保持 `ExportSave`、`ImportSave`、`Inspect`、`CancelInteraction`、`OpenCharacterPicker` 的桥接接口。

## R2.2 元素主题 UI 说明

- 主题：`ui.lua` 顶部 `THEMES`（electro/dendro/geo/hydro/pyro）与 `heroElement`。颜色写作 `'@main'`、`'@face'`、`'@main60'`（带透明度）或 `'@ink_c8'`；`shape`/`text` 会登记主题控件，`applyTheme` 在角色变化时整体重新着色。功能色（品质、放置绿/红、血条）用固定色。
- 组件：`panel`、`tag`、`rshape`（圆角/胶囊）、`button`（果冻按钮，`jellies` 在 OnUpdate 中挤压回弹，控件枢轴为中心）。装饰 `splat`、`dots`、`zigzag` 仅用 100001–100006 图元。
- 布局：主界面 `views.hub`；背包窗口 `views.bagWin`（背包面板坐标不变 + 下方 `toolbox`）；商店窗口 `views.shop`；卡牌 `views.card`（底座、遮罩光效、技能栏）与 `views.cardTop`（粒子、徽章、名牌）。常量 `CX,CY,CW,CH` 为卡牌，`PX,PY,PW,PH` 为立绘窗口。
- 层级顺序：背景 → 主界面 → 背包窗口 → 卡牌底座 → 出战按钮 → 战斗面板 → 开始界面 → 选角 → 角色遮罩层 → 对手 → 卡牌上层 → 商店 → 结算/选择 → 图鉴。光标控件的子节点不会接收点击，可交互区域不要嵌套在光标控件下。
- 开始界面角色：`TS` 为斜向色块（中心、尺寸、角度、角色缩放）。标题姿态下角色居中站在色块上、不裁切；只有卡牌姿态使用遮罩裁切。
- 文字框：`text()` 会把高度撑到至少「字号 × 1.3 + 12」，因为真机会丢弃放不下一整行的文字。
- 动效：`animate(dt)` 只改变换和颜色（立绘呼吸、光芒旋转、光晕、扫光、16 个元素粒子），不新建控件。
- `Inspect()` 新增 `title`、`resumable`、`shopOpen`、`bagOpen`；网页在开始界面不自动存档。

## 开发与验证

```sh
npm run setup
npm run build
npm test
npm run test:simulator
npm run test:browser-core
python -m http.server 8080 --directory dist
```

Node.js 22+；首次安装使用锁定依赖。`npm run build` 会生成 GIA 并校验导入回环，同时重建网页 bundle。测试覆盖规则、内容、成长流程、原生交互与浏览器目标运行时；浏览器目标测试是 VM 测试，仍需人工打开网页检查实际 Pixi 渲染、字体和移动端视觉。

人工走通：8 角色选角 → 商店购买与取消拖放 → 背包移动/旋转/撤销 → 储物/出售 → 配方追踪和联动 → 匹配 → 战斗 → 结算贡献 → 合成 → 下一轮；再检查 10 胜、5 败、生存及无尽分支。原生交互测试包含固定坐标，布局有意改变时同步更新测试坐标。

可直接导入 `dist/downloads/01-ui.gia`、`02-templates.gia`、`03-script.gia`，或打开 `game/out/backpack-r2.qx-save.json`，运行 `backpack/main`。正式千星客户端尚未实测。

修改后先构建与验证，再运行 `npm run package` 更新下载包。不要手工修改 `dist/app.js`、导出的 Lua、GIA 或存档中的嵌入脚本；它们会被源文件重建覆盖。生成前后的文件差异应和实际 UI 修改对应。

## 来源与许可证

保留 `licenses/` 及模拟器源码中的许可证，模拟器为 GPL-3.0-only。角色图的生成记录在 `game/art/sources.json`，拟合说明在 `game/art/ART-NOTES.md`。原神名称和题材属于同人改编；第三方来源详见 README。仓库未附带商用授权声明。
