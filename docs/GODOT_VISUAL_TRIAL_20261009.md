# 2026-10-09 · Godot 港口视觉试片 02

后续评审：用户已明确否定本轮美术，认为基础且缺少 HD-2D 观感。当前结论与下一步以 [深入复盘](GODOT_HD2D_DIRECTION_RESET_20261009.md) 为准。本页保留实现和原始证据，不代表美术达标。

本轮接上“规划 Godot 重做路线”的已有工程，研究新增 B 站参考后，继续到实际 Forward+ 场景、截图和原速动作影片。不是概念图或视频背景，也不是完整游戏。

## 打开与运行

```powershell
./tools/godot-harbor.ps1 -Mode Play
```

工程：`Godot/project.godot`；引擎：`Local/Godot/4.7.2/`。已使用 Godot 4.7.2 stable、Vulkan Forward+、RTX 4090 实际运行。

WASD／方向键移动；1 总览、2 码头、3 人物跟随近景；滚轮缩放；T 切昼暮；G 固定路线漫步；Tab 隐藏文字；F12 保存截图。手动移动可立即接管漫步，不等待动作片段结束。手动截图不会启动自动镜头时间线。

评审文件：[`Artifacts/Harbor-v02/20261009-final/`](../Artifacts/Harbor-v02/20261009-final/)。
打开其中的 `index.html`，或运行 `D:/miniforge/python.exe tools/preview_harbor.py` 后访问 [本地评审页](http://127.0.0.1:8374/Harbor-v02/20261009-final/)。预览服务只监听本机，支持影片分段跳转。

## 实际交付

| 文件 | 内容 |
| --- | --- |
| [harbor-tour.mp4](../Artifacts/Harbor-v02/20261009-final/harbor-tour.mp4) | 30.17 秒、1280×720、30 fps；白昼漫步、轻微镜头移动、码头折返、傍晚和人物近景 |
| [01-harbor.png](../Artifacts/Harbor-v02/20261009-final/01-harbor.png) | 1600×900 白昼总览 |
| [03-shore-and-ship.png](../Artifacts/Harbor-v02/20261009-final/03-shore-and-ship.png) | 人物、甲板、岸水与船的同镜头检查 |
| [05-actor-light.png](../Artifacts/Harbor-v02/20261009-final/05-actor-light.png) | 傍晚人物近景与环境受光 |
| [06-dusk-harbor.png](../Artifacts/Harbor-v02/20261009-final/06-dusk-harbor.png) | 同一港口的傍晚总览 |
| `capture-report.json`、`godot-run.log` | 引擎、渲染器、时序、镜头、人物位置和实际捕获来源 |
| `functional-checks.json` | 24 项输入、路线、反射投影和网格朝向检查，全部通过 |
| `video-integrity.json` | 完整解码 905 帧，0 黑帧；这是媒体完整性检查，不是艺术评分 |
| `runtime-sha256.json` | 本轮运行源码、材质、模型、图集与导入设置的 SHA256 |

影片由 Godot Movie Maker 实际渲染，再由 FFmpeg 编码，没有插帧或改变动作播放速度。固定模拟时间步使动作保持原速；不能用录制速度或影片 30 fps 推断前台运行性能。原始 AVI 留在 `Local/Harbor-v02/`。

## 相对基线的变化

原基线为 [`Harbor-v01/20261009-baseline/`](../Artifacts/Harbor-v01/20261009-baseline/)，之前已经导入模型和人物并运行过，不重新提交已完成的任务。

- 水改为实际场景深度驱动的浅深过渡与折射，半分辨率反射视口绘制真实树、船、建筑和人物。去掉人为船边椭圆亮圈，波纹改为稀疏波峰与少量码头桩边涟漪。
- 修正反射采样：透明背景保留的天空 RGB 曾在物体边缘产生白色描边，改用不透明／透明分明的反射源和 Alpha 加权过滤，实际画面中已消除该圈边。
- 树与人物从不受光贴片改为原生三维受光、深度遮挡和投影；精灵统一保持竖直朝向，反射与阴影视图不各自转向光源。树根固定，风只推动树冠上部。
- 调整弯曲岸线、前景树、步道、仓库与码头的关系；新增一种同画法柳树，减少所有树同形的重复感。植被与人物源图保持原始透明背景。
- 新木材贴图用于船体、弧形甲板、码头、木箱和桶；补充帆骨、索具、船舱细节。修正甲板和地形三角面方向。运行纹理生成 mipmap，消除先前木纹缩小时的明显闪点。
- 同一场景提供白昼与傍晚灯光。全程关闭强景深与辉光，没有用它们遮盖基础素材。
- 固定路线沿码头原路折返，避开新货物；已检查 60 秒内连续两圈不会卡在岸水边或木桶上。

## 当时的视觉判断（后续已被用户否定）

实际 PNG 和影片关键片段按 1 倍速抽查后，水岸、船旁接触与场景明暗比基线更连贯，木材和树形的重复问题有所改善。码头中央路径清楚，镜头轻移时未在所查片段中发现原先的明显木纹闪点或白色反射描边。

仍然不足的三处：

1. 仓库仍只有一个 HY 来源模型，大小／角度变化不能代替真正的建筑家族。草地与留白也还偏均匀，需要进一步布置与形体设计。
2. 船舱、岸石和遮棚仍偏简，船的局部材质比轮廓成熟。需要进一步统一这些物体与手绘角色、树木的造型语言。
3. 人物已接收环境与局部灯光，但没有制作逐帧体积法线、衣料／金属区域蒙版，尚未达到参考中 SpriteLamp 式的材质高光表现。

当前使用固定朝向镜头与单面绘制植物，不承诺任意环绕视角。反射增加一次场景绘制，大场景性能尚未专项测量。没有天气季节系统、可操纵海战或战斗逻辑。

## 来源与成本

补充参考的观看范围、实现思路和复用边界见 [研究记录](GODOT_REFERENCE_STUDY_20261009.md)。公开 `winkidney/hd-2d-godot` 的 NOTICE 保留项目许可选择，因此只用于学习，没有复制其代码、美术或角色进运行工程。

沿用已完成 HY-3D 仓库任务 `1499765997237706752`；上轮按 20 个免费积分的 Normal 模式提交，`query-response.json` 已记录 completed，原模型与下载校验仍在 `Assets/HarborTrial/v01/Models/warehouse-a/`。初始 `generation-state.json` 的 queued 是提交时快照，不应据此重发。

本轮没有新 Tencent TokenHub / MiniMax 任务，没有充值、购买插件或收费重试。仅通过内置 imagegen 新增以下两项，工具未返回货币金额，不虚报为“免费”或并入腾讯账单：

- [木材原图与完整提示词](../Assets/HarborTrial/v02/production-record.json)：`Working/weathered-timber.png`，用于真实网格的 albedo。
- [柳树原图与完整提示词](../Assets/HarborTrial/v02/willow-production-record.json)：`Working/waterside-willow.png`，参考已有树的画法生成变体。

已认可的 MiniMax Library PNG／图集／原视频没有改写；新的导入设置只作用于 Godot 运行副本。场景名、建筑和船的外观均为架空视觉候选，没有采用未经考据的具体史实断言。

## 复现

```powershell
./tools/godot-harbor.ps1 -Mode Check
./tools/godot-harbor.ps1 -Mode Stills -OutputDir D:/Work/project/joker/chess/Artifacts/Harbor-v02/new-stills
./tools/godot-harbor.ps1 -Mode Record -OutputDir D:/Work/project/joker/chess/Artifacts/Harbor-v02/new-recording
```

捕获目录必须新建，脚本拒绝覆盖旧证据。不得把功能检查、解码统计、素材数量或模型面数当成美术合格的依据。
