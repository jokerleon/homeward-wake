# 2026-10-09 · 港口第三轮视觉样片

在用户否定 v02、完成深入研究并授权继续后，重做了以岸台、人物通路和商船为主的 Godot 场景。用户随后明确认可：基本满足港口美术风格验证，整体感觉对味，细节可后续优化。这不等于航行、海战或所有素材已经通过。

[本地评审页](http://127.0.0.1:8374/Harbor-v03/20261009-review/) · [评审文件](../Artifacts/Harbor-v03/20261009-review/index.html) · [30 秒影片](../Artifacts/Harbor-v03/20261009-review/quay-tour.mp4)

![第三轮白昼 Godot 实机图](../Artifacts/Harbor-v03/20261009-review/01-quay-day.png)

## 画面与实际改动

- 将旧草岸总览改成石岸台、阶梯、围合建筑、装卸处、木码头与登船踏板。近处屋檐和树形成遮挡，商船占据主要体量，独立远岸绘制层建立背景。
- 新木、石、瓦、墙材质共用一张协调的像素绘制素材板；树和船的输入也参照这套画法。材质区域分别建立 mipmap，避免图集串色。修正了台面与铺地重叠导致的细条纹。
- 建筑、岸台、阶梯、码头与踏板是三维几何。商船是本轮生成后整理的真正 GLB，保留船体、舱、桅杆、帆和索具，并非将船图贴进截图。
- 人物使用保留的 MiniMax 动作与固定根点，只调整运行时采样和受光呈现，未修改 Library 源图。低俯角下旧屏幕投影算法会把部分斜向移动判成横向，现改为相机水平朝向判断，分别检查八方向输入。
- 水使用场景深度与真实反射视口，降低透底和反射强度，保持透视反射相机同步。人物可走上登船踏板并折返；尚不能自由漫游整艘船，更没有海战或接舷战斗。
- 白昼与暮色共用同一场景。近景景深、辉光均关闭；可开关的远景景深从 65 个世界单位后开始，强度 0.025。评审页保留同一相机、灯光、姿态的开关对照。

主镜头保持固定朝向，透视 FOV 30°。固定姿态测得约 1.94 个世界单位的角色高度投影为 87 像素／900 像素画面；这说明取景尺度，不是美术评分。角色外形、尺寸和港口仍为候选，不代表确定新主角或具体历史地点。

## 运行与验证

    ./tools/godot-quay.ps1 -Mode Play
    ./tools/godot-quay.ps1 -Mode Play -NoDof
    ./tools/godot-quay.ps1 -Mode Check

WASD／方向键移动；1／2／3 切换总景、码头、人物镜头；T 切昼暮；P 开关远景焦外；G 固定路线漫步；Tab 隐藏文字；F12 截图。手动输入立即接管，不等待片段结束。

Godot 默认场景现为 quay.tscn。旧 harbor.tscn、运行资源和 v02 证据保留，旧入口 godot-harbor.ps1 显式选择旧场景，不会误录新版的不同时间线。

本轮实际使用 Godot 4.7.2 stable、Vulkan Forward+、RTX 4090。PNG 为 1600×900，影片为 1280×720、30 fps、30.17 秒，由 Godot Movie Maker 录制后编码，没有插帧或动作加速。原始 AVI 位于 Local/Harbor-v03/。

- 26 项功能检查通过，覆盖八方向首次输入、松键、接管、透视反射、岸水阻挡、阶梯、挡土墙、踏板折返和景深开关。60 秒路线检查经过 21 次路点切换，最长停顿为切换路点的 1 帧。
- 影片完整解码 905 帧，0 黑帧。浏览器以 1 倍速播放，并抽查白昼、踏板、暮色与近景阶段；未声称逐帧人工观看全部影片。
- 静帧中主要船体和人物保持可读，地面重叠条纹已消失。上述完整性、数量和功能检查都不代替美术判断。

证据包括 [捕获记录](../Artifacts/Harbor-v03/20261009-review/capture-report.json)、[功能检查](../Artifacts/Harbor-v03/20261009-review/functional-checks.json)、[影片完整性](../Artifacts/Harbor-v03/20261009-review/video-integrity.json) 和 [运行文件散列](../Artifacts/Harbor-v03/20261009-review/runtime-sha256.json)。

重新捕获必须使用新目录：

    ./tools/godot-quay.ps1 -Mode Stills -OutputDir D:/Work/project/joker/chess/Artifacts/Harbor-v03/new-stills
    ./tools/godot-quay.ps1 -Mode Record -OutputDir D:/Work/project/joker/chess/Artifacts/Harbor-v03/new-recording

## 腾讯任务与费用

用户明确授权本轮腾讯支出上限 **100 元**。充值后实际检查到可用余额 109.51 元、HY-3D 免费包已用 100／100 积分、服务运行中且后付费已开启；额外 9.51 元不构成本轮授权。代理没有操作充值或后付费设置。

本轮仅提交 **1 个**腾讯任务：

| 项目 | 记录 |
| --- | --- |
| 内容 | 商船 merchant-ship-a |
| 任务 ID | 1499995051698167808 |
| 提供方／模型 | 腾讯 TokenHub，hy-3d-3.1 |
| 参数 | Normal，PBR 关闭；未加自定义面数、多视图或额外格式 |
| 状态 | completed，原 GLB／OBJ／预览图已下载并校验 |
| 预算占用 | 20 积分 × 0.12 元 = **预计 2.40 元** |
| 剩余授权 | **97.60 元** |
| 结算状态 | 日结账单尚未对账，2.40 元按全额保留，不冒称已取得最终账单 |

价格依据为本次查阅的 [腾讯官方计费表](https://cloud.tencent.com/document/product/1804/123461)，参数按 [TokenHub HY-3D 指南](https://cloud.tencent.com/document/product/1823/137181) 核对。

[预算台账](../Assets/HarborTrial/v03/tencent-budget.json) 与 submit_harbor_model.py 在提交前保留费用，包含不确定结果的保留金额不得超过 100 元；即使台账被改大，当前脚本也不会扩大该上限。没有自动重试、充值或批量任务。

原模型约 50 万面，本地用 Blender 整理到 10 万面、1536 像素材质、约 8.64 MB GLB；试用长度为 16 个 Godot 世界单位。源模型未改写，见 [转换记录](../Assets/HarborTrial/v03/Models/merchant-ship-a/runtime-preparation.json)。此尺寸是场景比例选择，不是历史船型结论。

## 内置 imagegen 素材

另有 **4 个内置 imagegen 源素材**，与腾讯积分分开记录。工具未返回货币价格，不将其虚报为“免费”。

| 原始文件（均在 Assets/HarborTrial/v03/Working/） | 用途 | 提示词记录 |
| --- | --- | --- |
| material-atlas.png | 木、石、瓦、墙同族素材板 | [完整提示词](../Assets/HarborTrial/v03/production-record.json) |
| broadleaf-tree.png | 透明植被贴片 | 同上 |
| merchant-ship-reference.png | 图生 3D 输入，不直接作为运行船图 | 同上 |
| far-shore.png | 独立远岸层，三次实例化延展背景 | [完整提示词](../Assets/HarborTrial/v03/far-shore-production.json) |

运行资源位于 Godot/assets/quay-v03/。没有新的 MiniMax 任务，没有重发旧仓库或失败攻击，没有导入参考作者的美术／代码。所有新输入均为原创架空设计，不声称是经过考据的明代复原，继续遵守 [历史来源规范](HISTORICAL_SOURCE_POLICY.md)。

## 当前判断与限制

本轮对主体、前后景、材质关系和人物取景作出了实质重构，已基本通过用户对港口风格的验证。下列限制继续保留。

1. 人物没有逐帧体积法线，局部灯光对衣褶的塑形仍弱；两名静止人物仅为临时比例参照。
2. 建筑窗格、檐口和铺地仍有重复规律；当前是样片构件，尚未形成完整建筑家族。
3. 远岸采用绘制层，适合当前固定朝向与有限移动，不支持据此推断全向旋转。水面倒影与波光仍有风格化简化。
4. 生成船适用于当前观看角度；完整甲板碰撞、船帆独立动画、航行／炮战和海战取景均未验证。

当前重点已转入 RPG 战斗、养成、剧情与船队经营的讨论。后续精修人物法线时仍从一个姿态和短动作开始，不因风格认可就批量扩图。
