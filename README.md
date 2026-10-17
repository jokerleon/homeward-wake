# 架空大明远洋 · Godot HD-2D

最新：《归港的人》首版玩法已接通招募、改装、原海域交战／脱战、真实甲板布阵与自动即时战斗、成长和归港。场景与水体延续 v03，独立人物立绘、正式攻击动画和演出尚未完成。

```powershell
./tools/godot-demo.ps1 -Mode Play
```

- [首版操作、运行证据与尚缺内容](docs/DEMO_FIRST_PLAYABLE_RESULT_20261010.md)
- [人物能力、对白与炮弹规格](docs/DEMO_FIRST_PLAYABLE_SPEC_20261010.md)

以下为原港口样片与设计阶段记录；此前“尚未开始玩法／仍在分析”的状态已由上述首版运行结果更新。

港口 v03 已获用户认可：基本满足美术风格验证，细节可后续优化。航行与海战效果另行验证。当前先规划一个短故事 Demo，覆盖控制、属性、同伴入队、海战与接舷；操作简化、内容先固定，尚未开始完整游戏或战斗系统。
首作从明朝出发，包含远洋与欧洲；架空历史是候选，穿越不再是必选设定。
当前战斗方向为默认自动即时战斗、选单位进入子弹时间下令。人物战进入专用场景并布阵；海战在原航行海域发生，甩开追击后继续航行。仍处于分析阶段。

RPG、NPC 对话、对话框、场景演出与剧情推进已确认；具体战斗模式、养成和剧情仍待讨论。

- [最新：自动即时战斗、子弹时间与海上遭遇分析](docs/COMBAT_AUTOMATION_AND_ENCOUNTERS_20261010.md)
- [短篇 Demo 剧情、玩法与素材制作方案](docs/DEMO_STORY_AND_PRODUCTION_PLAN_20261009.md)
- [整体战斗、养成、剧情与船队经营讨论稿](docs/GAME_DESIGN_DISCUSSION_20261009.md)
- [第三轮实机画面、操作与费用](docs/GODOT_VISUAL_TRIAL_V03_20261009.md)
- [第三轮评审页与原速影片](Artifacts/Harbor-v03/20261009-review/index.html)
- [v02 视觉复盘、实际对照与重新定向](docs/GODOT_HD2D_DIRECTION_RESET_20261009.md)
- [图片对照页：官方构图、相机实验、人物受光](Artifacts/HD2D-Research-20261009/index.html)
- [HD-2D 美术研究与 FrameRonin 评估](docs/GODOT_HD2D_VISUAL_RESEARCH_20261008.md)
- [补充 B 站参考与复用结论](docs/GODOT_REFERENCE_STUDY_20261009.md)
- [港口样片：实机结果、操作与已知限制](docs/GODOT_VISUAL_TRIAL_20261009.md)
- [当前重启决定与计划](docs/GODOT_REBOOT_PLAN.md)
- [MiniMax 人物与八方向流程](docs/CHARACTER_PRODUCTION.md)
- [本次清理与保留边界](docs/CLEANUP_20261008.md)

旧项目只保留 MiniMax 人物线的有效素材与处理流程。旧环境资产、模型和工具已清理。
原用户参考及必要历史证据已移出工作区，不作为新画风或新任务的默认依据。

Godot 4.7.2 便携文件位于 `Local/Godot/4.7.2/`，官方 SHA-512 校验通过，已在 RTX 4090 上运行 Forward+。
运行工程是 `Godot/project.godot`，只包含选用的运行资源。没有购买 FrameRonin 插件。

```powershell
./tools/godot-quay.ps1 -Mode Play
```

WASD／方向键移动；1／2／3 切换总览、码头、人物镜头；T 切昼暮；P 开关远景焦外；G 固定路线漫步；Tab 隐藏文字；F12 截图。
当前评审在 `Artifacts/Harbor-v03/20261009-review/`。腾讯总预算上限 100 元，本轮仅生成一艘船，预计 2.40 元；完整台账与素材提示词见上方报告。
旧 v02 位于 `Artifacts/Harbor-v02/20261009-final/`，保留作为已被否定的基线；旧入口 `godot-harbor.ps1` 显式运行旧场景。
