# 当前素材

2026-10-17：素材同步边界与清理规则已经单独整理，见
[素材存储、同步与清理规则](../docs/ASSET_STORAGE_AND_CLEANUP.md)。

`Assets/` 是原始素材库，不进入 Git。只把 `Godot/` 实际引用的运行副本纳入
版本管理。生成素材清单使用：

```powershell
./tools/assets/inventory_assets.ps1 -Roots Assets,Artifacts
```

清单默认输出到 `Artifacts/asset-inventory/`。清理前先隔离，不直接删除已接受、
已被否定、来源不明或仍被运行工程引用的素材。

2026-10-08：仅保留 `Characters/` 中 MiniMax 人物制作与八方向流程相关的内容：
原视频、输入图、透明帧、图集、源配方、任务/费用记录及离线预览。

保留流程不等于沿用主角身份或全部旧画风。2026-10-09 已将选用的人物图集接入 Godot 小港口。
其他旧环境模型和试验已清理；原用户参考与必要证据已移出工作区。

`HarborTrial/v01/` 是用户批准视觉执行后新增的树、地表、模型输入与 HY-3D 仓库任务记录。
`HarborTrial/v02/Working/` 是这次新增的木材贴图和柳树候选，源提示词与费用披露在同级 JSON 中。
运行副本放在 `Godot/assets/`。没有覆盖已认可的 Characters/Library 源帧或重发仓库模型任务。

后续评审：v02 美术已被用户否定，HarborTrial 素材仍为候选。下一轮先统一画法与构图，见 [最新复盘](../docs/GODOT_HD2D_DIRECTION_RESET_20261009.md)，不按旧布局批量补图或生成整套人物法线。

v03 已新增同族材质板、树、商船输入与远岸层，原始 PNG 及提示词保留在 `HarborTrial/v03/Working/` 和同级 JSON。`Models/merchant-ship-a/` 保留已完成任务 1499995051698167808 的原模型与回执，不得重发。实际画面与本轮 100 元预算台账见 [第三轮记录](../docs/GODOT_VISUAL_TRIAL_V03_20261009.md)；目前预计占用 2.40 元。

入口：[人物流程](../docs/CHARACTER_PRODUCTION.md) · [美术研究](../docs/GODOT_HD2D_VISUAL_RESEARCH_20261008.md)。
