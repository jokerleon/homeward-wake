# 人物素材与 Godot 视觉试片工具

人物线保留视频转精灵与八方向流程的 8 个 Python 脚本及两个离线 PowerShell 入口。
2026-10-09 已增加 Godot 样片接入与运行入口；旧 UE 工具仍已退役。

- `tokenhub_character_video.py`：历史 TokenHub MiniMax 适配；新提交显式提供模型、规格与当前报价，本轮未调用。
- `package_character_motion.py`：透明帧、根点、图集与动作元数据。
- `analyze_shenyan_fullset.py`、`build_shenyan_fullset.py`：原沈砚切点与镜像处理样例，不是新角色默认配方。
- `validate_character_motion_pack.py`、`validate_character_motion_set.py`：离线像素、方向、镜像与事件验证，无 UE 依赖。
- `preview_character_motion_set.py`：离线检查页、GIF 与视频。
- `package_character_motion_set.py`：通过当前离线验证后打包，无需 UE 原生报告。

`character-motion.ps1` 仅有 Package/Validate；`character-motion-set.ps1` 仅有 Validate。
新素材先用 Working，不为整理而重打包既有合格图片。
依赖 Python、Pillow、NumPy、OpenCV 和 FFmpeg，本机依赖在仓库外。

当前说明见 [人物流程](../docs/CHARACTER_PRODUCTION.md)。

当前 Godot 入口：`godot-quay.ps1 -Mode Play|Check|Stills|Record`；`-NoDof` 可关闭景深。
旧 `godot-harbor.ps1` 保留并显式运行 v02，不随默认场景切换。
Play 打开样片；Check 检查输入/路线/反射投影/网格朝向；Stills 与 Record 用实际 GPU 视口捕获。
Record 输出约 30 秒的 720p/30fps 视频，并保留原始 AVI 在 Local；固定时间步用于原速动作演示，不是运行性能基准。
证据目录须全新，脚本拒绝覆盖旧目录。

`prepare_godot_harbor.py` 只把已选用图集复制进运行工程；`prepare_harbor_models.py` 整理已有 HY 模型。
`tokenhub_3d.py` 留存有任务去重记录的远程适配，不由运行或捕获脚本自动触发收费生成。

v03 新增 prepare_quay_ship.py 做 Blender 模型整理；新收费提交使用 submit_harbor_model.py，受 Assets/HarborTrial/v03/tencent-budget.json 的 100 元本轮授权约束。先保留费用再提交，不确定结果仍占预算；不自动重试、充值或修改后付费设置。
