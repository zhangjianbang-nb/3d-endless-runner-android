# 3D Endless Runner (Android)

Godot 4 / GDScript 竖屏 3D 无尽跑酷游戏。三条车道、左右滑变道、上滑跳跃、躲避障碍、收集金币、速度渐增、计分与最高分持久化，含主菜单/暂停/游戏结束 UI 与程序化音效。全部 3D 模型用内置几何体程序化生成，零外部美术资源。

## 玩法
- 左右滑 / ←→：变道；上滑 / ↑ / 空格：跳跃
- 撞障碍结束，吃金币计分，速度随分数渐增（8→24）
- 最高分经 `user://highscore.cfg` 持久化（原子写 + .bak 降级链）

## 运行
用 Godot 4.x 打开项目根目录（project.godot 在顶层），或导出 Android APK（export_presets.cfg 已配竖屏 720×1280 + arm64）。

## 校验
```bash
python3 scripts/validate.py          # 结构校验（VALIDATION PASS, exit 0）
python3 -m pytest test_project_validation.py -q   # 15 项需求覆盖断言
```

## 可靠性设计（reliability F-1/F-3, SLO-1）
- 存档原子写：.bak 轮转 → .tmp → rename 提交；读档降级链 主档→.bak→默认值
- Android 生命周期挂钩：PAUSED/RESUMED/GO_BACK/CLOSE → 暂停 + 立即落盘 + clean_exit 位
- events.jsonl 本地结构化事件日志（score_saved/save_recovered/crash_suspected 等）

## 产出方式
由 ai-company 多部门流水线产出：supervisor→architect→adversary(3轮对抗评审)→reliability→performance→coding，设计文档（架构/可靠性/性能设计）见 docs/changes/ 变更快照。
